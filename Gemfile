source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem "hiera", :path => File.dirname(__FILE__), :require => false
gem 'deep_merge', :require => false

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake', "~> 10.1.0"
  gem 'rspec', "~> 3.3", :require => false
  gem "rspec-legacy_formatters", "~> 1.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'json', "~> 1.7", :require => false, :platforms => :ruby
  gem "yarjuf", "~> 2.0"
end


require 'yaml'
data = YAML.load_file(File.join(File.dirname(__FILE__), 'ext', 'project_data.yaml'))
bundle_platforms = data['bundle_platforms']
data['gem_platform_dependencies'].each_pair do |gem_platform, info|
  next if gem_platform =~ /mingw/
  if bundle_deps = info['gem_runtime_dependencies']
    bundle_platform = bundle_platforms[gem_platform] or raise "Missing bundle_platform"
    platform(bundle_platform.intern) do
      bundle_deps.each_pair do |name, version|
        gem(name, version, :require => false)
      end
    end
  end
end

platform(:mingw_19) do
  gem 'win32console', '~> 1.3.2', :require => false
end

mingw = [:mingw]
mingw << :x64_mingw if Bundler::Dsl::VALID_PLATFORMS.include?(:x64_mingw)

platform(*mingw) do
  gem 'win32-dir', '~> 0.4.8', :require => false
end
if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:ft=ruby
