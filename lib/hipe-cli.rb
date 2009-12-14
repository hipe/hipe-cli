require 'orderedhash'
require 'ostruct'
require 'hipe-core/lingual'
module Hipe
  module Cli
    VERSION = '0.0.4'
    DIR = File.expand_path('../../',__FILE__) # for examples run from tests :/
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
      def cli
        @cli
      end
    end
    class Cli
      attr_reader :commands
      def initialize(klass)
        @app_class = klass
        @commands = Commands.new
      end
      def dup_for_app_instance(instance)
        spawn = self.dup
        spawn.init_for_app_instance(instance)
        spawn
      end
      def init_for_app_instance(instance)
        @commands = @commands.dup
        @commands.app_instance = instance
      end
      def does name, *list, &block
        @commands.add(name, *list, &block)
      end
      def run argv
        @commands[argv.shift].run(argv)
      end
    end
    class Commands < OrderedHash
      attr_reader :aliases
      attr_writer :app_instance
      def initialize
        super()
        @app_instance = nil
        @aliases = {}
      end
      def add(name, *list, &block)
        command = CommandFactory.command_factory(name, *list, &block)
        name_str = command.name.to_s;
        command.aliases.each do |aliaz|
          raise Exception.f(%{For now we can't redefine commands ("#{aliaz}")}) if @aliases[aliaz]
          @aliases[aliaz] = name_str
        end
        self[name_str] = command
      end
      def [](aliaz)
        if (cmd = super(@aliases[aliaz.to_s]))
          cmd.app_instance = @app_instance
          cmd
        end
      end
      protected :[]=
    end
    module CommandFactory
      def self.command_factory(name, *list, &block)
        o = OptParseyCommandElement.parse_grammar(name,*list)
        if (o.short_name || o.long_name)
          OptionLikeCommand.new(o, &block)
        else
          Command.new(o, &block)
        end
      end
    end
    module OptParseyCommandElement # commands, required arguments, optional arguments, options (switches) and splat
      attr_accessor :hipe_type, :app_instance
      attr_reader :description
      def internal_name   # @TODO this will probably go now that we have integrated w/ optparse so much
        str = nil
        if (@long && @long.size > 0)
          str = /^-?-?(.+)/.match(@long[0]).captures[0]
        elsif (@short && @short.size > 0)
          str = /^-?(.+)/.match(@short[0]).captures[0]
        else
          raise "what name to use?"
        end
        str.gsub('-','_').downcase.to_sym
      end
      def natural_name
        /^-?-?(.+)/.match(@long[0]).captures[0]
      end
      LONG_NAME_WITHOUT_ARGS = /^--([-_a-z0-9]+)/i
      def self.parse_grammar(name,*list)
        o = OpenStruct.new()
        if (Symbol===name)
          o.internal_name = name
        elsif (String===name)
          if md = LONG_NAME_WITHOUT_ARGS.match(name)
            o.long_name = md[1]
            o.internal_name = o.long_name
          elsif md = /^-([a-z0-9])$/i.match(name)
            o.short_name = md[1]
            if list.size>0 and md = LONG_NAME_WITHOUT_ARGS.match(list[0])
              o.long_name = md[1]
            end
            o.internal_name = (o.long_name || o.short_name).downcase.gsub('-','_').to_sym
          else
            o.internal_name = name
          end
        else
          raise Exception.f(%{bad type for name: #{name.class}},:type=>:grammar_grammar)
        end
        if (idx = list.find_index{|x| String===x and /^[^-]/ =~ x  })
          o.description = list[idx]
        end
        o
      end
      def take_names(o) # take the contents of a parse tree containing internal_name, long_name, etc
        o.instance_variable_get('@table').each do |name,value|
          instance_variable_set(%{@#{name}}, value)
        end
      end
      def name; @internal_name end
    end
    module OptParseSwitch;
      include OptParseyCommandElement
      def init_as_hipe_type; end
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
      def init_as_hipe_type
        prepare_for_display
      end
    end
    module RequiredPositional;    include PositionalArgument       end
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
    class Command
      include OptParseyCommandElement
      def initialize(names, &block)
        @block = block
        take_names(names)
      end
      def aliases
        [@internal_name.to_s]
      end
      def run(argv)
        return run_with_application(argv) unless @block #if there is no definition block we pass the args raw
        opt_values = OptionValues.new     # is in scope below for switches to write their results to
        switches = {                      # hold on to each switch that OptParser builds
          OptParseSwitch=>[], PositionalArgument=>[],
          RequiredPositional=>[], OptionalPositional=>[],
          Splat=>[]  #never more than one element in here
        }
        opts = OptionParser.new do |opts| # build all the switches for options, required, optionals, splat in one go
          @option_parser = opts           # is made available thru opts() so definitions can e.g. opts.separator()
          @definitions = []     # gets populated in the next line
          self.instance_eval(&@block)     # runs all the option(), required(), optional(), splat() definitions
          @definitions.each do |my_info| # with each one of those definition we 'stored' ...
            first_arg = my_info.first_arg
            unless /^-/ =~ first_arg
              first_arg = %{--#{first_arg} VALUE} # positional arguments use names without '-'
            end
            switch = opts.define(first_arg,*my_info.list,&my_info.block)
            switch.extend my_info.hipe_type
            switch.hipe_type = my_info.hipe_type
            switches[switch.hipe_type] << switch
            if (PositionalArgument===switch)
              switches[PositionalArgument] << switch  # like an abstract base class. never the actual hipe_type
            end
            switch.init_as_hipe_type
            orig_block = switch.block
            new_block = Proc.new() do |x|
              if (orig_block)
                result_from_original = orig_block.call(x)
                opt_values[switch.internal_name] = result_from_original
              else
                opt_values[switch.internal_name] = x
              end
            end
            switch.instance_variable_set('@block',new_block)
          end
        end

        # parse any options (as oppposed to arguments) in the grammar
        if (switches[OptParseSwitch].size > 0)
          opts.parse!(argv)  # result equal? argv is always true probably
        end

        switches[PositionalArgument].each{|x| x.prepare_for_parse } #awful hack! if they request help

        # iterate over the remaining required and optional arguments...
        if (switches[PositionalArgument].size > 0)
          new_argv = treeify_argv(switches[PositionalArgument], argv)
          opts.parse!(new_argv)
        end

        # complain about any required arguments that are not in the opt_values
        provided = opt_values.keys
        missing = switches[RequiredPositional].select{|x| ! provided.include? x.internal_name}
        error_missing(missing) if missing.size > 0

        # complain if there are any remaining unparsed arguments  #@TODO splat
        error_needless(argv) if (argv.size > 0)

        args_for_implementer = flatten_args(switches, opt_values)
        run_with_application(args_for_implementer)
      end
      def flatten_args(switches, opt_values)
        arg_array = []
        switches[PositionalArgument].each do |switch|
          arg_array << opt_values.delete(switch.internal_name) # ok if nil
        end
        if (switches[OptParseSwitch].size > 0)
          arg_array << opt_values # even if it is empty
        end
        arg_array
      end
      def treeify_argv(positional, argv)
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
        names = missing.map{|x| x.natural_name }
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
      def categorize_switches(switches)
        required = []
        positional = []
        switches.each do |switch|
          if (PositionalArgument === switch)
            switch.add_dashes_and_arg_to_long
            positional << switch
            if (RequiredPositional === switch)
              required << switch
            end
          end
        end
        return [positional, required]
      end
      def option   (name,*list,&block); define(%s{options},            OptParseSwitch,     name, list, block) end
      def required (name,*list,&block); define(%s{required arguments}, RequiredPositional, name, list, block) end
      def optional (name,*list,&block); define(%s{optional arguments}, OptionalPositional, name, list, block) end
      def splat    (name,*list,&block); define(%s{splat definition},   Splat,              name, list, block) end
      def opts; @option_parser; end
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
        definition = {:hipe_type=>mod, :first_arg => name, :list => list, :block => block}
        @definitions << OpenStruct.new(definition)
      end
      def run_with_application(argv)
        @app_instance.send(name.to_s.gsub('-','_'), *argv)
      end
    end
    class OptionLikeCommand < Command
      include OptParseyCommandElement, OptParseyCommandElement
      def initialize(o, &block)
        take_names(o)
        @block = block
      end
      def aliases
        [@internal_name.to_s, @short_name ? %{-#{@short_name}} : nil,@long_name ? %{--#{@long_name}} : nil].compact
      end
    end
    class Range < ::Range  # experiments with our first validation struct
      def initialize(start,endo,exclusive=false)
        super start,endo,exclusive
      end
      def self.[](start,endo)
        return self.new(start,endo)
      end
      def match(value)
        return self === value
      end
    end
    class Exception < ::Exception
      attr_reader :details
      protected
      def initialize(msg,details)
        super(msg)
        @details = details
      end
      def self.f(msg,details={}) # factory
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
