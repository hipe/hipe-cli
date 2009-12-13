require 'orderedhash'
require 'ostruct'
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
        o = OptParsey.parse_grammar(name,*list)
        if (o.short_name || o.long_name)
          OptionLikeCommand.new(o, &block)
        else
          Command.new(o, &block)
        end
      end
    end
    module CommandElement
      attr_reader :description
      attr_accessor :app_instance
      def take_names(o)
        o.instance_variable_get('@table').each do |name,value|
          instance_variable_set(%{@#{name}}, value)
        end
      end
      def name; @use_name end
    end
    module OptParsey
      LONG_NAME_WITHOUT_ARGS = /^--([-_a-z0-9]+)/i
      def self.parse_grammar(name,*list)
        o = OpenStruct.new()
        if (Symbol===name)
          o.use_name = name
        elsif (String===name)
          if md = LONG_NAME_WITHOUT_ARGS.match(name)
            o.long_name = md[1]
            o.use_name = o.long_name
          elsif md = /^-([a-z0-9])$/i.match(name)
            o.short_name = md[1]
            if list.size>0 and md = LONG_NAME_WITHOUT_ARGS.match(list[0])
              o.long_name = md[1]
            end
            o.use_name = (o.long_name || o.short_name).downcase.gsub('-','_').to_sym
          else
            o.use_name = name
          end
        else
          raise Exception.f(%{bad type for name: #{name.class}},:type=>:grammar_grammar)
        end
        if (idx = list.find_index{|x| String===x and /^[^-]/ =~ x  })
          o.description = list[idx]
        end
        o
      end
    end
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
      include CommandElement
      def initialize(names, &block)
        @block = block
        take_names(names)
      end
      def aliases
        [@use_name.to_s]
      end
      def run(argv)
        return run_with_application(argv) unless @block
        args_for_implementer = []
        opt_values = OptionValues.new
        opts = OptionParser.new do |opts|
          @opts = opts
          @opt_parse_args = []
          self.instance_eval(&@block)
          @opt_parse_args.each do |opt|
            use_name = OptParsey.parse_grammar(opt[0],*opt[1]).use_name
            opts.on(opt[0],*opt[1]) do |x|
              opt_values[use_name] = opt[2] ? opt[2].call(x) : x  # this is the most important line of the thing
            end
          end
        end
        rs = opts.parse!(argv)
        args_for_implementer << opt_values
        run_with_application(args_for_implementer)
      end
      def option(name,*list,&block)
        @opt_parse_args << [name,list,block]
      end
      def opts; @opts; end
      def run_with_application(argv)
        @app_instance.send(name.to_s.gsub('-','_'), *argv)
      end
    end
    class OptionLikeCommand < Command
      include CommandElement, OptParsey
      def initialize(o, &block)
        take_names(o)
        @block = block
      end
      def aliases
        [@use_name.to_s, @short_name ? %{-#{@short_name}} : nil,@long_name ? %{--#{@long_name}} : nil].compact
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
