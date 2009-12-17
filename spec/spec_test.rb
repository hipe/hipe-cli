# bacon spec/spec_test.rb
require File.expand_path('../bacon-helper', __FILE__)

describe "Hipe.shell!" do
  it "should work (t1)" do
    x = Hipe.shell!(%{--blah="blah" --blah-blah})
    y = ['--blah=blah', '--blah-blah']
    x.should.equal y
  end
end
