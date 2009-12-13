#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'
require 'ruby-debug'
require 'optparse/time'

class AppOp3
  include Hipe::Cli

  cli.does(:go, "blah") do

    opts.banner = "Usage: example.rb [options]"

    opts.separator ""
    opts.separator "Specific options:"

    # Mandatory argument.
    option("-r", "--require LIBRARY", "Require the LIBRARY before executing your script")

    # Optional argument; multi-line description.
    option("-i", "--inplace [EXTENSION]",
            "Edit ARGV files in place",
            "  (make backup if EXTENSION supplied)") do |ext|
      (ext || '').sub(/\A\.?(?=.)/, ".")  # Ensure extension begins with dot.
    end

    # Cast 'delay' argument to a Float.
    option("--delay N", Float, "Delay N seconds before executing")

    # Cast 'time' argument to a Time object.
    option("-t", "--time [TIME]", Time, "Begin execution at given time")

    # Cast to octal integer.
    option("-F", "--irs [OCTAL]", OptionParser::OctalInteger,
            "Specify record separator (default \\0)")

    # List of arguments.
    option("--list x,y,z", Array, "Example 'list' of arguments")

    # Keyword completion.  We are specifying a specific set of arguments (CODES
    # and CODE_ALIASES - notice the latter is a Hash), and the user may provide
    # the shortest unambiguous text.
    CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
    CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }
    code_list = (CODE_ALIASES.keys + CODES).join(',')
    option("--code CODE", CODES, CODE_ALIASES, "Select encoding",
            "  (#{code_list})")

    # Optional argument with keyword completion.
    option("--type [TYPE]", [:text, :binary, :auto],
            "Select transfer type (text, binary, auto)")

    # Boolean switch.
    option("-v", "--[no-]verbose", "Run verbosely")

    opts.separator ""
    opts.separator "Common options:"

    # No argument, shows at tail.  This will print an options summary.
    # Try it and see!
    option("-h", "--help", "Show this message") do
      opts.to_s
    end

    # Another typical switch to print the version.
    option("--version", "Show version") do
      OptionParser::Version.join('.')
    end
  end

  def go opts
    if opts[:help]
      opts[:help]
    else
      opts.inspect
    end
  end

end

puts AppOp3.new.cli.run(ARGV) if ($PROGRAM_NAME == __FILE__)
