# This is the grammar for an individual command, which manages parsing and validating
# the options, required arguments ("required"), optional arguments ("optionals"), and splat arguments.
# This is done in two steps, the first where the string of arguments is turned into name-value pairs,
# and a second pass where we perform validation of provided elements and checking for missing required
# elements. It is broken up like this so that the grammar can also be used to validate 
# data coming in from a web app
# 
# The command grammar data can specify any command class it wants to parse data.
 
class Hipe::Cli::CommandGrammar
  
  def initialize(name, data, logger = nil)
    @name = name
    @options = data[:options]   || {}
    @required = data[:required] || []
    @optionals = data[:optionals] || []
    @splat = data[:splat]       || false
    @description = data[:description]
  end
  
  @@subclasses = []
  def inherited klass
    @@sumclasses << klass
  end
          
  # this argument list should not include the name of this command itself, that should have been
  # shifted off already.  This only creates a data structure, it doesn't do any validation
  def parse argv
    require 'hipe-cli/command'    
    cursor = argv.find_index{|x| x[0].chr != '-' } # the index of the first one that is not an option
    cursor ||= argv.size # either it was all options or the argv is empty
    options_argv = argv.slice(0,cursor)
    required_argv = argv.slice(cursor,@required.size)
    optional_argv = argv.slice((cursor+=@required.size), @optionals.size) || []
    # in practice a command grammar will almost never have both optionals and splat
    # (really wierd but imagine:)    app.rb --opt1=a --opt2 REQ1 REQ1 [OPT1 [OPT2 [SPLAT [SPLAT]]]]        
    splat_argv = @splat ? argv.slice(cursor+=@optionals.size,argv.size) : nil
    extra_args_arr = @splat ? [] : argv.slice(cursor,argv.size)
    # putting extra args in a hash will make validation easier
    extra_args_hash = extra_args_arr.size == 0 ? {} :
      Hash[*((0..extra_args_arr.size-1).to_a.zip(extra_args_arr)).flatten]
    command = Hipe::Cli::Command.new()
    command[:options] = getopt_parse options_argv
    command[:required] = parse_required required_argv
    command[:optionals] = parse_optionals optional_argv
    command[:splat] = splat_argv || []
    command[:extra] = extra_args_hash
    command
  end
  
  def parse_required required_argv
    Hash[*@required.slice(0,required_argv.size).map{|x| x[:name].to_sym }.zip(required_argv).flatten]
  end

  def parse_optionals optional_argv
    Hash[*@optionals.slice(0,optional_argv.size).map{|x| x[:name].to_sym }.zip(optional_argv).flatten]
  end
  
  def getopt_parse options_argv
    return {} if options_argv.size == 0 && @options.size == 0
    require 'getopt/long'
    cli_opts_grammar = @options.map do |name,value|
      [ '--'+name.to_s.gsub('_','-'), 
        value[:getopt_letter] ? ('-'+value[:getopt_letter]) : nil,
        value[:getopt_type] || Getopt::REQUIRED]
    end
    begin
      ARGV.replace(options_argv)
      parsed_opts = Getopt::Long.getopts(*cli_opts_grammar); # splat operator makes an array into a series of arguments
    rescue Getopt::Long::Error => e
      raise SyntaxError.new  e.message
    end
    # turn {'alpha'=>1,'a'=>,'beta-gamma'=>2, 'b'=>2} into {:alpha=>1, :beta_gamma=>2}
    ks = @options.map{|pair| pair[0].to_s.gsub('_','-')} & parsed_opts.keys
    ret = Hash[ks.map{|x| x.gsub('-','_').to_sym }.zip(ks.map{|k| parsed_opts[k]})]
    ret
  end # def 
end

