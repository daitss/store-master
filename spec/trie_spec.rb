$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'datyl/trie'

describe Trie do

  it "should create a trie object" do
    lambda { trie = Trie.new }.should_not raise_error
  end
  
  it "should allow us to store a string and determine it is a key" do

    trie = Trie.new

    trie["A Test"] = 'stuff'
    trie["A Test"].should == 'stuff'

    trie["A Tester"].should == nil

    trie.keys.include?("A Test").should == true
    trie.keys.length.should == 1
  end

  it "should not suppose a substring or superstring is a key" do
    trie = Trie.new

    trie["A Test"] =  :stuff

    trie["A Tes"].should    == nil
    trie["A Test"].should   == :stuff
    trie["A Tester"].should == nil
    trie.keys.length.should == 1
  end

  it "should determine the longest common prefix in all the stored keys" do

    trie = Trie.new

    trie["A Test"]   = :stuff
    trie["A Tes"]    = :stiff
    trie["A Tester"] = :staff

    trie.prefix.should == "A Tes"

    trie["A"]  = :stoff

    trie.prefix.should == "A"
  end

  it "should provide the last value stored for a repeated key" do

    trie = Trie.new
  
    trie['001']  =  :a
    trie['002']  =  :b
    trie['002']  =  :c  # double up
    trie['003']  =  :d
  
    trie['001'].should == :a
    trie['002'].should == :c
    trie['003'].should == :d

  end

  it "should provide a list of keys, sorted" do

    trie = Trie.new
  
    trie['003']  =  :c
    trie['001']  =  :a
    trie['004']  =  :d
    trie['002']  =  :b
  
    trie.keys.should == ['001', '002', '003', '004']
  end

  it "should provide a list of values, presented in the order that the corresponding keys are." do

    trie = Trie.new
  
    trie['003']  =  :the
    trie['004']  =  :other
    trie['001']  =  :this
    trie['002']  =  :that
    trie['005']  =  :thing
  
    trie.keys.should   == ['001', '002', '003', '004',  '005']
    trie.values.should == [:this, :that, :the,  :other, :thing]

  end


  it "should provide the unique suffixes of all the stored keys" do

    trie = Trie.new
  
    trie['silos.darchive.fcla.edu:/daitssfs/001']  =  :a
    trie['silos.darchive.fcla.edu:/daitssfs/002']  =  :b
    trie['silos.darchive.fcla.edu:/daitssfs/002']  =  :c  # double up
    trie['silos.darchive.fcla.edu:/daitssfs/004']  =  :d
    trie['silos.darchive.fcla.edu:/daitssfs/010']  =  :e
    trie['silos.darchive.fcla.edu:/daitssfs/015']  =  :f
    trie['silos.darchive.fcla.edu:/daitssfs/027']  =  :g
 
    trie.prefix.should == 'silos.darchive.fcla.edu:/daitssfs/0'
 
    trie.twigs.should  ==  [ '01', '02', '04', '10', '15', '27' ]
  end


  it "should properly update a record to nil" do

    trie = Trie.new
  
    trie['some key'] = 'some value'
    trie['some key'].should  == 'some value'

    trie['some key'] = nil
    trie['some key'].should  == nil

  end


  it "should retrieve a key in the keys list, when the value has been entered as nil" do
    trie = Trie.new

    trie['a'] = true
    trie['b'] = false
    trie['c'] = nil

    trie.keys.include?('a').should == true
    trie.keys.include?('b').should == true
    trie.keys.include?('c').should == true

  end
end
