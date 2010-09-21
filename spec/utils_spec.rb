require 'store/utils'
require 'fileutils'
require 'tempfile'
require 'find'

describe StoreUtils do

  def new_yaml text
    f = Tempfile.new("mysgl_test_config")
    f.puts text + "\n"
    f.close
    f.path
  end

  it "should get mysql configuration information from a yaml file" do
    name = new_yaml("test: { hostname: localhost,  database: db, username: me, password: }")
    mydata = StoreUtils.mysql_config 'test', name
    mydata.password.should == nil
    mydata.hostname.should == 'localhost'
    mydata.username.should == 'me'
    mydata.database.should == 'db'
  end

  it "should get nil if configuration information from a yaml file is not available." do
    name = new_yaml("test: { hostname: localhost,  database: db, username: me, password: topsecret }")
    mydata = StoreUtils.mysql_config 'foo', name
    mydata.should == nil
  end

  it "should get nil if the yaml configuration file does not exist." do
    mydata = StoreUtils.mysql_config 'foo', "/some/random/file"
    mydata.should == nil
  end

  it "should show some free space in bytes" do
    StoreUtils.disk_free("/").should > 1024
  end

  it "should show the number of bytes available on a partition" do
    StoreUtils.disk_size("/").should > 1024
  end

  it "should detect a filesystem id" do
    StoreUtils.disk_id("/").should_not == nil
  end
  
  it "should return / as the mount point for /etc" do
    StoreUtils.disk_mount_point("/etc").should == "/"
  end

  it "should return /dev/ as the mount point for /dev" do
    StoreUtils.disk_mount_point("/dev").should == "/dev"
  end

  it "should return / as the mount point for /etc/passwd" do
    StoreUtils.disk_mount_point("/etc/passwd").should == "/"
  end

  it "should recognize valid IEID names" do
    StoreUtils.valid_ieid_name?("E20070101_AAAAAA").should == true
  end

  it "should recognize invalid IEID names" do
    StoreUtils.valid_ieid_name?("Yo' Mamma").should == false
  end
  
  it "should generate the correct base64 encoding of a hexstring" do
    StoreUtils.md5hex_to_base64("d41d8cd98f00b204e9800998ecf8427e").should == "1B2M2Y8AsgTpgAmY7PhCfg=="
  end
  
  it "should retrieve the original hexstring, after a base64 encoding of a hexstring" do
    StoreUtils.base64_to_md5hex("1B2M2Y8AsgTpgAmY7PhCfg==").should == "d41d8cd98f00b204e9800998ecf8427e"
  end

  it "should allow us to retrieve correctly specified command line arguments, defaulting the db_configuration_file" do
    argv = [ "--hostname", "example.com", "--silo-path", "/tmp", "--db-configuration-key", "foobar", "--syslog-facility", "LOCAL0"]
    conf = StoreUtils.get_silo_options(argv)

    conf.should_not == nil

    conf.hostname.should              == 'example.com'
    conf.db_configuration_file.should == '/opt/fda/etc/db.yml'
    conf.db_configuration_key.should  == 'foobar'
    conf.syslog_facility.should       == 'LOCAL0'
    conf.silo_path.should             == '/tmp'
  end

  it "should strip trailing slashes, leaving trailing non-slashes, and single slashes, alone" do
    StoreUtils.strip_trailing_slash_maybe('/this/is/a/test/').should == '/this/is/a/test'
    StoreUtils.strip_trailing_slash_maybe('/this/is/a/test////').should == '/this/is/a/test'
    StoreUtils.strip_trailing_slash_maybe('/this/is/a/test').should  == '/this/is/a/test'
    StoreUtils.strip_trailing_slash_maybe('/').should  == '/'
  end

  it "should provide a hashed path based on a name, suitable for a silo storage directory" do
    StoreUtils.hashpath('E20010101_AAAAAA').should == 'bdc/fbeae5d04dea3e7491f3611ea15f9'
  end

  it "should provide the first part of a hashed path based on a name, suitable for a silo storage directory" do
    StoreUtils.hashpath_parent('E20010101_AAAAAA').should == 'bdc'
  end

  it "should provide the user name of a file" do
    StoreUtils.user("/etc/passwd").should == 'root'
  end

  it "should provide the group name of a file" do

    StoreUtils.group("/etc/passwd").should == case RUBY_PLATFORM
                                              when /linux/   ; 'root'
                                              when /darwin/  ; 'wheel'
                                              else ; raise "Unhandled platform #{RUBY_PLATFORM}"
                                              end

                                                
  end

  it "should provide the user name of the current process" do
    StoreUtils.user.should == `whoami`.chomp
  end

  it "should provide the group name of the current process" do
    `groups`.split(/\s+/).include?(StoreUtils.group).should == true
  end


  it "should provide a utlity that commifies numbers" do
    StoreUtils.commify(1000000).should   == '1,000,000'
    StoreUtils.commify('1000000').should == '1,000,000'
    StoreUtils.commify(100000).should    == '100,000'
    StoreUtils.commify('100000').should  == '100,000'    
  end


end
