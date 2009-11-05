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
        @cliCommands = {
          :generate_transform_scaffold => {
            :description => 'Generates a transformation file template '+
              '(ruby code) and outputs it to STDOUT.'
          },
          :csv_to_xml => {
            :description => 'the csv will be run through the filter and data will be added '+
            'to an existing xml document (by calling user-defined methods.) Outputs result to STDOUT.',
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
            if (
              (patternData[:line_index] && index==patternData[:line_index]) ||
              (patternData[:pattern]    && patternData[:pattern].match(row.join(',')))
            )
              matchingPatternData = patternData
              break
            end
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
      
      def csv_process_row_flatten_section_name_to_field_value(patternData, row, index, opts)
        @extraFields ||= {}
        @extraFields[patternData[:field_name]] = opts[:orig_row][0]
      end
      
      def csv_process_row_is_field_names(patternData, row, index, xtra)
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