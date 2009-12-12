# bacon spec/spec_webland.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require File.dirname(__FILE__)+'/helpers/shared_one.rb'

describe Hipe::Cli::App do
  it "should return a response to invalid request" do
    response = AppOne.new.cli.commands['bark'] << {:this => :that}
    response.valid?.should == false
    response.errors.should.respond_to('size')
    response.errors.each do |x|
      x.should.respond_to("message")
    end
  end
  
  it "should process a valid request" do
    req = {
      'the_volume' => 'loud',
      'mood' => 'somber',
      'target' => 'some guy',
      'req2' => 'blah2',
      'opt1' => 'opt 1',
      'splat' => 'wtf'
    }
    response = AppOne.new.cli.commands['bark'] << req
    response.valid?.should == true
    response[:target].should == 'some guy'
  end  
end
