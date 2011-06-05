def run_all_specs
    files = Dir.glob("spec/unit/**/*spec.rb")
    system("rspec -c #{files.join ' '}")
end

watch('spec/unit/.+spec.rb') { run_all_specs }
watch('lib/.+rb') { run_all_specs }
