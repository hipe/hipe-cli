require 'hipe-cli/logger'
require 'ruby-debug'

module Hipe
  module Cli 
    VERSION = '0.0.0'
    include Logger::Constants

    module AppClasses
      @@classes = []
      def self.<<(klass)
        @@classes << klass
      end
      
      # @private
      def self.classes; @@classes; end   # for irb debugging only! 
      
      def self.has_class? class_name
        class_name = class_name.to_s
        results = @@classes.select{ |klass| klass.to_s == class_name }
        results.size > 0 
      end
      
      def self.get_class_from_full_filename filename        
        raise HardException.new %{parse failure with plugin filename: "#{filename}"} unless 
          (md = %r{^(?:[^/]+/)*([^/]+)\.rb$}.match filename)
        raise HardException.new %{parse failure with plugin filename: "#{md[1]}"} unless 
          (%r{^[a-z0-9]+(?:[_-][a-z0-9]+)*$} =~ md[1]) # to make sure that the below scan doens't miss anything
        raise PluginNotFoundException.new(%{Plugin file not found: "#{filename}"}) unless File.exist? filename          
        require filename  
        class_name = md[1].gsub(/(?:[-_]|^)[a-z]/){|m| m[-1].chr.upcase }
        re = Regexp.new(Regexp.escape(class_name)+'$')
        classes = @@classes.select do |klass|
           re =~ klass.to_s;
        end 
        raise PluginNotFoundException.new %{Expecting to find a class called "#{class_name}" }+
          %{in the plugin file "#{filename}"} if 
            classes.size == 0
        raise HardException.new %{We need better logic to deal with files of same names in diff. folders}+
        %{(with name: "#{class_name}")} if classes.size > 1
        classes[0]
      end
    end
    
    # the supersyntax for all command grammars covered by this is be something like: 
    # this-script.rb command-name [OPTIONS] [REQUIRED ARGS] [OPTIONAL ARGS] [SPLAT] ...
    # A class includes Cli::App to get the cli_run() method, which parses and dispatches a string of 
    # tokens out to the appropriate "controllers".
    # Classes that include the Cli::App module should define: 
    #    cli_app_title() or @cli_app_title
    module App

      attr_accessor :logger
      
      def self.included klass
        klass.extend ClassMethods
        klass.instance_variable_set('@cli_commands',{})
        AppClasses << klass
        super klass
      end

      module ClassMethods
        def has_cli_plugin prefix, class_or_full_path
          @cli_plugins ||= {}
          prefix = prefix.to_s
          raise HardException if @cli_plugins[prefix]
          data = {}
          if class_or_full_path.instance_of? Class
            data[:class] = class_or_full_path 
          else 
            data[:full_path] = class_or_full_path + '.rb' #*
          end
          @cli_plugins[prefix] = data
        end
        
        def has_cli_plugin? prefix
          !! @cli_plugins[prefix.to_s]
        end

        # @return Class object or null if not found
        def get_cli_plugin_class_from_prefix prefix
          prefix = prefix.to_s
          if ! @cli_plugins[prefix]
            return nil
          elsif @cli_plugins[prefix][:class]
            @cli_plugins[prefix][:class]
          else
            path = @cli_plugins[prefix][:full_path]
            AppClasses.get_class_from_full_filename path
          end
        end        

        def does command_name, command_grammar_data
          # allow overwrite.  always use strings internally.  ('-' will map to '_' with gsub later)
          @cli_commands[command_name.to_s.gsub('-','_')] = command_grammar_data
        end
        
        def cli_command_grammar name
          name = name.to_s.gsub('-','_')
          return nil unless @cli_commands[name]
          require 'hipe-cli/commandgrammar'
          CommandGrammar.new name, @cli_commands[name]
        end
        
        def does? command_name
          return !! @cli_commands[command_name.to_s]
        end
      end # ClassMethods

      def cli_app_title
        @cli_app_title || 'the command line app'
      end
        
      # raises PluginNotRegisteredException with nonexistent prefix
      # returns false if the command has no separators ':' in it
      def cli_get_plugin_for_command command_name
        prefix, remainder = %r{^([^:]*):?(.*)}.match(command_name).captures
        return false if '' == remainder
        raise PluginNotRegisteredException.new(%{Prefix is not registered with any commands: "%{first}"}) unless 
          self.class.has_cli_plugin? prefix
        klass = self.class.get_cli_plugin_class_from_prefix prefix
        command_name.replace remainder
        klass
      end 
      
      def log(type, &block)
        @cli_logger.log(type,&block)
      end
      
      def cli_command argv
        if argv.size == 0 || (argv.size == 1 && ['-h','--help'].include?(argv[0]))
          argv[0] = 'help'
        end    
        command_name = argv.shift
        if plugin_class = cli_get_plugin_for_command( command_name )
          plugin = plugin_class.new
          command = plugin.cli_command( [command_name] + argv) 
        else
          grammar = self.class.cli_command_grammar command_name
          command = grammar ? grammar.parse( argv ) : nil
        end
        command
      end
      
      # @return the executed command object
      def cli_run argv #consider that argv might be name-value pairs! 
        begin
          command = cli_command argv
          command.execute!
        rescue SoftException => e
          str = e.message+"\n"+cli_usage_message
          puts str
          return
        end
      end #def cli_run
    end #module App
  end #module Cli
end #module Hipe