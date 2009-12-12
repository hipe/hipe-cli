# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hipe-cli}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mark Meves"]
  s.date = %q{2009-12-12}
  s.description = %q{yet another take on cli}
  s.email = %q{mark.meves@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
    "History.txt"
  ]
  s.files = [
    ".gitignore",
    "History.txt",
    "LICENSE",
    "README",
    "Rakefile.rb",
    "Thorfile",
    "hipe-cli.gemspec",
    "lib/hipe-cli.rb",
    "lib/hipe-cli/exceptions.rb",
    "lib/hipe-cli/extensions/help.rb",
    "lib/hipe-cli/extensions/library.rb",
    "lib/hipe-cli/extensions/predicates.rb",
    "lib/hipe-cli/sandbox/README",
    "lib/hipe-cli/sandbox/animals.rb",
    "lib/hipe-cli/sandbox/basic.rb",
    "lib/hipe-cli/sandbox/food.rb",
    "lib/hipe-cli/sandbox/shelter.rb",
    "spec/fakes/plugind.rb",
    "spec/fakes/some-plugin-empty.rb",
    "spec/fakes/some-plugin.rb",
    "spec/helpers/argv.rb",
    "spec/helpers/shared_one.rb",
    "spec/helpers/test-strap.rb",
    "spec/spec_basics.rb",
    "spec/spec_commands.rb",
    "spec/spec_help.rb",
    "spec/spec_plugin.rb",
    "spec/spec_predicate.rb",
    "spec/spec_webland.rb",
    "spec/test_data/dummy-file-2.txt",
    "spec/test_data/dummy-file.txt",
    "spec/test_data/out-file.txt",
    "spec/test_data/tmp/out-file.txt"
  ]
  s.homepage = %q{http://github.com/hipe/hipe-core}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{beginnings of yet another cli library}
  s.test_files = [
    "spec/fakes/plugind.rb",
    "spec/fakes/some-plugin-empty.rb",
    "spec/fakes/some-plugin.rb",
    "spec/helpers/argv.rb",
    "spec/helpers/shared_one.rb",
    "spec/helpers/test-strap.rb",
    "spec/spec_basics.rb",
    "spec/spec_commands.rb",
    "spec/spec_help.rb",
    "spec/spec_plugin.rb",
    "spec/spec_predicate.rb",
    "spec/spec_webland.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rools>, [">= 0.4"])
    else
      s.add_dependency(%q<rools>, [">= 0.4"])
    end
  else
    s.add_dependency(%q<rools>, [">= 0.4"])
  end
end
