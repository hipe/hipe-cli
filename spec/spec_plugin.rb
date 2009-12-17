# bacon spec/spec_plugin.rb
require File.expand_path('../bacon-helper', __FILE__)
require Hipe::Cli::DIR+'/examples/app-p1-plugins.rb'

describe AppP1, "plugins" do

  it "object graph (p1)" do
    @app4 = AppP4.new
    cli4 = @app4.cli
    lambda{ cli4.app_instance! }.should.not.raise
    cli3 = cli4.plugins[:app3].cli
    parent_cli = cli3.parent_cli
    parent_cli.equal?(cli4).should.equal true
    parent_cli.app_instance!.class.should.equal AppP4
    parent_cli.app_instance!.equal?(@app4).should.equal true

    cli3.command_prefix.should.equal "app3:"
    cli2 = cli3.plugins[:app2].cli
    cli2.command_prefix.should.equal "app3:app2:"
    cli1 = cli2.plugins[:app1].cli
    cli1.command_prefix.should.equal "app3:app2:app1:"

    cli1.app_instance!.cli.parent_cli.app_instance!.
      cli.parent_cli.app_instance!.cli.parent_cli.app_instance!.equal?(@app4).should.equal true
  end

  it "command should report a nice long name (p2)" do
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"

    @app4 = AppP4.new
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"
  end

  it "should have a good looking reflection (p3)" do
    @app3 = AppP3.new
    (@app3.cli.plugins.equal? @app3.cli.plugin).should.equal true
    @app3.cli.plugin[:app3].should.equal nil
    app2 = @app3.cli.plugin[:app2]
    app2.should.be.kind_of(AppP2)
    app2_2 = @app3.cli.plugin[:app2]
    (app2_2.equal? app2).should.equal true
  end

  it "should archipelagate (p4)" do
    str = @app4.cli.run(['app3:app2:app1:archipelago', '--o1', 'O1VAL', 'REQ1VAL'])
    str.should.equal 'archi: "REQ1VAL", "O1VAL"'
  end
end

module DontBecomePartOfName
  class AppP5
    include Hipe::Cli
  end
end
e = nil
begin
  class AppP6
    include Hipe::Cli
    cli.plugins << DontBecomePartOfName::AppP5
  end
rescue Exception => ee
  e = ee
end

describe AppP6 do
  it "should be able to plugin with the left shift operator and just with a class (p5)" do
    e.should.equal nil
    @app = AppP6.new
    @app.cli.plugins['app-p5'].cli.app_instance!.should.be.kind_of DontBecomePartOfName::AppP5
  end
  it "should fail on (p6)" do
    e = lambda { @app.cli.commands["not:there"] }.should.raise(Exception)
    e.message.should.match %r{unrecognized plugin "not". Known plugins are "app-p5"}i
  end
end
