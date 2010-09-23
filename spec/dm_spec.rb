HOME = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path(File.join(HOME, 'lib')) # for spec_helpers

# Note: please set up databases as specified in db.yml in this directory.

require 'store/dm'
require 'spec_helpers'


MD5 = 'd3b07384d113edec49eaa6238ad5ff00'
SHA = 'f1d2d2f924e986ac86fdf7b36c94bcdf32beec15'

@@name = 'E20100921_AAAAAA'

def ieid
  @@name
end

def next_ieid
  @@name.succ!
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

    package  = DM::Package.create

    package.name      = ieid
    package.md5       = MD5
    package.sha1      = SHA
    package.size      = 10000

    package.save.should == true
  end

  it "should let us a retrieve a previously created package record by name" do

    package  = DM::Package.first(:name => ieid)

    package.md5.should      == MD5
    package.sha1.should     == SHA
    package.size.should     == 10000
  end

  it "should create new packages with a default time stamp of now" do

    package  = DM::Package.first(:name => ieid)
    (DateTime.now - package.datetime).should  be_close(0, 0.0001)
  end

  it "should create new packages with a default type of application/x-tar" do

    package  = DM::Package.first(:name => ieid)
    package.type.should == 'application/x-tar'
  end

  it "should let not let us create a new package with the same name as an old package" do

    package  = DM::Package.create

    package.name      = ieid
    package.md5       = MD5
    package.sha1      = SHA
    package.size      = 10000

    package.save.should == false
  end

  it "should let not let us create a new package without a name" do

    package  = DM::Package.create

    package.md5       = MD5
    package.sha1      = SHA
    package.size      = 10000

    package.save.should == false
  end

  it "should let not let us create a new package without an md5" do

    package  = DM::Package.create

    package.name      = ieid
    package.sha1      = SHA
    package.size      = 10000

    package.save.should == false
  end

  it "should let not let us create a new package without a sha1" do

    package  = DM::Package.create

    package.name      = ieid
    package.md5       = MD5
    package.size      = 10000

    package.save.should == false
  end

  it "should let not let us create a new package without a size" do

    package  = DM::Package.create

    package.name      = ieid
    package.md5       = MD5
    package.sha1      = SHA

    package.save.should == false
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
