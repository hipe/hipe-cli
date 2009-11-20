#!/usr/bin/env ruby
require File.dirname(__FILE__)+'/../cli'
require 'hpricot'
require 'csv'
require 'builder'
require 'json/pure' # the slower more widely available pure ruby variant (we don't need performance here)

module Hipe
  module Migrate
    class MigrateException < Exception; end
    class MigrateFailure < Exception; end    
    class Migrate
      ASCII_A = 65
      include Cli::App
      def initialize
        cli_pre_init
                
        @line_patterns  = []    # this is the main workhorse of the whole thing
        @csv_line       = nil   # the current line we are on, when parsing csv       
        @csv_row_arr    = nil   # an array of the row being currently processed
        @field_rename   = {}    # an option -- see :field_rename below
        @skip_cols      = nil   # an option -- see :skip_cols below
        @field_names    = nil   # created once we hit a 'fields' row per the option
        
        # -------------- Huge crazy data structures to define our CLI interface -------------
        @cli_description = "Pulls in data from excel sheets and spits it out to XML"        
        @cli_commands[:help]       = @@cli_common_commands[:help]
        @cli_global_options[:debug] = @@cli_common_options[:debug]
        @cli_global_options[:client_log] = {
          :description => 'A filename for client-specific warnings and notices.',
          #:validations => [:file_must_not_exist],  nah, overwrite the file
          :action => {:action=>:open_file, :as=>'w'}
        }
        @cli_commands[:make_transform_scaffold] = {
          :description => 'generates a transformation file template '+
            '(ruby code) and outputs it to STDOUT.'
        }
        @cli_commands[:make_dirty_xml] = {
          :description => "take an existing xml file you want to add to, mark existing elements as dirty. "+
            "(outputs to STDOUT)",
          :required_arguments => [
            {  :name => :XML_IN,
               :description => "the file you are trying to emulate and add to",
               :validations => [:file_must_exist],
               :action    => {:action=>:open_file, :as=>'r'}
            },
            {  :name => :XPATH,
               :description => "the path to the elements you want to mark as dirty",
            }
          ]
        }
        @cli_commands[:make_clean_xml] = {
          :description => %{to be used in conjunction with "make-dirty-xml." After you finish adding data to the xml file, this removes all objects that remain marked as "dirty" (stale), that is all objects that weren't added by or updated by the data import.  (outputs to STDOUT)},
          :required_arguments => [
            {  :name => :XML_IN,
               :description => "the xml file you are pruning of dirty entries",
               :validations => [:file_must_exist],
               :action    => {:action=>:open_file, :as=>'r'}
            },
            {  :name => :XPATH,
               :description => "the path to the elements you want to mark as dirty",
               :validations => [
                 {:type=>:regexp, :regexp=>%r{(?:/?[\da-z_\-:]+)+}i, :message=>'your xpath cannot end in a slash '+
                   'because w\'re gonna add some stuff after it.'
                  }
                ],               
            }
          ]
        }        
        @cli_commands[:csv_to_xml] = {
          :description => 'the csv will be run through the filter and data will be added '+
          'to an existing xml document (by calling user-defined methods.) Outputs result to STDOUT.',
          :options => {
            :fields => { 
              :description => "comma-separated list of row number(s) that indicate the field names",
              :validations => [
                {:type=>:regexp, :regexp=>/^\d+(?:, *\d+)*$/, :message=>'must have only numbers and commas'}
              ]                
            },
            :field_rename => {
              :description => "rename a field from as it appears in the document, e.g. --field-rename=\""+
              "{The Original Field Name:newname}\".  You can indicate this option multiple times for multiple fields.",
              :validations => [
                { :type=>:jsonesque,
                  :message=>'must be of the form "Orig Name:New Name". Couldn\'t parse: "%input%"'
                }
              ]
            },
            :skip => {
              :description => "comma-separated list of line numbers to skip, starting at line 1.  If you want to also skip blank lines (you usually do), include 'blank', e.g. \"--skip=1,2,blank\"",
              :validations => [
                {:type=>:regexp, :regexp=>/^(?:\d+|blanks?)(?:, *(?:\d+|blank?))*$/i, :message=>'must have only numbers (or "blank") and commas'}
              ]
            },
            :skip_cols => {
              :description => "comma-separated list of *column letters* (not names) to completely disregard. ("+
              "this feature was added only b/c of a bug in Apple Numbers in the \"export to CSV\" function)",
              :validations => [
                {:type=>:regexp, :regexp=>/^[a-z](?: *, *[a-z])*$/i, :message=>'It must be a comma-separated '+
                  'list of column letters (e.g "A,C,D") (sorry for now limit 26 columns!)'
                }
              ]
            },            
            :section => {                
              :description => 
              "You can indicate that when a certain cel appears as the only value on a row it is a section indicator "+
              "which should be \"flattened\" into a virtual field for the subsequent rows, until the next such section, "+
              "in which case the virtual field will become that value. e.g. --section='A:state'",
              :validations=>[
                { :type=>:jsonesque,
                  :message=>'Invalid specifiction -- please follow the pattern "AA:11 field_name"'
                }
              ]
            },
            :stop => { :description => "the row before this one is the last one processed.",
              :validations => [ {:type=>:regexp, :regexp=>/^\d+$/} ]
            }
          },
          :required_arguments => [
            { :name => :CSV_FILE, 
              :description => 'the csv we are processing',
              :validations => [:file_must_exist],
              # :action => {:action=>:open_file, :as=>'r'} #nope
            },
            { :name => :STARTING_XML_FILE, 
              :description => 'the xml you use as a starting point for your output',
              :validations => [:file_must_exist],
              :action => {:action=>:open_file, :as=>'r'}              
            }
          ] #end required
        } #end command
        cli_post_init
      end
    
      protected 
      
      def cli_process_option_skip given_opts, k
        line_numbers = given_opts[:skip][0].split(/, */)
        given_opts[:skip] = line_numbers
        line_numbers.each do |i|
          case i
            when /^\d+$/
              @line_patterns << {:line_number => i.to_i, :action => :skip}
            when /^blanks?$/i
              @line_patterns << {:regexp => /^,*$/, :action => :skip }
            else
              raise CliException.new("don't know what it means to skip \"#{i}\"")
          end
        end
        cli_log(6){ "added 'skip' line processors. it has "+@line_patterns.count.to_s+" now." }
      end
      
      def cli_process_option_skip_cols given_opts, k
        @skip_cols ||= {}
        # turn "A,B,C" into {0=>true,1=>true,2=>true}
        @skip_cols.merge! Hash[given_opts[:skip_cols][0].split(/ *, */).map{ |x| [x.upcase[0]-ASCII_A,true]}]
        cli_log(6){ "added 'skip_cols' line processors. skipping: "+@skip_cols.keys.join(',')  }
      end      
      
      def cli_process_option_stop given_opts, k
        @line_patterns << {:line_number => given_opts[k][0].to_i, :action => :stop }
      end
      
      def cli_process_option_fields(given_opts, k)
        line_numbers = given_opts[:fields][0].split(/, */).map{|s|s.to_i}
        given_opts[:fields] = line_numbers
        line_numbers.each do |i|
          @line_patterns << {:line_number => i, :action => :fields}
        end
        cli_log(6){ "added #{line_numbers.count} \"field\" line processors. "+
          "it has "+@line_patterns.count.to_s+" now."
        }
      end
      
      def cli_process_option_field_rename(given_opts, k)
        @field_rename.merge! given_opts[:field_rename]
        cli_log(6){ "added \"field_rename\" filter. it is now "+@field_rename.inspect }
      end      
      
      def cli_process_option_section(given_opts, k)
        given_opts[:section].each do |col, field_name|
          raise Exception.new("For now only columns A-Z are supported, not '#{col}'.") unless /^[A-Z]$/ =~ col
          number_of_commas = (col[0]-65) # "A" is ascii number 65
          @line_patterns << { 
            :regexp     => Regexp.new('^'+(','*number_of_commas)+'([^,]+),*$'), 
            :action     => :section,
            :field_name => field_name
          }
          cli_log(6){"added 'section' line processor. it has "+@line_patterns.count.to_s+" now."}
        end
      end
      
      def cli_process_option_client_log(a,b); end  # nothing to do! file already opened
      
      def xml_builder
        return Builder::XmlMarkup.new(:indent=>2, :margin=>4)
      end

      #def csv_to_xml_start; 
      #end

      def client_log msg
        cli_file(:client_log).puts(msg) if cli_has_file(:client_log)
        STDERR.puts(msg)  # we multiplex it out to our own private, more detailed log
      end
      
      ## can be overridden by client
      #def csv_to_xml_finish; 
      #  STDOUT << @xml_doc.to_s if @xml_doc
      #end
      #
      def match_line
        matching_patternData = nil           
        do_delete = false
        row_asString = @csv_row_arr.join(',')
        @line_patterns.each_with_index do |pattern_data,pattern_index|
          if (pattern_data[:line_number])  # could be optimized with procs at beginnning of program!
            if (@csv_line==pattern_data[:line_number]) 
              matching_patternData = pattern_data
              @line_patterns.delete_at(pattern_index)
            end
          elsif (pattern_data[:regexp])
            if pattern_data[:regexp] =~ row_asString
              matching_patternData = pattern_data              
            end
          else
            raise MigrateException.new("don't know how to process line_pattern: "+pattern_data.inspect)
          end
          break if matching_patternData
        end
        matching_patternData
      end
      
      def cli_execute_csv_to_xml
        #csv_to_xml_start
        @xml_doc = Hpricot cli_file(:STARTING_XML_FILE)
        @csv_rows = CSV.read @cli_arguments[:CSV_FILE]
        client_log(%{=========== Processing CSV (Spreadsheet) File: "#{@cli_arguments[:CSV_FILE]}"==========})        
        if (@csv_rows.size < 1)
          raise MigrateFailure.new("unable to retrieve one or more rows from \"#{@cli_arguments[:CSV_FILE]}\"") 
        end        
        begin
          cli_log(4){ spp("\000LINE PATTERNS", @line_patterns) }
          @csv_rows.each_with_index do |@csv_row_arr,line_index| 
            @csv_line = ( @csv_index = line_index ) + 1   
            do_this = ( matching_patternData = match_line ) ? 
               matching_patternData[:action].to_s : 'default'
            if (@field_names.nil? && 'default'==do_this)
              raise MigrateFailure.new("We can't process row #{index+1} because we haven't processed "+
              "the field names yet.  Please check that your --fields pattern is hitting before any content "+
              "rows are by running with -ddddd debugging."+
              " (the row: \""+row.join(',')[0,60]+"...")              
            end
            cli_log(4){ "\000line #{@csv_line} doing \"#{do_this}\" with: \n"+
             (@csv_row_arr.join(','))[0,77]+'...'
            }
            next if do_this == 'skip' # small optimization
            break if do_this == 'stop' # instead of catch/throw
            use_row = @field_names ? get_processed_row : @csv_row_arr
            __send__('csv_process_row_'+do_this,matching_patternData,use_row,line_index)
          end
          #csv_to_xml_finish
          STDOUT << @xml_doc.to_s
        rescue MigrateFailure => e
          puts e.message
        else
          client_log(%{============== Finished Processing CSV (Spreadsheet) File: "#{@cli_arguments[:CSV_FILE]}"=============})        
        end
      end
      
      def get_processed_row
        use_row = {}
        @field_names.each do |column_index,name|
          name = @field_rename[name] if @field_rename[name]
          if @repeated_field_names[name]
            use_row[name] ||= []
            use_row[name] << @csv_row_arr[column_index]
          else
            use_row[name] = @csv_row_arr[column_index]
          end
        end
        @repeated_field_names.keys.each do |name|
          if (1 == use_row[name].uniq.size)
            use_row[name] = use_row[name][0]
          else
            first_nonNilValue = nil
            use_row[name].each_with_index do |v, i|
              if (!v.nil? && first_nonNilValue.nil?)
                first_nonNilValue = v
                break
              end
            end
            client_log(
              %{WARNING: on line #{@csv_line} you have #{use_row[name].size} "#{name}" fields with }+
              "different values: ("+use_row[name].map{|x| %{"#{x}"}}.join(', ')+"). "+
              %{Using the first non-blank value or null: "#{first_nonNilValue}"}
            )
            use_row[name] = first_nonNilValue
          end # end if different values
        end # each repeated field name
        use_row
      end
      
      # user will almost always want to override this.  this is to serve as a simple example
      def csv_process_row_default(pattern_data, row, index)
        STDOUT << @xm.row(:index => index){
          row.each do |key,value|
            @xm.__send__(key,value) unless value.nil?
          end
        }
      end      
      
      def csv_process_row_section(pattern_data, row, index)
        @extra_fields ||= {}
        @extra_fields[pattern_data[:field_name]] = @csv_row_arr[0]
        cli_log(3){"extra added fields with --section option): "+@extra_fields.inspect}
      end
      
      # note this allows for repeats of the same fieldname!
      def csv_process_row_fields(pattern_data, row, index)
        orig_row = @csv_row_arr.clone

        # counting back from the end, remove blank cels.  
        # but if there are blank cells in the middle, leave them (ick!)
        # i need to test if this step is even necessary #*
        [*0..(@csv_row_arr.size-1)].reverse.each { |i| orig_row.delete_at(i) if orig_row[i].nil? }

        # in case we have columns we are skipping, we will make a hash that maps 
        # column numbers to field names, called "field_names". note the keys are integers
        # that correspond to column offsets, but the aren't necessarily contiguous, hence hash not array.
        @field_names = Hash[Array(*[0..orig_row.size-1]).zip(orig_row.map{|x|normalize_fieldname(x)})]
        @field_names.reject!{|k,v| @skip_cols[k]} if @skip_cols
                
        # in the wierd cases where a document repeats the same field name but might have different values,
        # we want to be able to report it and make an intelligent guess as to which column we want to use.
        @repeated_field_names = {}
        if (@field_names.size > @field_names.values.uniq.size)
          # we don't care which column it's in          
          @field_names.each{|k,v| @repeated_field_names[v]||=0; @repeated_field_names[v]+=1;} 
          @repeated_field_names.delete_if{|k,v| v==1}
        end
      end
      
      def normalize_fieldname(name)
        return name.to_s.gsub(/[^a-z0-9_]/i, '').downcase
      end
      
      # not sure about this one
      def cli_execute_make_transform_scaffold
        File.open(File.dirname(__FILE__)+'/data/transform_template.rb.tmpl','r') do |f|
          body = f.readlines.join('')
          body.gsub!('%%timestamp%%',Time.now.strftime("%a, %d %b %Y"));
          body.gsub!('%%app name%%',cli_program_name);
          STDOUT.syswrite body
        end
      end #def

      def cli_execute_make_dirty_xml
        @xml_doc = Hpricot cli_file :XML_IN
        els = @xml_doc.search(@cli_arguments[:XPATH])
        if (0==els.count)
          raise MigrateFailure("Sorry, coundn't find any elements with \"#{@cli_arguments[:XPATH]}\"")
        end
        els.attr('cleanliness','dirty')
        print @xml_doc.to_s
      end
      
      def cli_execute_make_clean_xml
        @xml_doc = Hpricot cli_file :XML_IN
        all_path = @cli_arguments[:XPATH][0]
        dirty_tail = %{[@cleanliness='dirty']}
        all_els = @xml_doc.search(all_path)
        dirty_els = all_els.search dirty_tail
        if (0==dirty_els.count)
          cli_log(0){%{There were no elements matching "@cli_arguments[:XPATH]"}}
        else
          total_count = all_els.count
          dirty_count = dirty_els.count
          client_log(%{Removing #{dirty_count} elements})
          dirty_els.each do |el|
            client_log("\n\nRemoving old element: \n"+el.to_html)
          end
          dirty_els.remove()
          new_count = @xml_doc.search(all_path).count
          client_log(%{Removed #{dirty_count} old elements from a total of #{total_count} to leave a remaining }+
            %{#{new_count} items.}
          )
        end
        print @xml_doc.to_s        
      end
      
      def opt_or_arg_action_open_file(action, var_hash, var_name)
        if :hpricot==action[:as]
          @cli_files[var_name] = {
            :fh       => Hpricot(File.open(var_hash[var_name],'r')),
            :filename => var_hash[var_name]
          }
        else  
          super
        end
      end      
      
    end #class Migrate
  end #module Migrate
end #module Hipe

Hipe::Migrate::Migrate.new.cli_run if $PROGRAM_NAME == __FILE__
# * -- comments with just an asterisk above ('#*') indicate stuff that will be cleaned up later