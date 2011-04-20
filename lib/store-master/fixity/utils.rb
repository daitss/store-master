require 'fileutils'
require 'optparse'

module FixityUtils

  def FixityUtils.pluralize count, word, plural
    return word if count.to_s == '1' or count.to_s.downcase == 'one'
    return plural
  end

  Struct.new('FixityConfig', :syslog_facility, :server_name, :db_config_file, :db_store_master_key, :db_daitss_key, :pid_directory, :required_copies, :expiration_days)

  def FixityUtils.parse_options args

    conf = Struct::FixityConfig.new(nil, nil, '/opt/fda/etc/db.yml', nil, nil, nil, 2, 45)

    opts = OptionParser.new do |opts|
      opts.on("--syslog-facility FACILITY",  String, "The facility in syslog to log to (LOCAL0...LOCAL7), otherwise log to STDERR") do |facility|
        conf.syslog_facility = facility
      end
      opts.on("--server-address HOSTNAME[:PORT]",  String, "The address of the store-master web service - port defaults to 80") do |host_name|
        conf.server_name = host_name
      end
      opts.on("--db-config-file PATH", String, "A database yaml configuration file, defaults to #{conf.db_config_file}") do |path|
        conf.db_config_file = path
      end
      opts.on("--db-store-master-key KEY", String, "The key for the store master database in the database yaml configuration file")  do |key|
        conf.db_store_master_key = key
      end
      opts.on("--db-daitss-key KEY", String, "The key for the daitss database in the database yaml configuration file") do |key|
        conf.db_daitss_key = key
      end
      opts.on("--pid-directory PATH", String, "Optionally, a directory for storing this scripts PID for external moitoring agents, such as xymon") do |path|
        conf.pid_directory = path
      end
      opts.on("--required-copies NUM", Integer, "Optionally, the number of required pool copies we'll need (defaults to #{conf.required_copies})") do |num|
        conf.required_copies = num
      end
      opts.on("--expiration-days DAYS", Integer, "Optionally, the number of days after which a fixity is considered to have expired (defaults to #{conf.expiration_days})") do |days|
        conf.expiration_days = days
      end
    end
    opts.parse!(args)

    raise "Configuration yaml file #{conf.db_config_file} not found"                                     unless File.exists? conf.db_config_file
    raise "No store-master database key to the DB configuration file (#{conf.db_config_file}) provided"  unless conf.db_store_master_key
    raise "No daitss database key to the DB configuration file (#{conf.db_config_file}) provided"        unless conf.db_daitss_key
    raise "Configuration yaml file #{conf.db_config_file} not readable"                                  unless File.readable? conf.db_config_file

    # FIXME: this can be user, uucp, news, others on our system

    if conf.syslog_facility
      raise "Syslog facility should be of the form 'LOCAL0' .. 'LOCAL1'"            unless conf.syslog_facility =~ /^LOCAL[0-7]$/
    end

    if conf.pid_directory
      raise "The specified PID directory #{conf.pid_directory} doesn't exist"       unless File.exists? conf.pid_directory
      raise "The specified PID directory #{conf.pid_directory} isn't a directory"   unless File.directory? conf.pid_directory
      raise "The specified PID directory #{conf.pid_directory} isn't writable"      unless File.writable? conf.pid_directory
    end

  rescue => e
    STDERR.puts e, opts
    STDERR.puts e.backtrace.join("\n")
    return nil
  else
    return conf
  end

end # of module FixityUtils
