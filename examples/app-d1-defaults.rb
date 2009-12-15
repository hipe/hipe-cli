#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'

class AppD1
  include Hipe::Cli


  cli.does '-h', '--help'

  cli.does(:swim) do
    option('--depth DEPTH', :default => '10ft')
    required(:duration)
    optional(:feet, :default=>'100ft')
  end
  def swim(duration, feet, opts)
    %{dur:#{duration}, ft:#{feet}, depth:#{opts[:depth]}}
  end

  cli.does(:jump) do
    required(:blah, :default =>'blah!')  # no defaults allowed for required, throw at runtime.
  end

  cli.does('pole-vault') do
    optional('height', :default=>'1000feet') do |x|
      'this many: '+x
    end
  end
  def pole_vault(height)
    %{pv height: #{height}}
  end

  cli.does('rhythmic-gymnastics') do
      things = ['round ball','streamer thing']
      abbrev = {'rb'=>'round ball', 'st'=>'streamer thing'}
      apparatii = (things + abbrev.keys).join(',')
    option('-h',&help)
    option('--long-one VAL',:default => 'longval')
    option('-o VAL',:default=> 'just one')
    option('--other-one VAL')
    option('--last-one VAL',:default=>'last1')
    optional('apparatus', things, abbrev, "select encoding", %{(#{apparatii})},:default=>'round ball')
  end

  def rhythmic_gymnastics(apparatus,opts)
    %{apparatus is "#{apparatus}" and opts are: #{opts.inspect}}
  end
end

puts AppD1.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
