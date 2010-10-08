require 'store' 
require 'builder'

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...
# TODO: Authentication

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
  Logger.info "Connecting to DB keyed by #{ENV['DATABASE_CONFIG_KEY']} in file #{ENV['DATABASE_CONFIG_FILE']}."

  begin
    # Make sure our diskstores are correctly setup - the constructor will throw errors otherwise.

    set :staged_root,  DiskStore.new(File.join(ENV['DISK_STORE_ROOT'], 'staged')).filesystem
    set :updates_root, DiskStore.new(File.join(ENV['DISK_STORE_ROOT'], 'updates')).filesystem

    # Get connected to db.

    DM.setup(ENV['DATABASE_CONFIG_FILE'], ENV['DATABASE_CONFIG_KEY'])

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

post '/reserve/?' do
  raise Http412, "Missing expected paramter 'ieid'." unless ieid = params[:ieid]
  res = Store::Reservation.new ieid
  
  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.reserved(:ieid => ieid, :location => web_location("/packages/#{res.name}"))
  xml.target!

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{res.name}"), 'Content-Type' => 'application/xml'
  xml.target!
end

get '/pacakges/:name' do |name|
  name
end

delete '/pacakges/:name' do |name|
  name
end

put '/packages/:name' do |name|

  ieid = Store::Reservation.lookup_ieid(name)
  raise Http404, "The resource #{name} must first be reserved" unless ieid

  
  # Store::Package.lookup(name)

  # does it exist already?  Die!
  # do we have a reservation to create it? Die!
  # lock here....

  '
huh. Seemed to
work'

end






# load 'lib/app/updates.rb'
# load 'lib/app/packages.rb'

# get '/' do
#  redirect '/updates/', 302
# end

# testing

get '/foo/:bar' do |bar|
  erb :dump, :locals => { :params => params, :at_env => @env, :env => ENV, :revision => REVISION }
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

