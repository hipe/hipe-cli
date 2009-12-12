module Hipe
  module Cli
    module Exceptions
      class UsageFail             < Exception;      end # for errors related to parsing command grammars, etc. 
      class UserFail              < Exception;      end # for "soft" errors ok for the enduser to see
      class SyntaxError           < UserFail;       end # 
      class PluginLoadFail        < UsageFail;      end # failure to load a plugin
      class PluginNotFound        < PluginLoadFail; end # see also PrefixNotRecognized
      class PrefixNotRecognized   < SyntaxError;    end # user types a prefix for an unknown plugin
      class InvalidKeys           < SyntaxError;    end
      class MissingKeys           < SyntaxError;    end      
      class ValidationFail        < SyntaxError;    end
      class LibraryObjectNotFound < UsageFail;      end
      class OptionIssue           < SyntaxError
        def initialize(string, data)
          require 'hipe-cli/extensions/help'          
          sentences = []
          sentences << string if string.length > 0
          command,option,e = data[:command],data[:option],data[:exception]
          if (e.instance_of?(ArgumentError) && /^no switches provided/ =~ e.message)
            sentences << %{wasn't expecting any options for "#{command.full_name}" and got: "#{option}".}
          elsif (Getopt::Long::Error === e && (md = /^invalid switch '(.+)'$/.match(e.message)))
            option = md[1]
            sentences << %{"#{command.full_name}" doesn't understand "#{option}".}
            options = command.options.map{|k,v| %{"#{v.full_inner_syntax}"} }
            sentences << Hipe::Lingual.en{ sp(np(adjp('valid'),'option',options)) }.say
          elsif (Getopt::Long::Error === e && (md = /^no value provided for required argument '(.+)'$/.match(e.message)))
            option = md[1]
            sentences << %{"#{command.full_name}" was expecting a value for "#{option}".}
          else
            sentences << %{unexpected exception #{e.class} - "#{e.message}"}
          end
          sentences << %{See "#{command.cli.invocation_name} help #{command.full_name}" for more info.\n}
          super(sentences * '  ')
        end
      end
    end
  end
end
