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

      @@cliCommonCommands = {
        :help => {
          :description => 'Show detailed help for a given COMMAND, or general help',
          :optional_arguments => [
            {:name=>:COMMAND_NAME}
          ]
        }
      }
      
      @@cliCommonOptions = {      
        :debug => {
          :description => 'Type one thru six d\'s (e.g. "-ddd" to indicate varying degrees of '+
          'debugging output (put to STDERR).',
          :getopt_type => Getopt::INCREMENT,
        },
      }

      def cli_pre_init
        # the below hold the entire "grammar" and help documentation for the interface of your cli app
        @cliCommands = {}
        @cliGlobalOptions = {}
        
        # the below are the result of parsing the user's input
        @cliCommand = nil
        @cliOptions =   {}
        @cliArguments = {}
        @cliFiles =     {} # filehandles and filenames to files the user may have passed as arguments or options        

        # housekeeping
        @cliLogLevel = 0
      end
      
      def cli_post_init #* this might get replaced by an "add command" type of thing
        names = []
        self.methods.each do |meth| 
          if ((m = /^cli_execute_(.*)$/.match(meth)) && @cliCommands[m[1].to_sym].nil?)
            @cliCommands[m[1].to_sym] = {:name=>m[1].to_sym, :description=>'(user-defined method)'}
          end
        end
      end
            
      def cli_app_title
        File.basename $PROGRAM_NAME
      end
      
      def cli_usage_message
        s = 'Usage: '
        if (@cliCommandData.nil?)
          s << cli_app_title() +" COMMAND [OPTIONS] [ARGUMENTS]\n" + 
          "commands:\n"
          ks = @cliCommands.keys.map{|k| k.to_s }.sort
          if (ks.include? 'help')
            ks.delete 'help'
            ks.unshift 'help'
          end
          ks.each do |key|
            commandData = @cliCommands[key.to_sym]
            commandData[:name] = key unless commandData[:name]
            s << "\n  "+describe_command(commandData, :length=>:one_line)
          end
        else
          s << "\n"+describe_command(@cliCommandData)
        end
        s
      end
        
      # the supersyntax for all commands will be: 
      # this-script.rb command-name --opt="x" --opt2="x y" [filename1 [filename2 [...]]] ...    
      def cli_run(argList=nil)

        # so parse out a string not starting with a dash, zero or more ones starting with a dash, 
        # and zero or more not starting with a dash
        argList ||= ARGV
        begin
          @cliCommandData = parse_command   argList
          @cliArguments   = parse_arguments argList
          @cliOptions     = parse_options   argList
        rescue SyntaxError,SoftException => e
          str = e.message+"\n"+cli_usage_message
          puts str
          return
        end
                
        method_name = 'cli_execute_'+(@cliCommandData[:name].to_s)
        
        #unless cli_log(7){"\n\nAbout to request #{method_name} with this grammar:\n"+spp(nil, @cliCommandData);}
        cli_log(4){"\000Running #{method_name}() to implement the command."}
        #end

        __send__(method_name)
      end #def cli_run

      def cli_validate_opt_or_arg(validationsList, varHash, varName)
        validationsList.each do |valData|
          methTail = case valData
            when String: valData            
            when Symbol: valData.to_s
            else valData[:type].to_s
          end
          methName = 'cli_validate_'+methTail
          __send__(methName, valData, varHash, varName)
        end
      end
      
      def cli_activate_opt_or_arg(action, varHash, varName)
        ppp "blah"
        case action[:action]
          when :open_file
            @cliFiles[varName] = {
              :fh => File.open(varHash[varName], action[:as]),
              :filename => varHash[varName]
            }
          else
            raise CliException.new("can't determine action for "+spp(:action, action))
          end
      end
      
      def cli_validate_file_must_exist(validationData, varHash, varName)
        FileStuff.file_must_exist(varHash[varName])
      end
      
      def cli_validate_regexp(validationData, varHash, varName)
        value = varHash[varName]  
        re = validationData[:regexp]
        if (! matches = (re.match(value))) 
          raise SyntaxError.new(validation[:message]+' (your value: "'+value+'", re: '+re.to_s+')')
        end
        varHash[varName] = matches # clobbers original ! 
      end

      # this guy makes string keys and string values!
      # pls note that according to apeiros in #ruby, "your variant of json isn't json"
      def cli_validate_jsonesque(validationData, varHash, varName)
        varHash[varName] = Hash[*(varHash[varName]).split(/:|,/)] # thanks apeiros
      end
      
      def cli_file name
        if (!@cliFiles[name] || !@cliFiles[name][:fh])
          raise CliException.new(%{no such file "#{name}" -- #{@cliFiles.inspect}});
        end
        @cliFiles[name][:fh]
      end
      
      protected
            
      def self.truncate(str,maxLen,ellipses='...')
        if (str.nil?)
          ''
        elsif (str.length <= maxLen)
          str
        elsif (maxLen <= ellipses.length)
          str[0,maxLen]
        else
          str[0,maxLen-ellipses.length-1]+ellipses
        end
      end
      
      def describe_command(commandData, opts={})
        if (opts[:length] && opts[:length]==:one_line)
          descr = commandData[:description].nil? ? '(no description)' : commandData[:description]
          s = sprintf('%-28s',switch( commandData[:name] ))+App.truncate(descr,50)
        else
          parts = []
          args_desc_lines = []
          opts_desc_lines = []
          parts << "\nUsage: \n #{cli_app_title} #{commandData[:name].to_s}"
          
          #cli_populate_global_options(commandData) if (0<@cliGlobalOptions.size)
                    
          if (commandData[:options] && commandData[:options].size > 0)
            parts << "[OPTIONS]"
          end
          if (commandData[:required_arguments])
            commandData[:required_arguments].each do |v|
              parts << v[:name]
              desc_line = describe_command(v, :length=>:one_line)                
              if (0<desc_line.length)
                args_desc_lines << desc_line 
              end
            end
          end
          if (commandData[:optional_arguments])
            last = commandData[:optional_arguments].size - 1
            commandData[:optional_arguments].each_with_index do |v,i|
              desc_line = describe_command(v, :length=>:one_line)
              args_desc_lines << desc_line if (0<desc_line.length) 
              s = '['+ switch( v[:name] );
              s << (']'*(i+1)) if (i==last)
              parts << s
            end              
          end
          if (commandData[:options])
            commandData[:options].each do |k,v|

                unless (v.instance_of? Hash)
                  pp commandData
                  puts "ls;akfjleskfjesalkfjesak;"
                  exit
                end
                
              opts_desc_lines << sprintf('--%-26s', switch( k )+'=ARG') + 
              (v[:description] ? v[:description] : '')
            end
          end
          sections = []
          grammar = parts.join(' ');
          sections << commandData[:description] if commandData[:description]
          sections << grammar if (grammar.length > 0)
          sections << ("\nArguments:\n  "+ args_desc_lines.join("\n  ")) if args_desc_lines.size > 0
          sections << ("\n\nOptions:\n  "+ opts_desc_lines.join("\n\n  ")) if opts_desc_lines.size > 0
          sections << "\n"
          s = sections.join("\n");
        end # else show grammar
        if (s.nil?) 
          s = "hwat gives ? "+pp(commandData, opts)
        end
        return s
      end
      
      def cli_populate_global_options(commandData)
        commandData[:options] ||= {}
        commandData[:options].merge!(@cliGlobalOptions) { |key, oldVal, newVal| oldVal.nil? ? newVal : oldVal }
      end 
      
      def parse_command(argList)
        # raise SyntaxError.new('Please indicate a command.') if (argList.size==0)
        argList << 'help' if argList.size==0
        dirtyCommand = argList.shift
        asSym = switch( dirtyCommand )
        if @cliCommands[asSym].nil?
            raise SyntaxError.new("Sorry, \"#{dirtyCommand}\" is not a valid command.");
        else
          commandData = @cliCommands[asSym].clone
        end
        commandData[:name] = asSym if commandData[:name].nil?  # not sure when we would indicate a :name if ever
        return commandData
      end
        
      def cli_execute_help
        commandName = @cliArguments[:COMMAND_NAME] 
        commandSym = switch( commandName )
        commandData = @cliCommands[commandSym]
        if commandName.nil? 
          print cli_app_title+": "+@cliDescription+"\n\n"
          @cliCommandData = nil; 
          print cli_usage_message                   
        elsif
          commandData.nil?
          print "Sorry, there is no command \"#{commandName}\"\n";
          @cliCommandData = nil; 
          print cli_usage_message
        else
          puts @cliArguments[:COMMAND_NAME]+":"
          commandData[:name] = commandSym
          puts describe_command commandData
        end
      end        
      
      def parse_arguments(argList)
        namedArgs = {}
        dirtyArgs = []
        
        # starting from the end, pick off arguments one by one until you find one that 
        # starts with a "-" (and assume it is an option)
        while argList.size > 0 && argList.last[0].chr != '-' do
          dirtyArgs << argList.pop
        end
        dirtyArgs.reverse!
        
        # shlurp all required arguments, barking if they are missing
        missingRequired = []
        if ( @cliCommandData[:required_arguments] )
          @cliCommandData[:required_arguments].each_with_index do |arg, i|
            if (dirtyArgs.length == 0) # no more inputted arguments to parse!
              names = @cliCommandData[:required_arguments][i..-1].map{|x| x[:name].to_s}
              raise SyntaxError.new("Missing required argument#{names.size>0?'s': ''}: "+names.join(' '));
            end
            value = dirtyArgs.shift
            namedArgs[arg[:name]] = value
            cli_validate_opt_or_arg(arg[:validations], namedArgs, arg[:name]) if arg[:validations]
            cli_activate_opt_or_arg(arg[:action]    , namedArgs, arg[:name]) if arg[:action]
          end
        end # if

        # if we have optional arguments, schlurp them up too
        if @cliCommandData[:optional_arguments] 
          names = []
          nameToIndex = {}
          lastI = [@cliCommandData[:optional_arguments].size - 1, dirtyArgs.size - 1].min
          vals = []
          (0..lastI).each do |i|
            info = @cliCommandData[:optional_arguments][i]
            nameSym = info[:name]
            vals << i if info[:validations]            
            namedArgs[nameSym] = dirtyArgs.shift
          end 
          vals.each do |i| # for no reason the optionals args have the privilege of getting all the named args
            cli_validate_opt_or_arg(
              @cliCommandData[:optional_arguments][i][:validations], namedArgs, 
              @cliCommandData[:optional_arguments][i][:name]
            )
          end
        end
        
        # if we have any remaining provided arguments, we have a syntax error
        if (0 < dirtyArgs.length)
          raise SyntaxError.new("Sorry, there were unexpected arguments: \""+dirtyArgs.join(' ')+"\"",
            :type => :extra_arguments,
            :args => dirtyArgs
          )
        end
        return namedArgs
      end
            
      def parse_options argList
        cli_populate_global_options @cliCommandData        
        if @cliCommandData[:options].nil?
          cli_log(2){"NOTICE: skipping the parsing of options because none are present in the grammar!"}
          return
        end
        optsGrammar = []
        @cliCommandData[:options].each do |key,value|
          if value.nil?
            raise CliException("Strange -- no value for option node")
          end
          arr = ['--'+switch(key), nil, ( value[:getopt_type] || REQUIRED )]
          optsGrammar.push arr
        end 
        
        begin
          givenOpts = Long.getopts(*optsGrammar); # splat operator makes an array into a series of arguments
        rescue Getopt::Long::Error => e
          raise SyntaxError.new( e.message )
        end
        
        # use symbol keys instead of strings, because it is what we are used to and it corresponds to other code
        givenOpts.keys.each{ |k| givenOpts[ switch k ] = givenOpts[k]; givenOpts.delete(k) }
        
        # we do this inline here instead of using the "process_options" convention so we can use
        # debugging output to report on the progress of "process_options" actions
        @cliLogLevel = givenOpts[:debug] unless givenOpts[:debug].nil? #if not nil, it is almost certainly an integer of [0...]

        cli_log(7){ spp("Here are the parsed not processed given opts:\n ",givenOpts) }
        
        # clean up and run validations on options
        givenOpts.keys.each do |k|
          grammar = @cliCommandData[:options][k]
          if grammar.nil?  # get rid of single letter keys for clarity
            givenOpts.delete(k) 
          elsif grammar[:validations]
            cli_validate_opt_or_arg(grammar[:validations], givenOpts, k)
          end
        end

        #doTheseKeys.each do |k|
        cli_log(4){"processing each of "+givenOpts.size.to_s+" provided opts\000"}; (cli_log(5){"\000:"}) or (cli_log(4){""})
        givenOpts.keys.each do |k|
          processingMeth = 'cli_process_option_'+k.to_s
          cli_log(5){"#{processingMeth}()"}
          __send__(processingMeth, givenOpts, k)
        end
        cli_log(3){spp("\000givenOpts",givenOpts)}
        
        return givenOpts
      end

      # we do this inline above so we can use it to report on the non-processed options but we leave the stub here
      # to fit in with the "api"
      def cli_process_option_debug(givenOpts, k)
        # cliLogLevel = givenOpts[:debug] unless givenOpts[:debug].nil?
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
        PP.pp object, objBuff=''
        
        # location = "(at #{file}:#{meth}:#{line})"
        location ="(at #{file}:#{line})"        
        if (location == @lastLocation)
          location = nil
        else 
          @lastLocation = location
        end
        
        buff = '';
        buff << label.to_s + ': ' if label
        buff << location if location
        buff << "\n" if (/\n/ =~ objBuff)
        buff << objBuff
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

      # Notes on log levels: level 0 means output no matter what. Level 1 is output informational stuff
      # perhaps for the client (not developer) to see. Level 2 and above are informational and for the developer
      # or user trying to troubleshoot a bug.
      # there is no upper bounds to the debug levels.  but we might restrict it to the range (0..10] (sic) 
      # and use floats instead; one day.
      
      # if you end a string with the null character (zero, ie \000) it means "no newline afterwards"
      # if a string starts with the null character (zero, ie "\000") it means "do not indent this line"
      # print the string that results from calling the block iff logLevelInt is less than or equal to
      # the log level set by passing --debug flags
      def cli_log(logLevelInt, &printBlock)
        if logLevelInt <= @cliLogLevel
          str = yield;
          unless(str.instance_of? String)
            STDERR.print "misuse of cli_log() -- block should return string at "+caller[0]+"\n"
            false
          else 
            STDERR.print('  '*[logLevelInt-2,0].max) unless str[0] == 0
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