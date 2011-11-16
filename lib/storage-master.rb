require 'builder'
require 'ostruct'
require 'datyl/logger'
require 'storage-master/model'       # brings in storage-master specific data models
require 'storage-master/disk-store'
require 'storage-master/fixity'
require 'storage-master/exceptions'  # brings in http-exceptions
require 'storage-master/utils'
require 'time'
require 'daitss/model'


class DateTime
  # Get a properly formatted UTC string from a DateTime object. 

  def to_utc
    new_offset(0).to_s.sub(/\+00:00$/, 'Z')
  end
end


# When we deploy with Capistrano it checks out the code using Git
# into its own branch, and places the git revision hash into the
# 'REVISION' file.  Here we search for that file, and if found, return
# its contents.

def get_capistrano_git_revision
  revision_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'REVISION'))
  File.exists?(revision_file) ? File.readlines(revision_file)[0].chomp : 'Unknown'
end

# When we deploy with Capistrano, it places a newly checked out
# version of the code into a directory created under ../releases/,
# with names such as 20100516175736.  Now this is a nice thing, since
# these directories are backed up in the normal course of events: we'd
# like to include this release number in our service version
# information so we can easily locate the specific version of the
# code, if need be, in the future.
#
# Note that this release information is more specific than a git
# release; it includes configuration information that may not be
# checked in.

def get_capistrano_release
  full_path = File.expand_path(File.join(File.dirname(__FILE__)))
  (full_path =~ %r{/releases/((\d+){14})/}) ? $1 : "Not Available"
end

module StorageMaster

  REVISION = get_capistrano_git_revision()
  RELEASE  = get_capistrano_release()
  VERSION  = File.read(File.expand_path("../../VERSION",__FILE__)).strip
  NAME     = 'Storage Master Service'


  # Return version information for the Storage Master service.
  #
  # @return [Struct]  A struct with 'name' and 'uri' members

  def self.version
    os = OpenStruct.new("name" => "#{NAME} Version #{VERSION}, Git Revision #{REVISION}, Capistrano Release #{RELEASE}.",
                        "uri"  => "info:fcla/daitss/storage-master/#{VERSION}")
  end


  # Set up DataMapper connections.  Attempts to perform an operation on the database connections, so we'll fail fast.
  #
  # @param [String, String] connection strings for the Storage Master and, optionally, the DAITSS databases.

  def self.setup_databases(store_db_connection_string, daitss_db_connection_string = nil)

    dms = []
    dms.push StorageMasterModel.setup_db(store_db_connection_string)
    dms.push Daitss.setup_db(daitss_db_connection_string) if daitss_db_connection_string

    DataMapper.finalize
    dms.each { |dm| dm.select('select 1 + 1') }   # fail fast
  end


end
