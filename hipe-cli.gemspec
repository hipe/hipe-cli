# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hipe-cli}
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mark Meves"]
  s.date = %q{2009-12-12}
  s.default_executable = %q{hipe-cli}
  s.description = %q{yet another take on cli}
  s.email = %q{mark.meves@gmail.com}
  s.executables = ["hipe-cli"]
  s.extra_rdoc_files = [
    "LICENSE",
    "History.txt"
  ]
  s.files = [
    ".gitignore",
    "History.txt",
    "LICENSE",
    "Rakefile.rb",
    "Thorfile",
    "examples/app-op2-simple-help.rb",
    "examples/app-op3-big-op-example.rb",
    "examples/app-op4-for-arguments-too.rb",
    "hipe-cli.gemspec",
    "lib/hipe-cli.rb",
    "spec/bacon-helper.rb",
    "spec/spec_basics.rb",
    "spec/spec_commands.rb",
    "spec/spec_grammar-grammar.rb",
    "spec/spec_optparsey.rb",
    "bin/hipe-cli"
  ]
  s.homepage = %q{http://github.com/hipe/hipe-cli}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{beginnings of yet another cli library}
  s.test_files = [
    "spec/bacon-helper.rb",
    "spec/spec_basics.rb",
    "spec/spec_commands.rb",
    "spec/spec_grammar-grammar.rb",
    "spec/spec_optparsey.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
