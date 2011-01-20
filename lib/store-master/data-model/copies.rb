module DataModel

  class Copy
    include DataMapper::Resource
    storage_names[:default] = 'copies'          # don't want dm_copies

    property   :id,               Serial,   :min => 1
    property   :datetime,         DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :store_location,   String,   :length => 255, :required => true, :index => true  #, :format => :url

    belongs_to :pool
    belongs_to :package

    validates_uniqueness_of :pool, :scope => :package

    # Careful with the URL returned here; it may have an associated username and password
    # which will print out in the URL.to_s method as http://user:password@example.com/ - you
    # don't want that logged. Use the url.sanitized method in preference to url.to_s.

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
