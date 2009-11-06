#!/usr/bin/env ruby
require File.dirname(__FILE__)+'/../cli'
require 'hpricot'
require 'csv'
require 'builder'

module Markus
  module Migrate
    class MigrateException < Exception; end
    class Migrate
      include Cli::App
      def initialize
        cli_pre_init
        @cliDescription = "Pulls in data from excel sheets and spits it out to XML"
        @cliGlobalOptions = {
          :debug => {
            :description => 'Type one thru six d\'s (e.g. "-ddd" to indicate varying degrees of '+
            'debugging output (put to STDERR).',
            :getopt_type => Getopt::INCREMENT
          }
        }
        @cliCommands = {
          :generate_transform_scaffold => {
            :description => 'Generates a transformation file template '+
              '(ruby code) and outputs it to STDOUT.'
          },
          :csv_to_xml => {
            :description => 'the csv will be run through the filter and data will be added '+
            'to an existing xml document (by calling user-defined methods.) Outputs result to STDOUT.',
            :options => {
              :fields => { 
                :description => "comma-separated list of line numbers to use to (re-)set the field names of the columns",
                :validations => [
                  {:type=>:regex, :regex=>/^\d+(?:, *\d+)*$/, :message=>'must have only numbers and commas'}
                ]                
              },
              :skip => {
                :name => :skip,
                :description => "comma-separated list of line numbers to skip, starting at line 1."+
                "  (blank lines are skipped by default.)",
                :validations => [
                  {:type=>:regex, :regex=>/^\d+(?:, *\d+)*$/, :message=>'must have only numbers and commas'}
                ]
              },
              :section => {                
                :description => "when a cel is used as a sect",#ion divider, you can turn it into a virtual field value"+
                #" for all the following rows (until the next section)  Please provide a string like this: \"A country\""+
                #" to match any row where there is only data in column 'A', and \"flatten\" that field to stand for a field"+
                #" called 'country'",
                :validations=>[
                  { :type=>:regex,
                    :regex=>/^([A-Z]+)(?:(\d+))? (.+)$/, 
                    :message=>'Invalid specifiction -- please follow the pattern "AA:11 field_name"'
                  }
                ]
              }
            },
            :arguments => {
              :required => [
                { :name => :CSV_FILE, 
                  :description => 'the csv we are processing', 
                  :validations => [
                    :file_must_exist
                  ]
                },
                { :name => :STARTING_XML_FILE, 
                  :description => 'the xml file to add to', 
                  :validations => [
                    :file_must_exist
                  ]
                }
              ] #end required
            } #end arguments
          } #end command          
        } #end commands
        cli_post_init
      end
    
      protected 
      
      def cli_process_option_skip(givenOpts, k)
        lineNumbers = givenOpts[:skip][0].split(/, */).map{|s| s.to_i}
        givenOpts[:skip] = lineNumbers
        lineNumbers.each do |i|
          @withRowsMatchingPattern << {:line_index => i-1, :action => :skip}
        end
      end
      
      def cli_process_option_fields(givenOpts, k)
        lineNumbers = givenOpts[:fields][0].split(/, */).map{|s|s.to_i}
        givenOpts[:fields] = lineNumbers
        lineNumbers.each do |i|
          @withRowsMatchingPattern << {:line_index => i-1, :action => :fields}
        end
      end
      
      def cli_process_option_section(givenOpts, k)
        m = givenOpts[:section]
        col, row, fieldName = m[1], m[2], m[3]
        raise Exception.new('sorry, specific row is not yet implemented!') if row
        raise Exception.new("For column please indicate a letter A-Z for now, not '#{col}'.") unless /^[A-Z]$/ =~ col
        numberOfCommas = (col[0]-65) # "A" is ascii number 65
        @withRowsMatchingPattern << { 
          :pattern    => Regexp.new('/^'+(','*numberOfCommas)+'([^,]+),*$/'), 
          :action     => :section,
          :field_name => fieldName
        }
      end
      
      def cli_process_option_debug(givenOpts, k)
        ppp :FIX_THIS_BADBOYS, givenOpts
      end
       
      def ppp name, value, die=true
        puts "\n\n#{name.to_s}:\n";
        pp value
        puts "\n"+File.basename(__FILE__)+__LINE__.to_s
        exit if die
      end 
      
      def build_xml
        return Builder::XmlMarkup.new(:indent=>2, :margin=>4)
      end

      def csv_to_xml_start; 
      end
      
      def log_change msg
        @changeLog ||= File.open('./migrate-change-log', 'a+')        
        @changeLog.puts(msg)
        STDERR.puts(msg)
      end
      
      # can be overridden by client
      def csv_to_xml_finish; 
        STDOUT << @doc.to_s if @doc
      end
      
      def cli_execute_csv_to_xml
        csv_to_xml_start
        @csvRows = CSV.read @cliArguments[:CSV_FILE]
        if (@csvRows.size < 1)
          raise MigrateException.new("unable to retrieve one or more rows from \"#{@cliArguments[:CSV_FILE]}\"") 
        end
        @csvRows.each_with_index do |row,index|     
          matchingPatternData = nil
          @withRowsMatchingPattern.each do |patternData|
            
            #puts "line: "+row.join(',');
            
            if (
              (patternData[:line_index] && index==patternData[:line_index]) ||
              (patternData[:pattern]    && patternData[:pattern].match(row.join(',')))
            )
              matchingPatternData = patternData
              break
            end
            
            #fputs "we got it? "+(!! matchingPatternData);
            
          end
          doThis = matchingPatternData ? matchingPatternData[:action].to_s : 'default'
          # STDERR.print "#{doThis}."
          next if doThis == 'skip' # small optimization
          if (@fieldNames)
            useRow = {}
            @fieldNames.each do |stringKey, numericIndex|
              useRow[stringKey] = row[numericIndex]
            end
            useRow.merge!(@extraFields)
          else
            useRow = row
          end
          __send__('csv_process_row_'+doThis,matchingPatternData,useRow,index,:orig_row => row)
        end
        csv_to_xml_finish
      end
      
      # user will almost always want to override this.  this is to serve as a simple example
      def csv_process_row_default(patternData, row, index, opts)
        STDOUT << @xm.row(:index => index){
          row.each do |key,value|
            @xm.__send__(key,value) unless value.nil?
          end
        }
      end      
      
      def csv_process_row_section(patternData, row, index, opts)
        @extraFields ||= {}
        @extraFields[patternData[:field_name]] = opts[:orig_row][0]
      end
      
      def csv_process_row_fields(patternData, row, index, xtra)
        origRow = xtra[:orig_row]
        @fieldNames = {}
        origRow.each_with_index do |value,index|
          next if value.nil?
          @fieldNames[value.gsub(/[a-z0-9_]/, '').downcase] = index
        end
      end
      
      def cli_execute_generate_transform_scaffold
        File.open(File.dirname(__FILE__)+'/data/transform_template.rb.tmpl','r') do |f|
          body = f.readlines.join('')
          body.gsub!('%%timestamp%%',Time.now.strftime("%a, %d %b %Y"));
          body.gsub!('%%app name%%',$PROGRAM_NAME);
          STDOUT.syswrite body
        end
      end #def      
    end #class Migrate
  end #module Migrate
end #module Markus

Markus::Migrate::Migrate.new.cli_run if $PROGRAM_NAME == __FILE__
# * -- comments with just an asterisk above ('#*') indicate stuff that will be cleaned up later