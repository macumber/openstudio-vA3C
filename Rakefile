require 'bundler'
Bundler.setup

require 'rake'
require 'rest-client'

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
  
end

task :default => [:build]