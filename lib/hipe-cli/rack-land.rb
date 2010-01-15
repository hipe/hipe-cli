require 'hipe-cli'
require 'hipe-core/lingual/en'

module Hipe::Cli
  # Mangle classes and modules in Cli so that they can process rack requests
  # (all it's doing really is allowing Command.run() and Cli.run() to process Hashes in addition to Arrays)

  class Cli
    alias_method :run_flat, :run
    def run params
      out.klass ||= Hipe::Io::GoldenHammer
      cmd = nil
      return run_flat(params) if params.kind_of?(Array)
      return out.new(:error=>"invalid rack request class #{params.class}") unless params.kind_of?(Hash)
      return out.new(:error=>"no command provided") unless params['command_name']
      return out.new(:error=>"there is no #{params['command_name'].inspect} command") unless
        command = @commands[params['command_name']]
      params_copy = params.dup
      params_copy.delete('command_name')
      command.run(params_copy)
    end
  end
  module CommandElement
    def rack_name; main_name.to_s end
  end
  module Switch
    def rack_names
      @rack_names ||= begin
        long.map{|x| /^--(.+)/.match(x).captures[0]} + short.map{|x| /^-(.+)/.match(x).captures[0] }
      end
    end
  end
  class Command
    alias_method :run_flat, :run
    include Hipe::Lingual::English
    def run *args
      return run_flat(*args) if args[0].kind_of?(Array)
      raise ArgumentError.new("bad request") unless args.size==1 && args[0].kind_of?(Hash)
      out = application.cli.out
      params = args[0]
      elements = self.elements
      argv = []
      missing_required = []
      return out.new(:error=>"splat is not supported") if elements.splat
      elements.options.each do |el|
        intersect = params.keys & el.rack_names
        if intersect.size > 0
          argv << (el.long[0] || el.short[0])
          value = params.delete(intersect[0]) # note intersect might be > 1 but caught below
          argv << value unless value == "" # for flags that don't take parameters, the rack request should send the empty string
        end
      end
      elements.required.each do |el|
        if params.has_key? el.rack_name
          argv << params.delete(el.rack_name)
        else
          missing_required << el.main_name
        end
      end
      elements.optionals.each do |el|
        if params.has_key? el.rack_name
          argv << params.delete(el.rack_name)
        else
          argv << "" # normally this wouldn't be possible from the command line.  be careful!
        end
      end
      result = out.new
      if missing_required.size > 0
        result.errors << ("What about " << en{list(missing_required.map{|x| %{"#{x}"}})}.say << '?')
      end
      universal_defs = application.cli.universal_definitions
      universal_option_names = universal_defs ? universal_defs.map{|x| x.rack_name} : []
      unexpected = params.keys.map{|x| x.to_s} - (universal_option_names + ['submit']) # hack1
      if unexpected.size > 0
        result.errors << ("#{full_name} asks: what do you mean by "<<
          en{list(unexpected.sort.map{|x| %{"#{x}"}})}.say << '?')
      end
      return result unless result.valid?
      run_flat(argv)
    end
  end
end
