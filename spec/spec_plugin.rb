# bacon spec/spec_plugin.rb
require File.expand_path('../bacon-helper', __FILE__)
require Hipe::Cli::DIR+'/examples/app-p1-plugins.rb'

describe AppP1, "plugins" do

  skipit "object graph (p1)" do
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

  skipit "command should report a nice long name (p2)" do
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"

    @app4 = AppP4.new
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"
  end

  skipit "should have a good looking reflection (p3)" do
    @app3 = AppP3.new
    (@app3.cli.plugins.equal? @app3.cli.plugin).should.equal true
    @app3.cli.plugin[:app3].should.equal nil
    app2 = @app3.cli.plugin[:app2]
    app2.should.be.kind_of(AppP2)
    app2_2 = @app3.cli.plugin[:app2]
    (app2_2.equal? app2).should.equal true
  end

  skipit "should archipelagate (p4)" do
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

module Hipe::Cli::ModuleForTesting; end

class AppP7
  include Hipe::Cli
  cli.plugins.add_directory(File.join(Hipe::Cli::DIR,'spec',
    'read-only','a-plugins-directory'),Hipe::Cli::ModuleForTesting
  )
end

describe AppP6,' and AppP7' do
  skipit "if you have a handle on your plugin class you can use the left shift operator (p5)" do
    e.should.equal nil
    @app = AppP6.new
    @app.cli.plugins['app-p5'].cli.app_instance!.should.be.kind_of DontBecomePartOfName::AppP5
  end
  skipit "should fail when you ask for an invalid plugin (p6)" do
    e = lambda { @app.cli.commands["not:there"] }.should.raise(Exception)
    e.message.should.match %r{unrecognized plugin "not". Known plugins are "app-p5"}i
  end
  skipit "should load plugins from dir (p7)" do
    app = AppP7.new
    app.cli.plugins.size.should.equal 2
    app.cli.plugin['plugin-a'].should.be.kind_of(Hipe::Cli)
  end
end

class AppP8LazyLoading
  include Hipe::Cli
  dir = File.join(Hipe::Cli::DIR,'spec','read-only','a-plugins-directory')
  cli.plugins.add_directory(dir,Hipe::Cli::ModuleForTesting,:lazy=>true)
end

describe AppP8LazyLoading do
  it "should be able to plugin with just a plugin directory (p8)" do
    @app = AppP8LazyLoading.new
    @app.cli.plugin['plugin-a'].should.be.kind_of(Hipe::Cli)
  end
  it "should fail on (p9)" do
    e = lambda { @app.cli.commands["not:there"] }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match %r{unrecognized plugin "not". Known plugins are "plugin-a"}i
  end
  it "should load plugins from dir (p10)" do
    @app = AppP8LazyLoading.new
    @app.cli.plugins.size.should.equal 2
    @app.cli.plugin['plugin-a'].should.be.kind_of(Hipe::Cli)
  end
end
