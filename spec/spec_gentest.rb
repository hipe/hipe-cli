# bacon -n '.*' spec/spec_gentest.rb
require 'hipe-cli'
require 'hipe-cli/hipe-cli-cli'
require 'hipe-core/test/bacon-extensions'
require 'ruby-debug'

class Klz
  def self.singleton
    @sing ||= Klz.new
  end
  def initialize
    @folder = File.join(Hipe::Cli::DIR,'spec','gentest-screenshots')
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
    filething = Klz.singleton.filething 'gentest-one-line-json.screenshots'
    json = @a.parse_json_header(filething)
    json.table.keys.map{|x| x.to_s}.sort.should.equal [ "describe", "klass", "letter", "prompt", "requires"]
  end

  it "should parse good json multi line (gt2)" do
    filething = Klz.singleton.filething 'gentest-multi-line-json.screenshots'
    json = @a.parse_json_header(filething)
    json.table.keys.map{|x| x.to_s}.sort.should.equal ["describe", "klass", "letter", "module",
      "prompt", "relative_requires", "requires"]
  end

  it "should parse no json (gt3)" do
    @filething = Klz.singleton.filething 'gentest-no-json.screenshots'
    json = @a.parse_json_header(@filething)
    json.table.keys.map{|x| x.to_s}.sort.should.equal ["describe", "letter"]
  end

  it "should raise on no json (gt4)" do
    @a = HipeCliCli.new
    infile_path = Klz.singleton.filepath 'gentest-no-json.screenshots'
    rs = @a.cli.run(['gentest',infile_path])
    rs.valid?.should.equal false
    rs.to_s.should.match %r{missing \(klass, prompt, requires\) in json header}
  end

  it "should parse the test cases and write a file! (gt5)" do
    Hipe::Test::Helper[Hipe::Cli].clear_writable_tmp_dir!
    @a = HipeCliCli.new
    in_path = Klz.singleton.filepath 'gentest-multi-line-json.screenshots'
    out_path = File.join(Dir.pwd,'spec','writable-tmp','spec_my-genned-spec.rb')
    rs = @a.cli.run(['gentest','--out-file',out_path, in_path])
    notice_stream.puts rs.to_s unless rs.valid?
    rs.valid?.should.equal true
    rs.to_s.should.match %r{Generated spec file}i
    notice_stream << rs
    Hipe::Test::Helper[Hipe::Cli].clear_writable_tmp_dir!     # for now we don't test it,
    # and we have to remove it so rcov doesn't try to generate coverage for it after it
    # has been deleted by subsequent tests!
  end
end
