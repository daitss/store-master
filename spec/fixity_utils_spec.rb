require 'store-master/fixity/utils'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

class CommandLine
  # everything but --server-address
  @@options =  {
    "--db-config-file"        =>  "/dev/null",
    "--db-daitss-key"         =>  "ps_daitss_2",
    "--db-store-master-key"   =>  "ps_store_master",
    "--expiration-days"       =>  "45",
    "--pid-directory"         =>  "/var/tmp",
    "--required-copies"       =>  "1",
    "--syslog-facility"       =>  "LOCAL3"
  }

  def self.options
    @@options
  end

  def self.arguments
    @@options.to_a.flatten
  end

end


describe FixityUtils do

  it "should properly parse an options command line" do

    opts = CommandLine.options

    conf = FixityUtils.parse_options CommandLine.arguments + [ "--server-address", "betastore.tarchive.fcla.edu" ]

    conf.should_not be_nil

    conf.db_config_file.should      ==  opts['--db-config-file']
    conf.db_daitss_key.should       ==  opts['--db-daitss-key']
    conf.db_store_master_key.should ==  opts['--db-store-master-key']
    conf.pid_directory.should       ==  opts['--pid-directory']
    conf.syslog_facility.should     ==  opts['--syslog-facility']

    conf.expiration_days.should     ==  opts['--expiration-days'].to_i
    conf.required_copies.should     ==  opts['--required-copies'].to_i

    conf.server_address.should      ==  "betastore.tarchive.fcla.edu"
  end


  it "should edit the default port out of a server-address" do

    conf = FixityUtils.parse_options CommandLine.arguments + [ "--server-address", "betastore.tarchive.fcla.edu:80" ]

    conf.should_not be_nil

    conf.server_address.should      ==  "betastore.tarchive.fcla.edu"
  end


  it "should retain a non-default port out of a server-address" do

    conf = FixityUtils.parse_options CommandLine.arguments + [ "--server-address", "betastore.tarchive.fcla.edu:70" ]

    conf.should_not be_nil

    conf.server_address.should      ==  "betastore.tarchive.fcla.edu:70"
  end


  it "should properly pluralize" do

    FixityUtils.pluralize(0, 's', 'es').should == 'es'

    FixityUtils.pluralize(1, 's', 'es').should == 's'

    FixityUtils.pluralize(2, 's', 'es').should == 'es'
  end


end
