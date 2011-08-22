# -*- mode:ruby; -*-

require 'fileutils'
require 'rake'
require 'rspec'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'socket'

HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')
FILES   = FileList["#{LIBDIR}/**/*.rb", "views/**/*erb", "public/*",'config.ru', 'app.rb']         # run yard/hanna/rdoc on these and..
DOCDIR  = File.join(HOME, 'public', 'internals')                       # ...place the html doc files here.

# require 'bundler/setup'

# These days, bundle is called automatically, if a Gemfile exists, by a lot
# of different libraries - rack and rspec among them.  Use the development
# gemfile for those things run from this Rakefile.


ENV['BUNDLE_GEMFILE'] = File.join(HOME, 'Gemfile.development')

def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end



def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end

RSpec::Core::RakeTask.new do |task|
  task.rspec_opts = [ '--color', '--format', 'documentation' ] 
  ## task.rcov = true if Socket.gethostname =~ /romeo-foxtrot/   # do coverage tests on my devlopment box
end

Cucumber::Rake::Task.new do |task|
   task.rcov = true
end

# assumes git pushed out

desc "Deploy to darchive's storemaster"
task :darchive do
  sh "cap deploy -S target=darchive.fcla.edu:/opt/web-services/sites/storemaster -S who=daitss:daitss"
end

desc "Deploy to tarchive's test storemaster - betastore.tarchive.fcla.edu"
task :betastore do
  sh "cap deploy -S target=tarchive.fcla.edu:/opt/web-services/sites/betastore -S who=daitss:daitss"
end

desc "Deploy to retsina development storemaster - storemaster.retsina.fcla.edu"
task :retsina do
  sh "cap deploy -S target=retsina.fcla.edu:/opt/web-services/sites/storemaster -S who=daitss:daitss"
end

desc "Deploy to ripple's test storemaster"
task :ripple do
  sh "cap deploy -S target=ripple.fcla.edu:/opt/web-services/sites/storemaster -S who=daitss:daitss"
end

desc "Deploy to stub-storemaster on ripple"
task :ripple_stub do
  sh "cap deploy -S target=ripple.fcla.edu:/opt/web-services/sites/stub-master -S who=daitss:daitss"
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

# rebuild local bundled Gems, as well as the distributed Gemfile.lock

desc "Regenerate development and production gem bundles"
task :bundle do
  sh "rm -rf #{HOME}/bundle #{HOME}/.bundle #{HOME}/Gemfile.development.lock #{HOME}/Gemfile.lock"
  sh "mkdir -p #{HOME}/bundle"
  sh "cd #{HOME}; bundle --gemfile Gemfile.development install --path bundle"
  sh "cd #{HOME}; bundle install --path bundle"
end

desc "Hit the restart button for apache/passenger, pow servers"
task :restart do
  sh "touch #{HOME}/tmp/restart.txt"
end

desc "Make emacs tags files"
task :etags do
  files = (FileList['lib/**/*', "tools/**/*", 'views/**/*', 'spec/**/*', 'bin/**/*']).exclude('spec/files', 'spec/reports')        # run yard/hanna/rdoc on these and..
  sh "xctags -e #{files}"
end

defaults = [:restart, :spec]
defaults.push :etags   if dev_host

task :default => defaults
