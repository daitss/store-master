require 'storage-master'
require 'app/helpers'
require 'app/package-reports'
require 'app/misc'
require 'app/errors'
require 'app/packages'
require 'datyl/logger'
require 'datyl/config'
require 'haml'

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...

include StorageMaster
include StorageMasterModel
include Datyl

def get_config
  raise ConfigurationError, "No DAITSS_CONFIG environment variable has been set, so there's no configuration file to read"             unless ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The VIRTUAL_HOSTNAME environment variable has not been set"                                               unless ENV['VIRTUAL_HOSTNAME']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a non-existant file, (#{ENV['DAITSS_CONFIG']})"          unless File.exists? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a directory instead of a file (#{ENV['DAITSS_CONFIG']})"     if File.directory? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to an unreadable file (#{ENV['DAITSS_CONFIG']})"            unless File.readable? ENV['DAITSS_CONFIG']

  config = Datyl::Config.new(ENV['DAITSS_CONFIG'], :defaults, :database, ENV['VIRTUAL_HOSTNAME'])

  
  [ 'storage_master_db', 'required_pools' ].each do |option|
    raise ConfigurationError, "The option '#{option}' was not found in the configuration file #{ENV['DAITSS_CONFIG']}" unless config[option]
  end

  return config
end


configure do
  $KCODE = 'UTF8'

  config = get_config

  set :logging,      false        # Stop CommonLogger from logging to STDERR
  set :environment,  :production  # Get some exceptional defaults.
  set :raise_errors, false        # Let our app handle the exceptions.
  set :dump_errors,  false        # Don't add backtraces automatically (we'll decide)

  set :haml, :format => :html5, :escape_html => true

  set :required_pools, config.required_pools

  Logger.setup('StorageMaster', ENV['VIRTUAL_HOSTNAME'])

  Logger.facility = config.log_syslog_facility  if config.log_syslog_facility
  Logger.filename = config.log_filename         if config.log_filename
  Logger.stderr     unless (config.log_filename or config.log_syslog_facility)

  use Rack::CommonLogger, Logger.new(:info, 'Rack:')  # Bend CommonLogger to our logging system

  Logger.info "Starting #{StorageMaster.version.name}"

  case settings.required_pools
  when 0
    Logger.info "No silo pools are required: this storage master will act as a testing-only stub server and not actually store to any silo-pools."
  when 1
    Logger.info "Requiring one silo pool for storage."
  else
    Logger.info "Requiring #{settings.required_pools} silo pools for storage."
  end

  Logger.info "Using #{ENV['TMPDIR'] || 'system default'} for temp directory"
  Logger.info "Using database #{StoreUtils.safen_connection_string(config.storage_master_db)}"

  DataMapper::Logger.new(Logger.new(:info, 'DataMapper:'), :debug) if config.log_database_queries

  StorageMaster.setup_databases(config.storage_master_db)
end

before do
  @started = Time.now
  raise Http401, 'You must provide a basic authentication username and password' if needs_authentication?
  @revision = StorageMaster.version.name
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
