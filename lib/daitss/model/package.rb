module Daitss

  # authoritative package record

  class Package
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    @@uri_prefix = 'info:fcla'

    def self.uri_prefix=  prefix
      @@uri_prefix = prefix
    end

    property :id,  EggHeadKey
    property :uri, String,     :unique => true, :required => true, :default => proc { |r,p| @@uri_prefix + ':' + r.id }

    has n,    :events
    has n,    :requests
    has 1,    :sip
    has 0..1, :aip

# These are things we don't need, since we never delete or modify packages:

#   has 0..1, :intentity              # brings in way too much baggage
#   has 0..1, :report_delivery
#   has n, :batch_assignments
#   has n, :batches, :through => :batch_assignments


    belongs_to :project

    # makes an event for this package

    def log name, options={}
      e = Event.new :name => name, :package => self
      e.agent = options[:agent] || Program.get("SYSTEM")
      e.notes = options[:notes]
      e.timestamp = options[:timestamp] if options[:timestamp]

      unless e.save
        raise "cannot save op event: #{name} (#{e.errors.size}):\n#{e.errors.map.join "\n"}"
      end
    end

    def status

      if self.aip
        'archived'
      elsif self.events.first :name => 'reject'
        'rejected'
      elsif self.wip
        'ingesting'
      elsif self.stashed_wip
        'stashed'
      else
        'submitted'
      end

    end

  end

end
