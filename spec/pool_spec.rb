$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store/dm'
require 'store/pool'

require 'spec_helpers'

def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end


describe Store::Pool do

  before(:all) do
    datamapper_setup
  end

  it "should let us determine when a pool doesn't exist" do
    Store::Pool.exists?('http://first.example.com/packages/').should == false
  end

  it "should let us create a new pool server by put URL" do
    pool = Store::Pool.create 'http://first.example.com/packages/'
    pool.put_location.should == 'http://first.example.com/packages/'
  end

  it "should let us determine when a package does exist" do
    Store::Pool.exists?('http://first.example.com/packages/').should == true
  end

  it "should let us determine when a package doesn't exist" do
    Store::Pool.exists?('http://bogus.example.com/packages/').should == false
  end

  it "should have created new pool servers with sensible defaults" do
    pool = Store::Pool.lookup 'http://first.example.com/packages/'
    pool.required.should == true
    pool.read_preference.should == 0
  end

  it "should not allow us to create a new pool with an existing put_location" do
    lambda { Store::Pool.create 'http://first.example.com/packages/' }.should raise_error
  end

  it "should allow us to set new attributes" do
    pool = Store::Pool.lookup 'http://first.example.com/packages/'
    lambda { pool.required = false }.should_not raise_error
    lambda { pool.read_preference = 10 }.should_not raise_error
  end

  it "should allow us to retrieve the new attributes" do
    pool = Store::Pool.lookup 'http://first.example.com/packages/'
    pool.required.should == false
    pool.read_preference.should == 10
  end

  it "should retrieve an empty list when there are no active pools" do  # recall first.example.com is now not required
    pools = Store::Pool.list_active
    pools.should == []
  end

  it "should retrieve an list of active pools" do
    Store::Pool.create 'http://second.example.com/packages/'
    Store::Pool.create 'http://third.example.com/packages/'

    pools = Store::Pool.list_active

    pools.select { |p| p.put_location == 'http://first.example.com/packages/'  }.length.should == 0
    pools.select { |p| p.put_location == 'http://second.example.com/packages/' }.length.should == 1
    pools.select { |p| p.put_location == 'http://third.example.com/packages/'  }.length.should == 1
  end


  it "should order the list of active pools by preference" do
    p2 = Store::Pool.lookup 'http://second.example.com/packages/'
    p3 = Store::Pool.lookup 'http://third.example.com/packages/'
    p0 = Store::Pool.create 'http://zero.example.com/packages/'

    p2.read_preference = 2  # second.example.com
    p3.read_preference = 3  # third.example.com

    pools = Store::Pool.list_active  # the first shall be last, and the last shall be first

    pools.length.should == 3
    pools[0].put_location.should == 'http://third.example.com/packages/'
    pools[1].put_location.should == 'http://second.example.com/packages/'
    pools[2].put_location.should == 'http://zero.example.com/packages/'
  end


end
