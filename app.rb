require 'store' 

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...

REVISION = StoreMaster.version.rev

include Store

configure do
  $KCODE = 'UTF8'
  
  disable :logging        # Stop CommonLogger from logging to STDERR, please.
  disable :dump_errors    # Normally set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.
  
  set :environment,  :production  # Get some exceptional defaults.
  set :raise_errors, false        # Handle our own exceptions.

  if ENV['LOG_FACILITY'].nil?
    Logger.stderr
  else
    Logger.facility  = ENV['LOG_FACILITY']
  end

  use Rack::CommonLogger, Logger.new

  Logger.info "Starting #{StoreMaster.version.rev} with disk storage at #{ENV['DISK_STORE_ROOT']}."

  begin
    # Make sure our disks-tores are correctly setup - the new will throw errors otherwise.

    set :staged_root,      DiskStore.new(File.join(ENV['DISK_STORE_ROOT'], 'staged')).filesystem
    set :updates_root,     DiskStore.new(File.join(ENV['DISK_STORE_ROOT'], 'updates')).filesystem

    # TODO: setup ENV['DATABASE_CONFIG_FILE'], ENV['DATABASE_CONFIG_KEY']

  rescue ConfigurationError => e
    Logger.err e.message
    raise e
  rescue => e
    Logger.err e.message
    e.backtrace.each { |line| Logger.err e.message }
    raise e
  end
end

load 'lib/app/helpers.rb'
load 'lib/app/errors.rb'




put  '/updates/:ieid' do |ieid|

  # TODO: check to make sure the old package exists.
  # TODO: locking issues?
  # TODO: event - update init
  # TODO: make sure it's a tar file
  # TODO: authentication

  res = web_location("/updates/#{ieid}")

  ds = DiskStore.new(settings.updates_root)

  raise Http403, "The resource #{res} already exists; delete it first" if ds.exists?(ieid)
  
  supplied_md5 = request_md5()
  
  raise Http409, "The identifier #{ieid} does not meet the resource naming convention for #{res}" unless good_name(ieid)
  raise Http409, "Missing the Content-MD5 header, required for PUTs to #{res}" unless supplied_md5
  raise Http409, "This site only accepts content types of application/x-tar" unless (request.content_type and request.content_type == 'application/x-tar')

  begin 
    data = request.body                                          # singleton method to provide content length. (silo.put needs
    eval "def data.size; #{request.content_length.to_i}; end"    # to garner size; but that's not provided by 'rewindable' body object)    
    ds.put(ieid, data, request.content_type)
    computed_md5 = ds.md5(ieid)

    if computed_md5 != supplied_md5
      ds.delete(ieid) if ds.exists?(ieid)
      raise Http412, "The request indicated the MD5 was #{supplied_md5}, but the server computed #{computed_md5}"
    end

  rescue Http400Error => e
    raise e
  rescue => e
    raise "Error during PUT to /updates/#{ieid} - #{e.message}"   # let error handler take care of the details.
  end
end


# list all of the updates

get '/updates/?' do
  ds = DiskStore.new(settings.updates_root)

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')

  
  xml.updates(:location => web_location('/updates'), :time =>  Time.now.iso8601) {
    ds.each do |ieid|
      xml.package(:ieid     => ieid,
                  :etag     => ds.etag(ieid),
                  :md5      => ds.md5(ieid),
                  :sha1     => ds.sha1(ieid),
                  :size     => ds.size(ieid),
                  :type     => ds.type(ieid),
                  :time     => ds.datetime(ieid).to_s,
                  :location => web_location("/updates/#{ieid}"))
    end
  }
  content_type 'application/xml'
  xml.target!
end

delete '/updates/:ieid' do |ieid|
  ds = DiskStore.new(settings.updates_root)
  raise Http404, "The resource #{web_location('/updates/' + ieid)} does not exist" unless ds.exists?(ieid)
  ds.delete(ieid)
  status 204
end

# An updated package is ready to be commited....

post '/updates/:ieid'  do |ieid|

  ## TODO: check that locking logic will work as expected here.

  ds = DiskStore.new(settings.updates_root)

  raise Http404, "The resource /updates/#{ieid} doesn't exist."                unless ds.exists? ieid
  raise Http412, "Missing expected paramter 'committed'."                     unless commit = params[:committed]
  raise Http412, "Are your afraid to commit? Wanted true, but got #{commit}." unless commit.downcase == 'true'

  # TODO: send to individual silos

  # TODO: update package events

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:ieid     => ieid,
              :etag     => ds.etag(ieid),
              :md5      => ds.md5(ieid),
              :sha1     => ds.sha1(ieid),
              :size     => ds.size(ieid),
              :type     => ds.type(ieid),
              :time     => ds.datetime(ieid).to_s,
              :location => web_location("/packages/#{ieid}"))

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{ieid}"), 'Content-Type' => 'application/x-tar'
  xml.target!
end






get '/settings/?' do
  myopts = {}
  [ :app_file, :clean_trace, :dump_errors, :environment, :host, :lock,
    :logging, :method_override, :port, :public, :raise_errors, :root, 
    :run, :server, :sessions, :show_exceptions, :static, :views ].each  do |key|

    if settings.respond_to? key
      value = settings.send key
      rep = value
      if rep.class == Array
        rep = '[' + value.join(', ') + ']'
      elsif rep.class == Symbol
        rep = ':' + value.to_s
      end
      myopts[key] = rep
    else
      myopts[key] = '--'   # undefined
    end
  end
  erb :settings, :locals => { :opts => myopts, :revision => REVISION }
end



# load 'lib/app/gets.rb'
# load 'lib/app/posts.rb'
# load 'lib/app/puts.rb'
# load 'lib/app/deletes.rb'

