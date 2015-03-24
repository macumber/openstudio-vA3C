require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'fileutils'

require 'minitest/autorun'

class ViewModel_Test < MiniTest::Test
    
  # paths to expected test files, includes osm and eplusout.sql
  def modelPath
    #return "#{File.dirname(__FILE__)}/SimpleModel.osm"
    return "#{File.dirname(__FILE__)}/ExampleModel.osm"
  end
  
  def runDir
    #return "#{File.dirname(__FILE__)}/SimpleModel/"
    return "#{File.dirname(__FILE__)}/ExampleModel/"
  end
  
  def sqlPath
    #return "#{File.dirname(__FILE__)}/SimpleModel/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
    return "#{File.dirname(__FILE__)}/ExampleModel/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
  end
  
  def reportPath
    return "./output/report.json"
  end
  
  # create test files if they do not exist
  def setup

    if File.exist?(reportPath())
      FileUtils.rm(reportPath())
    end
    
    assert(File.exist?(modelPath()))
    
    #assert(File.exist?(runDir()))
    
    # DLM: we do not need sql data 
    #if not File.exist?(sqlPath())
    #  puts "Running EnergyPlus"
    #  
    #  co = OpenStudio::Runmanager::ConfigOptions.new(true)
    #  co.findTools(false, true, false, true)
    #  
    #  wf = OpenStudio::Runmanager::Workflow.new("modeltoidf->energypluspreprocess->energyplus")
    #  wf.add(co.getTools())
    #  job = wf.create(OpenStudio::Path.new(runDir()), OpenStudio::Path.new(modelPath()))
    #
    #  rm = OpenStudio::Runmanager::RunManager.new
    #  rm.enqueue(job, true)
    #  rm.waitForFinished
    #end
  end

  # delete output files
  def teardown
  
    # comment this out if you don't want to rerun EnergyPlus each time
    if File.exist?(sqlPath())
      #FileUtils.rm(sqlPath())
    end
    
    # comment this out if you want to see the resulting report
    if File.exist?(reportPath())
      #FileUtils.rm(reportPath())
    end
  end
  
  # the actual test
  def test_ViewModel
     
    assert(File.exist?(modelPath()))
    #assert(File.exist?(sqlPath()))
     
    # create an instance of the measure
    measure = ViewModel.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments()
    assert_equal(0, arguments.size)
    
    # set up runner, this will happen automatically when measure is run in PAT
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(modelPath()))    
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sqlPath()))    
    
    current_dir = Dir.pwd
    run_dir = File.dirname(__FILE__) + "/output"
    FileUtils.rm_rf(run_dir) if File.exists?(run_dir)
    FileUtils.mkdir_p(run_dir)
    Dir.chdir(run_dir)
    
    # set argument values to good values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    #assert(result.info.size == 1)
    
    Dir.chdir(current_dir)
    
    assert(File.exist?(reportPath()))
    
    # load the output in http://threejs.org/editor/ to test
    
  end  

end
