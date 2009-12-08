# bacon spec/predicate_spec.rb
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/animals'

describe "command validation" do
  app = AnimalSounds.new
  app.cli.out = Hipe::BufferString.new
  bad_idea = nil
  
  it "should display help with nothing entered (p1)" do
    app.cli << []
    app.cli >> (bad_idea='')
    arr = bad_idea.scan(/^ {#{app.cli.screen[:margin]}}[^ ]/m) # there should be at least two lines indented properly
    (arr.size >= 2).should == true
  end
  
  it "should display the same help streen with -h (p2)" do
    app.cli << ['-h']
    app.cli >> (str='')
    str.should == bad_idea
  end
  
  it "should display the same screen with --help (p3)" do
    app.cli << ['--help']
    app.cli >> (str='')
    str.should == bad_idea
  end
  
  it "should display help for a valid core command (not plugin command) (p4)" do
    app.cli << ['help','reproduce']
    app.cli >> (str='')
    matches = str.scan(/\n/) # it should have like 2 lines in it
    (matches.size >= 2).should == true
  end
  
  it "for asking for help that doesn't exist it should say that it is sorry (p5)" do
    app.cli << ['help','no']
    app.cli >> (str='')
    ( str.scan(/sorry/i).size >= 1 ).should == true
  end
  
  it "should display help for a valid core command (not plugin command) (p6)" do
    app.cli << ['help','reproduce']
    app.cli >> (str='')
    matches = str.scan(/\n/) # it should have like 2 lines in it
    (matches.size >= 2).should == true
  end
  
  it "should dipslay help for a child command (p7)" do
    app.cli << ['help','dog:bark']
    app.cli >> (str='')
    matches = str.scan(/this is the primary sound a dog makes/i)
    (matches.size >= 1).should == true
  end
  
  it "should be cool even if you ask for help on an invalid command for the child (p9)" do
    app.cli << ['help','dog:fark']
    app.cli >> (str='')
    (!! (/sorry.*fark/i =~ str) ).should.== true
  end
  
  it "should parse that ridiculous valid input (p10)" do
    app.cli << ['dog:bark', '-njoseph','-iblah:blah,blah:blah', '-a100',  
      'spec/test_data/tmp/out-file.txt', 'spec/test_data/dummy-file.txt', 'spec/test_data/dummy-file-2.txt']
    app.cli >> (str='')      
    str.should == "bow wow. outfile name: spec/test_data/tmp/out-file.txt in_files_size: 2  dog_name:joseph  dog_info:blahblah  dog_age:100.0 \n"
  end
  
  it "should fail four times (p11)" do
    app.cli << ["dog:bark", "-n%%%", "-iblah:blah:blah", "-aZ", "spec/test_data/tmp/out-file.txt", "blah", "spec/test_data/not-there"]
    app.cli >> (str='')
    str.should.match(/dog name must be alphanumeric/i  )
    str.should.match(/invalid jsonesque string/i       )
    str.should.match(/dog age must be a number/i       )
    str.should.match(/file does not exist/i            )
    str.should.match(/-h dog:bark.*more info/i )
  end
  
  it "should wine about files (p12)" do
    # animals dog:pant spec/test_data/out-file.txt spec/test_data/tmp/in-file.txt    
    app.cli << ["dog:pant", "spec/test_data/out-file.txt", "spec/test_data/tmp/in-file.txt", "3"]
    app.cli >> (s='')
    s.should.match(%r{spec/test_data/out-file.txt})
    s.should.match(%r{spec/test_data/tmp/in-file.txt})    
    s.should.match(%r{must be within the range|between|below|too high})
  end
end