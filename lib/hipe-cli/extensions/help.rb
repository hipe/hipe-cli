gem 'hipe-core', '=0.0.1'
require 'hipe-core/ascii-typesetting'
require 'hipe-core/lingual'

module Hipe
  module Cli
    module Library
      module Elements
        class HelpRequest < RequestHash
          include Hipe::AsciiTypesetting, Hipe::Cli::Lingual
          #include Hipe::AsciiTypesetting::Methods
          def execute! app
            @cli = app.cli
            @out = @cli.out
            @command = self[:COMMAND_NAME]
            @screen = @cli.screen
            if @command.nil? then return execute_app_help_page end      
            
            if @command.include? ':'
              this,that = Hipe::Cli::Plugins.split_command(@command)
              if (plugin = @cli.plugins[this])
                return plugin.cli.run(['help',that])
              end
            end
            # even if the command was pluginy but invalid, we let it fall thru
            
            @command_object = @cli.commands.has_alias?(self[:COMMAND_NAME]) ?
               @cli.commands[self[:COMMAND_NAME]] : nil
            if @command_object.nil? then return execute_help_on_invalid_command
            else @out << @command_object.help_page(@cli) end
            @out
          end
          def execute_app_help_page
            left = %{usage: #{@cli.invocation_name} }
            right = FormattableString.new(@cli.full_inner_syntax)
            @out << left
            @out.puts right.word_wrap_once!(@screen[:width]-left.size) # @todo bug when...
            @out.puts right.word_wrap!(@screen[:width]-left.length).indent!(left.length)
            # for second line, if it has a description (and maybe a version), go
            if (line = @cli.description)
              if (@cli.commands[:version])
                version_number = @cli.commands[:version] << ['--bare']
                line << %{ version #{version_number}}
              end
              @out.puts line
            end
            size = @cli.commands.size #@TODO @fixme
            sp = lingual.en{sp(np(adjp('Available'),'subcommand',size))}
            sp.np.say_count = false
            @out.puts %{#{sp.say.gsub(/\.$/,'')}:}
            prefix_name = @cli.command_prefix
            @cli.commands.each do |key,command|
              if (command.cli.command_prefix != prefix_name)
                _cli = command.cli
                @out.puts "\n"
                @out.puts _cli.qualified_name +  (_cli.description ? %{ - #{_cli.description}} : '')
                prefix_name = _cli.command_prefix
              end
              @out.puts command.oneline(@screen)
            end
            @out.puts %{\nSee "#{@cli.invocation_name} help COMMAND" }+
              %{for more information on a specific command.}
          end
          def execute_help_on_invalid_command
            @out.puts %{#{@cli.invocation_name}: Sorry, there is no "#{@command}" command. }+
            %{See "#{@cli.invocation_name} --#{@cli.commands[:help].long_name}"};
          end
        end
      end
    end
  end
end

module Hipe
  module Cli

    class Cli
      def full_outer_syntax
        invocation_name + full_inner_syntax
      end

      def qualified_name
        @parent ? %{#{@parent.invocation_name} #{plugin_name}} : invocation_name
      end

      def full_inner_syntax
        #@todo for the next refactor:
        # Options are like commands that take zero or one argument and can appear multiple times.
        select = lambda{|k,v| v.short_name_long_name_syntax }
        map    = lambda{|x| x[1].short_name_long_name_syntax}
        begin
          arr = commands.select(&select).map(&map).uniq
        rescue Hipe::Cli::Exceptions::PluginNotFound => e
          arr = commands.local.select(&select).map(&map).uniq
          arr.unshift "(PLUGIN ERROR)"
        end
        app_opts = arr.size > 0 ? %{#{arr * ' '} } : ''
        %{#{app_opts}COMMAND [OPTIONS] [REQUIRED_ARGS] [OPTIONAL_ARGS]}
      end
    end

    class Option
      include Hipe::AsciiTypesetting::Methods
      def full_outer_syntax
        %{[#{full_inner_syntax}]}
      end
      def value_name
        @data[:value_name] ||
        /([a-z]+)$/.match(@name.to_s).captures[0].upcase
      end
      def full_inner_syntax
        appends = (@type == :required) ? [%{ #{value_name}}, %{=#{value_name}}] : ['','']
        short_and_long = []
        if short_name
          sn = %{-#{short_name}}
          if @type == :increment
            short_and_long << recursive_brackets([sn,sn,'...'],'[',']')
          else
            short_and_long << %{#{sn}#{appends[0]}}
          end
        end
        if long_name
          short_and_long << %{--#{long_name}#{appends[0]}}
        end
        short_and_long * '|'
      end
    end

    class Command
      include Hipe::AsciiTypesetting::Methods
    end
    module CommandLike
      def cli= cli # for now just for
        @cli = cli
      end
      def oneline screen
        first_col = sprintf(%{%-#{screen[:col1width]}s},%{#{' '*screen[:margin]}#{full_name}})
        # we won't deal with what if it's too long yet @todo
        desc = description || '[no description]'
        second_col = Hipe::AsciiTypesetting::FormattableString.new(desc).sentence_wrap_once!(screen[:col2width])
        %{#{first_col}#{second_col}}
      end

      # kind of hackerly -- for those special commands like 'version' and 'help'.
      # for now the pattern is "if a command has a short name or a long name, it can act as
      # an option passed to the application""
      def short_name_long_name_syntax
        blah = []
        blah << %{-#{short_name}} if short_name
        blah << %{--#{long_name}} if long_name
        return nil if blah.size == 0
        %{[#{blah * '|'}]}
      end

      # @return the formatted string with help info. -- this doesn't write to any buffers like app does
      # @param cli needs this for the app name
      def help_page cli
        el = Element.new
        screen = cli.screen
        out = Hipe::Io::BufferString.new
        out.puts name.to_s + (description ? %{ - #{description}} : '') + "\n\n"
        out.puts "usage: #{cli.invocation_name} #{full_name} #{full_inner_syntax}\n\n"
        col1width,col2width = screen[:col1width], screen[:col2width]
        margie = ' '*screen[:margin]
        min_width = [0, screen[:col1width] - screen[:margin] * 2 ].max
        format = %{#{margie}%-#{min_width}s#{margie}} # for first column
        els = []
        els += options.map{|k,v| [v.full_inner_syntax, v.description]}
        els += required.map{|v|  el.flyweight(v); [el.name, el.description] }
        els += optionals.map{|v| el.flyweight(v); [el.name, el.description] }
        els.each do |pair|
          line = sprintf(format,pair[0])
          out << line
          overhang = (line.length == col1width) ? line.length : (line.length % screen[:width])
          line_width = screen[:width] - overhang
          desc = pair[1]
          desc.extend Hipe::AsciiTypesetting::FormattableString
          out << desc.word_wrap_once!(line_width)+"\n"
          out << desc.word_wrap!(col2width).indent!(col1width)+"\n" if desc.length > 0
        end
        out
      end

      # the command's syntax not including the app name or the command name (hence "inner").
      #"Full" because we explicate the syntax of each option, as opposed to just saying [OPTIONS]
      def full_inner_syntax
        el = Element.new
        elements = []
        elements += options.map{|k,v| v.full_outer_syntax }
        elements += required.map{|el_data| el.flyweight(el_data).name }
        names    = optionals.map{|el_data| el.flyweight(el_data).name }
        elements += [%{[#{recursive_brackets(names,' [',']')}]}] if optionals.size > 0
        el.flyweight(splat) if splat
        elements += ['['+recursive_brackets(Array.new(2,el.name)+['...'],' [',']')+']'] if splat
        elements * ' '
      end
    end
    module ElementLike
      include Lingual

      # @fixme -- this kind of stuff must be moved into the predicate classes.
      # @return a string describing this argument or option
      # If the element does not have a description string, one is attempted by
      # describing various validation info.  If a description string is provided,
      # it can constain placeholders such as %enum% or %range% that will be
      # substituted with sentences describing the predicate @todo offload predicate description
      def description
        replacements = OrderedHash.new
        replacements[:enum] = lingual.list(@data[:enum]).or{|x| x.to_s} if @data[:enum]
        replacements[:regexp_sentence] = @data[:regexp_sentence] if @data[:regexp_sentence]
        if @data[:range]
          low, hi = @data[:range].begin, @data[:range].end
          replacements[:range] = %{must be between #{low} and #{hi}}
        end
        all_keys = @data.keys + (@data[:it] ? @data[:it] : []) + (@data[:they] ? @data[:they] : [])
        replacements[:is_jsonesque] = "must be a jsonesque string" if @data[:is_jsonesque]
        these = [:must_exist,:must_not_exist] & all_keys
        replacements[:must_exist] = 'File must exist' if these.include? :must_exist
        replacements[:must_not_exist] = 'File must not exist' if these.include? :must_not_exist
        desc = @description || @data[:description] # @todo
        if desc
          re = Regexp.new(replacements.keys.map{|x| %{%#{x}%} } * '|')
          desc.gsub!(re) do |match|
            key = match.slice(1,match.size-2).to_s
            replacements[key]
          end
          desc
        elsif replacements.size > 0
          desc = replacements.values.join('  ') # @sentence
        else %{[no description]} end
      end
    end
  end
end
