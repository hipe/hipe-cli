# bacon -n '.*' spec/spec_annoying-default-bug.rb
require 'hipe-cli'
require 'ruby-debug'
require 'bacon'


class Annoying
  include Hipe::Cli
  cli.option('-a ARG',:default=>'default-value-a')
  cli.does('go') do
    option('-b ARG',:default=>'default-value-b')
  end
  def go(opts)
    opts
  end
end


describe "Annoying Default Bug" do
   it "we are using the same app object each time here (adb--100)" do
     1.should.equal 1
     @app = Annoying.new
   end

   it "should parse-out defaults raw the first time (adb--1)" do
     argv = ['go']
     univ = @app.cli.universal_option_values(argv)
     {:a=>"default-value-a"}.should.equal univ.to_hash
   end

   it "should parse-out defaults raw the second time (adb-0)" do
    argv = ['go']
    univ = @app.cli.universal_option_values(argv)
    {:a=>"default-value-a"}.should.equal univ.to_hash
   end

   it "should parse-out defaults the first time (adb-1)" do
     argv = ['go']
     opts = @app.cli.run(argv)
     {:a=>"default-value-a", :b=>"default-value-b"}.should.equal opts.to_hash
   end

   it "should parse-out defaults the second time (adb-2)" do
     argv = ['go']
     opts = @app.cli.run(argv)
     {:a=>"default-value-a", :b=>"default-value-b"}.should.equal opts.to_hash
   end
end
