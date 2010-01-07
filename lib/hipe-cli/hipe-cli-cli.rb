require 'orderedhash'
require 'json'
require 'hipe-cli'
require 'hipe-core/io/flushing-buffer-string'
require 'hipe-core/io/stack-like'
require 'hipe-core/struct/open-struct-common-extension'
require 'hipe-core/struct/open-struct-write-once-extension'
require 'hipe-core/struct/table'
require 'hipe-core/lingual/en'
require 'hipe-core/test/helper'
require 'abbrev'
require 'readline'

class HipeCliCli
  class GentestException < Hipe::Exception
    def message
      spr = super
      if (@details[:line_no])
        spr << %{ at #{File.basename(@details[:path])} line #{@details[:line_no]}}
      end
      spr
    end
  end
  attr_accessor :notice
  include Hipe::Cli
  cli.graceful{|e| e if GentestException === e}
  cli.does('-h','--help', 'help<<self')
  cli.out.klass = Hipe::Io::GoldenHammer
  cli.default_command = :help
  cli.does(:aliases, "outputs the lines to make aliases for each of the"+
                    " example applications in the examples folder.  If you want to "+
                    "get really crazy you can put them in your .bashrc") do |x|
    option('-h',&help)
    option('-l','--list', 'just list the names of the alises.')
  end
  def aliases(opts)
    exes = []
    shorts = []
    Dir[Hipe::Cli::DIR+'/examples/*'].each do |fn|
      next unless (md = /app-([a-z]+\d+)[-a-z]*\.rb$/.match(fn))
      number = md[1]
      exes <<  %{alias #{number}='#{fn}'}
      shorts << number
    end
    if opts.list
      puts "please select from among these glorious apps:\n"
      puts shorts.sort.join(' ')
    else
      puts "# copy paste these and run them in your shell or put them in your .bashrc to make the aliases:"
      puts exes.join "\n"
      puts"# done.\n"
    end
  end

  cli.does(:gentest, "generate tests from copy-pasted terminal output") do
    option('-h','--help','help<<self', &help)
    option('-l','--list [NUM]',"choose from a list of files in the default folder.") do |number|
      goto{ application.list_gentest_screenshots(number) }
    end
    option('-o','--out-file FILE', 'write to this file instead of the default location.') do |it|
      it.must_not_exist
    end
    # option('-s','--[no-]sped-up', 'whether or not to use the shell hack to speed up rendering (default true)')
    # hidden options in the yaml file
    # chomp       whether or not to chomp the newline character after app output (default true)
    # run_with    "command" | "cli" | "app"
    # app_regen   whether or not to create a new instance of the app each time (default false)
    # describe    describe YourApp, "<your text" do
    splat('INPUT_FILE', 'the file of copy-pasted terminal stuff', :minimum => 1){ |it|
      it.must_exist.gets_opened('r')
    }
  end

  def gentest(infiles, cmd_line_opts)
    out = cli.out.new
    infiles.each do |file|
      out.puts '*' * 30 + " #{file.path} " + '*' * 30
      out.puts _gentest(file, cmd_line_opts, out)
    end
    out
  end

  def _gentest(infile, cmd_line_opts, notice)
    Hipe::Io::StackLike[infile]
    cmd_line_opts.sped_up = true if cmd_line_opts.sped_up.nil?
    basename = File.basename(infile.path)
    raise ge(%{please rename #{basename} to match the pattern "*.screenshots"}) unless
      (md = basename.match(/^([^\.]+).screenshots$/))
    filename_inner = md[1]
    opts = parse_json_header(infile)
    opts.merge! cmd_line_opts._table
    if (opts.out_file)
      raise ge(%{sorry expected output file #{opts.out_file.inspect} to be in pwd #{Dir.pwd.inspect}}) unless
        (md = Regexp.new('^'+Regexp.escape(Dir.pwd)+'/(.+)$').match(opts.out_file))  # @SEP
      outfile_short = md[1]
    else
      outfile_short =  File.join('spec',"spec_#{filename_inner}-genned.rb")
      opts.out_file = outfile_short # used to be an abs path
    end

    missing = nil
    raise ge(%{missing (#{missing * ', '}) in json header of #{infile.path}}) if
      (missing = [:construct, :prompt, :requires] - opts._table.keys).size > 0
    begin
      test_cases = parse_test_cases(infile, opts.prompt, notice)
    rescue GentestException => e
      if (e.details[:on_line])
        e.details[:line_no] = infile.offset
        e.details[:path] = infile.path
      end
      raise e
    end
    shell_expansion(test_cases,opts)

    str = write_bacon_file( infile,      opts.out_file,   outfile_short,  test_cases,       opts.requires,
                         opts.construct, opts.describe,   opts.letter,    filename_inner,   opts
    )
    def str.valid?; true end
    str
  end

  def shell_expansion(test_cases,opts)
    raise "sorry, slow way has been unimplemented" unless opts.sped_up
    sep = '561ccbcb1909a1579dde2c9a655301900e17cc03'
    long = test_cases.map{|kase| kase.prompt } * %{ #{sep} }
    rs = Hipe::Test::Helper.shell!(long)
    nu = []
    cursor = 0
    curr_array = []
    (0..(rs.size - 1)).map.each do |idx|
      if rs[idx] == sep
        nu << curr_array
        curr_array = []
      else
        curr_array << rs[idx]
      end
    end
    nu << curr_array
    raise gge("something went wrong") unless nu.size == test_cases.size
    (0..test_cases.size-1).each{|i| test_cases[i].parsed_prompt = nu[i] }
    nil
  end

  def gge(*args); Hipe::Cli::GrammarGrammarException[*args] end
  def ge(*args);  GentestException[*args] end
  def e(*args);   Hipe::Exception[*args] end

  # skip initial lines that are blank or comments,
  # stop at the first line that ends in a '}'
  def parse_json_header(fh)
    raise e(%{needed StackLike, had #{infile.inspect}}) unless Hipe::Io::StackLike===fh
    return if fh.peek.nil?
    lines = []
    fh.pop while( fh.peek =~ /^(:? *#|(?: *$))/ )
    if fh.peek =~ /^ *\{/
      begin;  p = fh.pop; (lines << p.chomp) if p end until( (p =~ /\} *$/) || p.nil? )
      json_string = (lines.compact * "\n").gsub(/  */,' ')
      begin
        json_hash = JSON.parse(json_string)
      rescue JSON::ParserError => e
        raise ge <<-HERE.gsub(/^  /,'')
        Failed to parse the beginning of #{fh.path} as json:
        #{e.message}
        HERE
      end
    else
      json_hash = {}
    end
    json = Hipe::OpenStructCommonExtension[OpenStruct.new(json_hash)]
    json.describe ||= 'generated test'
    json.letter   ||= 'gt'
    json
  end

  def list_gentest_screenshots(number)
    out = cli.out.new
    default_location = 'spec/gentest-screenshots'
    list = Dir[File.join(default_location,'/*')].sort
    if (number && /^\d+$/ =~ number)
      thing = number
    else
      out.puts "Pick a screenshot file to regen:\n\n"
      list.each_with_index do |filename, i|
        out.puts %{#{i}) #{filename}}
      end
      puts out.read
      print "\nchoose a number or enter anything else to quit: "
      thing = $stdin.gets.chop
    end
    if /^\d+$/ =~ thing and list[thing.to_i]
      fh = File.open(list[thing.to_i], 'r')
      return gentest(fh,Hipe::Cli::OptionValues.new) # ahem
    else
      puts "thank you."
    end
    ''
  end

  # we really avoided using racc @todo
  def parse_test_cases(infile, prompt, notice=nil)
    @notice ||= (notice || $stdout)
    new_struct = lambda {
      struct = Hipe::OpenStructWriteOnceExtension.new(:response_lines => [])
      struct.write_once! :prompt, :result_lines
      struct.response_lines = []
      struct.captures = {}
      struct
    }
    test_cases = []
    current_case = new_struct.call
    state = :start
    advance = lambda {
      test_cases << current_case
      current_case = new_struct.call
      @notice << "     < < < "+Hipe::Lingual.en{sp(np('test case',pp('now'),test_cases.size))}.say+" > > > \n\n"
    }
    change_state = lambda { |new_state, line|
      case new_state
      when :prompt then  current_case.prompt  = line
      when :comment then current_case.comment = line
      when :response then current_case.response_lines << line
      else raise gge("never") end
      state = new_state
      @notice.puts "#{(state.to_s.+'-').ljust(10,'-')}------->#{line}<------"
    }
    directive_re = /^ *#! *(.+)/
    comment_re = /^ *# ?(.+)/
    prompt_re = Regexp.new('^'+Regexp.escape(prompt)+'(.+)')
    blank_re = /^ *$/

    capture = nil
    while (line = infile.pop)     # infile.each_line do |line|
      line.chomp!
      if (md = directive_re.match(line))
        directive = md[1]
        if (capture)
          re = Regexp.new("end +"+Regexp.escape(capture.name))
          raise gge(%{expecting #{re} had "#{line}"}) unless re =~ directive
          current_case.captures[capture.name] = capture
          capture = nil
          state = :comment
          advance.call
        else
          re = Regexp.new("^ *start +(.+)")
          raise gge(%{expecting #{re} had "#{line}"}) unless (md = re.match(directive))
          capture = OpenStruct.new
          capture.name = md[1]
          capture.lines = []
        end
        next
      elsif (capture)
        capture.lines << line
        next
      end

      case line
      when blank_re
        case state
        when :response then change_state.call(:response, line)
        else # skip blanks
        end
      when comment_re
        case state
        when :start,:comment then
        when :prompt
          raise ge((%{comments should not come between prompt and response}<<
          %{ (interpreting this line as a comment: "#{line}")}),
          :on_line=>true)
        when :response then advance.call
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:comment, line)
      when prompt_re
        case state
        when :start,:comment then
        when :response then advance.call
        when :prompt then raise ge(%{a prompt after a prompt?},:on_line=>true)
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:prompt, $1) # eew
      else
        case state
        when :comment
          raise ge(%{Failed to parse the following line. It didn't look like a comment, prompt, etc:\n"#{line}"},
          :on_line=>true)
        when :response,:prompt then
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:response, line)
      end
    end
    case state
    when :response then advance.call
    when :comment then # ignore
    else raise gge(%{bad end state for to end file in: #{state.inspect}})
    end
    test_cases
  end

  def putz x; @out.puts x end

  def write_bacon_file(infile,         outfilename,  outfile_short, test_cases,   requires,
                       construct,      describee,    letter,        filename_inner, opts
  )
    @out = Hipe::Io::BufferString.new
    run_it_with_this = %{bacon -n '.*' #{outfile_short}}
    putz %{# #{run_it_with_this}}
    requires.each do |req|
      putz %{require '#{req}'}
    end
    if (opts.relative_requires)
      opts.relative_requires.each do |req|
        putz %{require File.join(#{opts.module}::DIR,'#{req}')}
      end
    end

    putz <<-HERE.gsub(/^      /,'')


      # You may not want to edit this file.  It was generated from data in "#{File.basename(infile.path)}"
      # by #{cli.program_name} gentest on #{DateTime.now.strftime('%Y-%m-%d %H:%M')}.
      # If tests are failing here, it means that either 1) the gentest generated
      # code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
      # your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
      # and the tests generated from them.
      # So, if the tests are failing here (and assuming gentest isn't broken), fix your app, get the output you want,
      # make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
      # an achieve your success that way.  It's really that simple.


    HERE

    putz %{describe "#{describee.capitalize.gsub('-',' ')} (generated tests)" do}

    opts.run_with ||= "command"
    (test_cases).each_with_index do |test_case, idx|
      comment = test_case.comment || test_case.prompt
      should = %{#{comment} (#{letter}-#{idx})}.dump
      putz %{\n  it #{should} do}
      x = nil
      ge(%{Parse failure of prompt: Expecting #{cli.program_name} had #{x}}) unless
        (cli.program_name==(x=test_case.parsed_prompt.shift))
      putz %{    @app = #{construct}} if (0==idx  or opts.app_regen)
      case opts.run_with
      when "command"
        cmd = test_case.parsed_prompt.shift
        putz %{    x = @app.cli.commands["#{cmd}"].run(#{test_case.parsed_prompt.inspect})}
      when "cli"
        putz %{    x = @app.cli.run(#{test_case.parsed_prompt.inspect})}
      when "app"
        putz %{    x = @app.run(#{test_case.parsed_prompt.inspect})}
      else
        raise ArgumentError.new(%{Bad value for run_with -- "#{opts.run_with}"})
      end

      test_case.response_lines.pop while test_case.response_lines.last =~ /^ *$/
      if (test_case.captures['code'])
        putz test_case.captures['code'].lines.map{|x| %{  #{x}}} * "\n"
      elsif (test_case.response_lines.size <= 1)
        putz %{    y = #{test_case.response_lines.join.dump}}
        putz %{    x.to_s.chomp.should.equal y}
      else
        putz <<-HERE1.gsub(/^      /,'')
          y =<<-__HERE__.gsub(/^    /,'').chomp
          #{test_case.response_lines.join("\n          ")}
          __HERE__
        HERE1
        putz( (opts.chomp == false) ? %{    x.to_s.should.equal y} : %{    x.to_s.chomp.should.equal y} )
      end
      putz %{  end}
    end
    putz %{end}
    File.open(outfilename,'w'){|fh| fh.write @out.read }
    %{\nGenerated spec file:\n#{outfilename}\n}+
    %{Try running the generated test with:\n\n#{run_it_with_this}\n\n}
  end

  cli.does('rackful','play with one of the examples interactively with rack-like command processing') do
    optional('app_name')
  end
  def rackful app_name=nil
    require 'hipe-cli/rack-land'
    @quit_abbrevs = ['quit'].abbrev
    default_app_name = nil
    msg = catch(:finished) do
      begin
        catch(:prompt_again) do
          app_name ||= prompt_app_name(default_app_name)
          unless(app_thing = examples_list.detect{|x| x.short==app_name})
            puts "app #{app_name.inspect} not found";
            app_name = nil
            throw :prompt_again
          end
          app_name = nil
          app = app_thing.make_one
          puts "built new #{app_thing.short}."
          hash = nil
          annoying = true
          begin
            catch(:prompt_again) do
              hash = prompt_request
              annoying = false
            end
          end while annoying
          puts app.respond_to?(:run) ? app.run(hash).to_s : app.cli.run(hash).to_s
        end
      end while true
    end
    puts msg.to_s
  end
  def examples_list
    Dir[File.join(Hipe::Cli::DIR, 'examples/*.rb')].map{|x| ExampleApp.new(x) }.sort{|x,y| x.short <=> y.short}
  end
  def prompt_request
    if File.exist?("tmp.last_command")
      default = File.read("tmp.last_command")
      default_str = default ? %{ (#{default.slice(0,7)}...)} : ''
      unless Readline::HISTORY.to_a.include?(default)
        Readline::HISTORY.push(default)
      end
    else
      default_str = ''
      default = nil
    end
    prompt = "enter json request (hash)#{default_str}: "
    entered = Readline.readline(prompt,true).strip
    throw(:prompt_again) if '' == entered
    throw(:finished, "thanks, goodbye") if @quit_abbrevs[entered]
    File.open("tmp.last_command","w+"){|fh| fh.write(entered) }

    begin
      request = JSON.parse(entered)
    rescue JSON::ParserError => e
      puts e.message
      throw :prompt_again
    else
      request
    end
  end
  def prompt_app_name default
    examples_list = self.examples_list
    table = Hipe::Table.make do
      field(:name){|x| x.short}
      field(:description){|x| x.description}
      self.list = examples_list
    end
    puts table.render(:ascii)
    default_str = default ? " [#{default}]" : ""
    prompt = "choose app (type beginning of name)#{default_str}: "
    name = Readline.readline(prompt,true)
    name = default if name=="" && default
    throw(:finished, "thanks, goodbye.") if @quit_abbrevs[name]
    name
  end
  class ExampleApp
    attr_reader :path, :short, :description
    def initialize(path)
      @path = path
      @short, thing = File.basename(path).match(/^app-([^-]+)-?(.*)\.rb$/).captures
      @description = thing.gsub('-',' ')
    end
    def app_class_name; %{App#{short.capitalize}} end
    def make_one
      require @path
      klass = app_class_name.split('::').inject(Object){|a,v| a.const_get(v) }
      klass.new
    end
  end
end
