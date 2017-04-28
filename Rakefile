require 'bundler'
Bundler.setup

require 'rake'
require 'rest-client'
require 'fileutils'

begin
  require_relative 'config'
rescue LoadError
  $OPENSTUDIO_EXE = 'openstudio'
end

desc 'Build html files for measures and OS App'
task :build do

  in_file = ""
  app_file = ""
  removing = false
  File.open('report.html.in', 'r') do |file|
    file.each_line do |line|

      if md = /<script\s*src=\"(.*?)\"><\/script>/.match(line)
        url = md[1].gsub('https', 'http')
        request = RestClient::Resource.new(url)
        response = request.get
        line = "<script>#{response}</script>\n"
      end
      
      in_file += line
      
      if /\/\/ BEGIN_REMOVE/.match(line)
        removing = true
        next
      elsif /\/\/ END_REMOVE/.match(line)
        removing = false
        next
      elsif removing
        next
      end
      
      app_file += line 
      
    end
  end
  
  File.open(File.join(File.dirname(__FILE__), 'ViewModel/resources/report.html.in'), 'w') do |file|
    file << in_file
  end

  File.open(File.join(File.dirname(__FILE__), 'ViewData/resources/report.html.in'), 'w') do |file|
    file << in_file
  end
  
  File.open(File.join(File.dirname(__FILE__), 'geometry_preview.html'), 'w') do |file|
    file << app_file
  end
  
  FileUtils.cp('va3c.rb', File.join(File.dirname(__FILE__), 'ViewModel/resources/va3c.rb'))
  
  FileUtils.cp('va3c.rb', File.join(File.dirname(__FILE__), 'ViewData/resources/va3c.rb'))
  
  cmd = "\"#{$OPENSTUDIO_EXE}\" measure --update_all ."
  puts cmd
  system(cmd)
end

desc 'Run Measure Tests'
task :test do

  Dir.chdir("#{File.join(File.dirname(__FILE__), 'ViewModel/tests/')}")
  cmd = "\"#{$OPENSTUDIO_EXE}\" ViewModel_Test.rb"
  puts cmd
  view_model_result = system(cmd)
  
  Dir.chdir("#{File.join(File.dirname(__FILE__), 'ViewData/tests/')}")
  cmd = "\"#{$OPENSTUDIO_EXE}\" ViewData_Test.rb"
  puts cmd
  view_data_result = system(cmd)  
  
  puts "Test failed" if !(view_model_result && view_data_result)
end

task :default => [:build, :test]