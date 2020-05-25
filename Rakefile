require 'openstudio'
require 'open3'

task :test do
  failures = []
  
  measure_dir = File.join(File.dirname(__FILE__))
  measure_tests = Dir.glob(measure_dir + '/*/tests/*.rb')
  measure_tests.each do |measure_test|
    command = "'#{OpenStudio::getOpenStudioCLI}' '#{measure_test}'"
    puts command
    stdout_str, stderr_str, status = Open3.capture3(command)
    puts stderr_str if !stderr_str.empty?
    puts stdout_str
    STDOUT.flush
    
    if !status.success?
      failures << measure_test
    end
  end
  
  if !failures.empty?
    puts "The following tests failed"
    failures.each {|failure| puts failure}
    STDOUT.flush
    
    raise "#{failures.size} tests failed"
  end
end

task default: :test