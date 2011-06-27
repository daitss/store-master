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

# Setup database

def initialize_database config_file, config_key
  StoreMasterModel.setup_db(config_file, config_key)

rescue ConfigurationError => e
  Logger.err e.message
  raise e
rescue => e
  Logger.err e.message
  e.backtrace.each { |line| Logger.err e.message }
  raise e
end

def database_logging? val
  return false if val.nil?
  return ['true', 'ok', 'yep', 'sure'].include? val.downcase
end

configure do
  $KCODE = 'UTF8'

  disable :logging        # Stop CommonLogger from logging to STDERR, please.
  disable :dump_errors    # Normally set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.

  set :environment,  :production  # Get some exceptional defaults.
  set :raise_errors, false        # Handle our own exceptions.

  set :minimum_required_pools, (ENV['MINIMUM_REQUIRED_POOLS'] || '2').to_i

  set :haml, :format => :html5, :escape_html => true

  Logger.setup('StoreMaster', ENV['VIRTUAL_HOSTNAME'])

  ENV['LOG_FACILITY'].nil? ? Logger.stderr : Logger.facility  = ENV['LOG_FACILITY']

  Logger.info "Starting #{StoreMaster.version.name}."
  Logger.info "Connecting to the DB using key '#{ENV['DATABASE_CONFIG_KEY']}' with configuration file #{ENV['DATABASE_CONFIG_FILE']}."
  Logger.info "Requiring #{settings.minimum_required_pools} pools for storage"

  DataMapper::Logger.new(Logger.new(:info, 'DataMapper:'), :debug) if database_logging? ENV['DATABASE_LOGGING']

  initialize_database(ENV['DATABASE_CONFIG_FILE'], ENV['DATABASE_CONFIG_KEY'])
end

before do
  @started = Time.now
  @revision = StoreMaster.version.name
  @service_name = service_name()
  Package.server_location = @service_name
end

after do
  log_end_of_request @started
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


# testing stuff:

# get '/settings/?' do
#   myopts = {}
#   [ :app_file, :clean_trace, :dump_errors, :environment, :host, :lock,
#     :logging, :method_override, :port, :public, :raise_errors, :root,
#     :run, :server, :sessions, :show_exceptions, :static, :views ].each  do |key|
#
#     if settings.respond_to? key
#       value = settings.send key
#       rep = value
#       if rep.class == Array
#         rep = '[' + value.join(', ') + ']'
#       elsif rep.class == Symbol
#         rep = ':' + value.to_s
#       end
#       myopts[key] = rep
#     else
#       myopts[key] = '--'   # undefined
#     end
#   end
#   erb :settings, :locals => { :opts => myopts, :revision => REVISION }
# end

