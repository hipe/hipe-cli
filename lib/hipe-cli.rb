require 'orderedhash'
require 'ostruct'
require 'rubygems'
require 'ruby-debug'
gem     'hipe-core', '0.0.2'
require 'hipe-core/ascii-typesetting'
require 'hipe-core/lingual'

module Hipe
  module Cli
    VERSION = '0.0.7'
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
    class Cli
      attr_reader :commands, :parent_cli, :out, :output_registrar
      attr_accessor :description, :plugin_name
      def initialize(klass)
        @app_class = klass
        @commands = Commands.new(self)
        @plugins = nil
        @out = OutputBufferRegistrar.new(self)
        @output_registrar = @out
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
        if (@out.class == Class)
          @out = @out.new
        end
      end
      def out=(symbol)
        if (@out.kind_of? OutputBufferRegistrar)
          @output_registrar = @out
        end
        @out = symbol # the only one ever doing this should be a plugin who knows it's a plugin
      end
      def init_as_plugin(parent_app_instance, name, plugin_app_instance)
        @parent_cli = parent_app_instance.cli
        @plugin_name = name
        if Symbol === @out
          @out = @parent_cli.output_registrar[@out].new
        end
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
      def run argv
        if (cmd = @commands[name = argv.shift])
          begin
            cmd.run(argv)
          rescue OptionParser::ParseError => e
            e.extend ParseErrorExtension
            e.add_details(cmd)
            e.cli_message
          end
        else
          bad_command(name)
        end
      end
      def bad_command(name)
        return "done.\n" if name.nil? and @commands.size == 0;
        list = Hipe::Lingual::List[@commands.map{|pair| %{"#{pair[1].full_name}"}}].or()
        s = %{Unexpected command "#{name}".  Expecting #{list}.\n}
        s << %{See "#{program_name} -h" for more info.\n} if @commands['-h']
        s
      end
      def program_name; File.basename($0,'*.rb') end
      def help(cmd_name=nil)
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
        left = %{usage: #{program_name} }
        right = Hipe::AsciiTypesetting::FormattableString.new('')
        right.replace( [@commands.select{|i,cmd| OptionLikeCommand === cmd}.map do |c|
            '[' + ([c[1].short_name,c[1].long_name].compact * '|') + ']'
          end * ' ', "COMMAND [OPTIONS] [ARG1 [ARG2 [...]]]"
        ].compact * ' ')
        right_column_width = [20, screen.width-left.length].max
        lines << left + right.word_wrap_once!(right_column_width)
        lines << right.word_wrap!(right_column_width).indent!(left.length) if right.size > 0
        lines * "\n"
      end
    end
    class OutputBufferRegistrar<Hash
      def initialize(cli); @cli=cli end
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
        if (cmd = super(@aliases[name]))
          cmd.app_instance = @cli.app_instance
          cmd
        elsif name.include? ':'
          plugin_name, remainder = /^([^:]+):(.+)/.match(name).captures
          @cli.plugins[plugin_name].cli.commands[remainder]
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
        if (o.short_name || o.long_name)
          OptionLikeCommand.new(o, &block)
        else
          Command.new(o, &block)
        end
      end
      LONG_NAME_WITHOUT_ARGS = /^--([-_a-z0-9]+)/i
      # optparse does something similar, too but we don't use it to parse commands themselves
      def self.parse_grammar(name,*list)
        o = OpenStruct.new()
        if (Symbol===name)
          o.main_name = name
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
    module OptParseyCommandElement #required arguments, optional arguments, options (switches) and splat
      attr_accessor :hipe_type, :app_instance
      attr_reader :description, :default
      def main_name   # @TODO this will probably go now that we have integrated w/ optparse so much
        str = nil
        if (@long && @long.size > 0)
          str = /^-?-?(.+)/.match(@long[0]).captures[0]
        elsif (@short && @short.size > 0)
          str = /^-?(.+)/.match(@short[0]).captures[0]
        end
        str.gsub('-','_').downcase.to_sym
      end
      def surface_name
        /^-?-?(.+)/.match(@long[0]).captures[0]
      end
      def set_default(val) # separate method only so that required positionals can complain
        @has_default = true
        @default = val
      end
      def init_as_hipe_type(opt_hash)
        if (opt_hash)
          if opt_hash.has_key? :default
            if (@arg.nil? or !(/[^ ]/=~@arg) or (/\[\]/=~@arg))
              raise Exception.f(%{for "#{main_name}" to take a default value it must take a required arg, not "#{@arg}"})
            end
            set_default(opt_hash.delete(:default))
          end
        end
      end
      def has_default?; @has_default end
    end
    module OptParseSwitch;
      include OptParseyCommandElement
    end
    module PositionalArgument;
      include OptParseyCommandElement
      def prepare_for_display
        @long[0].gsub!(/^--/,'')
        @arg = nil
      end
      def prepare_for_parse
        @long[0].replace(%{--#{@long[0]}})
        @arg = ' '
      end
      def init_as_hipe_type(opt_hash)
        super(opt_hash)
        prepare_for_display
      end
    end
    module RequiredPositional;
      include PositionalArgument
      def set_default(val)
        raise Exception.f(%{required arguments can't have defaults ("#{main_name}")})
      end
    end
    module OptionalPositional;    include PositionalArgument       end
    module Splat;                 include OptParseyCommandElement  end

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
    end
    class Command
      include CommandLike
      def initialize(names, &block)
        @app_instance = nil
        @block = block
        take_names(names)
      end
      def aliases
        [@main_name.to_s]
      end
      def elements
        parse_definition unless @switches_by_name
        @switches_by_name
      end
      def desc_arr  # if we wanna be like optparse, return an array.
        return [] unless @description
        Hipe::AsciiTypesetting::FormattableString.new(@description).word_wrap!(39).split("\n") # @todo
      end
      def help_switch
        help_option = elements.detect do |x|
           OptParseSwitch===x[1] and x[1].short.include?('-h') or x[1].long.include?('--help')
        end
        help_option ? ( help_option[1].short.size > 0 ? help_option[1].short[0] : help_option[1].long[0]) : nil
      end
      # because of the crazy nature of the code blocks this needs to be run for each call to run()
      # @return [OptionValues] the hash that is in scope when you made the definition
      # @post_condition: @switches_by_name, @switches_by_type get set
      def parse_definition
        @prev = nil
        opt_values = OptionValues.new     # is in scope below for switches to write their results to
        switches = {                      # hold on to each switch that OptParser builds
          OptParseSwitch=>[], PositionalArgument=>[],
          RequiredPositional=>[], OptionalPositional=>[],
          Splat=>[]  #never more than one element in here
        }
        switches_by_name = {}
        opts = OptionParser.new do |opts| # build all the switches for options, required, optionals, splat in one go
          @option_parser = opts           # is made available thru opts() so definitions can e.g. opts.separator()
          @definitions = []               # gets populated in the next line
          self.instance_eval(&@block)     # runs all the option(), required(), optional(), splat() definitions
          @definitions.each do |my_info|  # with each one of those definition we 'recoreded' ...
            first_arg = my_info.first_arg.to_s
            unless /^-/ =~ first_arg
              first_arg = %{--#{first_arg} VALUE} # positional arguments will need proper names and parameters
            end                           # only for their construction (hack alert!)
            switch = opts.define(first_arg,*my_info.list,&my_info.block) # make an optional, required, option, etc.
            switch.extend my_info.hipe_type
            switch.hipe_type = my_info.hipe_type
            switches[switch.hipe_type] << switch
            if (PositionalArgument===switch)
              switches[PositionalArgument] << switch  # like an abstract base class. never the actual hipe_type
            end
            switch.init_as_hipe_type(my_info.opt_hash)
            switches_by_name[switch.main_name] = switch
            orig_block = switch.block
            new_block = Proc.new() do |x|
              if (orig_block)
                result_from_original = orig_block.call(x)
                opt_values[switch.main_name] = result_from_original
              else
                opt_values[switch.main_name] = x
              end
            end
            switch.instance_variable_set('@block',new_block)
          end
        end
        @switches_by_type = switches
        @switches_by_name = switches_by_name
        opt_values
      end

      def run(argv)
        return run_with_application(argv) unless @block #if there is no definition block we pass the args raw
        opt_values = parse_definition
        switches = @switches_by_type
        ret = catch(:interrupt) do # options like "help" might throw an interrupt so that the rest of the thing isn't validated

          # add defaults to the argv (we do it now and not later to trigger validation by optpare even on default values)
          if (sw = switches[OptParseSwitch].select{|x| x.has_default? }).size>0 then apply_defaults(sw, argv) end

          # parse any options (as oppposed to arguments) in the grammar
          opts.parse!(argv) if switches[OptParseSwitch].size > 0

          # awful hack! if they requested for help above, we want the things to have names w/o dashes, but now we need them.
          switches[PositionalArgument].each{|x| x.prepare_for_parse }

          # iterate over the remaining required and optional arguments
          if switches[PositionalArgument].size > 0
            new_argv = turn_positionals_into_switches(switches[PositionalArgument], argv)
            if (sw = switches[PositionalArgument].select{|x| x.has_default? }).size>0 then apply_defaults(sw, new_argv) end
            opts.parse!(new_argv)
          end

          # complain about any required arguments that are not in the opt_values
          missing = (switches[RequiredPositional].map{|x| x.main_name} - opt_values.keys).map{|x| @switches_by_name[x]}
          error_missing(missing) if missing.size > 0

          # complain if there are any remaining unparsed arguments  #@TODO splat
          error_needless(argv) if (argv.size > 0)

          # flatten the parsed values back into an array for the implementing method
          args_for_implementer = flatten_args(switches, opt_values)
          ret = run_with_application(args_for_implementer)
        end
        ret
      end
      def apply_defaults(switches, argv)
        shorts, longs = [], []
        argv.grep(/(?:^(-[a-z0-9]))|(?:^(--[a-z0-9][-a-z0-9]+))/){|_| shorts<<$1 if $1; longs<<$2 if $2 }
        switches.select{|x| (x.short & shorts).size == 0 and (x.long & longs).size == 0 }.each do |x|
          argv.concat( (x.long.size > 0 ) ? [x.long[0], x.default ] : [%{#{x.short[0]}#{x.default}}] )
        end
      end
      def flatten_args(switches, opt_values)
        arg_array = []
        switches[PositionalArgument].each do |switch|
          arg_array << opt_values.delete(switch.main_name) # ok if nil
        end
        if (switches[OptParseSwitch].size > 0)
          arg_array << opt_values # even if it is empty
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
        e = OptionParser::MissingArgument.new
        names = missing.map{|x| x.surface_name }
        sp = Hipe::Lingual.en{ sp(np(adjp('missing','required'),'argument',names))  }
        e.reason = sp.say
        raise e
      end
      def error_needless(argv)
        e = OptionParser::NeedlessArgument.new
        names = argv.map{|x| %{"#{x}"}}
        sp = Hipe::Lingual.en{ sp(np(adjp('unexpected'),'argument',names))  }
        e.reason = sp.say
        raise e
      end
      def option   (name,*list,&block); define(%s{options},            OptParseSwitch,     name, list, block) end
      def required (name,*list,&block); define(%s{required arguments}, RequiredPositional, name, list, block) end
      def optional (name,*list,&block); define(%s{optional arguments}, OptionalPositional, name, list, block) end
      def splat    (name,*list,&block); define(%s{splat definition},   Splat,              name, list, block) end
      def opts; @option_parser; end
      def help; # circumvent normal validation if the user wants to display help
        lambda{ throw :interrupt, @option_parser.to_s }
      end
      @fsa = {
        :options               => [nil, :options],
        %s{required arguments} => [nil, :options, %s{required arguments}],
        %s{optional arguments} => [nil, :options, %s{required arguments}, %s{optional arguments}],
        %s{splat definition}   => [nil, :options, %s{required arguments}]
      }
      class << self
        def valid_state_change?(prev,current)
          @fsa[current].include? prev
        end
      end
      def define(state_symbol, mod, name, list, block)
        unless (@prev.nil? or Command.valid_state_change?(@prev, state_symbol))
          raise Exception.f(%{#{state_symbol} should not appear after #{@prev}})
        end
        @prev = state_symbol
        # find any hashes that do not follow arrays and assert there is no more then one... then make it an opts hash
        opt_hashes = []
        i = nil
        list.each_with_index do |val, i|
          if (Hash===val and i==0 || !(Array===list[i-1]))
            opt_hashes << val
          end
        end
        if (opt_hashes.size > 0)
          raise Exception.f(%{Cannot have more than one options hash for "#{name}"}) if opt_hashes.size > 1
          opt_hash = list.slice!(i,1)[0]
        end
        definition = {:hipe_type=>mod, :first_arg => name, :list => list, :block => block, :opt_hash=>opt_hash}
        @definitions << OpenStruct.new(definition)
      end
      def run_with_application(argv)
        if @app_instance.respond_to?(as_method_name)
          begin
            @app_instance.send(as_method_name, *argv)
          rescue ArgumentError => e
            if md = /wrong number of arguments \((\d+) for (\d+)\)/.match(e.message)
              raise Exception.f(%{Your #{@app_instance.class}\##{as_method_name}() must take #{md[1]} arguments to }+
              %{correspond to the grammar defined for the command. You take #{md[2]}.}
              )
            else
              raise e
            end
          end
        elsif([:help].include? as_method_name)
          @app_instance.cli.help(*argv)
        else
          raise Exception.f(%{Please implement "#{as_method_name}"})
        end
      end
    end
    class OptionLikeCommand < Command
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
    class Plugins < OrderedHash  # remember we store application classes or instances, not cli's
      attr_accessor :cli
      alias_method :set, :[]= # necessary in [] because we rewrite the class with the instance using the same name
      def initialize(cli)
        @cli = cli
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
      alias_method :get, :[]
      def [](name)
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
    end
    # add as much metadata as you can to parse errors thrown from OptionParser
    module ParseErrorExtension
      attr_reader :command_element, :command
      def add_details(cmd)
        @command = cmd
        if "invalid argument" == reason
          detected = case @args[0]
            when /^--/ then cmd.elements.detect{|x| x[1].long[0] == @args[0]}
            when /^-([^-])/  then cmd.elements.detect{|x| x[1].short[0] == $1 }
          end
          @command_element = detected[1] if detected
        end
      end
      def extended_message
        msg = self.message
        if (@command_element && 'invalid argument' == reason)
          msg = %{invalid value for #{@command_element.main_name}: "#{@args[1]}"}
          if (false)
            # describe possible blah blah
          end
        end
        msg
      end
      def cli_message
        msg = extended_message
        if (@command and help_switch = @command.help_switch)
          msg << %{\nSee "#{@command.app_instance.cli.program_name} #{@command.full_name} #{help_switch}" for more info.}
        end
        msg
      end
      def message; @use_message || super end
      alias_method :to_s, :message
    end
    class Exception < ::Exception
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
    class GrammarGrammarException < Exception; end
  end
end
