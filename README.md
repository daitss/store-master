StoreMaster Service
===================
Suppose you have an archive service, and consider that you have a
collection of REST-based storage services.  Further suppose that your
archive requires that you save each archived package to multiple,
adminisitratively separated storage locations.  
StoreMaster is a RESTful werb service that acts as a single
point for storing and retreiving those packages.  You can think of
it as a storage-multiplexing service, or a reverse proxy, if you like.


Environment
-----------

We use apache with passenger fusion; you could run the service right from the
config file using 'rackup config.ru' if you desired, though.

In apache-speak, the environment:

  * SetEnv LOG_FACILITY         LOG_LOCAL1              - syslog setup, or nothing if you want STDERR
  * SetEnv DATABASE_CONFIG_FILE /opt/fda/etc/db.yml     - database YAML file
  * SetEnv DATABASE_CONFIG_KEY  store_master            - the key into the above for this service
  * SetEnv TMPDIR               /var/tmp                - need plenty of headroom here 
  * PassengerUploadBufferDir    /var/tmp/phusion        - and here

Requirements
------------
Known to work with with ruby 1.8.7. You can deploy using bundler version 1.0.0 or greater.
Bundler will pull in the required libraries (see Gemfile

Quickstart
----------

 1. Retrieve the package from this repository
 2. Setup a database use the <mumble> tools provided; adjust the configuration file in the spec directory
 3. Run 'rake spec'
 4. Adjust the capistrano configuration file; run 'cap deploy'


Directory Structure
-------------------
You can use the supplied Capfile to set up. Adjust
the top few lines in that file to match your installation.

 * config.ru & app.rb - the Sinatra setup
 * public/            - programming docs will land in public/internals, other static assets
 * views/             - instructional erb pages and forms
 * lib/app/           - root of the sinatra-specific stuff - helpers and routes
 * lib/store/         - root of the storage libraries
 * spec/              - tests
 * tmp/               - phusion checks the restart.txt file here.  Rake has a restart target for this, capistrano uses it
 * Capfile, Rakefile  - build and deployment support
 * Gemfile*           - bundler support

Usage
-----
Configure with backend storage services; see the daitss <mumble> project; add the
following to you pools configuration table with the <mumble> tool.


Documentation
-------------
See the root of the running service for a web page of instructions on
use and testing; there is a Rake task that will install the
application documentation under public/internals.
