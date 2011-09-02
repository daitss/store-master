require 'store-master'
require 'app/helpers'
require 'app/package-reports'
require 'app/misc'
require 'app/errors'
require 'app/packages'
require 'datyl/logger'
require 'datyl/config'
require 'haml'

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...

include StoreMaster
include StoreMasterModel
include Datyl

def get_config
  raise ConfigurationError, "No DAITSS_CONFIG environment variable has been set, so there's no configuration file to read"             unless ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The VIRTUAL_HOSTNAME environment variable has not been set"                                               unless ENV['VIRTUAL_HOSTNAME']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a non-existant file, (#{ENV['DAITSS_CONFIG']})"          unless File.exists? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a directory instead of a file (#{ENV['DAITSS_CONFIG']})"     if File.directory? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to an unreadable file (#{ENV['DAITSS_CONFIG']})"            unless File.readable? ENV['DAITSS_CONFIG']
  config = Datyl::Config.new(ENV['DAITSS_CONFIG'], :defaults, :database, ENV['VIRTUAL_HOSTNAME'])

  raise ConfigurationError, "The database connection string ('storemaster_db') was not found in the configuration file #{ENV['DAITSS_CONFIG']}" unless config.storemaster_db

  return config
end


configure do
  $KCODE = 'UTF8'

  config = get_config

  disable :logging        # Stop CommonLogger from logging to STDERR, please.

  disable :dump_errors    # Normally set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.

  set :environment,  :production  # Get some exceptional defaults.

  set :raise_errors, false        # Handle our own exceptions.

  set :haml, :format => :html5, :escape_html => true

  set :required_pools, (config.required_pools || 2)

  ENV['TMPDIR'] = config.temp_directory if config.temp_directory

  Logger.setup('StoreMaster', ENV['VIRTUAL_HOSTNAME'])

  if not (config.log_filename or config.log_syslog_facility)
    Logger.stderr
  end

  Logger.facility = config.log_syslog_facility  if config.log_syslog_facility
  Logger.filename = config.log_filename         if config.log_filename

  use Rack::CommonLogger, Logger.new(:info, 'Rack:')  # Bend CommonLogger to our will...

  Logger.info "Starting #{StoreMaster.version.name}"

  case settings.required_pools
  when 0
    Logger.info "No silo pools are required: this storage master will act as a testing-only stub server and not actually store to any silo-pools."
  when 1
    Logger.info "Requiring one silo pool for storage."
  else
    Logger.info "Requiring #{settings.required_pools} silo pools for storage."
  end

  Logger.info "Using temp directory #{config.temp_directory}" if config.temp_directory
  Logger.info "Using database #{StoreUtils.safen_connection_string(config.storemaster_db)}"

  DataMapper::Logger.new(Logger.new(:info, 'DataMapper:'), :debug) if config.log_database_queries

  StoreMasterModel.setup_db(config.storemaster_db)
end

before do
  @started = Time.now
  raise Http401, 'You must provide a basic authentication username and password' if needs_authentication?
  @revision = StoreMaster.version.name
  @service_name = service_name()
  Package.server_location = @service_name
end

get '/internals?' do
  redirect '/internals/index.html'
end

get '/' do
  haml :index
end

get '/guide' do
  haml :guide
end

get '/status' do
  [ 200, {'Content-Type'  => 'application/xml'}, "<status/>\n" ]
end
