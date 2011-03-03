require 'store-master/fixity/utils'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

describe FixityUtils do

  it "should properly parse an options command line" do

     args = 
     [ 
	 "--db-config-file",       "/dev/null",
         "--db-daitss-key",         "ps_daitss_2",
	 "--db-store-master-key",   "ps_store_master",
	 "--expiration-days",       "45",
	 "--pid-directory",         "/var/tmp",
	 "--required-copies",       "1",
	 "--server-name",           "betastore.tarchive.fcla.edu",
	 "--syslog-facility",       "LOCAL3"
     ]

     conf = FixityUtils.parse_options args

     conf.should_not be_nil

     conf.db_config_file.should ==       "/dev/null"
     conf.db_daitss_key.should ==         "ps_daitss_2"
     conf.db_store_master_key.should ==   "ps_store_master"
     conf.expiration_days.should ==       45
     conf.pid_directory.should ==         "/var/tmp"
     conf.required_copies.should ==       1
     conf.server_name.should ==           "betastore.tarchive.fcla.edu"
     conf.syslog_facility.should ==       "LOCAL3"
  end


  it "should properly pluralize" do

    FixityUtils.pluralize(0, 's', 'es').should == 'es'

    FixityUtils.pluralize(1, 's', 'es').should == 's'

    FixityUtils.pluralize(2, 's', 'es').should == 'es'
  end


end
