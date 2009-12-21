# bacon spec/spec_predicates.rb
require 'hipe-cli'
require 'hipe-core/test/helper'
require Hipe::Cli::DIR+'/examples/app-it3-predicates.rb'


# this is here ase a test simply so we remember how we came up w/ the predicates extension,
# and so we can play w/ it in the future.

module A
  @predicate_modules = []
  def self.register_predicates(mod)
    @predicate_modules.unshift mod   # we put them in the order they will be searched
  end
  def self.module_with_method(method_name)
   it  = @predicate_modules.detect{|x| x.instance_methods.include? method_name.to_s}
    if (it.nil?)
      raise Exception.new(%{Can't find "#{method_name}()" anywhere within }+@predicate_modules.map{|x| x.to_s}.join(', '))
    end
    it
  end
  def method_missing name, *args
   it  = A.module_with_method(name)
    self.extend it
    send(name,*args)
  end
end

class B
end

module C
  A.register_predicates(self)
  def foo_c(one,two,three);
    %{foo c three: "#{three}"};
  end
end

describe "Predicates" do
  it  "should work (it1)" do
    b = B.new
    b.extend A
    b.foo_c('uno','dos','tres').should.equal %{foo c three: "tres"}
  end
  it  "should fail (it2)" do
    b = B.new
    b.extend A
    e = lambda {
      b.foo_d('uno','dos','tres').should.equal %{foo c three: "tres"}
    }.should.raise(Exception)
    e.message.should.equal %{Can't find "foo_d()" anywhere within C}
  end
end

class AppPred1
  include Hipe::Cli
  cli.does(:laundry,%{the output of this might not make sense. it's just for tests}){
    required(:in_file){|it|
      it.must_exist!()
      it.gets_opened('r')
    }
    required(:out_file){|it|
      it.must_not_exist!()
      it.gets_opened('w+')
    }
  }
  def laundry(infile,outfile)
    s = %{input filename: #{infile.path}, output filename: #{outfile.path}\n}
    bytes = outfile.write(infile.read)
    s << %{wrote #{bytes} bytes to outfile.}
    infile.close
    outfile.close
    s
  end
end



describe "Specific Builtin Predicates" do
  it  "before all (pred0)" do
    @app = AppPred1.new
    @helper = Hipe::Test::Helper.singleton(Hipe::Cli)
    1.should == 1
  end

  def make_two_files
    @helper.clear_writable_tmp_dir!
    d = @helper.writable_tmp_dir
    @exists = File.join(d,'must-exist')
    File.open(@exists,'w+'){|fh| fh.write("blah\nand blah.")}
    @doesnt_exist = File.join(d,'not-exist')
  end
  def cleanup
    @helper.clear_writable_tmp_dir!
  end

  it  "should run filesystem predicates (pred1)" do
    make_two_files
    rs = @app.cli.commands['laundry'].run([@exists,@doesnt_exist])
    rs.should.match %r{input filename: .+must-exist, output filename: .+not-exist\nwrote 14 bytes to outfile.$}m
    cleanup
  end

  it  "fail file exist assertion(pred2)" do
    make_two_files
    rs = @app.cli.commands['laundry'].run([@doesnt_exist,@exists])
    rs.to_s.should.match %r{file not found.+not-exist}mi
    @helper.clear_writable_tmp_dir!
  end
end

class AppPred3
  include Hipe::Cli
  cli.does(:command_level_validation_failure)
  def command_level_validation_failure
    raise Hipe::Cli::ValidationFailure.f("your data is bad")
  end
end

class AppPred4;
  include Hipe::Cli
  cli.does('this') do
    option('--thiz') do |it|
      it.must_blah_blah()
    end
  end
  def this(opts); 'xyzzy' end
end


describe "predicates" do
  it "you can throw validation failures from your implementing method (of course!) (pred3)" do
    @app = AppPred3.new
    rs = @app.cli.run(['command_level_validation_failure'])
    rs.to_s.should == "your data is bad"
  end

  it "won't complain about bad predicates until it's much much much too late (pred4)" do
    e = lambda{  AppPred4.new.cli.commands['this'].run(['--thiz']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(%r{Can't find predicate "must_blah_blah\(\)" anywhere.*Hipe::Cli::BuiltinPredicates})
  end
end
