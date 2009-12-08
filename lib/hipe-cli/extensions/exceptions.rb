require 'hipe-cli/extensions/ascii_documentation'
require 'hipe-core/lingual'

module Hipe
  module Cli
    class SoftException < CliException
      def self._factory(string,data)
        class_name = data[:type].to_s.gsub(/(?:^|_)(.)/){|m| $1.upcase}
        if class_name and class_name.length > 0 and SoftExceptions.constants.include?(class_name)
          klass = SoftExceptions.const_get(class_name)
          prepend = ''
        else
          klass = self
          prepend = %{(error type "#{data[:type]}")}          
        end
        klass.new(string,data)
      end
    end
    class ValidationFailure < SoftException; end
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
          super("Syntax error -- "+string)
          @keys = data[:invalid_keys]
        end        
      end
        
      class OptionIssue < SoftException
        def initialize(string, data)
          sentences = []
          sentences << string if string.length > 0
          command,option,e = data[:command],data[:option],data[:exception]
          if (e.instance_of?(ArgumentError) && /^no switches provided/ =~ e.message)
            sentences << %{wasn't expecting any options for "#{command.invocation_name}" and got: "#{option}".}
          elsif (Getopt::Long::Error === e && (md = /^invalid switch '(.+)'$/.match(e.message)))
            option = md[1]
            sentences << %{"#{command.invocation_name}" doesn't understand "#{option}".}
            options = command.options.map{|k,v| %{"#{v.full_inner_syntax}"} }
            sentences << Hipe::Lingual.en{ sp(np(adjp('valid'),'option',options)) }.say
          elsif (Getopt::Long::Error === e && (md = /^no value provided for required argument '(.+)'$/.match(e.message)))
            option = md[1]
            sentences << %{"#{command.invocation_name}" was expecting a value for "#{option}".}
          else
            sentences << %{unexpected exception #{e.class} - "#{e.message}"}
          end
          sentences << %{See "#{command.cli.invocation_name} help #{command.invocation_name}" for more info.}
          super(sentences * '  ')
        end
      end
    end
  end
end
