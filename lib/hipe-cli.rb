require 'orderedhash'
module Hipe
  module Cli
    VERSION = '0.0.4'
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
      attr_reader :commands # debugging
      def initialize(klass)
        @app_class = klass
        @commands = Commands.new
      end
      def dup_for_app_instance(instance)
        spawn = self.dup
        spawn.instance_variable_set('@app_instance',instance)
        spawn
      end
      def does name, *list, &block
        @commands.add(name, *list, &block)
      end
    end
    class Commands < OrderedHash
      attr_accessor :aliases
      def initialize
        super()
        @aliases = {}
      end
      def add(name, *list, &block)
        command = CommandFactory.command_factory(name, *list, &block)
        name_s = command.name.to_s
        command.aliases.each do |aliaz|
          raise Exception.f(%{For now we can't redefine commands ("#{aliaz}")}) if @aliases[aliaz]
          @aliases[aliaz] = name_s
        end
        set name_s, command
      end
      alias_method :get, :[]
      def [](aliaz)
        return get @aliases[aliaz]
      end
      protected
      alias_method :set, :[]=
      def []=(x,y); super(x,y) end
    end
    module CommandFactory
      def self.command_factory(name, *list, &block)
        case name
        when Symbol
          use_name = name
        when String
          if md = /^--([-_a-z0-9]+)/i.match(name)
            long_name = md[1]
          elsif md = /^-([a-z0-9])$/i.match(name)
            short_name = md[1]
            if list.size>0 and md = /^--([-a-z0-9]+.*)$/.match(list[0])
              long_name = md[1]
            else
              use_name = short_name
            end
          else
            use_name = name
          end
        else
          raise Exception.f(%{bad type for name: #{name.class}},:type=>:grammar_grammar)
        end
        cursor = 0 + ((short_name && long_name) ? 1 : 0)
        description = list[cursor] if (list[cursor])
        if (short_name || long_name)
          return OptionLikeCommand.new(short_name, long_name, description, &block)
        else
          return Command.new(use_name, description, &block)
        end
      end
    end
    module CommandElement
      attr_reader :name, :description
    end
    module OptParsey

    end
    class Command
      include CommandElement
      def initialize(name, description, &block)
        @name, @description, @block = name,description, block
      end
      def aliases
        [@name.to_s]
      end
    end
    class OptionLikeCommand < Command
      include CommandElement, OptParsey
      def initialize(short_name, long_name, desc, &block)
        @short_name, @description, @block = short_name, desc, block
        if long_name
          @name = /^[-_a-z0-9]+/i.match(long_name)[0]
          @long_name_with_syntax = long_name
          @long_name = @name
          @name = @long_name
        else
          @name = @short_name
        end
      end
      def aliases
        [@name,@short_name ? %{-#{@short_name}} : nil,@long_name ? %{--#{@long_name}} : nil].compact
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
