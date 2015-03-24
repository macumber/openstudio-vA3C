require 'rubygems'
require 'json'

require_relative 'resources/va3c'

#start the measure
class ViewModel < OpenStudio::Ruleset::ReportingUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ViewModel"
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method
  
  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get
    
    #sqlFile = runner.lastEnergyPlusSqlFile
    #if sqlFile.empty?
    #  runner.registerError("Cannot find last sql file.")
    #  return false
    #end
    #sqlFile = sqlFile.get
    #model.setSqlFile(sqlFile)
    
    # convert the model to va3c JSON format
    json = Va3c.convert_model(model)

    # write json file
    json_out_path = "./report.json"
    File.open(json_out_path, 'w') do |file|
      file << JSON::generate(json, {:object_nl=>"\n", :array_nl=>"", :indent=>"  "})
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
    runner.registerFinalCondition("Goodbye.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ViewModel.new.registerWithApplication