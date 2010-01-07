# bacon spec/spec_plugin.rb
require 'hipe-cli'
require Hipe::Cli::DIR+'/examples/app-p4-plugins.rb'

describe AppP4, "plugins" do

  it "object graph (plug1)" do
    @app4 = AppP4.new
    cli4 = @app4.cli
    lambda{ cli4.app_or_raise }.should.not.raise
    cli3 = cli4.plugins[:app3].cli
    parent = cli3.parent
    parent.equal?(cli4).should.equal true
    parent.app_or_raise.class.should.equal AppP4
    parent.app_or_raise.equal?(@app4).should.equal true

    cli3.command_prefix.should.equal "app3:"
    cli2 = cli3.plugins[:app2].cli
    cli2.command_prefix.should.equal "app3:app2:"
    cli1 = cli2.plugins[:app1].cli
    cli1.command_prefix.should.equal "app3:app2:app1:"

    cli1.app_or_raise.cli.parent.app_or_raise.
    cli.parent.app_or_raise.cli.parent.app_or_raise.equal?(@app4).should.equal true
  end

  it "command should report a nice long name (plug2)" do
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"

    @app4 = AppP4.new
    cmd = @app4.cli.commands['app3:app2:app1:archipelago']
    name = cmd.full_name
    name.should.equal "app3:app2:app1:archipelago"
  end

  it "should have a good looking reflection (plug3)" do
    @app3 = AppP3.new
    (@app3.cli.plugins.equal? @app3.cli.plugin).should.equal true
    @app3.cli.plugin[:app3].should.equal nil
    app2 = @app3.cli.plugin[:app2]
    app2.should.be.kind_of(AppP2)
    app2_2 = @app3.cli.plugin[:app2]
    (app2_2.equal? app2).should.equal true
  end

  it "should archipelagate (plug4)" do
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
  it "if you have a handle on your plugin class you can use the left shift operator (plug5)" do
    e.should.equal nil
    @app = AppP6.new
    @app.cli.plugins['app-p5'].cli.app_or_raise.should.be.kind_of DontBecomePartOfName::AppP5
  end
  it "should fail when you ask for an invalid plugin (plug6)" do
    e = lambda { @app.cli.commands["not:there"] }.should.raise(Exception)
    e.message.should.match %r{unrecognized plugin "not". Known plugins are "app-p5"}i
  end
  it "should load plugins from dir (plug7)" do
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
  it "should be able to plugin with just a plugin directory (plug8)" do
    @app = AppP8LazyLoading.new
    @app.cli.plugin['plugin-a'].should.be.kind_of(Hipe::Cli)
  end
  it "should fail on (plug9)" do
    @app = AppP8LazyLoading.new
    e = lambda { @app.cli.commands["not:there"] }.should.raise(Hipe::Cli::ValidationFailure)
    e.message.should.match %r{unrecognized plugin "not". Known plugins are "plugin-a"}i
  end
  it "should load plugins from dir (plug10)" do
    @app = AppP8LazyLoading.new
    @app.cli.plugins.size.should.equal 2
    @app.cli.plugin['plugin-a'].should.be.kind_of(Hipe::Cli)
  end
end
