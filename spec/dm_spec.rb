HOME = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path(File.join(HOME, 'lib')) # for spec_helpers

# TODO: remove DataModel:: and do an include, once through refactoring it out of StoreMaster
# Note: please set up databases as specified in db.yml in this directory.

require 'store-master/data-model'
require 'spec_helpers'

ENV['TZ'] = 'UTC'

IEID  = 'E20100921_AAAAAA'

def name n
  IEID + sprintf('.%03d', n)
end

def pool id
  "http://pool#{id}.foo.com/services/"
end

def postgres_setup
  # DataMapper::Logger.new(STDERR, :debug)
  DataModel.setup(File.join(HOME, 'db.yml'), 'store_master_postgres')
  DataModel.create_tables
end

def mysql_setup
  # DataMapper::Logger.new(STDERR, :debug)
  DataModel.setup(File.join(HOME, 'db.yml'), 'store_master_mysql')
  DataModel.create_tables
end

share_examples_for "DataMapper Package class with any DB, when it" do
  
  it "should let us a create a new package" do
    package  = DataModel::Package.create(:ieid => IEID, :name => name(1)) 
    package.saved?.should == true
  end

  it "should let us a retrieve a previously created package record by ieid" do
    package  = DataModel::Package.first(:ieid => IEID)
    package.name.should     == name(1)
  end

  it "should let us a retrieve a previously created package record by name" do
    package  = DataModel::Package.first(:name => name(1))
    package.name.should     == name(1)
  end


  it "should let not let us create a new package without a ieid" do

    package  = DataModel::Package.create(:name => name(2))
    package.saved?.should == false
  end

  it "should let us create a new package with the same ieid as an old package, with a new name" do

    package  = DataModel::Package.create(:name => name(2), :ieid => IEID)
    package.saved?.should == true
  end


  it "should let us create pools with differing read preferences, and order them " do

    pool1 = DataModel::Pool.add(pool('a'), 10)
    pool2 = DataModel::Pool.add(pool('b'))

    pool1.save.should == true
    pool2.save.should == true

    pool1.read_preference.should > pool2.read_preference
  end


  it "should not let us create pools with the same location" do

    pool1 = DataModel::Pool.add(pool('c'))
    pool1.save.should == true

    lambda { DataModel::Pool.add(pool('c')) }.should raise_error
  end


  it "should allow us to get a posting URL for a pool" do
    pending "This test now requires an active pool"
    pool = DataModel::Pool.add(pool('poster'))
    pool.post_url('name').class.should == URI::HTTP    
  end



  it "should let us retrieve an associated pool from a copy" do

    pool1 = DataModel::Pool.add(:services_location => pool('g'))
    pool2 = DataModel::Pool.add(:services_location => pool('h'))

    pool1.save.should == true
    pool2.save.should == true

    bar = 'http://bar.example.com/bar/100'
    foo = 'http://foo.example.com/foo/100'

    pkg1  = DataModel::Package.create(:ieid => IEID, :name => name(4))


    copy2time = DateTime.now - 100
    copy1 = DataModel::Copy.create(:store_location => foo, :pool => pool1)
    copy2 = DataModel::Copy.create(:store_location => bar, :pool => pool2, :datetime => copy2time)

    pkg1.copies << copy1
    pkg1.copies << copy2

    pkg1.save.should == true

    pkg2 = DataModel::Package.first(:name => name(4))

    [ pool1, pool2 ].should  include(pkg2.copies[0].pool)
    [ pool1, pool2 ].should  include(pkg2.copies[1].pool)
  end


  it "should let us mark a package as deleted" do

    pool = DataModel::Pool.add(:services_location => pool('i'))
    pkg  = DataModel::Package.create(:ieid => IEID, :name => name(101))
    copy = DataModel::Copy.create(:store_location => 'http://bar.example.com/bar', :pool => pool)
    pkg.copies << copy
    
    pkg.save.should == true

    pkg  = DataModel::Package.lookup(name(101))
    pkg.should_not == nil

    pkg.extant = false
    pkg.save.should == true

    pkg  = DataModel::Package.lookup(name(101))

    pkg.should == nil
  end


  it "should let us associate copies URL with a packge, setting the time or defaulting it, storing and retreiving it" do

    pool1 = DataModel::Pool.add(:services_location => pool('d'))
    pool2 = DataModel::Pool.add(:services_location => pool('e'))

    pool1.save.should == true
    pool2.save.should == true

    bar = 'http://bar.example.com/bar'
    foo = 'http://foo.example.com/foo'

    pkg1  = DataModel::Package.first(:name => name(1))

    copy2time = DateTime.now - 100
    copy1 = DataModel::Copy.create(:store_location => foo, :pool => pool1)
    copy2 = DataModel::Copy.create(:store_location => bar, :pool => pool2, :datetime => copy2time)

    pkg1.copies << copy1
    pkg1.copies << copy2

    pkg1.save.should == true

    pkg2 = DataModel::Package.first(:name => name(1))

    pkg2.copies.length.should == 2
    pkg2.copies.map { |elt| elt.store_location }.include?(foo).should == true
    pkg2.copies.map { |elt| elt.store_location }.include?(bar).should == true

    (DateTime.now - pkg2.copies[0].datetime).should  be_within(0.0001).of(0)   # default time
    (copy2time - pkg2.copies[1].datetime).should  be_within(0.0001).of(0)      # spec
  end


  it "should not let us create copies within the same pool for a given package" do

    pkg  = DataModel::Package.create(:ieid => IEID, :name => name(3)) 
    pool = DataModel::Pool.first(:services_location => pool('d'))

    baz  = 'http://bar.example.com/baz'
    quux = 'http://bar.example.com/quxx'

    copy1 = DataModel::Copy.create(:store_location => quux, :pool => pool)
    copy2 = DataModel::Copy.create(:store_location => baz,  :pool => pool)

    pkg.copies << copy1
    pkg.copies << copy2

    pkg.save.should == false
  end


  it "should provide a uri method for a copy record that includes basic authentication information from the pool" do
    pass = 'top secret'
    user = 'fischer'

    pool = DataModel::Pool.add(pool('e'))
    pool.basic_auth_password = pass
    pool.basic_auth_username = user

    copy = DataModel::Copy.create(:store_location => 'http://example.com/', :pool => pool)

    copy.url.to_s.should =~ /#{user}:#{URI.encode pass}@/
  end

  it "should allow us to create reserved names based on an IEID" do

    res1 = DataModel::Reservation.create(:ieid => IEID, :name => name(1))
    res1.saved?.should == true
    res1.name.should == name(1)

    res2 = DataModel::Reservation.create(:ieid => IEID, :name => name(2))
    res2.saved?.should == true
    res2.name.should == name(2)
  end

  it "should not allow us to reuse reserved names" do
    res = DataModel::Reservation.create(:ieid => IEID, :name => name(1))
    res.saved?.should == false
  end
end


describe "DataMapper Package class (using Postgress); " do
  before(:all) do
    postgres_setup
  end

  it_should_behave_like "DataMapper Package class with any DB, when it"
end 


describe "DataMapper Package class (using MySQL); " do
  before(:all) do
    mysql_setup
  end

  it_should_behave_like "DataMapper Package class with any DB, when it"
end 

