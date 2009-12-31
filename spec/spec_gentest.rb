# bacon -n '.*' spec/spec_gentest.rb
require 'hipe-cli'
require 'hipe-cli/hipe-cli-cli'
require 'hipe-core/test/bacon-extensions'
require 'ruby-debug'

class Paths
  def self.singleton
    @sing ||= Paths.new
  end
  def initialize
    @folder = File.join(Hipe::Cli::DIR,'spec','test-gentest-screenshots')
  end
  def filepath(fn)
    File.join(@folder,fn)
  end
  def filething(fn)
    path = filepath(fn)
    fh = File.open(path,'r')
    Hipe::Io::StackLike[fh]
    fh
  end
end

describe "hipe-cli cli GENTEST" do

  it "should parse good jason one line (gt1)" do
    @a = HipeCliCli.new
    filething = Paths.singleton.filething 'gentest-one-line-json.screenshots'
    json = @a.parse_json_header(filething)
    json._table.keys.map{|x| x.to_s}.sort.should.equal ["construct", "describe", "letter", "prompt", "requires"]
  end

  it "should parse good json multi line (gt2)" do
    filething = Paths.singleton.filething 'gentest-multi-line-json.screenshots'
    json = @a.parse_json_header(filething)
    json._table.keys.map{|x| x.to_s}.sort.should.equal ["construct", "describe", "letter", "module", "prompt", "relative_requires", "requires"]
  end

  it "should parse no json (gt3)" do
    @filething = Paths.singleton.filething 'gentest-no-json.screenshots'
    json = @a.parse_json_header(@filething)
    json._table.keys.map{|x| x.to_s}.sort.should.equal ["describe", "letter"]
  end

  it "should raise on no json (gt4)" do
    @a = HipeCliCli.new
    infile_path = Paths.singleton.filepath 'gentest-no-json.screenshots'
    rs = @a.cli.run(['gentest',infile_path])
    rs.valid?.should.equal false
    rs.to_s.should.match %r{missing \(construct, prompt, requires\) in json header}
  end

  it "should parse the test cases and write a file! (gt5)" do
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!
    @a = HipeCliCli.new
    @a.notice = Hipe::Io::BufferString.new
    in_path = Paths.singleton.filepath 'gentest-multi-line-json.screenshots'
    out_path = File.join(Dir.pwd,'spec','writable-tmp','spec_my-genned-spec.rb')
    rs = @a.cli.run(['gentest','--out-file',out_path, in_path])
    #notice_stream.puts rs.to_s unless rs.valid?
    rs.valid?.should.equal true
    rs.to_s.should.match %r{Generated spec file}i
    #notice_stream << rs
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!     # for now we don't test it,
    # and we have to remove it so rcov doesn't try to generate coverage for it after it
    # has been deleted by subsequent tests!
  end

  it "should write test file when input has blanks (gt6)" do
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!
    @a = HipeCliCli.new
    @a.notice = Hipe::Io::BufferString.new
    in_path = Paths.singleton.filepath 'gentest-multi-line-w-blanks.screenshots'
    out_path = File.join(Dir.pwd,'spec','writable-tmp','spec_my-genned-multiline-spec.rb')
    rs = @a.cli.run(['gentest','--out-file',out_path, in_path])
    #notice_stream.puts rs.to_s unless rs.valid?
    rs.valid?.should.equal true
    rs.to_s.should.match %r{Generated spec file}i
    #notice_stream << rs
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!
  end

  # this test works but it won't respect other command line opts so we can't control the output folder
  #it "should write test with -l NUM option (gt7)" do
  #  @a = HipeCliCli.new
  #  out_path = File.join(Dir.pwd,'spec','writable-tmp','eraseme.rb')
  #  rs = @a.cli.run(['gentest','--out-file',out_path,'-l0'])
  #  rs.to_s.should_match %r{Generated spec file:\nspec/spec_a1-genned}
  #  debugger
  #  'x'
  #end

  it "should work when there is no comment header (gt8)" do
    @a = HipeCliCli.new
    @a.notice = Hipe::Io::BufferString.new
    in_path = Paths.singleton.filepath 'gentest-no-comment.screenshots'
    out_path = File.join(Dir.pwd,'spec','writable-tmp','spec_no-comment.rb')
    rs = @a.cli.run(['gentest','--out-file',out_path, in_path])
    #notice_stream.puts rs.to_s unless rs.valid?
    rs.valid?.should.equal true
    rs.to_s.should.match %r{Generated spec file}i
    #notice_stream << rs
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!
  end

  it "should handle literal code block directives (gt9)" do
    @a = HipeCliCli.new
    @a.notice = Hipe::Io::BufferString.new
    in_path = Paths.singleton.filepath 'directives.screenshots'
    out_path = File.join(Dir.pwd,'spec','writable-tmp','directives.rb')
    rs = @a.cli.run(['gentest','--out-file',out_path, in_path])
    #notice_stream.puts rs.to_s unless rs.valid?
    #rs.valid?.should.equal true
    rs.to_s.should.match %r{Generated spec file}i
    #notice_stream << rs
    Hipe::Test::Helper[Hipe::Cli].clear_writable_temporary_directory!
  end
end
