require 'builder'
require 'ostruct'
require 'datyl/logger'
require 'store-master/model'       # brings in store-master specific data models
require 'store-master/disk-store'
require 'store-master/fixity'
require 'store-master/exceptions'  # brings in http-exceptions
require 'store-master/utils'
require 'time'

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

module StoreMaster

  REVISION = get_capistrano_git_revision()
  RELEASE  = get_capistrano_release()
  VERSION  = '0.2.2'
  NAME     = 'Store Master Service'


  def self.version
    os = OpenStruct.new("rev" => "#{NAME} Version #{VERSION}, Git Revision #{REVISION}, Capistrano Release #{RELEASE}.",
                        "uri" => "info:fcla/daitss/store-master/#{VERSION}")
    def os.to_s
      self.rev
    end
    os
  end
end
