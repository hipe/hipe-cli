require 'rubygems'
require 'getopt/long'
require 'pp'
require File.dirname(__FILE__)+'/filestuff'

module Markus
  module Cli 
   
  class CliException < Exception; end # for errors related to argument handling. ideally would never be thrown
     
    class SyntaxError < Exception # soft errors for user to see.  (might change this to throw/catch?)
     def initialize(msg,opts=nil)
       super(msg)
     end
   end
   
    module App
      include Getopt    

      @@cli_common_commands = {
        :help => {
          :description => 'Show detailed help for a given COMMAND, or general help',
          :optional_arguments => [
            {:name=>:COMMAND_NAME}
          ]
        }
      }
      
      @@cli_common_options = {      
        :debug => {
          :description => 'Type one or more d\'s (e.g. "-ddd" to indicate varying degrees of '+
          'debugging output (put to STDERR).',
          :getopt_type => Getopt::INCREMENT
        }
      }

      def cli_pre_init
        # the below hold the entire "grammar" and help documentation for the interface of your cli app
        @cli_commands = {}
        @cli_global_options = {}
        
        # the below are the result of parsing the user's input
        @cli_command = nil
        @cli_options =   {}
        @cli_arguments = {}
        @cli_files =     {} # filehandles and filenames to files the user may have passed as arguments or options        

        # housekeeping
        @cli_log_level = nil # when set to nil it is supposed to let every debugging message thru to STDERR
      end
      
      def cli_post_init #* this might get replaced by an "add command" type of thing

        if (0 < @cli_global_options.size)
          @cli_commands.each do |name,command|
            cli_populate_global_options command
          end
        end
        
        # add an entry in the commands structure for each method even if it doesn't have metadata
        self.methods.each do |meth| 
          if ((m = /^cli_execute_(.*)$/.match(meth)) && @cli_commands[m[1].to_sym].nil?)
            @cli_commands[m[1].to_sym] = {:name=>m[1].to_sym, :description=>'(user-defined method)'}
          end
        end
        
        # for now validate that splat and options aren't combined even though in theory they could be
        # (really wierd but imagine:)    app.rb --opt1=a --opt2 REQ1 REQ1 [OPT1 [OPT2 [SPLAT [SPLAT]]]]
        @cli_commands.each do |k,v|
          if ([:splat,:optional_arguments] & v.keys).size > 1
            raise CliException("For now can't have both splat and optional args")
          end
        end
      end
            
      def cli_app_title
        File.basename $PROGRAM_NAME
      end
      
      def cli_usage_message
        s = 'Usage: '
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
          s << "\n"+two_columns(commands_like_arguments,:margin=>'  ').join("\n")
        else
          s << "\n"+describe_command(@cli_command_data)
        end
        s
      end
        
      # the supersyntax for all commands will be: 
      # this-script.rb command-name --opt="x" --opt2="x y" [filename1 [filename2 [...]]] ...    
      def cli_run(arg_list=nil)
        cli_log(2){"\000"+cli_app_title+" started on "+Time.now.to_s}; 
        # so parse out a string not starting with a dash, zero or more ones starting with a dash, 
        # and zero or more not starting with a dash
        arg_list ||= ARGV
        begin
          @cli_command_data = parse_command   arg_list
          @cli_arguments   = parse_arguments arg_list
          @cli_options     = parse_options   arg_list
        rescue SyntaxError,SoftException => e
          str = e.message+"\n"+cli_usage_message
          puts str
          return
        end
                
        method_name = 'cli_execute_'+(@cli_command_data[:name].to_s)
        
        cli_log(4){"\000Running #{method_name}() to implement the command."}
        #end
        __send__(method_name)
        cli_log(2){"\000"+cli_app_title+" finished on "+Time.now.to_s}        
      end #def cli_run

      def cli_validate_opt_or_arg(validations_list, var_hash, var_name)
        validations_list.each do |val_data|
          meth_tail = case val_data
            when String: val_data            
            when Symbol: val_data.to_s
            else val_data[:type].to_s
          end
          meth_name = 'cli_validate_'+meth_tail
          __send__(meth_name, val_data, var_hash, var_name)
        end
      end
     
      def cli_activate_opt_or_arg_open_file action, var_hash, var_name
        @cli_files[var_name] = {
          :fh => File.open(var_hash[var_name], action[:as]),
          :filename => var_hash[var_name]
        }      
      end
      
      def cli_activate_opt_or_arg action, var_hash, var_name
        if (action.instance_of? Proc)
          var_hash[var_name] = action.call(var_hash[var_name])
        else
          do_this = 'cli_activate_opt_or_arg_'+action[:action].to_s
          __send__ do_this, action, var_hash, var_name
        end
      end
      
      def cli_validate_file_must_exist(validation_data, var_hash, var_name)
        FileStuff.file_must_exist(var_hash[var_name])
      end
      
      def cli_validate_file_must_not_exist(validation_data, var_hash, var_name)
        FileStuff.file_must_not_exist(var_hash[var_name])
      end      
      
      def cli_validate_regexp(validation_data, var_hash, var_name)
        value = var_hash[var_name]  
        re = validation_data[:regexp]
        if (! matches = (re.match(value))) 
          msg = validation_data[:message] || "failed to match against regular expression #{re}"
          raise SyntaxError.new(%{Error with --#{var_name}="#{value}": #{msg}})
        end
        var_hash[var_name] = matches if matches.size > 1 # clobbers original, only when there are captures ! 
      end

      # this guy makes string keys and string values!
      # pls note that according to apeiros in #ruby, "your variant of json isn't json"
      def cli_validate_jsonesque(validation_data, var_hash, var_name)
        var_hash[var_name] = Hash[*(var_hash[var_name]).split(/:|,/)] # thanks apeiros
      end
      
      def cli_file name
        if (!@cli_files[name] || !@cli_files[name][:fh])
          msg = %{no suchfile #{name.inspect} -- available files are: }+cli_files_inspect
          raise CliException.new(msg);
        end
        @cli_files[name][:fh]
      end
      
      def cli_files_inspect
        @cli_files.map{|k,v| k.inspect+':'+v[:filename]}.join(',')
      end
      
      protected
            
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
      
      def el_recurso(list,left,right,use_outermost_brackets=1)
        if use_outermost_brackets
          _el_recurso(list,left,right,use_outermost_brackets=1)
        else
          list.shift.to_s + ' ' + _el_recurso(list,left,right,use_outermost_brackets=1)
        end
      end
      
      def _el_recurso(list,left,right,use_outermost_brackets=1)
        %{#{left}#{list.shift.to_s}#{(list.size > 0 ? (' '+el_recurso(list,left,right,true)) : '')}#{right}}
      end
      
      def describe_command(command_data, opts={})  
        opts = {
          :total_width => 80,
          :first_col_width => 30,
          :length => :one_line_,
          :margin => ''
        }.merge(opts)
        right_col_width = opts[:total_width] - opts[:first_col_width]        
        cmd = command_data
        command_label = cmd[:name].to_s
        command_label.gsub!(/_/,'-') unless opts[:is_arg]
        if :one_line == opts[:length]
          descr = cmd[:description].nil? ? '(no description)' : cmd[:description]
          return sprintf(%{#{opts[:margin]}%-#{opts[:first_col_width]}s},command_label)+
           App.truncate(descr,right_col_width)
        end      
        usage_parts = []; args_desc_lines = [];
        usage_parts << "\nUsage: \n #{cli_app_title} #{command_label.to_s}"
        usage_parts << "[OPTIONS]" if cmd[:options] && cmd[:options].size > 0
        if cmd[:required_arguments]
          cmd[:required_arguments].each { |arg| usage_parts << arg[:name] } # no special formatting for required
          args_desc_lines += two_columns(cmd[:required_arguments], opts)
        end
        if cmd[:optional_arguments]
          usage_parts << el_recurso( cmd[:optional_arguments].map { |x| x[:name] } , '[', ']' )
          args_desc_lines += two_columns(cms[:optional_arguments], opts.merge({:length=>0}))
        end
        if cmd[:splat]
          usage_parts << el_recurso( Array.new(2,cmd[:splat][:name]) + ['...'], '[', ']', !(cmd[:splat][:minimum]==1))
          desc_line = describe_command(cmd[:splat], :length=>:one_line, :is_arg=>1)
          args_desc_lines << desc_line if (0<desc_line.length)                
        end
        if cmd[:options]
          opts_desc_lines = two_columns(cmd[:options],opts.merge({:length=>0}))
        else 
          opts_desc_lines = []
        end
          # first_col_width = opts[:first_col_width] - 2
          # cmd[:options].each do |k,v|
          #   opts_desc_lines << sprintf(%{%-#{first_col_width}s}, (k.to_s+'=ARG')) + 
          #   (v[:description] ? v[:description] : '')
          # end
        sections = []
        grammar = usage_parts.join(' ');
        sections << cmd[:description] if cmd[:description]
        sections << grammar if (grammar.length > 0)
        sections << ("\nArguments:\n  "+ args_desc_lines.join("\n  ")) if args_desc_lines.size > 0
        sections << ("\nOptions:\n  "+ opts_desc_lines.join("\n  ")) if opts_desc_lines.size > 0
        sections << "\n"
        sections.join("\n");
      end
      
      def two_columns(args,opts={})
        opts = {
          :margin => ''
        }.merge(opts)
        ret = []
        if (args.instance_of?(Hash))
          args = args.map{ |k,v| {:name=>k.to_s, :description=>v[:description]}}
        end
        max = 0        
        args.each do |v|
          max = [max,v[:name].to_s.length].max
        end
        optos = {
         :length=>:one_line, 
         :is_arg=>1, 
         :first_col_width=>max+5, 
        }.merge(opts)
        args.each do |v|
          desc_line = describe_command(v, optos)
          if (0<desc_line.length)
            ret << desc_line 
          end
        end
        ret
      end
      
      def cli_populate_global_options(command_data)
        command_data[:options] ||= {}
        command_data[:options].merge!(@cli_global_options) { |key, old_val, new_val| old_val.nil? ? new_val : old_val }
      end 
      
      def parse_command(arg_list)
        # raise SyntaxError.new('Please indicate a command.') if (arg_list.size==0)
        arg_list << 'help' if arg_list.size==0
        dirty_command = arg_list.shift
        as_sym = switch( dirty_command )
        if @cli_commands[as_sym].nil?
          raise SyntaxError.new("Sorry, \"#{dirty_command}\" is not a valid command.");
        else
          command_data = @cli_commands[as_sym].clone
        end
        command_data[:name] = as_sym if command_data[:name].nil?  # not sure when we would indicate a :name if ever
        return command_data
      end
      
      def cli_execute_help
        command_name = @cli_arguments[:COMMAND_NAME] 
        command_sym = switch( command_name )
        command_data = @cli_commands[command_sym]
        if command_name.nil? 
          print cli_app_title+": "+@cli_description+"\n\n"
          @cli_command_data = nil; 
          print  %{For help on a specific command, try \n  #{cli_app_title} help COMMAND\n\n}+
            %{#{cli_usage_message}\n\n}
        elsif
          command_data.nil?
          print "Sorry, there is no command \"#{command_name}\"\n";
          @cli_command_data = nil; 
          print cli_usage_message
        else
          puts @cli_arguments[:COMMAND_NAME]+":"
          command_data[:name] = command_sym
          puts describe_command command_data
        end
      end      
      def schlurp_optional_arguments(dirty_args, named_args)
        # if we have optional arguments, schlurp them up too
        if @cli_command_data[:optional_arguments] 
          names = []
          last_i = [@cli_command_data[:optional_arguments].size - 1, dirty_args.size - 1].min
          vals = []
          (0..last_i).each do |i|
            info = @cli_command_data[:optional_arguments][i]
            name_sym = info[:name]
            vals << i if info[:validations]            
            named_args[name_sym] = dirty_args.shift
          end 
          vals.each do |i| # for no reason the optionals args have the privilege of getting all the named args
            cli_validate_opt_or_arg(
              @cli_command_data[:optional_arguments][i][:validations], named_args, 
              @cli_command_data[:optional_arguments][i][:name]
            )
          end
        end
      end
      
      def schlurp_required_arguments(dirty_args, named_args)
        # shlurp all required arguments, barking if they are missing
        if ( @cli_command_data[:required_arguments] )
          @cli_command_data[:required_arguments].each_with_index do |arg, i|
            if (dirty_args.length == 0) # no more inputted arguments to parse!
              names = @cli_command_data[:required_arguments][i..-1].map{|x| x[:name].to_s}
              raise SyntaxError.new("Missing required argument#{names.size>0?'s': ''}: "+names.join(' '));
            end
            value = dirty_args.shift
            named_args[arg[:name]] = value
            cli_validate_opt_or_arg(arg[:validations], named_args, arg[:name]) if arg[:validations]
            cli_activate_opt_or_arg(arg[:action]    , named_args, arg[:name]) if arg[:action]
          end
        end # if
      end
        
      def schlurp_splat_arguments(dirty_args, named_args)
        splat =  @cli_command_data[:splat]
        return unless splat        
        if splat[:minimum] && (splat[:minimum] > dirty_args.count)
          raise SyntaxError.new(%{Expecting at least #{splat[:minimum]} #{splat[:name]}}) # should only ever be 1
        end
        named_args[splat[:name]] = dirty_args.clone
        dirty_args.clear
      end
      
      def parse_arguments(arg_list)
        named_args = {}
        dirty_args = []
        # starting from the end, pick off arguments one by one until you find one that 
        # starts with a "-" (and assume it is an option)
        while arg_list.size > 0 && arg_list.last[0].chr != '-' do
          dirty_args << arg_list.pop
        end
        dirty_args.reverse!  # even though we just reversed it, it is in the orig. order
        schlurp_required_arguments(dirty_args, named_args)
        schlurp_optional_arguments(dirty_args, named_args)
        schlurp_splat_arguments(dirty_args, named_args)        
        # if we have any remaining provided arguments, we have a syntax error
        if (0 < dirty_args.length)
          raise SyntaxError.new("Sorry, there were unexpected arguments: \""+dirty_args.join(' ')+"\"",
            :type => :extra_arguments,
            :args => dirty_args
          )
        end
        return named_args
      end
            
      def parse_options arg_list
        if @cli_command_data[:options].nil?
          cli_log(2){"NOTICE: skipping the parsing of options because none are present in the grammar!"}
          return
        end
        opts_grammar = []
        @cli_command_data[:options].each do |key,value|
          if value.nil?
            raise CliException("Strange -- no value for option node")
          end
          arr = ['--'+switch(key), nil, ( value[:getopt_type] || REQUIRED )]
          opts_grammar.push arr
        end 
        
        begin
          given_opts = Long.getopts(*opts_grammar); # splat operator makes an array into a series of arguments
        rescue Getopt::Long::Error => e
          raise SyntaxError.new( e.message )
        end
        
        # use symbol keys instead of strings, because it is what we are used to and it corresponds to other code
        given_opts.keys.each{ |k| given_opts[ switch k ] = given_opts[k]; given_opts.delete(k) }
        
        # we do this inline here instead of using the "process_options" convention so we can use
        # debugging output to report on the progress of "process_options" actions
        @cli_log_level = given_opts[:debug] unless given_opts[:debug].nil? #if not nil, it is almost certainly an integer of [0...]

        cli_log(7){ spp("Here are the parsed not processed given opts:\n ",given_opts) }
        
        # clean up and run validations on options
        given_opts.keys.each do |k|
          grammar = @cli_command_data[:options][k]
          if grammar.nil?  # get rid of single letter keys for clarity
            given_opts.delete(k) 
          else
            cli_validate_opt_or_arg(grammar[:validations], given_opts, k) if grammar[:validations]
            cli_activate_opt_or_arg(grammar[:action]    , given_opts, k) if grammar[:action]
          end
        end

        #do_theseKeys.each do |k|
        cli_log(4){"processing each of "+given_opts.size.to_s+" provided opts\000"}; (cli_log(5){"\000:"}) or (cli_log(4){""})
        given_opts.keys.each do |k|
          processing_meth = 'cli_process_option_'+k.to_s
          cli_log(5){"#{processing_meth}()"}
          __send__(processing_meth, given_opts, k)
        end
        cli_log(3){spp("\000given_opts",given_opts)}
        
        return given_opts
      end

      # we do this inline above so we can use it to report on the non-processed options but we leave the stub here
      # to fit in with the "api"
      def cli_process_option_debug(given_opts, k)
        # cli_log_level = given_opts[:debug] unless given_opts[:debug].nil?
      end      
      
      # PrettyPrint.pp() that returns a string instead (like puts) of print to standard out, 
      # like sprintf() is to printf().  prints info about where it was called from.
      def spp label, object
        # go backwards up the call stack, skipping caller methods we don't care about (careful!)
        # this is intended to show us the last interesting place from which this was called.
        i = line = methname = nil
        caller.each_with_index do |line,index|
          matches = /`([^']+)'$/.match(line)
          break if (matches.nil?) # almost always the last line of the stack -- the calling file name
          matched = /(?:\b|_)(?:log|ppp|spp)(?:\b|_)/ =~ matches[1]
          break unless matched
        end
        m = /^(.+):(\d+)(?::in `(.+)')?$/.match line
        raise CliException.new(%{oops failed to make sense of "#{line}"}) unless m
        path,line,meth = m[1],m[2],m[3]
        file = File.basename(path)
        PP.pp object, obj_buff=''
        
        # location = "(at #{file}:#{meth}:#{line})"
        location ="(at #{file}:#{line})"        
        if (location == @last_location)
          location = nil
        else 
          @last_location = location
        end
        
        buff = '';
        buff << label.to_s + ': ' if label
        buff << location if location
        buff << "\n" if (/\n/ =~ obj_buff)
        buff << obj_buff
        buff
      end      

      # don't change the name of this w/o reading spp() very carefully!
      def ppp symbol, object=nil, die=nil
        unless (symbol.instance_of?(Symbol) || symbol.instance_of?(String))
          die = object
          object = symbol
          symbol = 'YOUR VALUE'
        end
        
        puts spp(symbol, object)
        if die
          exit
        end
      end

      # print the string that results from calling the block iff log_levelInt is less than or equal to
      # the log level set by passing --debug flags

      # Log levels: level 0 means output no matter what. Level 1 is output informational stuff
      # perhaps for the client (not developer) to see.  
      # Level 2 and above are informational and for the developer
      # or user trying to troubleshoot a bug.
      # there is no upper bounds to the debug levels.  but we might restrict it to the range (0..10] (sic) 
      # and use floats instead; one day.
      
      # if there is no @cli_log_level set at the time this is called, it probably means that the command-
      # line processor hasn't been called yet, in which case we output the message no matter what.
      
      # if a string starts with the null character (zero, ie "\000") it means "do not indent this line"      
      # (otherwise, lines will be indented according to their loglevel)
      # if you end a string with the null character (zero, ie \000) it means "no newline afterwards"
      def cli_log(log_levelInt, &print_block)
       if !@cli_log_level.nil? && log_levelInt <= @cli_log_level
         str = yield;
         unless(str.instance_of? String)
           STDERR.print "misuse of cli_log() -- block should return string at "+caller[0]+"\n"
           false
         else 
           STDERR.print('  '*[log_levelInt-2,0].max) unless str[0] == 0
           str = str[1..-1] if (0==str[0])
           STDERR.print str
           STDERR.print("\n") unless str[-1] == 0       
           true
         end
       else
         false
       end
     end
      
      def switch(sym_or_string)
        if sym_or_string.kind_of? Symbol
          sym_or_string.to_s.gsub(/_/,'-')
        elsif sym_or_string.kind_of? String
          sym_or_string.gsub(/-/,'_').to_sym
        else
          sym_or_string
        end
      end

    end #module App
  end #module Cli
end #module Markus