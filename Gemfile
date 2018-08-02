source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem "hiera", :path => File.dirname(__FILE__), :require => false
gem 'deep_merge', :require => false

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake'
  gem 'rspec', "~> 3.3", :require => false
  gem "rspec-legacy_formatters", "~> 1.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem "yarjuf", "~> 2.0"
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:ft=ruby
