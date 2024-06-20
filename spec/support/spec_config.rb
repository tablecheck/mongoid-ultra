# frozen_string_literal: true

require 'mongo'
require 'singleton'

class SpecConfig
  include Singleton

  DEFAULT_MONGODB_URI = 'mongodb://127.0.0.1:27017'

  def initialize
    if ENV['MONGODB_URI']
      @uri_str = ENV['MONGODB_URI']
    else
      warn "Environment variable 'MONGODB_URI' is not set, so the default url will be used."
      warn 'This may lead to unexpected test failures because service discovery will raise unexpected warnings.'
      warn 'Please consider providing the correct uri via MONGODB_URI environment variable.'
      @uri_str = DEFAULT_MONGODB_URI
    end

    @uri = Mongo::URI.get(@uri_str)
  end

  attr_reader :uri_str, :uri

  def addresses
    @uri.servers
  end

  def mri?
    !jruby?
  end

  def jruby?
    RUBY_PLATFORM.match?(/\bjava\b/)
  end

  def windows?
    ENV['OS'] == 'Windows_NT' && !RUBY_PLATFORM.match?(/cygwin/)
  end

  def platform
    RUBY_PLATFORM
  end

  def client_debug?
    %w[1 true yes].include?(ENV['CLIENT_DEBUG']&.downcase)
  end

  def app_tests?
    %w[0 false no].exclude?(ENV['APP_TESTS']&.downcase)
  end

  def ci?
    !!ENV['CI']
  end

  def atlas?
    !!ENV['ATLAS_URI']
  end

  def rails_version
    ENV['RAILS'].presence || '6.1'
  end

  # Scrapes the output of `gem list` to find which versions of Rails are
  # installed, and looks for first one that best matches whatever rails version
  # was requested (see `#rails_version`).
  #
  # @return [ String | nil ] the version of the requested Rails install, or
  #    nil if nothing matches.
  def installed_rails_version
    output = `gem list --exact rails`
    return unless output =~ /^rails \((.*)\)/

    versions = ::Regexp.last_match(1).split(/,\s*/)
    rails_version_re = /^#{rails_version}(?:\..*)?$/
    versions.detect { |v| v =~ rails_version_re }
  end
end
