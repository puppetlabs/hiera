source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem "hiera", :path => File.dirname(__FILE__), :require => false

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake', "~> 10.1.0"
  gem 'rspec', "~> 2.11.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'json', "~> 1.7", :require => false, :platforms => :ruby
  gem "yarjuf", "~> 1.0"
end

platform :mswin, :mingw do
  gem "ffi", "1.9.0", :require => false
  gem "win32-api", "1.4.8", :require => false
  gem "win32-dir", "0.4.3", :require => false
  gem "windows-api", "0.4.2", :require => false
  gem "windows-pr", "1.2.2", :require => false
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:ft=ruby
