source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem "hiera", :path => File.dirname(__FILE__), :require => false
gem 'deep_merge', :require => false

group :packaging do
  gem 'packaging', *location_for(ENV['PACKAGING_LOCATION'] || '~> 0.99')
end

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
