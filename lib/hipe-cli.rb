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
      def initialize(klass)
        @app_class = klass
      end
      def dup_for_app_instance(instance)
        spawn = self.dup
        spawn.instance_variable_set('@app_instance',instance)
        spawn
      end
    end
  end
end
