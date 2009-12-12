module Hipe::Cli::Library
  module Elements
    class VersionCommand < Hipe::Cli::Command
      def initialize cli, data
        super cli, {
          :decription => 'display the version number of this app and exit.',
          :options    => {
            '--bare' => {
               :description => 'show just the version number, e.g. "1.2.3"',
               :type        => :boolean
            }
          }
        }.merge(data)
      end
      def run argv
        super(argv, VersionRequest)
      end
      alias_method :<<, :run
    end
    class VersionRequest < Hipe::Cli::RequestHash
      def execute! app
        out = app.cli.out
        version = app.class.constants.include?('VERSION') ?
          app.class.const_get('VERSION') : '???'
        if self[:bare]
          out << version
        else
          out.puts %{#{app.cli.invocation_name} version #{version}}
        end
        out
      end
    end
    class HelpCommand < Hipe::Cli::Command
      def initialize cli, data
        super cli, {
          :description => 'Show detailed help for a given COMMAND, or general help',
          :optionals => [{:name=>:COMMAND_NAME}],
          :take_over_when_it_appears_as_an_option_for => :all
        }.merge!(data)
      end
      def run argv
        require 'hipe-cli/extensions/help'
        super(argv, HelpRequest)
      end # def
    end # class
  end # end Elements
end # Library
