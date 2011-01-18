$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store-master/dm'
require 'store-master/pool'
require 'spec_helpers'

def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end


describe StoreMaster::Pool do

  before(:all) do
    datamapper_setup
  end

  it "should let us determine when a pool doesn't exist" do
    StoreMaster::Pool.exists?('http://first.example.com/services/').should == false
  end

  it "should let us create a new pool server by put URL" do
    pool = StoreMaster::Pool.add 'http://first.example.com/services/'
    pool.services_location.should == 'http://first.example.com/services/'
  end

  it "should let us determine when a package does exist" do
    StoreMaster::Pool.exists?('http://first.example.com/services/').should == true
  end

  it "should let us determine when a package doesn't exist" do
    StoreMaster::Pool.exists?('http://bogus.example.com/services/').should == false
  end

  it "should have created new pool servers with sensible defaults" do
    pool = StoreMaster::Pool.lookup 'http://first.example.com/services/'
    pool.required.should == true
    pool.read_preference.should == 0
  end

  it "should not allow us to create a new pool with an existing put_location" do
    lambda { StoreMaster::Pool.add 'http://first.example.com/services/' }.should raise_error
  end

  it "should allow us to set new attributes" do
    pool = StoreMaster::Pool.lookup 'http://first.example.com/services/'
    lambda { pool.required = false }.should_not raise_error
    lambda { pool.read_preference = 10 }.should_not raise_error
  end

  it "should allow us to retrieve the new attributes" do
    pool = StoreMaster::Pool.lookup 'http://first.example.com/services/'
    pool.required.should == false
    pool.read_preference.should == 10
  end

  it "should retrieve an empty list when there are no active pools" do  # recall first.example.com is now not required
    pools = StoreMaster::Pool.list_active
    pools.should == []
  end

  it "should retrieve an list of active pools" do
    StoreMaster::Pool.add 'http://second.example.com/services/'
    StoreMaster::Pool.add 'http://third.example.com/services/'

    pools = StoreMaster::Pool.list_active

    pools.select { |p| p.services_location == 'http://first.example.com/services/'  }.length.should == 0
    pools.select { |p| p.services_location == 'http://second.example.com/services/' }.length.should == 1
    pools.select { |p| p.services_location == 'http://third.example.com/services/'  }.length.should == 1
  end


  it "should order the list of active pools by preference" do
    p2 = StoreMaster::Pool.lookup 'http://second.example.com/services/'
    p3 = StoreMaster::Pool.lookup 'http://third.example.com/services/'
    p0 = StoreMaster::Pool.add 'http://zero.example.com/services/'

    p2.read_preference = 2  # second.example.com
    p3.read_preference = 3  # third.example.com

    pools = StoreMaster::Pool.list_active  # the first shall be last, and the last shall be first

    pools.length.should == 3
    pools[0].services_location.should == 'http://third.example.com/services/'    # 3
    pools[1].services_location.should == 'http://second.example.com/services/'   # 2
    pools[2].services_location.should == 'http://zero.example.com/services/'     # 0
  end


end
