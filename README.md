Storage Master Service
=======================

Suppose you are running an archive service, and consider that you have
a variety of REST-based storage servers.  Further suppose that your
archive service requires that you save each archived package to
multiple, adminisitratively-separated storage locations.  Storage
Master is a web service that acts as a single point of contact for
your archive to store and retrieve those packages to back-end storage
servers.  You can think of it as a storage-multiplexing service, or a
reverse proxy, if you like. It insulates your archival system from
keeping track of changing back-end storage servers.  The DAITSS system
uses the Storage Master to manage the packages on the back-end storage
servers.  See the companion DAITSS Silo Pool project for setting up
the back-end services.

Current Production code
-----------------------
git commit sha1 - 3eb506c7909ddd7536a2c89f433e4331b889a3be

Environment
-----------
We've been using apache with passenger fusion; you could run the
service right from the config file using 'rackup config.ru' if you
desired, or using the thin web server, say.

There are three environment variables that must be set:

  * DAITSS_CONFIG_FILE,  a path to a yaml configuration file
  * VIRTUAL_HOSTNAME, the name that the server will run under
  * TMPDIR, optionally, the path to a large temporary directory

Requirements
------------
Known to work with with ruby 1.8.7. You can deploy using bundler version 1.0.x or greater.
Bundler will pull in the required libraries (see Gemfile).

Quickstart
----------

 *  Retrieve the package from this repository
 *  Setup a Postgres database using the tools/create-db script
 *  Adjust the sample configuration file, daitss-config.example.yml
 *  Run 'rake bundle' to get the packages set up
 *  Start your web server for this application with the environment variables above set as approriate.
 *  Set up back-end storage servers (see https://github.com/daitss/silo-pool)

Directory Structure
-------------------

 * config.ru & app.rb     - the Sinatra setup
 * docs/                  - miscellaneous doc sources used to generated on-line manuals
 * lib/app/               - root of the sinatra-specific stuff - helpers and routes
 * lib/storage-master/    - root of the storage libraries
 * public/                - programming docs will land in public/internals, other static assets
 * spec/                  - tests
 * tmp/                   - phusion, pow web server checks the restart.txt file here.
 * views/                 - instructional pages and forms
 * Capfile, Rakefile      - build and deployment support
 * Gemfile, Gemfile.lock  - bundler support

Usage
-----
See the DAITSS installation and operations manual.

Documentation
-------------
See the root of the running service for a web page of instructions on
use.  Ruby documentation tools are so poor that I've included the
pre-generated yard output. 
