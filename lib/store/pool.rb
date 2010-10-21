require 'store/dm'
require 'store/exceptions'
require 'dm-types'

module Store
  class Pool

    attr_reader :dm_record

    # Create a new pool object.  Mostly a wrapper over the DM::Pool datamapper class.

    def initialize dm_record
      @dm_record = dm_record
    end

    def self.create put_location
      rec = DM::Pool.create(:put_location => put_location)
      rec.saved? or raise "Can't create new pool recrord #{put_location}; DB errors: " + rec.errors.join('; ')
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

    def required
      @dm_record.required      
    end

    def required= bool
      @dm_record.required = bool
      @dm_record.save or raise "Can't set pool #{put_location} to 'required' flag of #{bool};  DB errors: " + rec.errors.join('; ')
    end

    def put_location
      @dm_record.put_location      
    end

    def put_location= url
      @dm_record.put_location = bool
      @dm_record.save or raise "Can't set pool #{put_location} to 'put_location' of #{url};  DB errors: " + rec.errors.join('; ')
    end

    def read_preference
      @dm_record.read_preference      
    end

    def read_preference= int
      @dm_record.read_preference = int
      @dm_record.save or raise "Can't set pool #{put_location} to 'read_preference' of #{int};  DB errors:  " + rec.errors.join('; ')
    end

    def self.list_active
      pools = []
      DM::Pool.all(:required => true, :order => [ :read_preference.desc ]).each do |rec|
        pools.push Pool.new(rec)
      end
      pools
    end

  end # of class Pool
end  # of module Store


