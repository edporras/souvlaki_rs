# frozen_string_literal: true

require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name               = 'souvlaki_rs'
  s.version            = SouvlakiRS::VERSION
  s.platform           = Gem::Platform::RUBY

  s.required_ruby_version = '>= 3.1.0'
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.metadata = { 'rubygems_mfa_required' => 'true' }

  s.authors = ['Ed Porras']
  s.email = 'technical@wgot.org'
  s.summary = "Tools for managing WGOT-LP's syndicated fetching and import"
  s.license = 'MIT'

  s.files = `git ls-files`.split("\n")
                          .grep_v('.gem')
                          .grep_v('.txt')
                          .grep_v('.edn')

  s.executables = %w[srs_fetch]
  s.homepage = 'http://rubygems.org/gems/souvlaki_rs'
  s.require_paths = ['lib']

  s.add_dependency('edn', '~> 1.1')
  s.add_dependency('mail', '~> 2.7')
  s.add_dependency('mechanize', '~> 2.8')
  s.add_dependency('net-smtp', '~> 0.3')
  s.add_dependency('rss', '~> 0.2')
  s.add_dependency('ruby-filemagic', '~> 0.7')
  s.add_dependency('syslogger', '~> 1.6')
  s.add_dependency('taglib-ruby', '~> 1.1')

  s.add_development_dependency('bundler', '~> 2.3')
  s.add_development_dependency('pry-byebug', '~> 3.10')
  s.add_development_dependency('rake', '~> 13.0')
  s.add_development_dependency('rubocop', '~> 1.31')
  s.add_development_dependency('shoulda-context', '~> 2.0')
  s.add_development_dependency('test-unit', '~> 3.5')
end
