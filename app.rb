require 'store-master'
require 'app/helpers'
require 'app/package-reports'
require 'app/misc'
require 'app/errors'
require 'app/packages'
require 'haml'

# TODO: transfer compression in PUT seems to retain files as compressed...fah.  Need to check for this...

include StoreMaster
include StoreMasterModel

def get_config
  filename = ENV['STOREMASTER_CONFIG_FILE'] || File.join(File.dirname(__FILE__), 'config.yml')
  config = StoreUtils.read_config(filename)
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

  set :required_pools, config.required_pools

  set :database_connection_string, config.database_connection_string

  Logger.setup('StoreMaster', config.virtual_hostname)

  if config.log_syslog_facility
    Logger.facility = config.log_syslog_facility
  else
    Logger.stderr
  end

  Logger.info "Starting #{StoreMaster.version.name}"
  Logger.info "Requiring #{settings.required_pools} pools for storage"
  Logger.info "Using temp directory #{config.temp_directory}" if config.temp_directory

  DataMapper::Logger.new(Logger.new(:info, 'DataMapper:'), :debug) if config.log_database_queries

  ENV['TMPDIR'] = config.temp_directory if config.temp_directory
end

before do
  @started = Time.now
  raise Http401, 'You must provide a basic authentication username and password' if needs_authentication?
  @revision = StoreMaster.version.name
  @service_name = service_name()
  Package.server_location = @service_name
end

after do
  log_end_of_request @started
end

StoreMasterModel.setup_db(settings.database_connection_string)

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
