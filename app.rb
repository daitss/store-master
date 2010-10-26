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
  Logger.info "Connecting to the DB using key '#{ENV['DATABASE_CONFIG_KEY']}' with configuration file #{ENV['DATABASE_CONFIG_FILE']}."

  begin
    # Make sure our diskstores are correctly setup - the constructor will throw errors otherwise.

    set :staged_root,  ENV['DISK_STORE_ROOT']   ## TODO: remove this when we work on 

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
load 'lib/app/packages.rb'



get '/' do
  erb :site, :locals => { :base_url => service_name, :revision => REVISION }
end

# testing stuff:

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

