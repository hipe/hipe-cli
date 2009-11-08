#!/usr/bin/env ruby
require File.dirname(__FILE__)+'/../cli'
require 'hpricot'
require 'csv'
require 'builder'
require 'json/pure' # the slower more widely available pure ruby variant (we don't need performance here)

module Markus
  module Migrate
    class MigrateException < Exception; end
    class MigrateFailure < Exception; end    
    class Migrate
      include Cli::App
      def initialize
        cli_pre_init
                
        @linePatterns = [] # this is the main workhorse of the whole thing
        @csvLine = nil     # the current line we are on, when parsing csv       
        @csvRowArr  = nil  # an array of the row being currently processed
        @fieldRename = {}  # an option -- see :field_rename below
        
        
        # -------------- Huge crazy data structures to define our CLI interface -------------
        @cliDescription = "Pulls in data from excel sheets and spits it out to XML"        
        @cliCommands[:help]       = @@cliCommonCommands[:help]
        @cliGlobalOptions[:debug] = @@cliCommonOptions[:debug]
        @cliGlobalOptions[:client_log] = {
          :description => 'A filename for client-specific warnings and notices.',
          #:validations => [:file_must_not_exist],  nah, overwrite the file
          :action => {:action=>:open_file, :as=>'w'}
        }
        @cliCommands[:make_transform_scaffold] = {
          :description => 'Generates a transformation file template '+
            '(ruby code) and outputs it to STDOUT.'
        }
        @cliCommands[:make_dirty_xml] = {
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
        @cliCommands[:csv_to_xml] = {
          :description => 'the csv will be run through the filter and data will be added '+
          'to an existing xml document (by calling user-defined methods.) Outputs result to STDOUT.',
          :options => {
            :fields => { 
              :description => "comma-separated list of line numbers to use to (re-)set the field names of the columns",
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
              :description => "comma-separated list of line numbers to skip, starting at line 1."+
              "  (blank lines are skipped by default.)",
              :validations => [
                {:type=>:regexp, :regexp=>/^(?:\d+|blanks?)(?:, *(?:\d+|blank?))*$/i, :message=>'must have only numbers (or "blank") and commas'}
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
      
      def cli_process_option_skip(givenOpts, k)
        lineNumbers = givenOpts[:skip][0].split(/, */)
        givenOpts[:skip] = lineNumbers
        lineNumbers.each do |i|
          case i
            when /^\d+$/
              @linePatterns << {:line_number => i.to_i, :action => :skip}
            when /^blanks?$/i
              @linePatterns << {:regexp => /^,*$/, :action => :skip }
            else
              raise CliException.new("don't know what it means to skip \"#{i}\"")
          end
        end
        cli_log(6){ "added 'skip' line processors. it has "+@linePatterns.count.to_s+" now." }
      end
      
      def cli_process_option_fields(givenOpts, k)
        lineNumbers = givenOpts[:fields][0].split(/, */).map{|s|s.to_i}
        givenOpts[:fields] = lineNumbers
        lineNumbers.each do |i|
          @linePatterns << {:line_number => i, :action => :fields}
        end
        cli_log(6){ "added #{lineNumbers.count} \"field\" line processors. "+
          "it has "+@linePatterns.count.to_s+" now."
        }
      end
      
      def cli_process_option_field_rename(givenOpts, k)
        @fieldRename.merge! givenOpts[:field_rename]
        cli_log(6){ "added \"field_rename\" filter. it is now "+@fieldRename.inspect }
      end      
      
      def cli_process_option_section(givenOpts, k)
        givenOpts[:section].each do |col, fieldName|
          raise Exception.new("For now only columns A-Z are supported, not '#{col}'.") unless /^[A-Z]$/ =~ col
          numberOfCommas = (col[0]-65) # "A" is ascii number 65
          @linePatterns << { 
            :regexp     => Regexp.new('^'+(','*numberOfCommas)+'([^,]+),*$'), 
            :action     => :section,
            :field_name => fieldName
          }
          cli_log(6){"added 'section' line processor. it has "+@linePatterns.count.to_s+" now."}
        end
      end
      
      def cli_process_option_client_log(a,b); end  # nothing to do! file already opened
      
      def xml_builder
        return Builder::XmlMarkup.new(:indent=>2, :margin=>4)
      end

      #def csv_to_xml_start; 
      #end

      def client_log msg
        cli_file(:client_log).puts msg
        @changeLog ||= File.open('./client-log', 'a+')        
        @changeLog.puts(msg)
        STDERR.puts(msg)
      end
      
      # can be overridden by client
      def csv_to_xml_finish; 
        STDOUT << @xmlDoc.to_s if @xmlDoc
      end
      
      def match_line
        matchingPatternData = nil           
        doDelete = false
        rowAsString = @csvRowArr.join(',')
        @linePatterns.each_with_index do |patternData,patternIndex|
          if (patternData[:line_number])  # could be optimized with procs at beginnning of program!
            if (@csvLine==patternData[:line_number]) 
              matchingPatternData = patternData
              @linePatterns.delete_at(patternIndex)
            end
          elsif (patternData[:regexp])
            if patternData[:regexp] =~ rowAsString
              matchingPatternData = patternData              
            end
          else
            raise MigrateException.new("don't know how to process linePattern: "+patternData.inspect)
          end
          break if matchingPatternData
        end
        matchingPatternData
      end
      
      def cli_execute_csv_to_xml
        #csv_to_xml_start
        client_log(%{============== Processing CSV (Spreadsheet) File: "#{@cliArguments[:CSV_FILE]}"=============})
        @xmlDoc = Hpricot cli_file(:STARTING_XML_FILE)
        @csvRows = CSV.read @cliArguments[:CSV_FILE]
        if (@csvRows.size < 1)
          raise MigrateFailure.new("unable to retrieve one or more rows from \"#{@cliArguments[:CSV_FILE]}\"") 
        end        
        begin
          cli_log(4){ spp("\000LINE PATTERNS", @linePatterns) }
          @csvRows.each_with_index do |@csvRowArr,lineIndex| 
            @csvLine = ( @csvIndex = lineIndex ) + 1   
            doThis = ( matchingPatternData = match_line ) ? 
               matchingPatternData[:action].to_s : 'default'
            if (@fieldNames.nil? && 'default' == doThis)
              raise MigrateFailure.new("We can't process row #{index+1} because we haven't processed "+
              "the field names yet.  Please check that your --fields pattern is hitting by running with -ddddd debugging."+
              " (the row: \""+row.join(',')[0,60]+"...")              
            end
            cli_log(4){ "\000line #{@csvLine} doing \"#{doThis}\" with line: \""+
             (@csvRowArr.join(','))[0,22]+'...'
            }
            next if doThis == 'skip' # small optimization
            useRow = @fieldNames ? get_processed_row : @csvRowArr
            __send__('csv_process_row_'+doThis,matchingPatternData,useRow,lineIndex)
          end
          csv_to_xml_finish
        rescue MigrateFailure => e
          puts e.message
        end
        client_log(%{============== Finished Processing CSV (Spreadsheet) File: "#{@cliArguments[:CSV_FILE]}"=============})        
      end
      
      def get_processed_row
        useRow = {}
        @fieldNames.each_with_index do |name,columnIndex|
          name = @fieldRename[name] if @fieldRename[name]
          if @repeatedFieldNames[name]
            useRow[name] ||= []
            useRow[name] << @csvRowArr[columnIndex]
          else
            useRow[name] = @csvRowArr[columnIndex]
          end
        end
        @repeatedFieldNames.keys.each do |name|
          if (1 == useRow[name].uniq.size)
            useRow[name] = useRow[name][0]
          else
            firstNonNilValue = nil
            useRow[name].each_with_index do |v, i|
              if (!v.nil? && firstNonNilValue.nil?)
                firstNonNilValue = v
                break
              end
            end
            client_log(
              %{WARNING: on line #{@csvLine} you have #{useRow[name].size} "#{name}" fields with }+
              "different values: ("+useRow[name].map{|x| %{"#{x}"}}.join(', ')+"). "+
              %{Using the first non-blank value or null: "#{firstNonNilValue}"}
            )
            useRow[name] = firstNonNilValue
          end # end if different values
        end # each repeated field name
        useRow
      end
      
      # user will almost always want to override this.  this is to serve as a simple example
      def csv_process_row_default(patternData, row, index)
        STDOUT << @xm.row(:index => index){
          row.each do |key,value|
            @xm.__send__(key,value) unless value.nil?
          end
        }
      end      
      
      def csv_process_row_section(patternData, row, index)
        @extraFields ||= {}
        @extraFields[patternData[:field_name]] = @csvRowArr[0]
        cli_log(3){"extra added fields with --section option): "+@extraFields.inspect}
      end
      
      # note this allows for repeats of the same fieldname!
      def csv_process_row_fields(patternData, row, index)
        origRow = @csvRowArr.clone
        # counting back from the end, remove blank cels.  
        # but if there are blank cells in the middle, leave them (ick!)
        Array(0..(origRow.size-1)).reverse.each do |i| 
          origRow.delete_at(i) if origRow[i].nil?
        end
        origRow.collect! {|x| normalize_fieldname x }
        @fieldNames = origRow
        @repeatedFieldNames = {}
        @fieldNames.sort.each_cons(2){|pair| @repeatedFieldNames[pair[0]] = true if pair[0] == pair[1]}
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
        @xmlDoc = Hpricot @cliFiles[:fh][:XML_IN]
        els = @xmlDoc.search(@cliArguments[:XPATH])
        if (0==els.count)
          raise MigrateFailure("Sorry, coundn't find any elements with \"#{@cliArguments[:XPATH]}\"")
        end
        els.attr('cleanliness','dirty')
        print @xmlDoc.to_s
      end      
    end #class Migrate
  end #module Migrate
end #module Markus

Markus::Migrate::Migrate.new.cli_run if $PROGRAM_NAME == __FILE__
# * -- comments with just an asterisk above ('#*') indicate stuff that will be cleaned up later