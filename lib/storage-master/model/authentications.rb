require 'storage-master/exceptions'
require 'storage-master/model'

module StorageMasterModel
  
  # Authenication maintains a username/password system that can be
  # used to restrict access to the Storage Master service. Passwords
  # are stored encrypted.  Currently, the rest of the Storage Master
  # service only uses a username of 'admin', but that is not a
  # limitation inherent in this class.
  #
  # Example:
  #
  #   Authentication.create('admin', 'top secret')
  #   ...
  #   user = Authentication.lookup('admin')
  #   if user.authenticate('top secret') 
  #      # do some stuff
  #   else 
  #      # don't
  #   end

  class Authentication

    include StorageMaster
    include DataMapper::Resource

    # def self.default_repository_name
    #   :store_master
    # end

    include DataMapper::Resource
    
    property :id,              Serial
    property :name,            String, :required => true
    property :salt,            String, :required => true
    property :password_hash,   String, :required => true


    # Authentication.lookup returns an authentication object for a username
    #
    # @param [String] username, a string 
    # @return [Authentication] the authentication object for this user if available, or nil


    def self.lookup username
      first(:name =>username)
    end

    # Authentication.create  creates a new authentication object, associating a password with a username
    #
    # @param [String] username, a string 
    # @param [String] password, a string 
    # @return [Authentication] the authentication object for this user, created if need be


    def self.create username, password
      rec = Authentication.first(:name => username) || Authentication.new(:name => username)
      
      rec.password = password
      raise "Can't create new credentials for #{administrator}: #{rec.errors.full_messages.join('; ')}." unless rec.save
      rec
    end

    # password= sets the password for this authentication object
    #
    # @param [String] password, the new password

    def password= password
      raise BadPassword, "No password supplied" unless password and password.length > 0

      self.salt = rand(1_000_000_000_000_000_000).to_s(36)
      self.password_hash = Digest::MD5.hexdigest(salt + password)
      raise "Can't create new password for #{self.name}: #{self.errors.full_messages.join('; ')}." unless self.save
    end

    # password checks a password for a user
    #
    # @param [String] password, a candidate password for this authentication object
    # @return [Boolean] true if this is the user's password

    def authenticate password
      Digest::MD5.hexdigest(self.salt + password) == self.password_hash
    end

    # Authentication.clear removes all authentications from the database

    def self.clear
      Authentication.destroy
    end

  end
end
