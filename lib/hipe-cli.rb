require 'rubygems'
require 'getopt/long'
require 'orderedhash'

module Hipe
  module Cli
    VERSION = '0.0.1'
    class CliException < Exception; end    # base class for all exceptions
    class SoftException < CliException; end # user input errors soft errors for user to see.
    class HardException < CliException; end # for errors related to parsing command grammars, etc.
    class PluginNotRegisteredException < SoftException; end   # user types a prefix for an unknown plugin
    class PluginNotFoundException < HardException; end    # failure to load a plugin     
    class CommandNotFound < SoftException; end
    class SyntaxError < SoftException; end
    
    class Cli
      attr_reader :commands 
      def initialize
        @commands = OrderedHash.new
      end
      
      def does name, mixed=nil
        case mixed
          when nil then mixed = {}
          when String then mixed = {:description => mixed }
        end
        @commands[name] = Command.new(name, mixed)
      end
    end
    
    module App
      def self.included base
        base.instance_variable_set('@cli', Cli.new)
        base.extend ClassMethods
        base.send(:define_method, :cli){ self.class.cli }
      end      
      module ClassMethods
        def cli; @cli end
      end
    end
    
    class Option
      GETOPT_TYPE = {:boolean => Getopt::BOOLEAN, :increment => Getopt::INCREMENT, :required => Getopt::REQUIRED}
      attr_accessor :short, :long, :name
      def initialize(name,opts=nil)
        if name.kind_of? String
          begin
            @short, @long = %r{^-([a-zA-Z]) --([-a-zA-Z0-9]{2,})$}.match(name).captures
            @name = @long.gsub('-','_').to_sym
          rescue NoMethodError => e
            raise HardException.new(%{please give options a name of the form "-x --alpha-beta"})
          end
        else
          @long = name.to_s.gsub('_','-')
          @short = name.to_s[0].chr
          @name = name
        end
        @data = opts  
      end
      def getopt_type
        @data[:type] ? GETOPT_TYPE[@data[:type]] : GETOPT_TYPE[:required]
      end
    end
    
    # This is the grammar for an individual command, which manages parsing and validating
    # the options, required arguments ("required"), optional arguments ("optionals"), and splat arguments.
    # This is done in two steps, the first where the string of arguments is turned into name-value pairs,
    # and a second pass where we perform validation of provided elements and checking for missing required
    # elements. It is broken up like this so that the grammar can also be used to validate 
    # data coming in from a web app
    # 
    # The command grammar data can specify any command class it wants to parse data.

    class Command

      def initialize(name, data)
        @name = name
        @required = data[:required] || []
        @optionals = data[:optionals] || []
        @splat = data[:splat]       || false
        @description = data[:description]
        @options = {}
        data[:options].each{|k,v| o=Option.new(k,v); @options[o.name] = o } if data[:options]
      end

      # this argument list should not include the name of this command itself, that should have been
      # shifted off already.  This only creates a data structure, it doesn't do any validation
      def << argv
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
        request = Hipe::Cli::Request.new()
        request[:options] = getopt_parse options_argv
        request[:required] = parse_required required_argv
        request[:optionals] = parse_optionals optional_argv
        request[:splat] = splat_argv || []
        request[:extra] = extra_args_hash
        request
      end

      def parse_required required_argv
        Hash[*@required.slice(0,required_argv.size).map{|x| x[:name].to_sym }.zip(required_argv).flatten]
      end

      def parse_optionals optional_argv
        Hash[*@optionals.slice(0,optional_argv.size).map{|x| x[:name].to_sym }.zip(optional_argv).flatten]
      end

      def getopt_parse argv
        return {} if argv.size == 0 && @options.size == 0
        grammar = @options.map do |key,value|
          [ %{--#{value.long}}, %{-#{value.short}},value.getopt_type ]
        end
        begin
          old_argv = ARGV.dup
          ARGV.replace(argv) # Getopt is annoying.  why are we using it? 
          parsed_opts = Getopt::Long.getopts(*grammar);
          ARGV.replace(old_argv) # this was breaking our tests b/c bacon was reading it.  EVIL Getopt.
        rescue Getopt::Long::Error => e
          raise SyntaxError.new  e.message
        end
        # turn {'alpha'=>1,'a'=>,'beta-gamma'=>2, 'b'=>2} into {:alpha=>1, :beta_gamma=>2}
        ks = @options.map{|pair| pair[1].long} & parsed_opts.keys
        ret = Hash[ks.map{|x| x.gsub('-','_').to_sym }.zip(ks.map{|k| parsed_opts[k]})]
        ret
      end # def 
    end
    class Request < Hash
    end
  end
end



    #    module AppClasses
    #      @@classes = []
    #      def self.<<(klass)
    #        @@classes << klass
    #      end
    #      
    #      # @private
    #      def self.classes; @@classes; end   # for irb debugging only! 
    #      
    #      def self.has_class? class_name
    #        class_name = class_name.to_s
    #        results = @@classes.select{ |klass| klass.to_s == class_name }
    #        results.size > 0 
    #      end
    #      
    #      def self.get_class_from_full_filename filename        
    #        raise HardException.new %{parse failure with plugin filename: "#{filename}"} unless 
    #          (md = %r{^(?:[^/]+/)*([^/]+)\.rb$}.match filename)
    #        raise HardException.new %{parse failure with plugin filename: "#{md[1]}"} unless 
    #          (%r{^[a-z0-9]+(?:[_-][a-z0-9]+)*$} =~ md[1]) # to make sure that the below scan doens't miss anything
    #        raise PluginNotFoundException.new(%{Plugin file not found: "#{filename}"}) unless File.exist? filename          
    #        require filename  
    #        class_name = md[1].gsub(/(?:[-_]|^)[a-z]/){|m| m[-1].chr.upcase }
    #        re = Regexp.new(Regexp.escape(class_name)+'$')
    #        classes = @@classes.select do |klass|
    #           re =~ klass.to_s;
    #        end 
    #        raise PluginNotFoundException.new %{Expecting to find a class called "#{class_name}" }+
    #          %{in the plugin file "#{filename}"} if 
    #            classes.size == 0
    #        raise HardException.new %{We need better logic to deal with files of same names in diff. folders}+
    #        %{(with name: "#{class_name}")} if classes.size > 1
    #        classes[0]
    #      end
    #    end
    #    
    #    # the supersyntax for all command grammars covered by this is be something like: 
    #    # this-script.rb command-name [OPTIONS] [REQUIRED ARGS] [OPTIONAL ARGS] [SPLAT] ...
    #    # A class includes Cli::App to get the cli_run() method, which parses and dispatches a string of 
    #    # tokens out to the appropriate "controllers".
    #    # Classes that include the Cli::App module should define: 
    #    #    cli_app_title() or @cli_app_title
    #    module App
    #
    #      module ClassMethods
    #        def has_cli_plugin prefix, class_or_full_path
    #          @cli_plugins ||= {}
    #          prefix = prefix.to_s
    #          raise HardException if @cli_plugins[prefix]
    #          data = {}
    #          if class_or_full_path.instance_of? Class
    #            data[:class] = class_or_full_path 
    #          else 
    #            data[:full_path] = class_or_full_path + '.rb' #*
    #          end
    #          @cli_plugins[prefix] = data
    #        end
    #        
    #        def has_cli_plugin? prefix
    #          !! @cli_plugins[prefix.to_s]
    #        end
    #
    #        # @return Class object or null if not found
    #        def get_cli_plugin_class_from_prefix prefix
    #          prefix = prefix.to_s
    #          if ! @cli_plugins[prefix]
    #            return nil
    #          elsif @cli_plugins[prefix][:class]
    #            @cli_plugins[prefix][:class]
    #          else
    #            path = @cli_plugins[prefix][:full_path]
    #            AppClasses.get_class_from_full_filename path
    #          end
    #        end        
    #
    #        def does command_name, command_grammar_data
    #          # allow overwrite.  always use strings internally.  ('-' will map to '_' with gsub later)
    #          @cli_commands[command_name.to_s.gsub('-','_')] = command_grammar_data
    #        end
    #        
    #        def cli_command_grammar name
    #          name = name.to_s.gsub('-','_')
    #          return nil unless @cli_commands[name]
    #          require 'hipe-cli/commandgrammar'
    #          CommandGrammar.new name, @cli_commands[name]
    #        end
    #        
    #        def does? command_name
    #          return !! @cli_commands[command_name.to_s]
    #        end
    #      end # ClassMethods
    #
    #      def cli_app_title
    #        @cli_app_title || 'the command line app'
    #      end
    #        
    #      # raises PluginNotRegisteredException with nonexistent prefix
    #      # returns false if the command has no separators ':' in it
    #      def cli_get_plugin_for_command command_name
    #        prefix, remainder = %r{^([^:]*):?(.*)}.match(command_name).captures
    #        return false if '' == remainder
    #        raise PluginNotRegisteredException.new(%{Prefix is not registered with any commands: "%{first}"}) unless 
    #          self.class.has_cli_plugin? prefix
    #        klass = self.class.get_cli_plugin_class_from_prefix prefix
    #        command_name.replace remainder
    #        klass
    #      end 
    #      
    #      def cli_command argv
    #        if argv.size == 0 || (argv.size == 1 && ['-h','--help'].include?(argv[0]))
    #          argv[0] = 'help'
    #        end    
    #        command_name = argv.shift
    #        if plugin_class = cli_get_plugin_for_command( command_name )
    #          plugin = plugin_class.new
    #          command = plugin.cli_command( [command_name] + argv) 
    #        else
    #          grammar = self.class.cli_command_grammar command_name
    #          command = grammar ? grammar.parse( argv ) : nil
    #        end
    #        command
    #      end
    #      
    #      # @return the executed command object
    #      def cli_run argv #consider that argv might be name-value pairs! 
    #        begin
    #          command = cli_command argv
    #          command.execute!
    #        rescue SoftException => e
    #          str = e.message+"\n"+cli_usage_message
    #          puts str
    #          return
    #        end
    #      end #def cli_run
    #    end #module App
    #  end #module Cli
    #end #module Hipe

# module Hipe
#   module Cli    
#     # The individual instance of something the user entered.
#     class Command < Hash
#       @validity_is_known = false
#       @errors = []  
#     end
#     
#     def self.[](hash)
#       hash = hash.clone
#       %w(options required optionals splat).map{|x| x.to_sym}.each do |thing|
#         self[thing] = hash.delete(thing)
#       end
#       self[:extra] = hash
#     end
#   end # Cli
# end # Hipe
