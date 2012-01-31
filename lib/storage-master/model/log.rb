require 'storage-master/exceptions'
require 'storage-master/model'

module StorageMasterModel

  class Log
    include DataMapper::Resource
    include StorageMaster

    property  :id,         Serial,   :min => 1
    property  :timestamp,  DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property  :action,     String,   :length => 255
    property  :user,       String,   :length => 255
    property  :url,        String,   :length => 225
    property  :note,       Text
  end
end

