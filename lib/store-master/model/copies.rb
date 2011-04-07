require 'store-master/exceptions'
require 'store-master/model'

module StoreMasterModel
  
  class Copy
    include DataMapper::Resource
    include StoreMaster

    def self.default_repository_name
      :store_master
    end

    property   :id,               Serial,   :min => 1
    property   :datetime,         DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :store_location,   String,   :length => 255, :required => true, :index => true

    belongs_to :pool
    belongs_to :package

    validates_uniqueness_of :pool, :scope => :package

    # Note: store-master/model.rb redefines the print method for URI so that
    # username/password credentials won't be exposed.

    def url
      url = URI.parse store_location
      if pool.basic_auth_username or pool.basic_auth_password
        url.user     = URI.encode pool.basic_auth_username
        url.password = URI.encode pool.basic_auth_password
      end
      url
    end
  end # of Copy

end
