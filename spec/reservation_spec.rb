$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store/dm'
require 'store/exceptions'
require 'store/reservation'
require 'spec_helpers'


def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end

BAD_IEID  = 'X-RAY'
GOOD_IEID = 'E20100101_FOOBAR'

describe Store::Reservation do

  before(:all) do
    datamapper_setup
  end

  it "should let us create a new name based on a good IEID" do
    res = Store::Reservation.new(GOOD_IEID)
    res.name.should =~ /^#{GOOD_IEID}/
  end

  it "should not let us create a new name based on a bad IEID" do
    lambda { res = Store::Reservation.new(BAD_IEID) }.should raise_error
  end

  it "should let us create a second new name based on a good IEID" do
    ieid = GOOD_IEID.succ
    res1 = Store::Reservation.new(ieid)
    res1.name.should =~ /^#{ieid}/
    res2 = Store::Reservation.new(ieid)
    res2.name.should =~ /^#{ieid}/

    res2.name.should_not == res1.name
  end

  it "should let us lookup an IEID based on a created name" do
    ieid = GOOD_IEID.succ.succ
    res  = Store::Reservation.new(ieid)
    res_ieid  = Store::Reservation.lookup_ieid(res.name)
    res_ieid.should == ieid
  end

  it "should return nil when a name has not been reserved" do
    ieid = Store::Reservation.lookup_ieid(GOOD_IEID + '.069')
    ieid.nil?.should == true
  end

  # too slow to really test
  # 
  # it "should fail with a DB error after 1000 names created for an IEID" do
  #   ieid = GOOD_IEID.succ.succ.succ
  #   1000.times {  Store::Reservation.new(ieid) }
  #   lambda { Store::Reservation.new(ieid) }.should_raise Store::DatabaseError
  # end

end 
    
