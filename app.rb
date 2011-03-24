require 'store-master' 
require 'app/helpers'
require 'app/package-reports'
require 'app/errors'
require 'app/packages'

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...

REVISION = StoreMaster.version.name

include StoreMaster
include StoreMasterModel

configure do
  $KCODE = 'UTF8'
  
  disable :logging        # Stop CommonLogger from logging to STDERR, please.
  disable :dump_errors    # Normally set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.
  
  set :environment,  :production  # Get some exceptional defaults.
  set :raise_errors, false        # Handle our own exceptions.

  Logger.setup('StoreMaster', ENV['VIRTUAL_HOSTNAME'])

  ENV['LOG_FACILITY'].nil? ? Logger.stderr : Logger.facility  = ENV['LOG_FACILITY']

  use Rack::CommonLogger, Logger.new(:info, 'Rack:')

  Logger.info "Starting #{REVISION}."
  Logger.info "Connecting to the DB using key '#{ENV['DATABASE_CONFIG_KEY']}' with configuration file #{ENV['DATABASE_CONFIG_FILE']}."
  (ENV.keys - ['BASIC_AUTH_PASSWORD', 'DATABASE_CONFIG_KEY', 'DATABASE_CONFIG_FILE']).sort.each do |key|
    Logger.info "Environment: #{key} => #{ENV[key].nil? ? 'undefined' : "'" + ENV[key] +"'"}"
  end

  DataMapper::Logger.new(Logger.new(:info, 'DataMapper:'), :debug) if ENV['DATABASE_LOGGING']

  begin
    StoreMasterModel.setup_db(ENV['DATABASE_CONFIG_FILE'], ENV['DATABASE_CONFIG_KEY'])

  rescue ConfigurationError => e
    Logger.err e.message
    raise e
  rescue => e
    Logger.err e.message
    e.backtrace.each { |line| Logger.err e.message }
    raise e
  end
end

get '/' do
  erb :site, :locals => { :base_url => service_name, :revision => REVISION }
end

# testing stuff:

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

