$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store/dm'
require 'store/package'
require 'store/reservation'
require 'fileutils'

require 'spec_helpers'

def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end

@@vers = '000'
SAME_OLD_IEID   = 'E20100921_AAAAAA'

def name
  String.new(SAME_OLD_IEID + '.' + @@vers)
end

def new_name
  @@vers.succ!
  name
end

describe Store::Package do

  before(:all) do
    @disk_root = "/tmp/test-diskstore"
    FileUtils::mkdir @disk_root
    @diskstore = Store::DiskStore.new @disk_root
    datamapper_setup
  end

  after(:all) do
    Find.find(@disk_root) do |filename|
      File.chmod(0777, filename)
    end
    FileUtils::rm_rf @disk_root
  end

  it "should let us determine that a package doesn't exist" do
    Store::Package.exists?(name).should == false
  end
    
  it "should not let us retrieve an unsaved package" do
    pkg = Store::Package.lookup(name)
    pkg.nil? == true
  end

  it "should let us initialize a package from a disk store" do
    res = Store::Reservation.new(SAME_OLD_IEID)
    @diskstore.put(name, 'this is some test data', 'text/plain')
    lambda { Store::Package.new_from_diskstore(SAME_OLD_IEID, name, @diskstore) }.should_not raise_error
  end

  it "should let us determine that a recorded package exists" do
    Store::Package.exists?(name).should == true
  end

  it "should let us retrieve a saved package" do
    pkg = Store::Package.lookup(name)
    pkg.name.should == name
  end

  it "should let us delete a package" do
    Store::Package.delete(name)
    Store::Package.lookup(name).should == nil
  end

  it "should let us find out that a package was deleted" do
    Store::Package.was_deleted?(name).should == true
  end

  it "should provide a list the names of the stored packges" do
    list = []
    10.times do
      list.unshift new_name
      @diskstore.put(list[0], 'this is some test data', 'text/plain')
      Store::Package.new_from_diskstore(SAME_OLD_IEID, list[0], @diskstore)
    end
    list.sort!.should == Store::Package.names
  end

end
