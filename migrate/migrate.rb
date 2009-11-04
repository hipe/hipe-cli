#!/usr/bin/env ruby
require File.dirname(__FILE__)+'/../cli'

module Markus
  module Migrate
    class Migrate
      include Cli::App
      def initialize
        cli_pre_init
        @cliDescription = "Pulls in data from excel sheets and spits it out to XML"
        @cliCommands = {
          :transform => {
            :description => 'With no arguments, generates a transformation file template '+
              '(ruby code) and outputs it to stdout. If arguments are provided they should be '+
              'the TRANSFORMATION_FILE and the CSV_FILE',
            :arguments => {
              :optional => [ 
                {:name=>:TRANSFORMATION_FILE, :description=>"a ruby file with settings for how to process the csv file" },
                {:name=>:CSV_FILE, :description=>"the file you want to process" }
              ]
            }
          },
        }
        cli_post_init
      end
    
      protected 
      
      def cli_execute_transform
        if @cliArguments.size == 0
          return generate_template_file
        else 
          return transform
        end
      end
      
      def generate_template_file
        File.open(File.dirname(__FILE__)+'/data/transform_template.rb.tmpl','r') do |f|
          body = f.readlines.join('')
          body.gsub!('%%timestamp%%',Time.now.strftime("%a, %d %b %Y"));
          body.gsub!('%%app name%%',$PROGRAM_NAME);
          STDOUT.syswrite body
        end
      end
    
    end #class Migrate
  end #module Migrate
end #module Markus

Markus::Migrate::Migrate.new.cli_run if $PROGRAM_NAME == __FILE__