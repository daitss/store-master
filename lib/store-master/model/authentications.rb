require 'store-master/exceptions'
require 'store-master/model'

module StoreMasterModel

  class Authentication

    include StoreMaster
    include DataMapper::Resource

    # def self.default_repository_name
    #   :store_master
    # end

    include DataMapper::Resource
    
    property :id,              Serial
    property :name,            String, :required => true
    property :salt,            String, :required => true
    property :password_hash,   String, :required => true


    def self.lookup username
      first(:name =>username)
    end

    def self.create username, password
      rec = Authentication.first(:name => username) || Authentication.new(:name => username)
      
      rec.password = password
      raise "Can't create new credentials for #{administrator}: #{rec.errors.full_messages.join('; ')}." unless rec.save
      rec
    end

    def password= password
      raise BadPassword, "No password supplied" unless password and password.length > 0

      self.salt = rand(1_000_000_000_000_000_000).to_s(36)
      self.password_hash = Digest::MD5.hexdigest(salt + password)
      raise "Can't create new password for #{self.name}: #{self.errors.full_messages.join('; ')}." unless self.save
    end

    def authenticate password
      Digest::MD5.hexdigest(self.salt + password) == self.password_hash
    end

    def self.clear
      Authentication.destroy
    end

  end
end
