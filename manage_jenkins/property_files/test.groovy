def command = ''
def profile = 'stage'
//startingPoint='executeForecastJob'
if(startingPoint=='executeImportJob') {
     return ['No Parameter Needed']
} else if(startingPoint=='executePredictorJob') {
    command = 'aws forecast list-dataset-groups --profile '+ profile
} else if(startingPoint=='executeForecastJob') {
    command = 'aws forecast list-predictors --output json --profile '+profile
} else {
    command = 'aws forecast list-forecasts --profile '+ profile
}

def proc = command.execute()
proc.waitFor()

def output = proc.in.text
def exitcode= proc.exitValue()
def error = proc.err.text

if (error) {
	println "Std Err: ${error}"
	println "Process exit code: ${exitcode}"
	return exitcode
}

//println output

def listToReturn = []
lines = output.readLines()
count=0;
for (String line : lines) {

    if (line.contains('DatasetGroupName') && startingPoint=='executePredictorJob' ){
        listToReturn.add(line.split(':')[1].split(',')[0].split('"')[1])
    }else if (line.contains('PredictorName') && startingPoint=='executeForecastJob' ){
        listToReturn.add(line.split(':')[1].split(',')[0].split('"')[1])
    }else if (line.contains('ForecastName') && startingPoint=='executeOutputJob' ){
        listToReturn.add(line.split(':')[1].split(',')[0].split('"')[1])
    }

}

return listToReturn
