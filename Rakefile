#require 'bundler'
#Bundler.setup

require 'rake'
require 'rest-client'
require 'fileutils'
require 'open3'

begin
  require_relative 'config'
rescue LoadError
  require 'openstudio'
  $OPENSTUDIO_EXE = OpenStudio::getOpenStudioCLI
end

def get_clean_env
  new_env = {}
  new_env['BUNDLER_ORIG_MANPATH'] = nil
  new_env['BUNDLER_ORIG_PATH'] = nil
  new_env['BUNDLER_VERSION'] = nil
  new_env['BUNDLE_BIN_PATH'] = nil
  new_env['RUBYLIB'] = nil
  new_env['RUBYOPT'] = nil
  new_env['GEM_PATH'] = nil
  new_env['GEM_HOME'] = nil
  new_env['BUNDLE_GEMFILE'] = nil
  new_env['BUNDLE_PATH'] = nil
  new_env['BUNDLE_WITHOUT'] = nil
  
  return new_env
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
  stdout_str, stderr_str, status = Open3.capture3(get_clean_env, cmd)
end

desc 'Run Measure Tests'
task :test do

  Dir.chdir("#{File.join(File.dirname(__FILE__), 'ViewModel/tests/')}")
  cmd = "\"#{$OPENSTUDIO_EXE}\" ViewModel_Test.rb"
  puts cmd
  view_model_stdout, view_model_stderr, status = Open3.capture3(get_clean_env, cmd)
  view_model_result = status.success?
  
  Dir.chdir("#{File.join(File.dirname(__FILE__), 'ViewData/tests/')}")
  cmd = "\"#{$OPENSTUDIO_EXE}\" ViewData_Test.rb"
  puts cmd
  view_data_stdout, view_data_stderr, status = Open3.capture3(get_clean_env, cmd)
  view_data_result = status.success?
  
  puts view_model_stdout if !view_model_result
  puts view_data_stdout if !view_data_result
  puts "Test failed" if !(view_model_result && view_data_result)
end

task :default => [:build, :test]