require 'rubygems'
require 'ruby-debug'
require 'getopt/long'     # one day will be optparse or coolopts or cmdparse or something? 
require 'orderedhash'
gem 'hipe-core','0.0.1'
require 'hipe-core'
require 'hipe-core/io'
require 'hipe-core/exception-like'
require 'hipe-cli/exceptions'

module Hipe
  module Cli
    DIR = File.expand_path(File.dirname(__FILE__)+'/../') # really only needed for plugin_spec    
    VERSION = '0.0.1'
    module Lingual
      def lingual
        require 'hipe-core/lingual'
        Hipe::Lingual
      end
    end  
    module Exceptions
      class Exception < Hipe::Exception
        include Hipe::ExceptionLike
        exception_modules << Exceptions
        self.default_exception_class = UsageFail
        def self.f(string,details={})
          self.factory(string,details)
        end
      end      
    end
    Exception = Exceptions::Exception # ick
    class Cli
      attr_reader :plugins, :libraries, :plugin_name, :parent, :app_class, :commands_data
      attr_accessor :out, :help_on_emtpy, :screen, :description, :app_instance, :default_command
      def initialize app_class
        @libraries = []
        @app_class = app_class
        @commands_data = OrderedHash.new
        @plugins = Plugins.new()
        @out = $stdout
        @help_on_empty = true
        @screen = {:width => 76, :margin=>3, :col1width=>30, :col2width=>36 }
      end
      
      def help_on_empty?
        @help_on_empty && commands[:help]
      end
      
      def commands
        @commands_object ||= Commands.new(self,@commands_data)
      end

      def does name, mixed=nil
        @commands_data[name] = mixed  # we keep the original key (as string or symbol
        # so successive calls to each have it
      end

      def plugin name, class_identifier
        @plugins[name] = AppReference.new(class_identifier,self,name)
      end
      
      def activate_as_plugin parent_cli, my_name
        @parent = parent_cli
        @plugin_name = my_name
        @out = parent_cli.out # our output buffer should be the same as theirs
      end

      def command_prefix
        @plugin_name.nil? ? '' : %{#{@parent.command_prefix}#{@plugin_name}:}
      end
      
      def set(*args)
        raise Exception.f(%{For now, args must be name-value pairs (a hash), not "#{args}"}) unless
          args.size == 1 && Hash === args[0]
        args[0].each do |pair|
          method_name = %{set_#{pair[0]}}
          raise Exception.f(%{No such setting "#{pair[0]}"}) unless self.respond_to? method_name
          send method_name, pair[1]
        end
        self # important
      end
      
      def set_out(symbol)
        if (String===symbol or Symbol===symbol)
          @out = Hipe::Cli::Io.const_get(symbol.to_s.gsub(/(?:^|_)([a-z])/){|x| $1.upcase}).new
        else
          @out = symbol #!
        end
      end

      # shifts command name off of argv!
      # @return [String] might be empty string (symbols can't be empty)
      def command_name(argv)
        if argv.size == 0
          if (@default_command)
            command_str = @default_command.to_s
          elsif (@help_on_empty && commands[:help])
            command_str = 'help'
          else 
            command_str = ''
          end
        else
          command_str = argv.shift
        end
        command_str
      end

      # dispatch the request to the appropriate command and call run() on it
      # @return whatever the implementing function returns, or the output buffer on failure
      # Note that this in theory captures all syntax errors and outputs them as text
      # so it is not suitable for anything other than a cli environment (e.g not middleware or web)
      def run argv # CLI
        name = command_name(argv)
        unless (command = commands[name])
          argv.unshift(name)
          command = UnrecognizedRequest.new(self)
        end
        res = command.run argv
        if res.respond_to? 'valid?' and ! res.valid?
          @out << res.errors.map{|x| x.message} * ' '
          @out << %{\nPlease see "#{invocation_name} -h } +
            %{#{command.full_name}" for more info.} if commands['help']
        end
        @out
      end

      alias_method :<<, :run

      def invocation_name
        File.basename($PROGRAM_NAME)
      end

      # write the contents of your buffer to the buffer provided
      def >> buffer; buffer << out.read end

      def expecting
        commands.map{|pair| pair[1].full_name}
      end
    end

    # for plugins -- hold a reference to the other app without loading it
    class AppReference
      attr_reader :plugin_name
      attr_accessor :initted # keeping track of whether we gave the child our settings like screen and stdout
      def initialize class_or_class_name, parent_cli, plugin_name
        @class_identifier = class_or_class_name
        @parent_cli = parent_cli
        @plugin_name = plugin_name
      end

      def dereference
        unless @referent
          klass =  @class_identifier.instance_of?(String) ?
            App.class_from_filepath(@class_identifier) : @class_identifier
          raise Exception.f("plugin class must be Hipe::Cli::App") unless
            klass.ancestors.include? Hipe::Cli::App
          @referent = klass.new
          @referent.cli.activate_as_plugin @parent_cli, @plugin_name
        end
        @referent
      end
    end

    module App
      class << self
        attr_reader :classes
      end
      @classes = {}
      def self.class_from_filepath filename
        raise Exception.f(%{Plugin file not found: "#{filename}"},
          {:type=>:plugin_not_found, :filename=>filename,:subtype=>:missing_file}) unless 
          (filename && File.exist?(filename))
        class_name = File.basename(filename).downcase.gsub(/\.rb$/,'').gsub(/(?:[-_]|^)([a-z])/){|m| $1.upcase }
        re = Regexp.new(Regexp.escape(class_name)+'$')
        require filename
        classes = @classes.select(){|name,klass| re =~ klass.name }
        raise Exception.f(%{Expecting to find a class called "#{class_name}" }+
          %{in the plugin file "#{filename}"},
          {:type=>:plugin_not_found, :filename=>filename,:subytype=>:missing_class,:class_name=>class_name}) if
             classes.size == 0
        raise Exception.f(%{We need better logic to deal with files of same names in diff. folders}+
        %{(with name: "#{class_name}")}) if classes.size > 1
        require filename
        classes[0][1]
      end
      def self.included base
        the_same_cli = Cli.new(base)
        base.instance_variable_set('@cli', the_same_cli)
        base.extend ClassMethods
        base.send(:define_method, :cli) do |*args|
          unless @cli
            @cli = the_same_cli
            @cli.app_instance = self # @todo ugly quickfix
          end
          if (args.size > 0)
            @cli.set(*args)
          end
          @cli
        end
        @classes[base.to_s] = base
      end
      module ClassMethods
        # part of the contract of Hipe::Cli is that this is the only method we add
        def cli(*args)
          if (args.size>0)
            @cli.set(*args)
          end
          @cli 
        end
      end
    end

    module ElementLike
      def flyweight(data)
        @data = data
        self
      end
      def name
        @data[:name].to_s
      end
      def title
        name.to_s.gsub('_',' ')
      end
      def keys
        @data.keys
      end
      def [](thing)
        @data[thing]
      end
    end
    class Element
      include ElementLike
    end
    class Option
      include ElementLike
      DEFINITION_RE = %r{^(?:-([a-zA-Z]))? ?(?:--([-a-zA-Z0-9]{2,}))$}
      GETOPT_TYPE = {:boolean => Getopt::BOOLEAN, :increment => Getopt::INCREMENT, :required => Getopt::REQUIRED}
      attr_accessor :name, :long_name, :short_name, :type
      def initialize(name,data={})
        if name.kind_of? String
          begin
            # @todo test for short name only, long name only
            @short_name, @long_name = DEFINITION_RE.match(name).captures
            @name = data[:name] ? data[:name] : @long_name.gsub('-','_').to_sym
          rescue NoMethodError => e
            raise Exception.f(%{please give options a name of the form "-x --alpha-beta"})
          end
        else
          @long_name = name.to_s.gsub('_','-')
          #@short_name = name.to_s[0].chr
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
      include ElementLike, Lingual
      attr_accessor :cli, :data #debugging only!
      [:name, :short_name, :long_name, :options, :required, :optionals, :splat].each do |name|
        define_method(name) do
          @data[name] 
        end
      end      
      def initialize_command cli, data
        raise Exception.f(%{bad type for data "#{data}"}) unless Hash===data
        raise Exception.f(%{bad type for name "#{data[:name].inspect}"}) unless 
          String===data[:name] || Symbol===data[:name]
        @cli = cli
        @data = data
        data[:required]  ||= []
        data[:optionals] ||= []
        data[:options]   ||= []
        data[:splat]     ||= false        
        options = OrderedHash.new
        data[:options].each{|k,v| o=Option.new(k,v); options[o.name] = o }
        data[:options] = options
      end

      def full_name 
        %{#{@cli.command_prefix}#{name}}
      end

      # Process an array of args and turn it into an executable request object, and execute it if it's valid
      # If it's not valid, ***return the request object (which will contain the errors)***
      #
      # @param [Array] argv an array of arguments, as seen in ARGV
      #   This argument list should not include the name of this command itself, that should have been
      #   shifted off already.  
      #
      # @param [RequestLike] if provided the parsed tree will go here.  This is only for custom-
      #   build command classes that want to return custom-build implementations (@fixme change this to procs/lambdas)
      #
      # @return whatever response the command gives if valid, if invalid the request object with errors
      #
      def run argv, request=nil #COMMAND!
        ret = nil
        redirect = catch(:command_redirect) do
          request = prepare_request argv, request
          validate! request
          if request.valid?
            ret = request.execute! @cli.app_instance
          else
           ret = request
          end
          nil # so that the redirect var doesn't get set
        end
        if redirect
          ret = redirect.call
        end
        ret
      end
      alias_method :<<, :run
      
      # @return a request object from either an array or a hash
      def prepare_request argument, request=nil
        request = case argument
          when Hash then process_hash argument, request
          when Array then process_array argument, request
          else raise Exception.f(%{arguments must me arrays or hashes, not "#{argument.class}"},{})
        end
        request.command = self
        request        
      end
      
      def process_hash hash, request=nil
        request ||= RequestHash.new  # hating orderedhash right now
        hash.each do
           |x,y| request[x.to_sym] = y end # string keys become symbol keys here note 1
        request
      end
      
      #@return RequestLike
      def process_array argv, request_class=nil
        cursor = argv.find_index{|x| x[0].chr != '-' } # the index of the first one that is not an option
        cursor ||= argv.size # either it was all options or the argv is empty
        options  = argv.slice(0,cursor)
        required = argv.slice(cursor,self.required.size)
        optionals = argv.slice((cursor+=self.required.size), self.optionals.size) || []
        # in practice a command grammar will almost never have both optionals and splat
        # (really wierd but imagine:)    app.rb --opt1=a --opt2 REQ1 REQ1 [OPT1 [OPT2 [SPLAT [SPLAT]]]]
        cursor += self.optionals.size
        # extra arguments means invalid arguments
        # if a grammar has splat the resulting request will never have extra arguments and vice versa
        splat_or_extra = argv.slice(cursor,argv.size) || []
        splat_ok = !! self.splat
        splat = splat_ok ? splat_or_extra : nil
        extra = splat_ok ? [] : splat_or_extra
        # putting extra args in a hash will make validation easier
        extra_args_hash = extra.size == 0 ? {} :
          Hash[*((0..extra.size-1).to_a.zip(extra)).flatten]
        tree = {}
        tree[:options] = getopt_parse options
        tree[:required] = parse_arguments(self.required,required)
        tree[:optionals] = parse_arguments(self.optionals,optionals)
        tree[:splat] = (splat && splat.size>0) ? {(self.splat[:name]) => splat} : {}
        tree[:extra] = extra_args_hash
        request = request_class ? request_class.new() : Hipe::Cli::OrderedRequest.new()
        request.cli_tree = tree
        request
      end  
      
      # given our command grammar put each Element in an array in the order
      # that it appears on the command line (and the order it will be passed to the implementing method)
      # we represent these things as strings internally! 
      def make_lookup
        @lookup = OrderedHash.new
        options.each do |k,opt|
          @lookup[opt.name.to_s] = opt
        end
        [required,optionals].each do |which|
          which.each do |el|
            @lookup[el[:name].to_s] = el
          end
        end
        if (self.splat)
          @lookup[self.splat[:name].to_s] = self.splat
        end
      end

      def parse_arguments gramma, argv
        OrderedHash[*gramma.slice(0,argv.size).map{|x| x[:name].to_sym }.zip(argv).flatten]
      end

      def getopt_parse argv
        return {} if argv.size == 0 && options.size == 0

        grammar = options.map {|o| [ %{--#{o[1].long_name}}, %{-#{o[1].short_name}},o[1].getopt_type ] }
        begin
          old_argv = ARGV.dup
          ARGV.replace(argv) # Getopt is annoying.  why are we using it?
          parsed_opts = Getopt::Long.getopts(*grammar);
        rescue Getopt::Long::Error, ArgumentError => e
          # totally crazy what we are about to do here.  
          option_name_with_dash = argv[0]
          if (cmd = self.cli.commands[option_name_with_dash] and
            :all == cmd.data[:take_over_when_it_appears_as_an_option_for]
          )
            argv2 = argv.dup # just in case
            argv2.unshift(self.name.to_s)
            throw :command_redirect, lambda{ cmd.run( argv2 ) }
          else
            raise Exception.f('',:type=>:option_issue, :exception=>e, :option=>argv[0],:command=>self)
          end
        ensure
          ARGV.replace(old_argv) # this was breaking our tests b/c bacon was reading it.  EVIL Getopt.
        end
        
        # turn {'alpha'=>1,'a'=>,'beta-gamma'=>2, 'b'=>2} into {:alpha=>1, :beta_gamma=>2}
        ks = options.map{|pair| pair[1].long_name} & parsed_opts.keys
        this = ks.map{|x| x.gsub('-','_').to_sym }.zip(ks.map{|k| parsed_opts[k]})
        
        # sort them in to the original order that was provided on the command line! 
        order = argv.map do |x| 
          md = /^(?:-([a-z0-9])|--([-_a-z0-9]{2,}))/i.match(x)
          ( md[1] ? options.select{|k,v| v.short_name == md[1] } :
          options.select{|k,v| v.long_name == md[2]} )[0][1].name
        end
        
        this.sort!{|x,y| order.index(x[0]) <=> order.index(y[0])}
        result = OrderedHash[*this.flatten]
      end # def

      def validate! request
        valid_keys = required.map{|x| x[:name]} + optionals.map{|x| x[:name]} + options.map{|x| x[0]}
        valid_keys << splat[:name] if splat
        errors = []
        if (invalid_keys = request.keys - valid_keys).size > 0
          sentence = lingual.en{sp(np(adjp('unexpected'),'argument',invalid_keys))}
          errors << Exception.f(sentence.say,:type=>:invalid_keys, :keys=>invalid_keys)
        end
        required_names = required.map{|x| x[:name]}
        required_names << self.splat[:name] if (self.splat && self.splat[:minimum] && self.splat[:minimum] > 0)
        if (missing_keys = required_names - request.keys).size > 0
          sentence = lingual.en{sp(np(adjp('expected'),'argument',pp('missing'),missing_keys))}
          errors << Exception.f(sentence.say,:type=>:missing_keys, :keys=>missing_keys)
        end
        require 'hipe-cli/extensions/predicates'
        make_lookup unless @lookup
        engine = PredicateEngine.new request
        element_object = Element.new
        request.keys.each do |parameter_name|
          element = @lookup[parameter_name.to_s]
          next unless element # assume invalid keys that were caught above 
          element = element_object.flyweight(element) if element.kind_of? Hash
          begin
            engine.run_predicates(element, parameter_name)
          rescue Hipe::Cli::Exceptions::ValidationFail => e
            errors << e
          end
        end
        request.errors.concat(errors)
      end # validate!
    end # CommandLike

    class Command
      include CommandLike
      protected
      def initialize cli, data
        initialize_command cli, data
      end
      def self.factory_via_library(cli,data={})
        libs = cli.libraries
        if (libs.size == 0)
          require 'hipe-cli/extensions/library'          
          libs << Hipe::Cli::Library::Elements  #changes the original!
        end
        class_name = 
        if (data[:class_name]) then data[:class_name]
        else (data[:long_name] || data[:name]).gsub(/(?:^|-)[a-z]/){|x| x.upcase}+'Command' end
        found = nil
        libs.each do |mod|
          if mod.constants.include? class_name  
            found = mod.const_get(class_name)
            break
          end
        end
        if (!found)
          np = lingual.en{ np(:the, 'module', libs.map{|x| x.to_s}, :say_count=>false) }
          raise Exception.f(%{Can't find "#{class_name}" in #{np.say}.}, 
            :class_name=>class_name, :type=>:library_object_not_found )
        end
        obj = found.new(cli,data)
      end
      public
      def self.factory cli, name, data   # Command.factory()
        case data
          when Hash
          when nil then data = {}
          when CommandLike
            command_obj = data
            command_obj.cli = cli
            return command_obj
          when String
            data = {:description => data}
          else
            raise Exception.f(%{bad type for command dat: "#{data}"})
        end
        case name
          when Symbol 
            data[:name] = name
            data[:invoke_with] = name
          when String 
            data[:name] = name
            if md = Option::DEFINITION_RE.match(name)
              data[:short_name] = md[1] if md[1].length > 0
              if (md[2].length > 0)
                data[:long_name] = md[2] if md[2].length > 0
                data[:name] = data[:long_name] # so it looks good in the help screens
              end              
            end
            data[:invoke_with] = data[:long_name] || data[:name]
          else
            raise Exception.f(%{bad type for command name: "#{name}"})            
        end
        
        app_has_it = if cli.app_instance then cli.app_instance.respond_to? data[:invoke_with]
                     else cli.app_class.instance_methods.include? name.to_s end
        if (app_has_it && !data[:library])
          command_obj = Command.new(cli,data)
        else
          begin
            command_obj = factory_via_library(cli,data)
          rescue Hipe::Cli::Exceptions::LibraryObjectNotFound => e 
            require 'hipe-core/reflection'
            require 'hipe-core/lingual'
            methods = Hipe::Reflection.instance_methods(cli.app_instance || cli.app_class) - ['cli']
            sp = lingual.en{sp(
              np(
                adjp('defined'),'method',methods.map{|x| %{"#{x}"}},
                pp('in','the','application')
              )
            )}
            sp.np.say_count = false
            e.message << '  '+sp.say.capitalize
            raise e
          end
        end
        command_obj
      end
    end

    # This manages building and cacheing of command objects from the command data
    # as it is specified in the call to Cli.does().  This is aware of plugins. 
    # It is the external api for grabbing and executing specific commands
    #
    class Commands < OrderedHash
      attr_reader :aliases # only for debugging!
      attr_accessor :local_only # disregard plugins
      def class; Commands end # i hate OrderedHash
      
      def initialize(cli,data)
        super()
        @aliases = {} # e.g. the following: "-h", "--help", "help", :help.
        @cli = cli
        data.each do |k,v|
          self.[]=(k,v)  # do this.  make aliases but no object
        end
      end
      
      def each &block # overrides parent to deal w/ plugins
        super(&block)
        @cli.plugins.each do |name,klass|
          klass.cli.commands.each(&block)
        end unless @local_only
      end
      
      # for when you get a plugin error
      def local
        ret = self.dup
        ret.local_only = true
        ret
      end
      
      def size
        rs = super()
        @cli.plugins.each do |name,klass|
          rs += klass.cli.commands.size
        end unless @local_only
        rs
      end
      
      def has_alias?(key)
        return @aliases.has_key? key
      end
      
      alias_method :orig_set, :[]=
      def []=(key,value)
        if @aliases.has_key?(key)
          raise Exception.f("not sure you meant this") if (CommandLike===orig_fetch(key))
        end
        @aliases[key] = key
        case key
        when Symbol then @aliases[key.to_s] = key
        when String then
          if key.length < 0 then raise Exception.f("invlaid command name",:type=>:usage_fail) end
          if md = Option::DEFINITION_RE.match(key)
            @aliases[%{-#{md[1]}}] = key if md[1].length > 0
            @aliases[%{--#{md[2]}}] = key if md[2].length > 0
            @aliases[md[2]] = key
            symbolize_me = md[2]
          else
            symbolize_me = key
          end
          @aliases[symbolize_me.gsub(/[^-_a-z0-9]/i,'').gsub('-','_').downcase.to_sym] = key
        else
          raise Exception.f(%{invalid name for command: "#{key}"},:type=>:usage_fail)
        end
        super(key,value)
      end
      
      # @raise PrefixNotRecognized, 
      # @return nil or Command object
      # note 1: we decided to let users decide whether to use symbols or strings as names. 
      alias_method :orig_fetch, :[]
      def [](name)  
         # if it's a pluginy-looking name, return it and don't cache it
         if String===name && name.include?(':')
           this, that = Plugins.split_command(name)
           if (plugin = @cli.plugins[this]) 
             return plugin.cli.commands[that]
           else
             raise Exception.f(%{Sorry, prefix is not associated with any known plugin: "#{this}"},
               :type=>:prefix_not_recognized)
           end
         end
         return nil unless orig_name = @aliases[name]
         spr = super(orig_name)
         if spr.kind_of? CommandLike
           command = spr
         else
           command = Command.factory(@cli, orig_name, spr)
           raise Exception.f("failed to build command!") unless command.kind_of?(CommandLike)
           self[orig_name] = command   # we clobber the original 'spr' here, hoping that the object has it
         end
         command
       end
    end
    module Erroneous
      def errors
        @errors ||= []
        @errors
      end
      def valid?
        !@errors || @errors.size == 0
      end
    end
    module RequestLike
      include Lingual, Erroneous
      attr_reader :cli_tree
      attr_accessor :command
      def cli_tree= tree
        @cli_tree = tree
        [:options,:required,:optionals, :splat].each do |which|
          @cli_tree[which].each do |k,v|
            self[k] = v
          end
        end
        @extra = tree[:extra]
      end
      # prepares the arguments in an order suitable for the app's function and calls it
      # @param [Hipe::Cli::App] app
      # @return the result of the call to the implementing function
      def execute! app # RequestLike
        unless valid?
          raise Exception.f("request hasn't been validated yet!") unless @errors
          error_strings = lingual.list(@errors.map{|x| x.message} )
          sp = lingual.en{ sp(
            np('issue', pp('preventing','the','request','from','being','processed'),
              error_strings
            )
          ) }
          raise Exception.f(sp.say,:errors=>errors,:command=>@command,:type=>:validation_failure)
        end
        raise Exception.f(%{please implement "#{command.name}"}) unless app.respond_to? command.name
        method = app.method(command.name)
        args = prepare_ordered_arguments
        method.call(*args)
      end
      
      def prepare_ordered_arguments
        args = @command.required.map{|x| self[x[:name]]} + @command.optionals.map{|x| self[x[:name]]}
        args << self[@command.splat[:name]] if @command.splat
        if (@command.options.size>0)
          # maintain the original order of the provided options
          opts = OrderedHash.new
          provided = (self.keys & @command.options.keys)
          provided.each do |sym|
            opts[sym] = self[sym]
          end
          args << opts
        end   
        args
      end
    end
    

    class OrderedRequest < OrderedHash; include RequestLike end
    
    class RequestHash < Hash; include RequestLike end    

    class UnrecognizedRequest
      include Lingual
      def initialize cli; @cli = cli end
      def run argv
        out = @cli.out
        out.puts %{Unexpected command "#{argv.first}".  Expecting }+
        lingual.list(@cli.expecting).or{|x| %{"#{x}"}}
        if @cli.help_on_empty?
          out.puts %{See "#{@cli.invocation_name} -#{@cli.commands[:help].short_name}" for more information.}
        end
        out
      end
    end

    class Plugins < OrderedHash
      # check string.include? ':' before you call this
      def self.split_command(string)
        md = %r{^([^:]+):(.+)$}.match(string)
        if md
          return md.captures
        end
      end
      
      alias_method :fetch, :[]
      def [](name)
        if (guy = fetch(name.to_s))
          guy.dereference
        end
      end
      
      alias_method :set, :[]
      def []=(k,v); super(k.to_s,v) end
    end
    module Io
      class BufferString < Hipe::Io::BufferString
        include Erroneous
      end
      # an all purpose response object
      class GoldenHammer < Hash
        include Erroneous, Hipe::Io::BufferStringLike
        def string
          @string ||= ''
        end
        alias_method :message, :string
      end
    end
  end # Cli
end # Hipe
