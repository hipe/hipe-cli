# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hipe-cli}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mark Meves"]
  s.date = %q{2009-11-19}
  s.description = %q{hipe-cli is an experimental command-line "framework" that aides
      in parsing commands and options and displaying and formatting
      help screens, etc.}
  s.email = %q{mark.meves@gmail.com}
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
    "lib/hipe-cli.rb",
    "lib/hipe-cli/app.rb",
    "lib/hipe-cli/asciitypesetter.rb",
    "lib/hipe-cli/commands/help.rb",
    "lib/hipe-cli/logger.rb",
    "lib/hipe-cli/options/debug.rb",
    "lib/hipe-cli/options/help.rb",
    "lib/hipe-cli/predicates/gets_opened.rb",
    "lib/hipe-cli/predicates/is_jsonesque.rb",
    "lib/hipe-cli/predicates/must_exist.rb",
    "lib/hipe-cli/predicates/must_match_regex.rb",
    "spec/argv.rb",
    "spec/basics_spec.rb",
    "spec/fakes/plugind.rb",
    "spec/fakes/some-plugin-empty.rb",
    "spec/fakes/some-plugin.rb",
    "spec/fixtures/dummy-file-2.txt",
    "spec/fixtures/dummy-file.txt",
    "spec/spec.opts",
    "spec/FOCUS.rb",
    "spec/plugin_speg.rb",
    "spec/test-strap.rb",
    "spec/validations_speg.rb"
  ]
  s.has_rdoc = false
  s.homepage = %q{http://github.com/hipe/hipe-cli}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Getopt plus validations and help screen generation}
  s.test_files = [
    "spec/FOCUS.rb",
    "spec/argv.rb",
    "spec/basics_spec.rb",
    "spec/fakes/plugind.rb",
    "spec/fakes/some-plugin-empty.rb",
    "spec/fakes/some-plugin.rb",
    "spec/plugin_speg.rb",
    "spec/test-strap.rb",
    "spec/validations_speg.rb"
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
