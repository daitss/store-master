# -*- mode:ruby; -*-

require 'fileutils'
require 'rake'
require 'socket'
require 'rake/rdoctask'
require 'spec/rake/spectask'

# require 'bundler/setup'

HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')

FILES   = FileList["#{LIBDIR}/**/*.rb", "views/**/*erb", "public/*",'config.ru', 'app.rb']         # run yard/hanna/rdoc on these and..
DOCDIR  = File.join(HOME, 'public', 'internals')                       # ...place the html doc files here.

def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end

# cleanup handling of CI & spec dependencies

spec_dependencies = []

# Working with continuous integration.  The CI servers out
# there.... Sigh... Something that should be so easy...let's start
# with ci/reporter...
#
# TODO: conditionally add to the spec tests, and send the output to
# a web service

begin
  require 'ci/reporter/rake/rspec'
rescue LoadError => e
else
  spec_dependencies.push "ci:setup:rspec"
end

begin
  require 'ci/reporter/rake/cucumber'
rescue LoadError => e
else
  spec_dependencies.push "ci:setup:cucumber"
end

task :spec => spec_dependencies

Spec::Rake::SpecTask.new do |task|
  task.spec_opts = [ '--format', 'specdoc' ]    # ci/reporter is getting in the way of this being used.
  task.libs << 'lib'
  task.libs << 'spec'
  task.rcov = true if dev_host   # do coverage tests on my devlopment box
end


desc "deploy to darchive's storemaster"
task :darchive do
  sh "git diff > /tmp/silos.diff; test -s /tmp/silos.diff && open /tmp/silos.diff"
  sh "test -s /tmp/silos.diff && git commit -a"
  sh "git push"
  sh "cap deploy -S target=darchive:/opt/web-services/sites/storemaster -S who=daitss:daitss"
end


desc "Generate documentation from libraries - try yardoc, hanna, rdoc, in that order."
task :docs do

  yardoc  = `which yardoc 2> /dev/null`
  hanna   = `which hanna  2> /dev/null`
  rdoc    = `which rdoc   2> /dev/null`

  if not yardoc.empty?
    command = "yardoc --quiet --private --protected --title 'Storage Master Service' --output-dir #{DOCDIR} #{FILES}"
  elsif not hanna.empty?
    command = "hanna --quiet --main StoreMaster --op #{DOCDIR} --inline-source --all --title 'Store Master' #{FILES}"
  elsif not rdoc.empty?
    command = "rdoc --quiet --main StoreMaster --op #{DOCDIR} --inline-source --all --title 'Store Master' #{FILES}"
  else
    command = nil
  end

  if command.nil?
    puts "No documention helper (yardoc/hannah/rdoc) found, skipping the 'doc' task."
  else
    FileUtils.rm_rf FileList["#{DOCDIR}/**/*"]
    puts "Creating docs with #{command.split.first}."
    `#{command}`
  end
end

# Following used for development:

desc "Maintain the sinatra tmp directory for automated restart (passenger phusion pays attention to tmp/restart.txt)."
task :restart do
  mkdir TMPDIR unless File.directory? TMPDIR
  restart = File.join(TMPDIR, 'restart.txt')
  if not (File.exists?(restart) and `find  #{FILES} -type f -newer "#{restart}" 2> /dev/null`.empty?)
    puts "Indicating a restart is in order."
    File.open(restart, 'w') { |f| f.write "" }
  end
end

# Build local (not deployed) bundled files for in-place development.
# This doesn't really work because of a chicken/egg issue (we now
# include bundler/setup above so we can use the rakefile against
# the bundled gems), but at it shows what you have to do.  Note
# that capistrano will use the Gemfile.lock file created (and 
# committed to the repository) to maintain bundled gems in a 
# a shared directory on the deployed host.

desc "Reset bundles"
task :bundle do
  `rm -f #{HOME}/Gemfile.lock`
  `rm -rf #{HOME}/vendor/bundle`
  `mkdir -p #{HOME}/vendor/bundle`
  `cd #{HOME}; bundle install --path vendor/bundle`
end

desc "Make emacs tags files"
task :etags do
  files = (FileList['lib/**/*', "tools/**/*", 'views/**/*', 'spec/**/*', 'bin/**/*']).exclude('spec/files', 'spec/reports')        # run yard/hanna/rdoc on these and..
  puts "Creating Emacs TAGS file"
  `xctags -e #{files}`
end

defaults = [:restart, :spec]
defaults.push :etags   if dev_host

task :default => defaults
