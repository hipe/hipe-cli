require 'rubygems'
require 'orderedhash'
require 'ostruct'
require 'hipe-core'
require 'hipe-core/lingual/ascii-typesetting'
require 'hipe-core/lingual/en'
require 'hipe-core/struct/open-struct-like'
require 'hipe-core/io/golden-hammer'


module Hipe
  module Cli
    VERSION = '0.0.9'
    DIR = File.expand_path('../../',__FILE__) # only used by tests that use examples :/
    AppClasses = {}
    def self.included klass
      cli = Cli.new(klass)
      klass.instance_variable_set('@cli', cli)
      klass.extend AppClassMethods
      klass.send(:define_method, :cli) do
        @cli ||= cli.dup_for_app_instance(self)
      end
      AppClasses[klass.to_s] = klass
    end
    module AppClassMethods
      def cli; @cli end
    end
    def self.make_definition(type_module, name, list, block)
      # find any hashes that do not follow arrays and assert there is no more then one... then make it an opts hash
      opt_hashes, i = [], nil
      list.each_with_index do |val, i|
        opt_hashes << val if (Hash===val and i==0 || !(Array===list[i-1]))
      end
      if (opt_hashes.size > 0)
        raise Exception.f(%{Cannot have more than one options hash for "#{name}"}) if opt_hashes.size > 1
        opt_hash = list.slice!(i,1)[0]
      end
      OpenStruct.new({:hipe_type=>type_module, :first_arg => name, :list => list, :block => block, :opt_hash=>opt_hash})
    end
    # because of the crazy nature of the code blocks this needs to be run for each call to run()
    # @return [OptionValues] the hash that is in scope when you made the definition
    # @post_condition: @definitions, @switches_by_name, @switches_by_type get set.  Not ordered for now.
    def self.definition_proc(definitions = nil,opt_values=nil)
      Proc.new do
        @prev = nil                       # for the "fsa" that makes sure things appear in the right order
        if definitions.nil?
          @definitions = []                # added to in instance eval below
        end
        opt_values ||= OptionValues.new   # is in scope below for switches to write their results to
        @switches_by_name = { }           # hold on to each switch that OptParser builds
        @switches_by_type = { Switch=>[], Positional=>[], Required=>[], Optional=>[], Universal=>[], Splat=>[] }
        # if you have no definitions and block then you are done.
        if (@block || definitions)
          pass_this_to_op = lambda do |opts| # build all the switches for options, required, optionals, splat in one go
            @option_parser = opts           # is made available thru opts() so definitions can e.g. opts.separator()
            self.instance_eval(&@block) unless definitions # runs all the option(), required(), optional(), splat() definitions
            (definitions || @definitions).each do |my_info|  # with each one of those definition we 'recorded' ...
              first_arg = my_info.first_arg.to_s
              unless /^-/ =~ first_arg
                first_arg = %{--#{first_arg} VALUE} # positional arguments will need proper names and parameters
              end                           # only for their construction (hack alert!)
              switch = opts.define(first_arg,*my_info.list,&my_info.block) # make an optional, required, option, etc.
              my_info.command = self
              switch = my_info.hipe_type.enhance_switch(switch, my_info)  # for now it returns the same object but maybe not later
              @switches_by_type[switch.hipe_type] << switch
              if (Positional===switch)
                @switches_by_type[Positional] << switch  # like an abstract base class. never the actual hipe_type
              end
              @switches_by_name[switch.main_name] = switch
              orig_block = switch.block
              new_block = Proc.new() do |it|
                if orig_block
                  It.make_it_an_It(it, self, switch)
                  result_from_original = orig_block.call(it)
                  un_it = It.make_it_not_an_It(result_from_original)
                  opt_values[switch.main_name] = un_it
                else
                  opt_values[switch.main_name] = it
                end
              end
              switch.instance_variable_set('@block',new_block)
            end
          end
          OptionParser.new(&pass_this_to_op) # really confusing -- a bunch of stuff above in this scope gets set
        end
        opt_values
      end
    end
    def self.apply_defaults(switches, argv)
      shorts, longs = [], []
      argv.grep(/(?:^(-[a-z0-9]))|(?:^(--[a-z0-9][-a-z0-9]+))/){|_| shorts<<$1 if $1; longs<<$2 if $2 }
      switches.select{|x| (x.short & shorts).size == 0 and (x.long & longs).size == 0 }.each do |x|
        argv.concat( (x.long.size > 0 ) ? [x.long[0], x.default ] : [%{#{x.short[0]}#{x.default}}] )
      end
    end
    class Cli
      attr_reader :commands, :parent_cli, :output_registrar, :out, :universals, :opts
      attr_accessor :description, :plugin_name, :default_command, :program_name, :config
      def initialize(klass)
        @app_class = klass
        @app_instance = @plugins = @default_command = nil
        @commands = Commands.new(self)
        @out = Out.new
        @universals = []
      end
      def dup_for_app_instance(instance)
        spawn = self.dup
        spawn.init_for_app_instance(instance)
        spawn
      end
      def init_for_app_instance(instance)
        @app_instance = instance
        @commands = @commands.dup
        @commands.cli = self
        if (@plugins)
          @plugins = @plugins.dup
          @plugins.cli = self
        end
      end
      def init_as_plugin(parent_app_instance, name, plugin_app_instance)
        @parent_cli = parent_app_instance.cli
        @plugin_name = name
        init_for_app_instance(plugin_app_instance)
      end
      def app_instance!
        raise "there is no app instance!" unless @app_instance
        @app_instance
      end
      def app_instance; @app_instance; end
      def does name, *list, &block
        @commands.add(name, *list, &block)
      end
      def plugin
        @plugins ||= Plugins.new(self)
      end
      alias_method :plugins, :plugin # hm
      def command_prefix
        @plugin_name ? %{#{@parent_cli.command_prefix}#{@plugin_name}:} : nil
       end
      def universals
        parse_universals if @switches_by_name.nil?
        @switches_by_name
      end
      def parse_universals
        definition = Hipe::Cli.definition_proc(@universals)
        instance_eval(&definition)
      end
      def parse_universal_values(argv)
        univ_values = Hipe::OpenStructLike[parse_universals]
        # oh boy..find the first instance of a token in argv that looks like a switch for which we
        # have no corresponding short or long switch.
        univ = @switches_by_name.values.map{|x| x.short + x.long }.flatten
        idx = argv.find_index{|x| (md=/^(-[a-z0-9])|(--[a-z0-9][-a-z0-9_]*)/i.match(x)) && (univ & md.captures).size == 0}
        later = (idx) ? argv.slice!(idx, argv.size-idx) : []
        if ((sw=@switches_by_name.values.select{|x| x.has_default?}).size > 0) then Hipe::Cli.apply_defaults(sw, argv) end
        @option_parser.parse!(argv)
        argv.concat(later)
        univ_values
      end
      def run argv # cli
        begin
          univ_values = parse_universal_values(argv) if (@universals.size>0)
          @opts = univ_values
          @app_instance.before_run if @app_instance.respond_to?(:before_run)
          if (cmd = @commands[name = (argv.shift || @default_command)])
            rs = cmd.run(argv,univ_values)
            rs.execution_context = :cli if rs.respond_to?("execution_context=")
            rs.nil? ? '' : rs
          else
            bad_command(name)
          end
        rescue ::Exception => e
          if Exception.graceful_list?(e)
            e = ParseErrorExtension.enhance_if_necessary(e,self)
            ret = ValidationFailures.new([e])
            ret.execution_context = :cli
            return ret
          else
            raise e
          end
        end
      end
      def bad_command(name)
        return "done.\n" if name.nil? and @commands.size == 0;
        list = Hipe::Lingual::List[@commands.map{|pair| %{"#{pair[1].full_name}"}}].or()
        s = %{Unexpected command "#{name}".  Expecting #{list}.\n}
        s << %{See "#{program_name} -h" for more info.\n} if @commands['-h']
        s
      end
      def program_name
        @program_name || (@parent_cli ? @parent_cli.program_name : File.basename($0,'.*'))
      end
      def help_recursive(argv,depth)
        return '' unless argv[0] =~ /^(?:-h|--help|-\?|help)$/
        if (depth == 0) then ret = %{Unfortunately there is no help if you want help on #{argv.shift}}
        elsif (depth > 6) then return "  [...[...[..[.]]]]"
        else
          use_depth = (depth > 3) ? (rand(5)+1) : depth
          adv = case use_depth; when 1..2 then ' in turn'; when 3 then ' as you probably guessed'; else ''; end
          ret = %{, which#{adv} does not have help for "#{argv.shift}"}
        end
        ret << help_recursive(argv,depth+1) if argv.size > 0
        ret
      end
      def help(*argv)
        return help_recursive(argv,0) if argv.size > 0 && argv[0] =~ /^(?:-h|--help|-\?|help)$/
        opts = OptionParser.new # hack just to use its display.  See Version 0.0.2 also
        list = opts.instance_variable_get('@stack')[2]
        commands_size = @commands.size
        opts.banner = generate_banner + "\n\n" +
          Hipe::Lingual.en{sp(np(adjp('available'),'subcommand',commands_size,:say_count=>false))}.say.capitalize + ':'
        @commands.each do |key, command|
          switch = OptionParser::Switch.new(nil,nil,nil,[command.full_name],nil,command.desc_arr,Proc.new{})
          list.append(switch,[switch.short],[switch.long])
        end
        return opts.to_s
      end
      def screen; @screen ||= OpenStruct.new({:width=>77}); @screen end
      def generate_banner
        lines = []
        lines <<  (%{#{program_name} - #{description}\n}) if description
        left = %{usage: #{program_name}}
        right = Hipe::AsciiTypesetting::FormattableString[ [
          ' ' + universals.values.map{|x|%{#{x.syntax}} } * ' ',
          ' ' + @commands.select{|i,cmd| OptionyLookingCommand === cmd}.map{|c|
            '[' + ([c[1].short_name,c[1].long_name].compact * '|') + ']'
          }.uniq * ' ',
          ' COMMAND [OPTIONS] [ARG1 [ARG2 [...]]]'].select{|x| x.strip.length > 0}.join ]
        right_column_width = [20, screen.width-left.length].max
        lines << left + right.word_wrap_once!(right_column_width)
        lines << right.word_wrap!(right_column_width).indent!(left.length) if right.size > 0
        lines * "\n"
      end
      def option(name,*list,&block)
        @universals << Hipe::Cli.make_definition(Universal, name, list, block)
      end
    end
    class Out
      alias_method :actual_class, :class
      attr_accessor :class
      def new; @class.new end  # note this is not the class method but an instance method
    end
    class Commands < OrderedHash
      attr_reader :aliases
      attr_accessor :cli
      def initialize(cli)
        super()
        @aliases = {}
        @cli = cli
      end
      def add(name, *list, &block)
        command = CommandFactory.command_factory(name, *list, &block)
        name_str = command.main_name.to_s
        command.aliases.each do |aliaz|
          raise Exception.f(%{For now we can't redefine commands ("#{aliaz}")}) if @aliases[aliaz]
          @aliases[aliaz] = name_str
        end
        self[name_str] = command
      end
      def [](aliaz)
        name = aliaz.to_s
        name = @cli.default_command.to_s if (name=='' && @cli.default_command)
        if (cmd = super(@aliases[name]))
          cmd.app_instance = @cli.app_instance
          cmd
        elsif name.include? ':' or (plugin = @cli.plugins[name])
          if (plugin)
            name = ''  # the command to the main app was the plugin name alone.  trigger its default command
          else
            plugin_name, name = /^([^:]+):(.+)/.match(name).captures
            unless (plugin = @cli.plugins[plugin_name])
              raise Exception.f( %{unrecognized plugin "#{plugin_name}". Known plugins are }+
                Hipe::Lingual::List[@cli.plugins.map{|x| %{"#{x[1].cli.plugin_name}"} } ].and(),
                :type=>:unrecognized_plugin_name)
            end
          end
          plugin.cli.commands[name]
        end
      end
      def each(&block)
        super(&block)
        @cli.plugins.each do |k,plugin|
          plugin.cli.commands.each(&block)
        end
      end
      def size
        super + @cli.plugins.inject(0){ |memo,pair| memo + pair[1].cli.commands.size }
      end
      protected :[]=
    end
    module CommandFactory
      def self.command_factory(name, *list, &block)
        o = parse_grammar(name,*list)
        (o.short_name || o.long_name) ? OptionyLookingCommand.new(o, &block) : Command.new(o, &block)
      end
      LONG_NAME_WITHOUT_ARGS = /^--([-_a-z0-9]+)/i
      # optparse does something similar, too but we don't use it to parse commands themselves because
      # there isn't enough crossover. (command elements are in fact more complex than commands here.)
      def self.parse_grammar(name,*list)
        o = OpenStruct.new()
        if (Symbol===name) then o.main_name = name
        elsif (String===name)
          if md = LONG_NAME_WITHOUT_ARGS.match(name)
            o.long_name = md[1]
            o.main_name = o.long_name
          elsif md = /^-([a-z0-9])$/i.match(name)
            o.short_name = md[1]
            if list.size>0 and md = LONG_NAME_WITHOUT_ARGS.match(list[0])
              o.long_name = md[1]
            end
            o.main_name = (o.long_name || o.short_name).downcase.gsub('-','_').to_sym
          else
            o.main_name = name
          end
        else
          raise Exception.f(%{bad type for name: #{name.class}},:type=>:grammar_grammar) # leave type in for tests
        end
        if (idx = list.find_index{|x| String===x and /^[^-]/ =~ x  })
          o.description = list[idx]
        end
        o
      end
    end
    module CommandElement #required arguments, optional arguments, options (switches) and splat
      attr_accessor :app_instance
      attr_reader :description, :default, :hipe_type, :command
      def self.enhance_switch(switch,my_info)
        switch.extend my_info.hipe_type
        switch.init_as_hipe_type(my_info)
        switch
      end
      def init_as_hipe_type(my_info)
        @command = my_info.command
        @hipe_type = my_info.hipe_type
        opt_hash = my_info.opt_hash
        @errors = nil
        if (opt_hash)
          if opt_hash.has_key? :default
            if (@arg.nil? or !(/[^ ]/=~@arg) or (/\[\]/=~@arg))
              raise Exception.f(%{for "#{main_name}" to take a default value it must take a required arg, not "#{@arg}"})
            end
            set_default(opt_hash.delete(:default))
          end
        end
      end
      def main_name; switch_name.gsub('-','_').downcase.to_sym; end
        #swt
        # str = nil                      @ todo
        # if (@long && @long.size > 0)
        #   str = /^-?-?(.+)/.match(@long[0]).captures[0]
        # elsif (@short && @short.size > 0)
        #   str = /^-?(.+)/.match(@short[0]).captures[0]
        # end
        # str.gsub('-','_').downcase.to_sym
      #end
      def surface_name
        /^-?-?(.+)/.match(@long[0]).captures[0]
      end
      def human_name
        surface_name.gsub(/-|_/,' ')
      end
      def set_default(val) # separate method only so that required positionals can complain
        @has_default = true
        @default = val
      end
      def has_default?; @has_default end
      def add_validation_failure(validation_failure)
        validation_failure.command_element ||= self
        command.add_validation_failure(validation_failure)
      end
    end
    module Switch # always an OptionParser switch, enhanced
      include CommandElement
      def self.enhance_switch(*args); CommandElement.enhance_switch(*args); end
      def syntax
        joinme = []
        joinme << (@short[0] + (@long[0] ? '' : (@arg||''))) if @short[0]
        joinme << (@long[0] + (@arg||'')) if @long[0]
        %{[#{joinme.join('|')}]}
      end
    end
    module Positional # a pseudo "abstract" "module" for required and optional
      include CommandElement
      def self.enhance_switch(*args); CommandElement.enhance_switch(*args); end
      def prepare_for_display
        @long[0].gsub!(/^--/,'')
        @arg = nil
      end
      def prepare_for_parse
        @long[0].replace(%{--#{@long[0]}})
        @arg = ' '
      end
      def init_as_hipe_type(*args)
        super(*args)
        prepare_for_display
      end
    end
    module Required  # a required positional argument
      include Positional
      def self.enhance_switch(*args); Positional.enhance_switch(*args); end
      def set_default(val)
        raise Exception.f(%{required arguments can't have defaults ("#{main_name}")})
      end
    end
    module Optional # an optional positional argument
      include Positional
      def self.enhance_switch(*args); Positional.enhance_switch(*args); end
    end
    module Splat # always at the end of the grammar
      include CommandElement
      def self.enhance_switch(*args); CommandElement.enhance_switch(*args); end
    end
    module Universal # application-level options that can appear before the command
      include Switch
      def self.enhance_switch(*args); Switch.enhance_switch(*args); end
    end
    # This is just a plain old (ordered) hash for storing the values from *all* command elements
    # (required, optional, options, splat) during the parse.  The difference is that when a value
    # is attempted to be added with when that key already exists, the existing value is turned
    # into an array and the new value is added to it.   This is a lazy way to allow any
    # option to be specified multiple times. (i don't know if/how OptParse handles that...@todo)
    #
    class OptionValues < OrderedHash
      def initialize
        super()
        @changed_to_array = {}
      end
      def []=(x,y)
        if (has_key?(x))
          unless (@changed_to_array[x])
            super(x,[self[x]])
            @changed_to_array[x] = true
          end
          self[x] << y
        else
          super(x,y)
        end
      end
    end
    module It
      @predicate_modules = []
      def self.register_predicates(mod); @predicate_modules.unshift mod end
      def self.module_with_method(method_name)
        predicate_module_names = @predicate_modules.map{|x| x.to_s}
        raise Exception.f(%{Can't find predicate "#{method_name}()" anywhere within }+
          Hipe::Lingual.en{np('registered predicate module',predicate_module_names,:say_count=>false)}.say) unless
            it = @predicate_modules.detect{|x| x.instance_methods.include? method_name.to_s}
         it
      end
      def self.changed_type(it,previous_it) # @TODO refactor
        return it unless has_virtual_class? it
        it.extend It
        it.init_it_with_it(previous_it)
        it
      end
      attr_accessor :command, :command_element
      def method_missing name, *args
        self.extend It.module_with_method(name)
        send(name,*args)
      end
      def self.make_it_an_It(it,command,command_element)
        it.extend self
        it.reinit_it!(command,command_element)
      end
      def self.has_virtual_class?(it)  # see zenspider/manvery/shevy's comments at 2009-12-20 20:50  @TODO refactor
        begin
          class << it; end
        rescue TypeError => e
          raise e unless e.message.match(%r{no virtual class})
          return false
        end
        return true
      end
      def self.make_it_not_an_It(it)
        return it unless has_virtual_class?(it)
        class << it
          undef_method :method_missing
        end
        it
      end
      def reinit_it!(command, command_element)
        raise %{must be Commmand! had "#{command.class}"} unless Hipe::Cli::Command === command #@todo remove?
        raise %{must be CommmandElement! had "#{command_element.class}"} unless
          Hipe::Cli::CommandElement === command_element #@todo remove?
        @command = command
        @command_element = command_element
      end
      def init_it_with_it(it)
        reinit_it!(it.command, it.command_element)
      end
      def add_validation_failure(f)
        f.info.provided_value = self unless f.info.provided_value
        @command_element.add_validation_failure(f)
      end
    end
    class Elements  # just a wrapper for elements_by_name, elements_by_type
      def initialize(command); @command = command end
      def size;                @command.switches_by_name.size; end
      def each &block;         @command.switches_by_name.each(&block) end
      def all;                 @command.switches_by_name; end
      def positionals;         @command.switches_by_type[Positional] end
      def options;             @command.switches_by_type[Switch] end
      def requireds;           @command.switches_by_type[Required] end
      def optionals;           @command.switches_by_type[Optional] end
      # splat is always only zero or one element, no need for plural alias
      def splat; @command.switches_by_type[Splat].size > 0 ? @command.switches_by_type[Splat][0] : false end
      alias_method :switches,   :options
      def method_missing(name,*args)
        if (name=[%{#{name}s},%{#{name}es}].detect{|x| respond_to?(x)}) then return self.send(name,*args) end
        raise NoMethodError.new("undefined method `#{name}' for #{self.inspect}")
      end
    end
    module CommandLike # probably no reason to be a module
      attr_accessor :app_instance
      attr_reader :description
      def take_names(o) # take the contents of a parse tree containing main_name, long_name, etc
        o.instance_variable_get('@table').each do |name,value|   # see CommandFactory#parse_grammar
          instance_variable_set(%{@#{name}}, value)
        end
      end
      def main_name; @main_name end
      def full_name # always return a string here! optparse wants it for length()
        %{#{@app_instance.cli.command_prefix}#{main_name}}
      end
      def as_method_name; main_name.to_s.gsub('-','_').downcase.to_sym end
      def desc_arr  # if we wanna be like optparse, return an array.
        return [] unless @description
        Hipe::AsciiTypesetting::FormattableString[@description].word_wrap!(39).split("\n") # @todo
      end
    end
    class Interrupt < OpenStruct
      def self.[](hash)
        me = self.new(hash)
        throw :interrupt_validation, me
      end
    end
    class Command
      attr_reader :option_parser, :switches_by_name, :switches_by_type, :opt_values # for testing and debugging only
      include CommandLike
      def initialize(names, &block)
        @definitions = @elements = @switches_by_name = @switches_by_type = @app_instance = @elements = nil
        @block = block
        take_names(names)
      end
      def aliases
        [@main_name.to_s]
      end
      def elements
        if @elements.nil?
          parse_definition if (@definitions.nil?)
          @elements = Elements.new(self)
        end
        @elements
      end
      def parse_definition(univ_values = nil)
        definition = Hipe::Cli.definition_proc(nil, univ_values)
        instance_eval(&definition)
      end
      def help_switch
        elements.switches.each do |s|
          return '-h' if s.short.include?('-h')
          return '--help' if s.long.include?('--help')
        end
        return nil
      end
      def add_validation_failure(validation_failure)
        validation_failure.command ||= self
        @validation_failures.push(validation_failure)
      end
      def run(argv,univ_values = nil)
        @validation_failures = []
        ret = opt_values = args_for_implementer = nil  #@TODO SEE WHAT BREAKS IF YOU MAKE THIS A MEMBER VARIABLE
        begin
          return run_with_application(argv,univ_values) unless @block #if there is no definition block we pass the args raw
          opt_values = parse_definition(univ_values)
          Hipe::OpenStructLike[opt_values]
          ret = catch(:interrupt_validation) do
            sws = @switches_by_type
            if (sw = sws[Switch].select{|x| x.has_default? }).size>0 then Hipe::Cli.apply_defaults(sw, argv) end
            opts.parse!(argv) if sws[Switch].size > 0
            sws[Positional].each{|x| x.prepare_for_parse }  # bad hack.  now we need the dashes
            if sws[Positional].size > 0
              new_argv = turn_positionals_into_switches( sws[Positional], argv)
              if (sw = sws[Positional].select{|x| x.has_default? }).size>0 then Hipe::Cli.apply_defaults(sw, new_argv) end
              opts.parse!(new_argv)
            end
            missing = (sws[Required].map{|x| x.main_name} - opt_values.keys).map{|x| @switches_by_name[x]}
            error_missing(missing) if missing.size > 0
            error_needless(argv) if (argv.size > 0)
            args_for_implementer = flatten_args(sws, opt_values,!!univ_values)
            Interrupt[:because=>:validation_failures] if @validation_failures.size > 0
          end
          unless Interrupt === ret
            ret = run_with_application(args_for_implementer)
          end
        rescue ::Exception => e
          if Exception.graceful_list?(e)
            e = ParseErrorExtension.enhance_if_necessary(e,self)
            ret = Interrupt.new(:because=>:validation_failures)
            @validation_failures << e
          else
            raise e
          end
        end
        if (Interrupt===ret)
          ret = case ret.because
            when :validation_failures then ValidationFailures.new(@validation_failures)
            when :goto then @opt_values = opt_values; instance_eval(&ret.block)
            when :done then ret.return
            else ret end
          @validation_failures = nil # important.  command is supposed to be stateless ?
        end
        ret
      end
      def flatten_args(switches, opt_values, univ_values_defined)
        arg_array = []
        switches[Positional].each do |switch|
          arg_array << opt_values.delete(switch.main_name) # ok if nil
        end
        if (switches[Switch].size > 0 || univ_values_defined)
          arg_array << opt_values # even if it is empty, but not if there were no options in the definition
        end
        arg_array
      end
      def turn_positionals_into_switches(positional, argv)
        new_argv = []
        positional.each do |switch|
          break if (argv.size == 0)
          new_argv << switch.long.first
          new_argv << argv.shift
        end
        new_argv
      end
      def error_missing(missing)
        names = missing.map{|x| x.surface_name }
        e = OptionParser::MissingArgument.new(Hipe::Lingual::List[names].and())
        e.reason = Hipe::Lingual.en{ sp(np(adjp('missing','required'),'argument',names.size)) }.say
        raise e
      end
      def error_needless(argv)
        e = OptionParser::NeedlessArgument.new
        names = argv.map{|x| %{"#{x}"}}
        sp = Hipe::Lingual.en{ sp(np(adjp('unexpected'),'argument',names))  }
        e.reason = sp.say
        raise e
      end

      # the below are the official "api" methods that command elements should know exist:
      def option   (name,*list,&block); define(%s{options},            Switch,     name, list, block) end
      def required (name,*list,&block); define(%s{required arguments}, Required, name, list, block) end
      def optional (name,*list,&block); define(%s{optional arguments}, Optional, name, list, block) end
      def splat    (name,*list,&block); define(%s{splat definition},   Splat,              name, list, block) end
      def opts; @option_parser; end
      def help; # be sure to circumvent normal validation of the command if the user wants to display help for a command
        lambda do
          cli = app_instance.cli
          re = Regexp.new('Usage: '+Regexp.escape(cli.program_name)+' \[options\]')
          if  re =~ @option_parser.banner # if it's the default generated banner thing...
            s = ''
            s << %{#{full_name} - #{description}\n\n} if description
            s << %{Usage: #{app_instance.cli.program_name} #{full_name}}
            s << ' '+elements.switches.map{|x| x.syntax }.join(' ') if elements.switches.size > 0
            s << ' '+elements.required.map{|x| x.main_name }.join(' ') if (elements.required.size > 0)
            s << ' '+elements.optionals.map{|x| %{[#{x.main_name}]} }.join(' ') if (elements.optionals.size > 0)
            s << ' '+%{[#{elements.splat.main_name} [#{elements.splat.main_name} [...]]]} if (elements.splat)
            @option_parser.banner = s
          end
          Interrupt[:because=>:done, :return => @option_parser.to_s]
        end
      end
      def goto(&block); Interrupt[:because=>:goto, :block=>block] end #appropriately named
      @fsa = {
        %s{options}            => [nil, %s{options}],
        %s{required arguments} => [nil, %s{options}, %s{required arguments}],
        %s{optional arguments} => [nil, %s{options}, %s{required arguments}, %s{optional arguments}],
        %s{splat definition}   => [nil, %s{options}, %s{required arguments}]
      }
      class << self
        def valid_state_change?(prev,current)
          @fsa[current].include? prev
        end
      end
      def define(state_symbol, type_module, name, list, block)
        unless (@prev.nil? or Command.valid_state_change?(@prev, state_symbol))
          raise Exception.f(%{#{state_symbol} should not appear after #{@prev}})
        end
        @prev = state_symbol
        @definitions << Hipe::Cli.make_definition(type_module,name,list,block)
      end
      def run_with_application(argv,univ_values=nil)
        if @app_instance.respond_to?(as_method_name)
          if (univ_values) # then there were no command-level options defined and the implementer can decide if it wants these
            arity = @app_instance.method(as_method_name).arity
            argv << univ_values if arity.abs >= (argv.length + 1)
          end
          begin
            @app_instance.send(as_method_name, *argv)
          rescue ArgumentError => e
            msg = nil
            if md = /wrong number of arguments \((\d+) for (\d+)\)/.match(e.message)
              msg = %{Your #{@app_instance.class}\##{as_method_name}() must take #{md[1]} arguments to }+
              %{correspond to the grammar defined for the command. You take #{md[2]}.}
            end
            raise msg.nil? ? e : Exception.f(msg) # re-raise original unless we were able to mess w/ it
          end
        elsif([:help].include? as_method_name)
          @app_instance.cli.help(*argv)
        else
          raise Exception.f(%{Please implement "#{as_method_name}"})
        end
      end
    end
    # these are expected to almost always be '-v --version' and '-h --help', and probably rarely made by users (?)
    # we don't use optparse directly for these because there's actually very little crossover
    class OptionyLookingCommand < Command
      def initialize(o, &block)
        take_names(o)
        @block = block
      end
      def aliases
        [@main_name.to_s, short_name, long_name].compact
      end
      def short_name; @short_name ? %{-#{@short_name}} : nil end
      def long_name; @long_name ? %{--#{@long_name}} : nil end
    end
    class Plugins < OrderedHash
      attr_accessor :cli
      alias_method :set, :[]= # necessary in [] because we rewrite the class with the instance using the same name
      def initialize(cli)
        @cli = cli
        @dirs = nil
        super()
      end
      def <<(klass)
        raise Exception.f(%{no: "#{klass}}) unless (Class == klass.class) && klass.ancestors.include?(Hipe::Cli)
        name = klass.to_s.match(/([^:]+)$/).captures[0].gsub(/([a-z])([A-Z])/){ %{#{$1}-#{$2}}}.downcase
        self[name] = klass
      end
      def []=(name, value)
        name = name.to_s
        raise GrammarGrammarException.f(%{Can't redefine a plugin ("#{name}")}) if has_key?(name)
        super(name,value)
      end
      def [](name)
        load_all!
        name = name.to_s
        return nil unless (plugin_class_or_app_instance = super(name))
        if (Class===plugin_class_or_app_instance)
          app_instance = plugin_class_or_app_instance.new
          app_instance.cli.init_as_plugin(@cli.app_instance!, name, app_instance)
          self.set(name,app_instance)
          return app_instance
        else
          return plugin_class_or_app_instance # assume it is app instance!
        end
      end
      def each(&block)
        load_all!
        super(&block)
      end
      def add_directory(full_path,container_module,opts={})
        if opts[:lazy]
          @dirs ||= []
          @dirs << [full_path,container_module]
        else
          add_directory!(full_path, container_module)
        end
      end
      def add_directory!(full_path,container_module)
        require 'hipe-core/infrastructure/class-loader'
        skip_file = (File.join full_path, 'ignore-list')
        skip_list = File.exist?(skip_file) ? File.read(skip_file).split("\n") : []
        files = Dir[File.join full_path, '*.rb']
        raise Exception.f(%{no plugins in directory: "#{full_path}"}) unless files.size > 0
        files.each do |filename|
          next if skip_list.include?(File.basename(filename))
          self << Hipe::ClassLoader.from_file!(filename,container_module)
        end
      end
      def size
        load_all!
        super
      end
      protected
      def load_all!
        return unless @dirs
        @cli.app_instance.before_plugins_load if @cli.app_instance.respond_to?(:before_plugins_load)
        @dirs.each do |arr|
          add_directory!(arr[0],arr[1])
        end
        @dirs = nil
      end
    end
    class ValidationFailures < Hipe::Io::GoldenHammer
      attr_writer :execution_context
      def initialize(array_of_failures)
        @execution_context = nil
        @errors = array_of_failures
      end
      def to_s
        msg = @errors.map{|x| x.msg || %{Unknown error from #{x}}}.join(' AND ')
        if :cli == @execution_context
          @errors.map{|x| x.command && x.command.help_switch ? x.command : nil }.compact.uniq.each do |x|
            msg << %{\nSee "#{x.app_instance.cli.program_name} #{x.full_name} #{x.help_switch}" for more info.}
          end
        end
        msg
      end
    end
    module ParseErrorCommon # common to both our ValidationFailures and ones thrown from OptParse (ParseErrorExtension)
    end
    class ValidationFailure < OptionParser::InvalidArgument
      include ParseErrorCommon
      attr_reader :info
      attr_accessor :command, :command_element
      def self.f(info) # factory
        info = {:message => info} if String === info
        return self.new(info)
      end
      def message
        if (@info.message_template)
          template_values = @info.instance_variable_get('@table').dup
          use_these = {:human_name => if @command_element then @command_element.human_name
            elsif @command then @command.main_name
            else; 'it' end,
           :provided_value => @info.provided_value ? @info.provided_value : 'provided value'
          }.merge template_values
          @info.message_template.gsub(/%([a-z_]+)%/)do |x| use_these[$1.to_sym] end
        elsif (@info.message)
          @info.message
        else
          super
        end
      end
      alias_method :msg, :message # note1
      protected
      # [:message, :message_template, :reason, :command, :command_element, :provided_value].each do |x| ..
      def initialize(info)
        super()
        @command = info.delete(:command)
        @command_element = info.delete(:command_element)
        @info = OpenStruct.new(info)
      end
    end
    # add as much metadata as you can to parse errors thrown from OptionParser
    module ParseErrorExtension
      include ParseErrorCommon
      attr_reader :command_element, :command, :orig_message
      def self.enhance_if_necessary(e,cmd)
        return e if ParseErrorExtension===e
        e.extend self
        e.add_details(cmd)
        e
      end
      def add_details(cmd)
        return unless CommandLike === cmd
        @command = cmd
        if respond_to?('reason') && "invalid argument" == reason
          detected = case @args[0]
            when /^--/ then cmd.elements.all.detect{|x| x[1].long[0] == @args[0]}
            when /^-([^-])/  then cmd.elements.all.detect{|x| x[1].short[0] == $1 }
          end
          @command_element = detected[1] if detected
        end
      end
      def msg #note1
        msg = message
        if (@command_element && 'invalid argument' == reason)
          msg = %{invalid value for #{@command_element.main_name}: "#{@args[1]}"}
          if (false)
            # describe possible blah blah
          end
        end
        msg
      end
    end
    class Exception < ::Exception
      @graceful_list = []
      def self.graceful_list?(e)
        @graceful_list.each do |mod|
          return true if mod===e
        end
        false
      end
      class << self
        attr_reader :graceful_list
      end
      attr_reader :details
      protected
      def initialize(msg,details)
        super(msg)
        @details = details
      end
      def self.f(msg,details={}) # factory lets us be lazy about creating new classes
        klass = nil
        if (details[:type])
          class_name = details[:type].to_s.gsub(/(?:^|_)([a-z])/){|x| $1.upcase}
          [class_name+'Exception', class_name].each do |klass_name|
            if Hipe::Cli.constants.include?(klass_name)
              klass = Hipe::Cli.const_get(klass_name)
              break
            end
          end
        end
        klass ||= GrammarGrammarException
        klass.new(msg,details)
      end
    end
    Exception.graceful_list << OptionParser::ParseError
    class GrammarGrammarException < Hipe::Exception; end
    module BuiltinPredicates
      It.register_predicates(self)
      def must_match_regexp(re, message_template=nil)
        if (md = re.match(self))
          if (md.captures.size > 0)
            it = md.captures
            It.changed_type(it, self)
          else
            # it passed and there's no captures.  fall thru
            it = self
          end
        else
          message_template ||= %{%human_name% "%provided_value%" does not match the correct pattern}
          add_validation_failure ValidationFailure.f(:message_template=>message_template, :type=>:regexp_failure)
          it = self
        end
        it
      end
      def must_match(pattern,*etc) # magic alert!
        method_man = 'must_match_'+pattern.class.to_s.gsub(/::/,'__').gsub(/([a-z])([A-Z])/,'\1_\2').downcase
        send(method_man,pattern,*etc)
      end
      def must_be_float(message_template=nil)
        if /^-?\d+\.?\d*$/.match(to_s)
          it = to_f
          It.changed_type(it, self)
        else
          message_template ||= %{Your value for %human_name% ("%provided_value%") does not appear to be a float}
          add_validation_failure ValidationFailure.f(:message_template=>message_template,:type=>:float_cast_failure)
          it = self
        end
        it
      end
      # this thing casts it to a fixnum so it must be the last predicate
      def must_be_integer(message_template=nil)
        if /^-?\d+$/.match(to_s)
          it = to_i
          It.changed_type(it, self)
        else
          message_template ||= %{Your value for %human_name% ("%provided_value%") does not appear to be an integer}
          add_validation_failure ValidationFailure.f(:message_template=>message_template,:type=>:integer_cast_failure)
          it = self
        end
        it
      end
      # this assertion implies that the thing must be a float (maybe it must be an integer, too!) but it does no casting.
      def must_match_range(range,message_template=nil)
        if ! (md = /^-?\d+(?:\.?\d+)?$/=~self)
          message_template ||= %{%human_name% must be numeric}
          add_validation_failure ValidationFailure.f(:message_template=>message_template, :type=>:range_failure)
        else
          as_number = self.to_f
          if ! (range===as_number)
            message_template ||= if as_number < range.begin
              %{%provided_value% is too low a value for %human_name%.  It can't be below #{range.end}}
            else
              %{%provided_value% is too high a value for %human_name%.  It can't be above #{range.end}}
            end
            add_validation_failure ValidationFailure.f(:message_template=>message_template, :type=>:range_failure)
          end
        end
        self
      end
      def must_exist!(message_template=nil) # as a file
        unless (File.exist?(self))
          message_template ||= %{File not found: "#{self}"}
          add_validation_failure ValidationFailure.f(:message_template=>message_template,:type=>:file_not_found)
          Interrupt[:because => :validation_failures]
        end
        self
      end
      def must_not_exist!(message_template=nil,interrupt_if_exists=false) # as a file
        if (File.exist?(self))
          message_template ||= %{File must not exist: "#{self}"}
          add_validation_failure ValidationFailure.f(:message_template=>message_template,:type=>:file_exists)
          Interrupt[:because =>:validation_failures]
        end
        self
      end
      def gets_opened(mode) # for a file, @return new Openstruct It with fh (filehandle) and filename
        begin
          fh = File.open(self,mode)
        rescue ::Exception => e
          add_validation_failure ValidationFailure.f(:message_template=>%{Couldn't open "#{File.basename(self)}" - }+
            e.message, :type=>:couldnt_open_file)  # @TODO does this reveal system info crap?
          return self
        end
        It.changed_type(fh, self)
      end
    end
  end
end
