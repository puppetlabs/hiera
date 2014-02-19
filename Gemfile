source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem "hiera", :path => File.dirname(__FILE__), :require => false

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake'
  gem 'rspec', "~> 2.11.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'json', "~> 1.7", :require => false, :platforms => :ruby
  gem "yarjuf", "~> 1.0"
end


require 'yaml'
data = YAML.load_file(File.join(File.dirname(__FILE__), 'ext', 'project_data.yaml'))
bundle_platforms = data['bundle_platforms']
data['gem_platform_dependencies'].each_pair do |gem_platform, info|
  if bundle_deps = info['gem_runtime_dependencies']
    bundle_platform = bundle_platforms[gem_platform] or raise "Missing bundle_platform"
    platform(bundle_platform.intern) do
      bundle_deps.each_pair do |name, version|
        gem(name, version, :require => false)
      end
    end
  end
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:ft=ruby
