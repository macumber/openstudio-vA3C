require 'rubygems'
require 'json'
require 'erb'

require_relative 'resources/va3c'

#start the measure
class ViewData < OpenStudio::Ruleset::ReportingUserScript
  
  #define the name that a user will see
  def name
    return "ViewData"
  end
  
  # human readable description
  def description
    return "Visualize energy simulation data plotted on an OpenStudio model in a web based viewer"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Converts the OpenStudio model to vA3C JSON format and renders using Three.js, simulation data is applied to surfaces of the model"
  end
  
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return result
    end
    
    variable_name = runner.getStringArgumentValue('variable_name',user_arguments)
    reporting_frequency = runner.getStringArgumentValue('reporting_frequency',user_arguments)

    result << OpenStudio::IdfObject.load("Output:Variable,*,#{variable_name},#{reporting_frequency};").get

    return result
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    variable_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('variable_name', true)
    variable_name.setDisplayName('Variable Name')
    variable_name.setDefaultValue('Surface Outside Face Temperature')
    args << variable_name
    
    chs = OpenStudio::StringVector.new
    chs << 'Timestep'
    chs << 'Hourly'
    reporting_frequency = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('reporting_frequency', chs, true)
    reporting_frequency.setDisplayName('Reporting Frequency')
    reporting_frequency.setDefaultValue('Hourly')
    args << reporting_frequency
    
    return args
  end 
  
  def vector_to_array(vector)
    result = []
    (0...vector.size).each {|i| result << vector[i]}
    return result
  end
  
  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end
    
    variable_name = runner.getStringArgumentValue('variable_name',user_arguments)
    reporting_frequency = runner.getStringArgumentValue('reporting_frequency',user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get
    
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)
    
    env_period = nil
    sqlFile.availableEnvPeriods.each do |p|
      if 'WeatherRunPeriod'.to_EnvironmentType == sqlFile.environmentType(p).get
        env_period = p
        break
      end
    end
    
    if !env_period
      runner.registerError("No WeatherRunPeriods found in results")
      return false
    end
    runner.registerInfo("Gathering results for run period '#{env_period}'")
    
    sqlFile.availableVariableNames(env_period, reporting_frequency).each do |variable|
      runner.registerInfo("Available variable name '#{variable}'")
    end
    
    surface_data = []
    model.getPlanarSurfaces.each do |surface|
      surface_name = surface.name.to_s.upcase
      thermal_zone_name = nil
      if (space = surface.space) && !space.empty?
        if (thermal_zone = space.get.thermalZone) && !thermal_zone.empty?
          thermal_zone_name = thermal_zone.get.name.to_s.upcase
        end
      end
      surface_data << {'surface_name'=>surface_name, 'thermal_zone_name'=>thermal_zone_name, 'values'=>nil}
    end
   
    times = nil
    sqlFile.availableKeyValues(env_period, reporting_frequency, variable_name).each do |key|
      runner.registerInfo("Available key '#{key}' for variable name '#{variable_name}'")
      
      ts = sqlFile.timeSeries(env_period, reporting_frequency, variable_name, key).get
      
      if times.nil?
        times = vector_to_array(ts.daysFromFirstReport)
      end
      
      values = vector_to_array(ts.values)
      
      if i = surface_data.index{|s| s['surface_name'] == key}
        surface_data[i]['values'] = values
      else  
        surface_data.each do |s|
          if s['thermal_zone_name'] == key
            s['values'] = values
          end
        end
      end
    end
    
    # convert the model to vA3C JSON format
    json = VA3C.convert_model(model)
    json['times'] = times
    json['surface_data'] = surface_data

    # write json file
    json_out_path = "./report.json"
    File.open(json_out_path, 'w') do |file|
      file << JSON::generate(json, {:object_nl=>"\n", :array_nl=>"", :indent=>"  "})
      #file << JSON::generate(json, {:object_nl=>"", :array_nl=>"", :indent=>""})
      # make sure data is written to the disk one way or the other      
      begin
        file.fsync
      rescue
        file.flush
      end
    end
    
    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.in"
    if File.exist?(html_in_path)
        html_in_path = html_in_path
    else
        html_in_path = "#{File.dirname(__FILE__)}/report.html.in"
    end
    html_in = ""
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end
    
    # configure template with variable values
    os_data = JSON::generate(json, {:object_nl=>"", :array_nl=>"", :indent=>""})
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = "./report.html"
    File.open(html_out_path, 'w') do |file|
      file << html_out
      
      # make sure data is written to the disk one way or the other      
      begin
        file.fsync
      rescue
        file.flush
      end
    end
    
    #closing the sql file
    #sqlFile.close()

    #reporting final condition
    #runner.registerFinalCondition("Model written.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ViewData.new.registerWithApplication