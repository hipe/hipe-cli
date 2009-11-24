# require 'spec'
require 'spec/rake/spectask'

desc "Run API and Core specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  t.spec_files = FileList['spec/public/**/*_spec.rb'] + FileList['spec/private/**/*_spec.rb']
end
