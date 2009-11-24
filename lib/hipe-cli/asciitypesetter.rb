module Hipe
  module Cli
    module AsciiTypesetter
      def initialize
        @column_padding = 4
        @screen_width = 80        
      end
      def self.truncate(str,max_len,ellipses='...')
        if (str.nil?)
          ''
        elsif (str.length <= max_len)
          str
        elsif (max_len <= ellipses.length)
          str[0,max_len]
        else
          str[0,max_len-ellipses.length-1]+ellipses
        end
      end
      
      def self.recursive_brackets(list,left,right,use_outermost_brackets=1)
        if use_outermost_brackets
          self._recursive_brackets(list,left,right,use_outermost_brackets=1)
        else
          list.shift.to_s + ' ' + self._recursive_brackets(list,left,right,use_outermost_brackets=1)
        end
      end
      
      def self._recursive_brackets(list,left,right,use_outermost_brackets=1)
        %{#{left}#{list.shift.to_s}#{(list.size > 0 ? (' '+recursive_brackets(list,left,right,true)) : '')}#{right}}
      end
      
      def describe_monoline_two_columns(first, second, first_width, second_width, margin)
        sprintf(%{%-#{first_width}s},margin+App.truncate(first,first_width - margin.length)) + 
        sprintf(%{%-s},App.truncate(second,second_width))
      end

      def word_wrap(text, line_width) # thanks rails
        #ret = text.gsub(/\n/, "\n\n").gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip 1.2.6
        # the above looses leading spaces etc.  below is from 2.2.2
        ret = text.split("\n").collect do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"        
        ret
      end

      def n_columns(columns)
        columns.each do |column|
          column[:lines ] =  word_wrap(column[:content], column[:width]).split("\n")
          column.delete(:content)
        end

        max_lines = (columns.inject{|memo,this| memo[:lines].length < this[:lines].length ? this : memo })[:lines].length
        
        lines = [*0..(max_lines-1)].map do |i|
          columns.map do |column|
            sprintf(%{%-#{column[:width]}s}, column[:lines][i])
          end * ''
        end

        ret = lines * "\n"
      end

      def describe_command_multiline(cmd, opts={})  
        opts = {
          :total_width => @cli_screen_width,
          :margin      => ''
        }.merge(opts)
        lines = []
        command_label = cmd[:name].to_s.gsub(/_/,'-')
        usage_line_parts = ["Usage: #{cli_app_title} #{command_label}"]
        usage_line_parts << "[OPTIONS]" if cmd[:options] && cmd[:options].size > 0
        usage_line_parts += cmd[:required_arguments].map{|x| x[:name].to_s } if cmd[:required_arguments]
        usage_line_parts << recursive_brackets(cmd[:optional_arguments].map{|x|x[:name]},'[',']') if cmd[:optional_arguments]
        usage_line_parts << recursive_brackets(Array.new(2,cmd[:splat][:name])+['...'],'[',']',!(cmd[:splat][:minimum]==1)) if 
          cmd[:splat]
        opts2 = opts.merge(:margin=>'  ', :padding => @cli_column_padding)
        # this is crazy: changing the original data structure, put the splat either on the required arguments or the 
        # optional arguments, depending on if it is minimum 1 or not
        if (cmd[:splat]) 
          which = (cmd[:splat][:minimum] && cmd[:splat][:minimum] >= 1) ? :required_arguments : :optional_arguments
          cmd[which] ||= []; cmd[which] << cmd[:splat]
        end
        [ usage_line_parts * ' ',
          #(!cmd[:splat]) ? nil : describe_multiline_two_columns([cmd[:splat]], opts2.merge(:title=>"\n")),
          describe_multiline_two_columns(cmd[:required_arguments], opts2.merge(:title=>"\nRequired Arguments:\n")),
          describe_multiline_two_columns(cmd[:optional_arguments], opts2.merge(:title=>"\nOptional Arguments:\n")),
          describe_multiline_two_columns(cmd[:options], opts2.merge(:title=>"\nOptions:\n")),          
        ].compact * "\n"
      end
      
      def describe_multiline_two_columns(args,opts)
        opts = {:title=>''}.merge(opts)
        return nil if args.nil?  # keep this here!
        if (args.instance_of?(Hash))
          args = args.map{ |k,v| {:name=>k.to_s.gsub('_','-'), :description=>v[:description]}}.sort{|a,b| a[:name]<=>b[:name]}
        end
        opts2 = {}
        opts2[:max] = (args.inject{ |longest,this| longest[:name].to_s.length > this[:name].to_s.length ? longest : this })[:name].to_s.length
        opts2[:max] += opts[:margin].length
        opts2[:first_column_width] = [opts2[:max], (opts[:total_width] / 2).floor].min + opts[:padding]
        opts2[:second_column_width] = ( opts[:total_width] - opts2[:first_column_width] )
        opts2.delete(:max)

        ret = args.map do |arg|
          desc = arg[:description] ? arg[:description] : '(no description)'          
          cols = [ { :content => opts[:margin]+(arg[:name].to_s), :width => opts2[:first_column_width ] }, 
            { :content => desc, :width => opts2[:second_column_width ] }
          ]
          n_columns(cols)
        end
        opts[:title] + (ret * "\n")
      end      
    end
  end
end # Hipe


def cli_usage_message
  opts = {:margin=>'  ',:total_width=>@cli_screen_width,:padding=>@cli_column_padding}
  s = ''; #s = 'Usage: '
  if (@cli_command_data.nil?)
    s << cli_app_title() +" COMMAND [OPTIONS] [ARGUMENTS]\n\n" + 
    "Commands:"
    ks = @cli_commands.keys.map{|k| k.to_s }.sort
    if (ks.include? 'help')
      ks.delete 'help'
      ks.unshift 'help'
    end
    
    commands_like_arguments = []
    ks.each do |key_as_str|
      commands_like_arguments << {
        :name => key_as_str,
        :description => @cli_commands[key_as_str.to_sym][:description]
      }
    end
    s << "\n"+describe_multiline_two_columns(commands_like_arguments,opts)
  else
    s << "\n"+describe_command_multiline(@cli_command_data,opts)
  end
  s
end