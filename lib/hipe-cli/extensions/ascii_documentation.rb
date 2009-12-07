module Hipe
  module Cli
    
    # @todo i couldn't figure out how to actually .. 
    def self.recursive_brackets list, left, right
      return '' if list.size == 0  # not the official base case.  just being cautius
      ret = list[0]
      if list.size > 1
        ret += left + recursive_brackets(list.slice(1,list.size-1), left, right) + right
      end
      ret
    end
    
    module Library
      module Elements # a request object gets extended with this and returned
        class HelpRequest
          include Executable
          def initialize(request); 
            @request = request 
          end
          def execute! app
            @cli, @out, @command, @screen = app.cli, app.cli.out, @request[:COMMAND_NAME], app.cli.screen
            @command_object = @cli.commands[@command ? @command.gsub('-','_').to_sym : '']
            if @command.nil? then execute_app_help_page
            elsif @command_object.nil? then execute_help_on_invalid_command
            else @out << @command_object.help_page(@cli) end
          end
          def execute_app_help_page
            left = %{usage: #{@cli.invocation_name} }
            right = Hipe::AsciiTypesetting::FormattableString.new(@cli.full_inner_syntax)
            @out.print left
            @out.puts right.word_wrap_once!(@screen[:width]-left.size) # @todo bug when...
            @out.puts right.word_wrap!(@screen[:width]-left.length).indent!(left.length)
            # for second line, if it has a description (and maybe a version) , go 
            if (line = @cli.description)
              if (@cli.commands[:version])
                version_number = ( @cli.commands[:version] << ['--bare'] ).execute!( @cli.sub_buffer )
                line << %{ version #{version_number}}
              end
              @out.puts line
            end            
            @out.puts %{\nAvailable subcommand#{@cli.commands.count > 1 ? 's' : ''}:}
            @cli.commands.each{|k,v| @out.puts v.oneline(@screen) }
            @out.puts %{\nSee "#{@cli.invocation_name} help COMMAND" for more information on a specific command.}
          end
          def execute_help_on_bad_command
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
      # to do git-like indentation we need everything that follows the app name separately 
      def full_inner_syntax
        #@todo for the next refactor.  
        # Options are like commands that take zero or one argument and can appear multiple times.
        arr = @commands.select{|k,v| v.short_name_long_name_syntax }.map{|x| x[1].short_name_long_name_syntax}
        app_opts = arr.size > 0 ? %{#{arr * ' '} } : ''
        %{#{app_opts}COMMAND [OPTIONS] [REQUIRED_ARGS] [OPTIONAL_ARGS]}        
      end
    end
        
    class Option
      
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
            short_and_long << Hipe::Cli.recursive_brackets([sn,sn,'...'],'[',']')
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
    
    module CommandLike
      def oneline screen
        first_col = sprintf(%{%-#{screen[:col1width]}s},%{#{' '*screen[:margin]}#{invocation_name}})
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
        out = Hipe::BufferString.new
        out.puts name.to_s + (description ? %{ - #{description}} : '') + "\n\n"
        out.puts "usage: #{cli.invocation_name} #{invocation_name} #{full_inner_syntax}\n\n"
        col1width,col2width = screen[:col1width], screen[:col2width]        
        margie = ' '*screen[:margin]
        min_width = [0, screen[:col1width] - screen[:margin] * 2 ].max
        format = %{#{margie}%-#{min_width}s#{margie}} # for first column
        els = []
        els += @options.map{|k,v| [v.full_inner_syntax, v.description]}
        els += @required.map{|v|  el.flyweight(v); [el.name, el.description] }
        els += @optionals.map{|v| el.flyweight(v); [el.name, el.description] }
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
        elements += @options.map{|k,v| v.full_outer_syntax }
        elements += @required.map{|el_data| el.flyweight(el_data).name }
        names    = @optionals.map{|el_data| el.flyweight(el_data).name }
        elements += [%{[#{Hipe::Cli.recursive_brackets(names,' [',']')}]}] if @optionals.size > 0 
        el.flyweight(@splat) if @splat
        elements += ['['+Hipe::Cli.recursive_brackets(Array.new(2,el.name)+['...'],' [',']')+']'] if @splat
        elements * ' '
      end  
    end
    module ElementLike
      def flyweight(data)
        @data = data
        self
      end
      def name
        @data[:name].to_s
      end
      def description
        enum = Hipe::Lingual::List[@data[:enum]].or{|x| x.to_s} if @data[:enum]
        if (@data[:description]) 
          if enum
            @data[:description].gsub('%enum%', enum)
          else
            @data[:description]
          end
        elsif @data[:enum] then enum
        else %{[no description]} end
      end
    end
  end
end
