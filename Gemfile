source "http://rubygems.org"
gemspec

gem "moped"
gem "mongoid_monkey"
gem "ruby_dep", "~> 1.3.0"
gem "listen", "~> 2.0"
gem 'rake', '< 11.0'

group :test do
  gem "rspec", "~> 2.12"

  unless ENV["CI"]
    gem "guard"
    gem "guard-rspec"
    gem "rb-fsevent"
  end
end
