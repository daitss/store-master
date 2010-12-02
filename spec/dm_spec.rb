HOME = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path(File.join(HOME, 'lib')) # for spec_helpers

# Note: please set up databases as specified in db.yml in this directory.

require 'store/dm'
require 'spec_helpers'

ENV['TZ'] = 'UTC'

IEID  = 'E20100921_AAAAAA'

NAME1 = IEID + '.000'
NAME2 = IEID + '.001'
NAME3 = IEID + '.002'


def pool id
  "http://pool#{id}.foo.com/packages/"
end


def postgres_setup
  DM.setup(File.join(HOME, 'db.yml'), 'store_master_postgres')
  DM.recreate_tables
end

def mysql_setup
  DM.setup(File.join(HOME, 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end

share_examples_for "DataMapper Package class using any database" do
  
  it "should let us a create a new package" do
    package  = DM::Package.create(:ieid => IEID, :name => NAME1) 
    package.saved?.should == true
  end

  it "should let us a retrieve a previously created package record by ieid" do
    package  = DM::Package.first(:ieid => IEID)
    package.name.should     == NAME1
  end

  it "should let us a retrieve a previously created package record by name" do
    package  = DM::Package.first(:name => NAME1)
    package.name.should     == NAME1
  end


  it "should let not let us create a new package without a ieid" do

    package  = DM::Package.create(:name => NAME2)
    package.saved?.should == false
  end

  it "should let us create a new package with the same ieid as an old package, with a new name" do

    package  = DM::Package.create(:name => NAME2, :ieid => IEID)
    package.saved?.should == true
  end


  it "should let us create an event and associate it with a package, retreiving it" do
    
    pkg1  = DM::Package.first(:name => NAME1)
  
    ev1 = DM::Event.create(:type => :put, :note => 'This is a test')

    ev1.saved?.should == false  # not a requirement per se,

    pkg1.events << ev1
    pkg1.save.should == true

    pkg2 = DM::Package.first(:name => NAME1)
    ev1.saved?.should == true

    ev2 = pkg2.events[0]

    ev2.type.should    == :put
    ev2.note.should    == 'This is a test'
    ev2.outcome.should == true               # default value

    (DateTime.now - ev2.datetime).should be_close(0, 0.0001)
  end

  it "should let us create pools with differing read preferences, and order them " do

    pool1 = DM::Pool.create(:put_location => pool('a'), :read_preference => 10)
    pool2 = DM::Pool.create(:put_location => pool('b'))

    pool1.save.should == true
    pool2.save.should == true

    pool1.read_preference.should > pool2.read_preference
  end

  it "should not let us create pools with the same location" do

    pool1 = DM::Pool.create(:put_location => pool('c'), :read_preference => 10)
    pool2 = DM::Pool.create(:put_location => pool('c'))

    pool1.save.should == true
    pool2.save.should == false
  end

  it "should let us associate copies URL with a pacakge, setting the time or defaulting it, storing and retreiving it" do

    pool1 = DM::Pool.create(:put_location => pool('d'))
    pool2 = DM::Pool.create(:put_location => pool('e'))

    pool1.save.should == true
    pool2.save.should == true

    bar = 'http://bar.example.com/bar'
    foo = 'http://foo.example.com/foo'

    pkg1  = DM::Package.first(:name => NAME1)

    copy2time = DateTime.now - 100
    copy1 = DM::Copy.create(:store_location => foo, :pool => pool1)
    copy2 = DM::Copy.create(:store_location => bar, :pool => pool2, :datetime => copy2time)

    pkg1.copies << copy1
    pkg1.copies << copy2

    pkg1.save.should == true

    pkg2 = DM::Package.first(:name => NAME1)

    pkg2.copies.length.should == 2
    pkg2.copies.map { |elt| elt.store_location }.include?(foo).should == true
    pkg2.copies.map { |elt| elt.store_location }.include?(bar).should == true

    (DateTime.now - pkg2.copies[0].datetime).should be_close(0, 0.0001)   # default time
    (copy2time - pkg2.copies[1].datetime).should be_close(0, 0.0001)      # spec
  end

  it "should not let us create copies within the same pool for a given package" do

    pkg  = DM::Package.create(:ieid => IEID, :name => NAME3) 
    pool = DM::Pool.first(:put_location => pool('d'))

    baz  = 'http://bar.example.com/baz'
    quux = 'http://bar.example.com/quxx'

    copy1 = DM::Copy.create(:store_location => quux, :pool => pool)
    copy2 = DM::Copy.create(:store_location => baz,  :pool => pool)

    pkg.copies << copy1
    pkg.copies << copy2

    pkg.save.should == false
  end

  it "should allow us to create reserved names based on an IEID" do

    res1 = DM::Reservation.create(:ieid => IEID, :name => NAME1)
    res1.saved?.should == true
    res1.name.should == NAME1

    res2 = DM::Reservation.create(:ieid => IEID, :name => NAME2)
    res2.saved?.should == true
    res2.name.should == NAME2
  end

  it "should not allow us to reuse reserved names based on an IEID" do
    res = DM::Reservation.create(:ieid => IEID, :name => NAME1)
    res.saved?.should == false
  end
end


describe "DataMapper Package using Postgress" do
  before(:all) do
    postgres_setup
  end

  it_should_behave_like "DataMapper Package class using any database"
end 


describe "DataMapper Package using MySQL" do
  before(:all) do
    mysql_setup
  end

  it_should_behave_like "DataMapper Package class using any database"
end 

