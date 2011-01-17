require 'store-master/dm'
require 'store-master/exceptions'
require 'dm-types'

module StoreMaster
  class Pool

    attr_reader :dm_record

    # Create a new pool object.  Almost entirely a wrapper over the DM::Pool datamapper class.

    # The constructor is only meant for internal use.

    def initialize dm_record
      @dm_record = dm_record
    end

    def self.create put_location
      rec = DM::Pool.create(:put_location => put_location)
      rec.saved? or raise "Can't create new pool record #{put_location}; DB errors: " + @dm_record.errors.full_messages.join('; ')
      Pool.new rec
    end

    def self.exists? put_location
      not DM::Pool.first(:put_location => put_location).nil? 
    end

    def self.lookup put_location
      rec = DM::Pool.first(:put_location => put_location)
      Pool.new rec
    end

    def datamapper_record
      @dm_record
    end

    # higher the preference, the more it should be preferred.

    def required
      @dm_record.required      
    end

    def required= bool
      @dm_record.required = bool
      @dm_record.save or raise "Can't set pool #{put_location} 'required' flag to #{bool};  DB errors: " + @dm_record.errors.full_messages.join('; ')
    end

    def put_location
      @dm_record.put_location      
    end

    def put_location= url
      @dm_record.put_location = bool
      @dm_record.save or raise "Can't set pool #{put_location} 'put_location' to#{url};  DB errors: " + @dm_record.errors.full_messages.join('; ')
    end

    def read_preference
      @dm_record.read_preference
    end

    def read_preference= int
      @dm_record.read_preference = int
      @dm_record.save or raise "Can't set pool #{put_location} 'read_preference' to #{int};  DB errors:  " + @dm_record.errors.full_messages.join('; ')
    end

    def password
      @dm_record.password
    end

    def password= password
      @dm_record.basic_auth_password = password
      @dm_record.save or raise "Can't set pool #{put_location} 'basic_auth_password' to #{password};  DB errors:  " + @dm_record.errors.full_messages.join('; ')
    end

    def username
      @dm_record.username
    end

    def username= username
      @dm_record.basic_auth_username = username
      @dm_record.save or raise "Can't set pool #{put_location} 'basic_auth_username' to #{username};  DB errors:  " + @dm_record.errors.full_messages.join('; ')
    end

    def post_url name
      @dm_record.post_url name
    end

    def self.list_active
      DM::Pool.list_active.map { |rec| Pool.new(rec) }
    end

  end # of class Pool
end  # of module StoreMaster


