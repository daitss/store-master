module Daitss

  DIGEST_CODES = [
    "MD5", # MD5 message digest algorithm, 128 bits
    "SHA-1", # Secure Hash Algorithm 1, 160 bits
    "CRC32"
  ]

  ORIGINATOR = ["unknown", "archive", "depositor"]


  class MessageDigest
    include DataMapper::Resource
    property :id, Serial, :key => true
    # property :dfid, String, :length => 16, :key => true # :unique_index => :u1
    property :code, String, :length => 10 #, :key=>true, :unique_index => :u1
    validates_with_method :code, :method => :validateDigestCode
    property :value,  String, :required => true, :length => 255
    property :origin, String, :length => 10, :required => true # :default => :unknown

    belongs_to :datafile #, :key => true#, :unique_index => :u1  the associated Datafile

    before :create, :check_unique_code

    def check_unique_code
      MessageDigest.first(:code => code, :datafile_id => datafile_id)
    end

    # validate the message digest code value which is a daitss defined controlled vocabulary
    def validateDigestCode
      if DIGEST_CODES.include?(@code)
        return true
      else
        [ false, "value #{@code} is not a valid message digest code value" ]
      end
    end

    def fromPremis(premis)
      code = premis.find_first("premis:messageDigestAlgorithm", NAMESPACES).content
      attribute_set(:code, code)
      attribute_set(:value, premis.find_first("premis:messageDigest", NAMESPACES).content)
      origin = premis.find_first("premis:messageDigestOriginator", NAMESPACES)
      attribute_set(:origin, origin.content.downcase) if origin
    end

    after :save do
      puts "#{self.errors.to_a} error encountered while saving #{self.inspect} " unless valid?
    end
  end

end
