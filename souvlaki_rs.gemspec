# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __DIR__)
require 'souvlaki_rs/version'

Gem::Specification.new do |s|
  s.name               = 'souvlaki_rs'
  s.version            = SouvlakiRS::VERSION
  s.platform           = Gem::Platform::RUBY
  s.default_executable = 'srs_fetch'

  s.required_ruby_version = '>= 3.0.0'
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=

  s.authors = ['Ed Porras']
  s.email = 'technical@wgot.org'
  s.date = SouvlakiRS::RELEASE_DATE
  s.summary = "Tools for managing WGOT-LP's syndicated fetching and import"
  s.description = 'Scripts for managing auto fech of files and dropbox import'
  s.license = 'MIT'

  s.files = `git ls-files`.split("\n")
                          .reject { |f| f =~ /\.gem/ }
                          .reject { |f| f =~ /\.txt/ }
                          .reject { |f| f =~ /\.edn/ }

  s.executables = ['srs_fetch']
  s.homepage = 'http://rubygems.org/gems/souvlaki_rs'
  s.require_paths = ['lib']
  s.rubygems_version = '1.6.2'

  s.add_dependency('edn', '~> 1.1')
  s.add_dependency('listen', '~> 3.0')
  s.add_dependency('mail', '~> 2.6')
  s.add_dependency('mechanize', '~> 2.7')
  s.add_dependency('ruby-filemagic', '~> 0.7')
  s.add_dependency('syslogger', '~> 1.6')
  s.add_dependency('taglib-ruby', '~> 0.7')

  if s.respond_to? :specification_version
    s.specification_version = 3
  end
end
