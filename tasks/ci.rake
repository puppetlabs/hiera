require 'yaml'
require 'time'

namespace "ci" do
  task :spec do
    ENV["LOG_SPEC_ORDER"] = "true"
    sh %{rspec -r yarjuf -f JUnit -o result.xml -fp spec}
  end

  desc "Tar up the acceptance/ directory so that package test runs have tests to run against."
  task :acceptance_artifacts => :tag_creator do
    rm_f "acceptance/acceptance-artifacts.tar.gz"
    sh "tar -czv --exclude acceptance/.bundle -f acceptance-artifacts.tar.gz acceptance schema"
  end

  task :tag_creator do
    Dir.chdir("acceptance") do
      File.open('creator.txt', 'w') do |fh|
        YAML.dump({
          'creator_id' => ENV['CREATOR'] || ENV['BUILD_URL'] || 'unknown',
          'created_on' => Time.now.iso8601,
          'commit' => (`git log -1 --oneline` rescue "unknown: #{$!}")
        }, fh)
      end
    end
  end
end
