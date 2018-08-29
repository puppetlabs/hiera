begin
  require 'packaging'
  Pkg::Util::RakeUtils.load_packaging_tasks
rescue LoadError => e
  puts "Error loading packaging rake tasks: #{e}"
end

begin
  require 'rubygems'
  require 'rspec/core/rake_task'
rescue LoadError
end

Dir['tasks/**/*.rake'].each { |t| load t }

namespace :package do
  task :bootstrap do
    puts 'Bootstrap is no longer needed, using packaging-as-a-gem'
  end
  task :implode do
    puts 'Implode is no longer needed, using packaging-as-a-gem'
  end
end

task :spec do
  sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
end

task :test => :spec

desc "verify that commit messages match CONTRIBUTING.md requirements"
task(:commits) do
  # This git command looks at the summary from every commit from this branch not in master.
  # Ideally this would compare against the branch that a PR is submitted against, but I don't
  # know how to get that information. Absent that, comparing with master should work in most cases.
  %x{git log --no-merges --pretty=%s master..$HEAD}.each_line do |commit_summary|
    # This regex tests for the currently supported commit summary tokens: maint, doc, packaging, or hi-<number>.
    # The exception tries to explain it in more full.
    if /^\((maint|doc|packaging|hi-\d+)\)|revert/i.match(commit_summary).nil?
      raise "\n\n\n\tThis commit summary didn't match CONTRIBUTING.md guidelines:\n" \
        "\n\t\t#{commit_summary}\n" \
        "\tThe commit summary (i.e. the first line of the commit message) should start with one of:\n"  \
        "\t\t(hi-<digits>) # this is most common and should be a ticket at tickets.puppetlabs.com\n" \
        "\t\t(doc)\n" \
        "\t\t(maint)\n" \
        "\t\t(packaging)\n" \
        "\n\tThis test for the commit summary is case-insensitive.\n\n\n"
    end
  end
end

task :default do
  sh 'rake -T'
end
