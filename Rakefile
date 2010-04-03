require 'rubygems'
require 'rake'

begin
  gem 'jeweler', '~> 1.4'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'hipe-cli'
    gem.summary     = "deprecated. don't use this."
    gem.description = "this is an old bloated cli framework i made many moons ago."
    gem.email       = 'chip.malice@gmail.com'
    gem.homepage    = 'http://github.com/hipe/hipe-cli'
    gem.authors     = [ 'Chip Malice' ]
    gem.bindir      = 'bin'
    # gem.rubyforge_project = 'none'

    gem.add_dependency 'hipe-core',    '~> 0.0.0'
  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end

desc "hack turns the installed gem into a symlink to this directory"

task :hack do
  kill_path = %x{gem which hipe-cli}
  kill_path = File.dirname(File.dirname(kill_path))
  new_name  = File.dirname(kill_path)+'/ok-to-erase-'+File.basename(kill_path)
  FileUtils.mv(kill_path, new_name, :verbose => 1)
  this_path = File.dirname(__FILE__)
  FileUtils.ln_s(this_path, kill_path, :verbose => 1)
end
