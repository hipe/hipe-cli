require 'rubygems'
require 'getopt/long'
require 'orderedhash'
require 'hipe-core/bufferstring'
require 'hipe-core/lingual'
require 'hipe-core/asciitypesetting'
require 'hipe-gorillagrammar'

module Hipe
  module Cli
    VERSION = '0.0.1'
    class CliException < Exception; 
      def initialize(str, info={})
        super(str)
        @info = info
      end
    end    # base class for all exceptions
    class SoftException < CliException; 
      def self.factory(data)
        require 'hipe-cli/extensions/exceptions'
        return _factory(data)
      end
    end # user input errors soft errors for user to see.
    class HardException < CliException; end # for errors related to parsing command grammars, etc.
    class PrefixNotRecognizedException < SoftException; end   # user types a prefix for an unknown plugin
    class PluginNotFoundException < HardException; end    # failure to load a plugin     
    class CommandNotFound < SoftException; end
    class SyntaxError < SoftException; end
    class ValidationFailure < SoftException; 
      def self.factory(*args)
        require 'hipe-cli/extensions/exceptions'
        return _factory(*args)
      end
    end        
      class Cli
      attr_reader :commands, :plugins, :libraries, :help_on_empty
      attr_accessor :out, :help_on_emtpy, :screen, :parent, :plugin_name, :description, :app_instance
      def initialize app_class
        @app_class = app_class
        @commands = OrderedHash.new
        @plugins = Plugins.new
        @out = $stdout
        @help_on_empty = true
        @screen = {:width => 76, :margin=>3, :col1width=>14, :col2width=>59 }
      end      

      def does name, mixed=nil
        case mixed
          when String then mixed = {:description => mixed }
          when nil then mixed = {:library => true}
        end
        @commands[ (command = Command.factory(name, mixed)).name ] = command 
      end
      
      def plugin name, class_identifier
        @plugins[name] = AppReference.new(class_identifier,self,name)
      end
            
      def << argv
        raise HardException.new("must be array") unless argv.kind_of? Array
        if (argv.length > 0 && plugin = plugins.plugin_for_argv(argv))
          plugin << argv
        else
          begin
            action = parse_argv argv
            action.execute! @app_instance
          rescue SoftException => e
            out.puts e.message
          end
        end
        out
      end
      
      def parse_argv argv
        command_name = argv.shift
        if command_name.nil?
          if (@help_on_empty) 
            command_name = 'help'
            command_symbol = :help
          end
        elsif md = /^-(?:-([a-z0-9-]+)|([a-z]))$/.match(command_name)
          search_proc = md[1] ? Proc.new{|k,v| v.long_name==md[1]} : Proc.new{|k,v| v.short_name==md[2]}
          matches = @commands.select(&search_proc)
          if (matches.size > 0)
            command_symbol = matches[0][1].name # first match!
          end
        else
          command_symbol = command_name.gsub('-','_').to_sym
        end
        if @commands[command_symbol]
          @commands[command_symbol].cli = self           
          @commands[command_symbol] << argv
        else
          UnrecognizedRequest.new(command_name)
        end
      end
      
      def invocation_name
        @parent ? %{#{@parent.invocation_name}:#{plugin_name}} : File.basename($PROGRAM_NAME)
      end
      
      # write the contents of your buffer to the buffer provided
      def >> buffer; buffer << out.read end
      
      def expecting 
        (@commands.map{|pair| pair[1].name} + @plugins.map do |p|
          app = p[1].dereference
          app.cli.expecting.map{ |x| %{#{p[0]}:#{x}} }
        end ).uniq
      end
      
      # experimental. if you want to execute a command programatically i.e. from another command
      # and you don't wan't that "sub command" to write to the main app's output buffer
      # call this as the parameter to the command's execute!() method instead of self
      def sub_buffer
        app_instance = @app_instance.dup
        app_instance.instance_variable_set('@cli',@app_instance.cli.dup) # @todo test if this is even necesssary
        app_instance.cli.out = BufferString.new
        app_instance
      end

    end
    
    module Executable
      #def execute! app
    end
    
    # for plugins -- hold a reference to the other app without loading it
    class AppReference
      attr_accessor :initted # keeping track of whether we gave the child our settings like screen and stdout
      def initialize mixed,parent,name
        @class_identifier = mixed
        @parent = parent
        @name = name
      end
      
      def dereference
        unless @referent
          klass =  @class_identifier.instance_of?(String) ? 
            App.class_from_filepath(@class_identifie) : @class_identifier
          raise HardException.new("plugin class must be Hipe::Cli::App") unless 
            klass.ancestors.include? Hipe::Cli::App
          @referent = klass.new
          @referent.cli.parent = @parent
          @referent.plugin_name = @name
        end
        @referent
      end
    end
    
    module App
      @classes = {}
      def self.class_from_filepath filename
        raise PluginNotFoundException.new(%{Plugin file not found: "#{filename}"}) unless File.exist? filename
        class_name = File.basename(filename).downcase.gsub(/\.rb$/,'').gsub(/(?:[-_]|^)([a-z])/){|m| $1.upcase }
        re = Regexp.new(Regexp.escape(class_name)+'$')
        require filename        
        classes = @classes.select(){|name,klass| re =~ klass.name }
        raise PluginNotFoundException.new %{Expecting to find a class called "#{class_name}" }+
          %{in the plugin file "#{filename}"} if classes.size == 0        
        raise HardException.new %{We need better logic to deal with files of same names in diff. folders}+
        %{(with name: "#{class_name}")} if classes.size > 1
        require filename
        classes[0][1]
      end
      def self.included base
        base.instance_variable_set('@cli', Cli.new(base))
        base.extend ClassMethods
        base.send(:define_method, :cli) do
          self.class.cli.app_instance = self; # @todo ugly quickfix -
          self.class.cli
        end
        @classes[base.to_s] = base
      end      
      module ClassMethods
        def cli; @cli end
      end
    end
    
    module ElementLike
    
    end
    class Element
      include ElementLike
    end
    class Option
      include ElementLike
      GETOPT_TYPE = {:boolean => Getopt::BOOLEAN, :increment => Getopt::INCREMENT, :required => Getopt::REQUIRED}
      attr_accessor :name, :long_name, :short_name, :type
      def initialize(name,data={})
        if name.kind_of? String
          begin
            # @todo test for short name only, long name only
            @short_name, @long_name = %r{^(?:-([a-zA-Z]))? ?(?:--([-a-zA-Z0-9]{2,}))$}.match(name).captures
            @name = data[:name] ? data[:name] : @long_name.gsub('-','_').to_sym
          rescue NoMethodError => e
            raise HardException.new(%{please give options a name of the form "-x --alpha-beta"})
          end
        else
          @long_name = name.to_s.gsub('_','-')
          @short_name = name.to_s[0].chr
          @name = name
        end
        @type = data[:type] || :required
        @description = data[:description]
        @data = data
      end
      def getopt_type
        @type ? GETOPT_TYPE[@type] : GETOPT_TYPE[:required]
      end
    end
    
    # CommandLike is a suite of methods for managing the parsing, validation, and description
    # of an individual command.  It assumed that the object is statelss although it need not be
    # It manages the parsing and validation of
    # the options, required arguments ("required"), optional arguments ("optionals"), and splat arguments.
    # This is done in two steps, the first where the string of arguments is turned into name-value pairs,
    # and a second pass where we perform validation of provided elements and checking for missing required
    # elements. It is broken up like this so that the grammar can also be used to validate 
    # data coming in from a web app
    # 
    # The command grammar data can specify any command class it wants to parse data.    
    module CommandLike
      include ElementLike
      attr_accessor :cli
      attr_reader :name, :short_name, :long_name, :options, :required, :optionals, :splat
      def initialize_command name, data
        case name
          when Symbol then @name = name
          when Array then captures = name
          when String then captures = name.match(/^-([a-z]) --([-a-z0-9]+)$/).captures
        end
        if captures
          @name = captures[1].gsub('-','_').to_sym
          @short_name, @long_name = captures
        end
        @required = data[:required] || []
        @optionals = data[:optionals] || []
        @splat = data[:splat]       || false
        @description = data[:description]
        @options = OrderedHash.new
        data[:options].each{|k,v| o=Option.new(k,v); @options[o.name] = o } if data[:options]
        @data = data # when we learn metaprogramming we will ... @todo
      end
      
      def invocation_name
        @name.to_s.gsub('_','-')
      end

      # Process an array of args and turn it into an executable request object
      #
      # @param [Array] argv an array of arguments, as seen in ARGV
      # @param [RequestLike] if provided the parsed tree will go here
      # @return [RequestLike] the  object
      # this argument list should not include the name of this command itself, that should have been
      # shifted off already.  Does this only create a data structure, and not do any validation?
      def << argv, request=nil
        cursor = argv.find_index{|x| x[0].chr != '-' } # the index of the first one that is not an option
        cursor ||= argv.size # either it was all options or the argv is empty
        options  = argv.slice(0,cursor)
        required = argv.slice(cursor,@required.size)
        optional = argv.slice((cursor+=@required.size), @optionals.size) || []
        # in practice a command grammar will almost never have both optionals and splat
        # (really wierd but imagine:)    app.rb --opt1=a --opt2 REQ1 REQ1 [OPT1 [OPT2 [SPLAT [SPLAT]]]]
        cursor += @optionals.size
        # extra arguments means invalid arguments
        # if a grammar has splat the resulting request will never have extra arguments and vice versa
        splat     = @splat ? (argv.slice(cursor,argv.size) || []) : nil
        extra     = @splat ? [] : (argv.slice(cursor,argv.size) || [] )
        # putting extra args in a hash will make validation easier
        extra_args_hash = extra.size == 0 ? {} :
          Hash[*((0..extra.size-1).to_a.zip(extra)).flatten]
        tree = {}
        tree[:options] = getopt_parse options
        tree[:required] = parse_arguments(@required,required)
        tree[:optionals] = parse_arguments(@optionals,optional)
        tree[:splat] = splat || []
        tree[:extra] = extra_args_hash
        request ||= Hipe::Cli::Request.new()        
        request.cli_tree = tree
        request.command = self
        validate!(request)
        request #! make sure you return this puppy
      end

      def parse_arguments gramma, argv
        OrderedHash[*gramma.slice(0,argv.size).map{|x| x[:name].to_sym }.zip(argv).flatten]
      end

      def getopt_parse argv
        return {} if argv.size == 0 && @options.size == 0
        grammar = @options.map {|o| [ %{--#{o[1].long_name}}, %{-#{o[1].short_name}},o[1].getopt_type ] }
        begin
          old_argv = ARGV.dup
          ARGV.replace(argv) # Getopt is annoying.  why are we using it? 
          parsed_opts = Getopt::Long.getopts(*grammar);
        rescue Getopt::Long::Error, ArgumentError => e
          raise SoftException.factory(:type=>:unrecognized_option, :exception=>e, :option=>argv[0], 
          :command=>self)
        ensure
          ARGV.replace(old_argv) # this was breaking our tests b/c bacon was reading it.  EVIL Getopt.        
        end
        # turn {'alpha'=>1,'a'=>,'beta-gamma'=>2, 'b'=>2} into {:alpha=>1, :beta_gamma=>2}
        ks = @options.map{|pair| pair[1].long_name} & parsed_opts.keys
        Hash[ks.map{|x| x.gsub('-','_').to_sym }.zip(ks.map{|k| parsed_opts[k]})]
      end # def 
      
      def validate! request
        valid_keys = @required.map{|x| x[:name]} + @optionals.map{|x| x[:name]} + @options.map{|x| x[0]}
        valid_keys << @splat[:name] if @splat
        errors = []
        if (invalid_keys = request.keys - valid_keys).size > 0
          sentence = Hipe::Lingual.en{sp(np(adjp('unexpected'),'argument',invalid_keys))}
          errors << ValidationFailure.factory(sentence.say,:type=>:invalid_keys, :invalid_keys=>invalid_keys)
        end
        if (missing_keys = @required.map{|x| x[:name]} - request.keys).size > 0
          sentence = Hipe::Lingual.en{sp(np(adjp('expected'),'argument',pp('missing'),missing_keys))}
          errors << ValidationFailure.factory(sentence.say,:type=>:missing_keys, :missing_keys=>missing_keys)
        end
        debugger
        'x'
      end

    end

    class Command
      include CommandLike
      protected
      def initialize name, data
        initialize_command name, data
      end
      public
      def self.factory name, data
        if data[:library]
          class_name = 
            if (data[:class_name]) then data[:class_name]
            elsif (name.kind_of? String)
              md = name.match(/^-([a-z]) --([-a-z0-9]+)$/i)
              md[2].gsub(/(?:^|-)[a-z]/){|x| x.upcase}
            else name.to_s.gsub(/(?:^|_)[a-z]/){|x| x.upcase}; end
          data.delete(:library) # stop the recursion
          klass = Library::Elements.const_get class_name
          obj = klass.new((md ? md.captures : name ), data)
        else
          obj = Command.new(name,data)
        end
        obj
      end
    end

    module RequestLike
      attr_reader :cli_tree
      attr_accessor :command
      def cli_tree= tree
        @cli_tree = tree
        @param = OrderedHash.new
        [:options,:required,:optionals].each do |which|
          @cli_tree[which].each do |k,v|
            @param[k] = v
          end
        end
        @splat = tree[:splat]
        @extra = tree[:extra]
      end
      
      def [](key); @param[key] end
      def keys; @param.keys end
      
      # prepares the arguments in an order suitable for the app's function and calls it
      # @param [Hipe::Cli::App] app
      # @return the result of the call to the implementing function
      def execute! app
        raise HardException.new(%{please implement "#{command.name}"}) unless app.respond_to? command.name
        method = app.method(command.name)
        args = @command.required.map{|x| self[x[:name]]} + @command.optionals.map{|x| self[x[:name]]}
        args << self[@command.splat[:name]] if @command.splat
        if (@command.options.size>0)
          opts = {}
          @command.options.each{|k,v| opts[k] = self[k] }
          args << opts
        end
        debugger
        method.call(*args)
      end
    end
    
    class Request < Hash
      include RequestLike
    end
    
    class UnrecognizedRequest
      include RequestLike
      def initialize command_name
        @command_name = command_name
      end
      def execute! app
        out = app.cli.out
        cli = app.cli
        out.puts %{Unexpected command "#{@command_name}".  Expecting }+
        Hipe::Lingual::List[cli.expecting].or{|x| %{"#{x}"}}
        if (cli.help_on_empty)
          require 'hipe-cli/extensions/ascii_documentation'
          out.puts %{See "#{cli.invocation_name} -#{cli.commands[:help].short_name}" for more information.}
        end
      end
    end

    class Plugins < OrderedHash
      def plugin_for_argv argv
        prefix, remainder = %r{^([^:]*):?(.*)}.match(argv[0]).captures
        return nil if '' == remainder
        unless plugin_ref = self[prefix.gsub('-','_').to_sym]
          raise PrefixNotRecognizedException.new(
            %{Sorry, prefix is not associated with any known plugin: "#{prefix}"})
        end
        plugin = plugin_ref.dereference
        argv[0].replace remainder
        plugin
      end
    end
    
    module Library
      module Elements
        class Version < Command
          include Executable
          def initialize name, data
            super name, {
              :decription => 'display the version number of this app and exit.',
              :options    => {
                '--bare' => {
                   :description => 'show just the version number, e.g. "1.2.3"',
                   :type        => :boolean
                }
              }
            }.merge(data)
          end
          def << argv
            VersionRequest.new(super)
          end
        end
        class VersionRequest
          def initialize(request)
            @request = request
          end
          def execute! app
            version = app.class.const_get :VERSION            
            if @request[:bare]
              app.cli.out << version
            else
              app.cli.out.puts %{#{app.cli.invocation_name} version #{version}}
            end
          end
        end
        class Help < Command
          def initialize name, data
            super name, {
              :description => 'Show detailed help for a given COMMAND, or general help',
              :optionals => [{:name=>:COMMAND_NAME}]
            }.merge!(data)
          end
          def << argv
            require 'hipe-cli/extensions/ascii_documentation'
            Library::Elements::HelpRequest.new(super)
          end # def
        end # class
      end # end Elements
      module Predicates # little actions and validations done on elements (options and arguments)
        def gets_opened action, var_hash, var_name
          @cli_files[var_name] = {
            :fh => File.open(var_hash[var_name], action[:as]),
            :filename => var_hash[var_name]
          }      
        end
        def must_match_regexp(validation_data, var_hash, var_name)
          value = var_hash[var_name]  
          re = validation_data[:regexp]
          if (! matches = (re.match(value.to_s))) 
            # the only time we should need to_s is when this accidentally turned against an INCREMENT value
            msg = validation_data[:message] || "failed to match against regular expression #{re}"
            raise SyntaxError.new(%{Error with --#{var_name}="#{value}": #{msg}})
          end
          var_hash[var_name] = matches.captures if matches.size > 1 # clobbers original, only when there are captures ! 
        end
        def must_exist(validation_data, var_hash, var_name)
          unless File.exist?( fn )
            raise SoftException.new("file does not exist: "+fn)
          end
        end        
        # this guy makes string keys and string values!
        # pls note that according to apeiros in #ruby, "your variant of json isn't json"
        def jsonesque(validation_data, var_hash, var_name)
          var_hash[var_name] = Hash[*(var_hash[var_name]).split(/:|,/)] # thanks apeiros
        end 
      end # Predicates
    end # Library
  end # Cli
end # Hipe