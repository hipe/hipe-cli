require 'orderedhash'
require 'json'
require 'hipe-cli'
require 'hipe-core/io/buffer-string'
require 'hipe-core/io/stack-like'
require 'hipe-core/struct/open-struct-common-extension'
require 'hipe-core/struct/open-struct-write-once-extension'
require 'hipe-core/lingual/en'

class HipeCliCli
  class GentestException < Hipe::Exception; end
  Hipe::Cli::Exception.graceful_list << GentestException
  include Hipe::Cli
  cli.does('-h','--help', 'help<<self')
  cli.out.class = Hipe::Io::GoldenHammer
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
    option('-l','--list',"choose from a list of files in the default folder.") do
      goto{ app_instance.list_gentest_screenshots(opt_values) }
    end
    option('-o','--out-file FILE', 'write to this file instead of the default location.') do |it|
      it.must_not_exist!
    end
    # option('-s','--[no-]sped-up', 'whether or not to use the shell hack to speed up rendering (default true)')
    # hidden options in the yaml file
    # chomp       whether or not to chomp the newline character after app output (default true)
    # direct      whether to call commands directly or thru the app   (default false)
    # app_regen   whether or not to create a new instance of the app each time (default false)
    # describe    describe YourApp, "<your text" do
    required('INPUT_FILE', 'the file of copy-pasted terminal stuff'){ |it|
      it.must_exist!.gets_opened('r')
    }
  end

  def gentest(infile, cmd_line_opts)
    Hipe::Io::StackLike[infile]
    cmd_line_opts.sped_up = true if cmd_line_opts.sped_up.nil?
    basename = File.basename(infile.path)
    raise ge(%{please rename #{basename} to match the pattern "*.screenshots"}) unless
      (md = basename.match(/^([^\.]+).screenshots$/))
    filename_inner = md[1]
    opts = parse_json_header(infile)
    opts.merge! cmd_line_opts
    if (opts.out_file)
      raise ge(%{sorrry expected output file #{opts.out_file.inspect} to be in pwd #{Dir.pwd.inspect}}) unless
        (md = Regexp.new('^'+Regexp.escape(Dir.pwd)+'/(.+)$').match(opts.out_file))  # @SEP
      outfile_short = md[1]
    else
      outfile_short =  File.join('spec',"spec_#{filename_inner}-genned.rb")
      opts.out_file = outfile_short # used to be an abs path
    end

    missing = nil
    raise ge(%{missing (#{missing * ', '}) in json header of #{infile.path}}) if
      (missing = [:klass, :prompt, :requires] - opts.keys).size > 0
    test_cases = parse_test_cases(infile, opts.prompt)
    shell_expansion(test_cases,opts)
    str = write_bacon_file( infile,   opts.out_file,   outfile_short,  test_cases,       opts.requires,
                         opts.klass,  opts.describe,   opts.letter,    filename_inner,   opts
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
      json_string = (lines.compact * ' ').gsub(/  */,' ')
      begin
        json_hash = JSON.parse(json_string)
      rescue JSON::ParserError => e
        raise ge <<-HERE.gsub(/^  /,'')
        Failed to parse the beginning of #{infh.fhname} as json:
        #{e.message}
        With Line:
        #{json_string.inspect}}
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

  def list_gentest_screenshots(opts)
    out = cli.out.new
    default_location = 'spec/gentest-screenshots'
    list = Dir[File.join(default_location,'/*')]
    out.puts "Pick a screenshot file to regen:\n\n"
    list.each_with_index do |filename, i|
      out.puts %{#{i}) #{filename}}
    end
    puts out.read
    print "\nchoose a number or enter anything else to quit: "
    thing = $stdin.gets.chop
    if /^\d+$/ =~ thing and list[thing.to_i]
      fh = File.open(list[thing.to_i], 'r')
      return gentest(fh,opts)
    else
      puts "thank you."
    end
    ''
  end

  # we really avoided using racc @todo
  def parse_test_cases(infile, prompt)
    @notice = $stdout
    new_struct = lambda {
      struct = Hipe::OpenStructWriteOnceExtension.new(:response_lines => [])
      struct.write_once! :prompt, :result_lines
      struct.response_lines = []
      struct
    }
    test_cases = []
    current_case = new_struct.call
    state = :start
    advance = lambda {
      test_cases << current_case
      current_case = new_struct.call
      @notice.print "     < < < "+Hipe::Lingual.en{sp(np('test case',pp('now'),test_cases.size))}.say+" > > > \n\n"
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
    comment_re = /^ *# ?(.+)/
    prompt_re = Regexp.new('^'+Regexp.escape(prompt)+'(.+)')
    blank_re = /^ *$/

    infile.each_line do |line|
      line.chomp!
      case line
      when blank_re then next
      when comment_re then
        case state
        when :start,:comment then
        when :prompt then raise ge(%{comments should not come between prompt and response})
        when :response then advance.call
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:comment, line)
      when prompt_re
        case state
        when :comment then
        when :response then advance
        when :prompt then raise ge(%{a prompt after a prompt?})
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:prompt, $1) # eew
      else
        case state
        when :comment then raise ge(%{comments should not come between prompt and response})
        when :response,:prompt then
        else raise gge(%{invalid state #{state.inspect}})
        end
        change_state.call(:response, line)
      end
    end
    case state
    when :response then advance.call
    else raise gge(%{bad end state for to end file in: #{state.inspect}})
    end
    test_cases
  end

  def putz x; @out.puts x end

  def write_bacon_file(infile,         outfilename,  outfile_short, test_cases,   requires,
                       app_class_name, describee,    letter,        filename_inner, opts
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
      # by #{cli.program_name} gentest.  If tests are failing here, it means that either 1) the gentest generated
      # code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
      # your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
      # and the tests generated from them.
      # So, if the tests are failing here (and assuming gentest isn't broken), fix your app, get the output you want,
      # make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
      # an achieve your success that way.  It's really that simple.


    HERE

    putz %{describe "#{describee.capitalize.gsub('-',' ')} (generated tests)" do}

    (test_cases).each_with_index do |test_case, idx|
      putz %{\n  it "#{test_case.comment||'should work'} (#{letter}-#{idx})" do}
      x = nil
      ge(%{Parse failure of prompt: Expecting #{cli.program_name} had #{x}}) unless
        (cli.program_name==(x=test_case.parsed_prompt.shift))
      putz %{    @app = #{app_class_name}.new } if (0==idx  or opts.app_regen)
      if opts.direct
        cmd = test_case.parsed_prompt.shift
        putz %{    x = @app.cli.commands["#{cmd}"].run(#{test_case.parsed_prompt.inspect})}
      else
        putz %{    x = @app.cli.run(#{test_case.parsed_prompt.inspect})}
      end
      putz <<-HERE1.gsub(/^  /,'')
      y =<<-__HERE__.gsub(/^      /,'').chomp
        #{test_case.response_lines.join("\n        ")}
      __HERE__
      HERE1
      putz( (opts.chomp == false) ? %{    x.to_s.should.equal y} : %{    x.to_s.chomp.should.equal y} )
      putz %{  end}
    end
    putz %{end}
    File.open(outfilename,'w'){|fh| fh.write @out.read }
    %{\nGenerated spec file:\n#{outfilename}\n}+
    %{Try running the generated test with:\n\n#{run_it_with_this}\n\n}
  end
end
