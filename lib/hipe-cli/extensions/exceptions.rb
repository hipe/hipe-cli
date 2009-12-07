require 'hipe-cli/extensions/ascii_documentation'
require 'hipe-core/lingual'

module Hipe
  module Cli
    class SoftException < CliException
      def self._factory(data)
        class_name = data[:type].to_s.gsub(/(?:^|_)(.)/){|m| $1.upcase}
        SoftExceptions.const_get(class_name).new(data)
      end
    end
    class ValidationFailure < SoftException
      attr_accessor :children
      def self._factory(string,data)
        class_name = data[:type].to_s.gsub(/(?:^|_)(.)/){|m| $1.upcase}
        SoftExceptions.const_get(class_name).new(string,data)
      end
      def << (exception)
        @children ||= []
        @children << exception
      end
      def initialize(children)
        if children.kind_of? String
          super(children)
        else
          @children = children
        end
      end
    end

    module SoftExceptions
      attr_reader :keys
      class MissingKeys < SyntaxError
        def initialize(string,data)
          super("Syntax error -- "+string)
          @keys = data[:missing_keys]
        end
      end
      
      class InvalidKeys < SyntaxError
        attr_reader :keys        
        def initialize(string,data)
          super("Syntax error -- "+args[0])
          @keys = data[:invalid_keys]
        end        
      end
        
      class UnrecognizedOption < SoftException
        def initialize(data)
          sentences = []
          command,option,e = data[:command],data[:option],data[:exception]
          if (e.instance_of?(ArgumentError) && /^no switches provided/ =~ e.message)
            sentences << %{wasn't expecting any options for "#{command.invocation_name}" and got: "#{option}".}
          elsif (e.instance_of?(Getopt::Long::Error) && (md = /^invalid switch '(.+)'$/.match(e.message)))
            option = md[1]
            sentences << %{"#{command.invocation_name}" doesn't understand "#{option}".}
            options = command.options.map{|k,v| v.full_inner_syntax }
            sentences << Hipe::Lingual.en{ sp(np(adjp('valid'),'option',options)) }.say
          else
            sentences = %{unexpected exception #{e.class} - "#{e.message}"}
          end
          sentences << %{See "#{command.cli.invocation_name} help #{command.invocation_name}" for more info.}
          super(sentences * '  ')
        end
      end
    end
  end
end
