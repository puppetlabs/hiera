source "https://rubygems.org"

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake'
  gem 'rspec', "~> 2.11.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'json', "~> 1.7", :require => false
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
