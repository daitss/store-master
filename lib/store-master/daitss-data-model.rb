$LOAD_PATH.unshift '/opt/daitss2/service/core/lib'

require 'daitss'
require 'store-master/exceptions'

module Daitss
  def self.franco_framework  yaml_file, key
    oops = "DB setup can't"

    raise ConfigurationError, "#{oops} understand the configuration file name - it's not a filename string, it's a #{yaml_file.class}."  unless (yaml_file.class == String)
    raise ConfigurationError, "#{oops} understand key for the configuration file #{yaml_file} - it's not a string, it's a #{key.class}." unless (key.class == String)
    begin
      dict = YAML::load(File.open(yaml_file))
    rescue => e
      raise ConfigurationError, "#{oops} parse the configuration file #{yaml_file}: #{e.message}."
    end
    raise ConfigurationError, "#{oops} parse the data in the configuration file #{yaml_file}." if dict.class != Hash
    dbinfo = dict[key]
    raise ConfigurationError, "#{oops} get any data from the #{yaml_file} configuration file using the key #{key}."                                    unless dbinfo
    raise ConfigurationError, "#{oops} get the vendor name (e.g. 'mysql' or 'postsql') from the #{yaml_file} configuration file using the key #{key}." unless dbinfo.include? 'vendor'
    raise ConfigurationError, "#{oops} get the database name from the #{yaml_file} configuration file using the key #{key}."                           unless dbinfo.include? 'database'
    raise ConfigurationError, "#{oops} get the host name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'hostname'
    raise ConfigurationError, "#{oops} get the user name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'username'

    # Example string: 'mysql://root:topsecret@localhost/silos'

    connection_string =                                               # e.g.
      dbinfo['vendor']    + '://' +                                   # mysql://
      dbinfo['username']  +                                           # mysql://fischer
     (dbinfo['password']  ? ':' + dbinfo['password'] : '') + '@' +    # mysql://fischer:topsecret@  (or mysql://fischer@)
      dbinfo['hostname']  + '/' +                                     # mysql://fischer:topsecret@localhost/
      dbinfo['database']                                              # mysql://fischer:topsecret@localhost/store_master

    Archive.dont_configure!
    archive
    adapter = DataMapper.setup(:default, connection_string)
    adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
  end

  class Package
    # this is actually fast enough, unless we need to include datetime in the output.

    def self.package_copies before = DateTime.now
      sql =   "SELECT packages.id, copies.url, copies.md5, copies.sha1, copies.size " +
                "FROM packages, aips, copies " +
               "WHERE packages.id = aips.package_id " + 
                 "AND aips.id = copies.aip_id " + 
                 "AND copies.timestamp < '#{before}' " +   # need to fix db for this to work
            "ORDER BY packages.id"                         # packages.id is the package name, e.g. "E20001230_AAAAAA.000"

      if block_given?
        repository(:default).adapter.select(sql).each do |rec|
          yield rec
        end
      else
        return repository(:default).adapter.select(sql)
      end
    end
  end
  
end 
