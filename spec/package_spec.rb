$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store/dm'
require 'store/package'
require 'store/pool'
require 'store/reservation'
require 'fileutils'

require 'spec_helpers'

def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end

@@tempfile = nil
@@vers = '000'
IEID   = 'E20100921_AAAAAA'

def name
  String.new(IEID + '.' + @@vers)
end

def new_name
  @@vers.succ!
  name
end



#### TODO: let datamapper folks know that URL validation doesn't accept dotted quads or localhost.

describe Store::Package do

  before(:all) do
    datamapper_setup
    Store::Pool.create('http://storage.local/b/data/')
  end

  it "should let us determine that a package doesn't exist" do
    Store::Package.exists?(name).should == false
  end
    
  it "should not let us retrieve an unsaved package" do
    pkg = Store::Package.lookup(name)
    pkg.nil? == true
  end

  it "should let us create a package" do

    nm = Store::Reservation.new(IEID).name
    nm = Store::Reservation.new(IEID).name

    io = File.open('/etc/passwd')
    metadata = { :name => nm, :ieid => IEID, :type => 'application/x-tar', :size => '3667', :md5 => '4732518c5fe6dbeb8429cdda11d65c3d' }
    pkg = Store::Package.create(io, metadata, Store::Pool.list_active)

    pkg.name.should == nm
  end

  it "should let us determine that a recorded package exists" do
    Store::Package.exists?(name).should == true
  end

  it "should let us retrieve a saved package" do
    pkg = Store::Package.lookup(name)
    pkg.name.should == name
  end


  it "should let us get the locations to which it was stored" do

  end


  it "should let us delete a package" do
    Store::Package.delete(name)
    Store::Package.lookup(name).should == nil
  end
  
  it "should let us find out that a package was deleted" do
    Store::Package.was_deleted?(name).should == true
  end

  # it "should provide a list the names of the stored packges" do
  #   list = []
  #   10.times do
  #     list.unshift new_name
  #     @diskstore.put(list[0], 'this is some test data', 'text/plain')
  #     Store::Package.new_from_diskstore(SAME_OLD_IEID, list[0], @diskstore)
  #   end
  #   list.sort!.should == Store::Package.names
  # end
 
end
