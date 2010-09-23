$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))  # for spec_helpers

require 'store/diskstore'
require 'fileutils'
require 'tempfile'
require 'find'

require 'spec_helpers'


describe Store::DiskStore do

  before do
    @disk_root = "/tmp/test-diskstore"
    FileUtils::mkdir @disk_root

    FileUtils::mkdir_p @disk_root + "/in"
    FileUtils::mkdir @disk_root + "/out"
    FileUtils::mkdir @disk_root + "/test"

    @diskstore     = Store::DiskStore.new @disk_root + "/test"
    @out_diskstore = Store::DiskStore.new @disk_root + "/out"
    @in_diskstore  = Store::DiskStore.new @disk_root + "/in"
  end
  
  after do
    Find.find(@disk_root) do |filename|
      File.chmod(0777, filename)
    end
  FileUtils::rm_rf @disk_root
  end
  
  it "should create a diskstore based on a directory" do
    lambda { Store::DiskStore.new @disk_root }.should_not raise_error
  end
  
  it "should not create a diskstore on anything but a directory" do
    t = Tempfile.new('testtmp')
    regular_file = t.path
    lambda { Store::DiskStore.new regular_file }.should raise_error(Store::ConfigurationError)
  end

  it "should not create a diskstore on an unwritable directory" do
    lambda { Store::DiskStore.new '/etc'}.should raise_error(Store::ConfigurationError)
  end

  it "should take a object name and some data to store an object" do
    name = "test object"
    data =  "some data"
    lambda { @diskstore.put name, data }.should_not raise_error
  end

  it "should find an existing object given an object name" do
    name = "test object"
    data = "some data"
    @diskstore.put name, data
    @diskstore.get(name).should == data
  end

  it "should return nil on a get of a non-existant object" do
    @diskstore.get("missing object").should be_nil
  end

  it "should store an object with slashes in the name" do
    name = "foo/bar/baz"
    data = "some data!"
    @diskstore.put name, data
    @diskstore.get(name).should == data
  end

  it "should store an object with dots in the name" do
    name = ".."
    data = "some data!"
    @diskstore.put name, data
    @diskstore.get(name).should == data
  end

  it "should not allow duplication of a name" do
    name = some_name
    data = some_data
    @diskstore.put name, data
    lambda {@diskstore.put(name, data)}.should raise_error(Store::DiskStoreResourceExists)
  end

  it "should have size for an object" do
    name = some_name
    data = some_data
    @diskstore.put name, data
    @diskstore.size(name).should_not be_nil
  end

  it "should generate an etag for an object" do
    name = some_name
    data = some_data
    @diskstore.put(name, data)
    @diskstore.etag(name).class.should == String
  end

  it "should raise DiskStoreError on requests for size for non-existant objects" do
    name = some_name
    lambda {@diskstore.size(name)}.should raise_error(Store::DiskStoreError)
  end

  it "should return size of zero, empty string, and specific md5 checksum on reading a zero length file" do
    name = some_name
    data = ""
    @diskstore.put name, data

    @diskstore.size(name).should == 0
    @diskstore.get(name).should == ""
    @diskstore.md5(name).should == "d41d8cd98f00b204e9800998ecf8427e"
  end

  it "should default type to 'application/octet-stream" do
    name = some_name
    @diskstore.put(name, some_data)
    @diskstore.type(name).should == 'application/octet-stream'
  end

  it "should allow us to set a type" do
    name = some_name
    @diskstore.put(name, some_data, 'x-application/tar')    
    @diskstore.type(name).should == 'x-application/tar'
  end

  it "should provide last_access time, a DateTime object" do
    name = some_name
    @diskstore.put(name, some_data)
    @diskstore.last_access(name).class.should == DateTime
    (@diskstore.last_access(name) - DateTime.now).should be_close(0, 0.0001)
  end

  it "should have date for an object" do
    name = "the name"
    data = "some data!"
    @diskstore.put name, data
    @diskstore.datetime(name).should_not be_nil    
  end

  it "datetime should raise an error if the object does not exist" do
    name = "bogus name"
    lambda{ @diskstore.datetime(name)}.should raise_error(Store::DiskStoreError)	
  end

  it "datetime should not raise error if the object does exist"	do
    name = "the name"
    data = "some data"
    @diskstore.put name, data
    lambda{ @diskstore.datetime(name)}.should_not raise_error(Store::DiskStoreError)				
  end

  it "datetime should return the time an object was created" do
    name = "the name"
    data = "some data!"
    @diskstore.put name, data
    t = @diskstore.datetime(name)
    (DateTime.now - t).should be_close(0, 0.0001)
  end
    
  it "should enumerate all of the names of the objects stored" do

    data  = "Now is the time for all good men to come to the aid of their country!\n"

    name1 = "George Washington!"
    name2 = "Franklin/Delano/Roosevelt"
    name3 = "Yo' Mama sez!"

    @diskstore.put name1, data
    @diskstore.put name2, data
    @diskstore.put name3, data

    bag = []

    @diskstore.each do |name|
      bag.push name
    end

    bag.should have(3).things  
    bag.should include(name1)
    bag.should include(name2)
    bag.should include(name3)
  end  			

  it "should not allow invalid characters in the name" do

    data  = "Now is the time for all good men to come to the aid of their country!\n"
    name  = "George Washington!?"

    lambda{ @diskstore.put(name, data)}.should raise_error(Store::DiskStoreBadName)
  end  			

  it "should allow grep of all the names in the collection" do

    data = "This Is A Test. It Is Only A TEST."

    @diskstore.put "this", data
    @diskstore.put "that", data
    @diskstore.put "that other one over there", data

    results = @diskstore.grep(/that/)

    results.should have(2).things
    results.should include("that")
    results.should include("that other one over there")

  end

  it "should accept a block for geting data out in chunks" do

    name = some_name

    data_in = ''
    (1..1000).each { data_in += some_data }  # currently we read in 4096 byte chunks, this should exceed that

    @diskstore.put(name, data_in)

    data_out = ''
    @diskstore.get(name) do |buff| 
      data_out = data_out + buff
    end

    data_in.should == data_out
  end

  it "should accept puting data from a file object" do

    input_data = some_data
    name = some_name

    tf = Tempfile.new("dang")
    tf.puts(input_data);
    tf.close

    file = File.open(tf.path)

    @diskstore.put(name, file)

    retrieved_data = @diskstore.get(name)
    retrieved_data.should == input_data

  end


  it "should get the md5 and sha1 checksums correct" do
    data = "This is a test.\n"
    md5  = "02bcabffffd16fe0fc250f08cad95e0c"
    sha1 = "0828324174b10cc867b7255a84a8155cf89e1b8b"
    name = some_name
    
    @diskstore.put(name, data)    
    @diskstore.md5(name).should  == md5
    @diskstore.sha1(name).should == sha1
  end
  
  it "should get the md5 checksum correct when reading from a data file handle" do
    data = "This is a test.\n"
    md5  = "02bcabffffd16fe0fc250f08cad95e0c"
    name = some_name
    
    tf = Tempfile.new("heck")
    tf.puts(data)
    tf.close
    
    @diskstore.put(name, File.open(tf.path))
    @diskstore.md5(name).should == md5
  end

  it "should delete an object given an object name" do
    name = "test object"
    data = "some data!"
    @diskstore.put name, data
    @diskstore.delete name
    @diskstore.get(name).should be_nil
  end

  it "should indicate saved storage exists" do
    name = some_name
    data = some_data

    @diskstore.exists?(name).should == false
    @diskstore.put(name, data)
    @diskstore.exists?(name).should == true
  end






end
