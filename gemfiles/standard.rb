def standard_dependencies
  gem 'rake'

  group :development do
    gem 'yard'

  end

  group :development, :test do
    gem 'rspec', '~> 3.12'

    platform :mri do
      gem 'byebug'
    end

    platform :jruby do
      gem 'ruby-debug'
    end
  end

  group :test do
    gem 'timecop'
    gem 'rspec-retry'
    gem 'benchmark-ips'
    gem 'fuubar'
    gem 'rfc'
    gem 'childprocess'
    gem 'puma' # for app tests

    platform :mri do
      gem 'timeout-interrupt'
    end
  end
end
