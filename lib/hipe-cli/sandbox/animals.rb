#!/usr/bin/env ruby
require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'

class DogSounds
  include Hipe::Cli::App
  #bark --dog-name=NAME --dog-age=AGE --dog-info={weight:120kg} OUT_FILE IN_FILE [IN_FILE[...]]
  cli.does '-h --help'
  cli.description = 'these are the sounds that dogs make'
  cli.does :bark, {
    :description => 'this is the primary sound a dog makes, you see.',
    :options => {
      '-a --dog-age'  , {:range=>(0..120)},
      '-i --dog-info' , {:is_jsonesque=>1},
      '-n --dog-name' , {:regexp=>/^[[:alnum:]]+/,:regexp_sentence=>'It must be alphanumeric (e.g. "abc123")'}
    },
    :required => [{:name=>:OUT_FILE, :it=>[:gets_opened]}],
    :splat => {:name=>:IN_FILES, :minimum=>1,:they =>[:must_exist, :gets_opened] }
  }
  def bark(out_file, in_files, opts)
    s = %{bow wow. outfile name: #{out_file[:filename]} in_files_size: #{in_files.size} }
    opts.each do |k,v|
      s << " #{k}:#{v} "
    end
    cli.out.puts s
  end
  cli.does :pant, {
    :required => [
      {:name=> :OUT_FILE, :it=>[:must_not_exist, :gets_opened]},
      {:name=> :IN_FILE,  :it=>[:must_exist, :gets_opened]},
      {:name=> :SOME_RANGE, :range =>(1..2) }
    ]
  }
  def pant(out_file, in_file, some_range)
    cli.out.puts %{out file name: #{out_file[:filename]} and in file name: #{in_file[:filename]}}
  end
end

class AnimalSounds
  include Hipe::Cli::App
  cli.plugin :dog, DogSounds
  cli.does '-h --help'
  cli.does :reproduce, "all living things reproduce"
  def reproduce; end
end

if $PROGRAM_NAME==__FILE__
  app = AnimalSounds.new
  app.cli << ARGV
end
