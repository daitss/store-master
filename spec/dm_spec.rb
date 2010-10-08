HOME = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path(File.join(HOME, 'lib')) # for spec_helpers

# Note: please set up databases as specified in db.yml in this directory.

require 'store/dm'
require 'spec_helpers'

ENV['TZ'] = 'UTC'

MD5  = 'd3b07384d113edec49eaa6238ad5ff00'
SHA  = 'f1d2d2f924e986ac86fdf7b36c94bcdf32beec15'
IEID = 'E20100921_AAAAAA'
NAME1 = IEID + '.000'
NAME2 = IEID + '.001'


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
    package  = DM::Package.create(:ieid => IEID, :name => NAME1, :md5 => MD5, :sha1 => SHA, :size => 10000)
    package.saved?.should == true
  end

  it "should let us a retrieve a previously created package record by ieid" do
    package  = DM::Package.first(:ieid => IEID)
    package.md5.should      == MD5
    package.sha1.should     == SHA
    package.size.should     == 10000
    package.name.should == NAME1
  end

  it "should let us a retrieve a previously created package record by name" do
    package  = DM::Package.first(:name => NAME1)
    package.md5.should      == MD5
    package.sha1.should     == SHA
    package.size.should     == 10000
    package.name.should == NAME1
  end

  it "should create new packages with a default time stamp of now" do

    package  = DM::Package.first(:name => NAME1)
    (DateTime.now - package.datetime).should  be_close(0, 0.0001)

    # (Time.now - package.datetime).should  < 1  # if using Time
  end

  it "should create new packages with a default type of application/x-tar" do
    package  = DM::Package.first(:name => NAME1)
    package.type.should == 'application/x-tar'
  end

  it "should let not let us create a new package without a ieid" do

    package  = DM::Package.create(:name => NAME2, :md5 => MD5, :sha1 => SHA, :size => 10000)
    package.saved?.should == false
  end

  it "should let not let us create a new package without an md5" do

    package  = DM::Package.create(:name => NAME2, :ieid => IEID, :sha1 => SHA, :size => 10000)
    package.saved?.should == false
  end

  it "should let not let us create a new package without a sha1" do

    package  = DM::Package.create(:name => NAME2, :ieid => IEID, :md5 => MD5, :size => 10000)
    package.saved?.should == false

  end

  it "should let not let us create a new package without a size" do

    package  = DM::Package.create(:name => NAME2, :ieid => IEID, :md5 => MD5, :sha1 => SHA)
    package.saved?.should == false
  end

  it "should let us create a new package with the same ieid as an old package, with a new name" do

    package  = DM::Package.create(:name => NAME2, :ieid => IEID, :md5 => MD5, :sha1 => SHA, :size => 10000)
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

  it "should let us create a pool and associate it with a pacakge, retreiving it and its defaults" do

    pool1 = DM::Pool.create(:location => "http://foo.com/pkg1")
  
    pkg1 = DM::Package.first(:name => NAME1)
    pkg1.pools.push pool1
    pkg1.save.should == true
                            
    # re-read via pools method on package

    pkg2 = DM::Package.first(:name => NAME1)
  
    pool2 = pkg2.pools[0]
    pool2.location.should == "http://foo.com/pkg1"
    pool2.preference.should  == 0
    pool2.required.should    == true

    # re-read via copies method on package

    pool3 = DM::Package.first(:name => NAME1)
    pool3.copies.length.should == 1
    pool3.copies.pools.length.should == 1
    (DateTime.now - pool3.copies[0].datetime).should be_close(0, 0.0001)
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

describe "DataMapper Package using MySQL" do
  before(:all) do
    mysql_setup
  end

  it_should_behave_like "DataMapper Package class using any database"
end 

describe "DataMapper Package using Postgress" do
  before(:all) do
    postgres_setup
  end

  it_should_behave_like "DataMapper Package class using any database"
end 

