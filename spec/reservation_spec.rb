$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store-master/data-model'
require 'store-master/exceptions'
require 'spec_helpers'


def datamapper_setup
  DataModel.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DataModel.recreate_tables
end

BAD_IEID  = 'X-RAY'
GOOD_IEID = 'E20100101_FOOBAR'

include DataModel

describe Reservation do

  before(:all) do
    # DataMapper::Logger.new(STDERR, :debug)
    datamapper_setup
  end

  it "should let us create a new name based on a good IEID" do
    name = Reservation.make(GOOD_IEID)
    name.should =~ /^#{GOOD_IEID}/
  end

  it "should not let us create a new name based on a bad IEID" do
    lambda { Reservation.make(BAD_IEID) }.should raise_error
  end

  it "should let us create a second new name based on a good IEID" do
    ieid = GOOD_IEID.succ
    name = Reservation.make(ieid)
    name.should =~ /^#{ieid}/
    name2 = Reservation.make(ieid)
    name2.should =~ /^#{ieid}/

    name.should_not == name2
  end

  it "should let us lookup an IEID based on a created name" do
    ieid = GOOD_IEID.succ.succ
    name = Reservation.make(ieid)
    res_ieid  = Reservation.find_ieid(name)
    res_ieid.should == ieid
  end

  it "should return nil when a name has not been reserved" do
    ieid = Reservation.find_ieid(GOOD_IEID + '.069')
    ieid.nil?.should == true
  end

  # too slow to really test
  # 
  # it "should fail with a DB error after 1000 names created for an IEID" do
  #   ieid = GOOD_IEID.succ.succ.succ
  #   1000.times {  Reservation.make(ieid) }
  #   lambda { Reservation.make(ieid) }.should_raise StoreMaster::DatabaseError
  # end

end 
    
