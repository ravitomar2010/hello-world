#!/bin/bash

echo "Started executor job"

#######################################################################
########################### Global Variables ##########################
#######################################################################

# profile='stage'
# client='axiom'
# startingPoint='executeForecastJob'
#######################################################################
############################# Generic Code ############################
#######################################################################

setEnv(){
	branchName=`echo ${GIT_BRANCH} | cut -d '/' -f2`

  if [[ $branchName == 'master' ]]; then
    env='prod'
  else
    env='stage'
  fi
  echo "Working on $env environment"

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

prepareVirtualEnv(){

  echo "Preparing virtual env for $env"

  echo "Installing python3-venv if it doesn't exists"

  sudo apt-get install python3-venv -y

  echo "Installing required library for execution"

  sudo apt-get install libpq-dev python-dev -y

  echo "Preparing Virtual environment for ${env}-df"

  python3 -m venv ${env}-df

  echo "Activating Virtual environment /data/venvs/${env}-forecast"

  echo "Installing all dependencies in Virtual environment ${env}-df"

  sudo -H /data/venvs/${env}-df/bin/pip install -r ./scripts/requirements.txt

}

executeImportJob(){
  echo "Executing Forecast Input job "
	if [[ $parameter == '' ]]; then
		echo 'no parameter defined for predictor job ... moving ahead with default'
		/data/venvs/${env}-forecast/bin/python3 ./scripts/aws_forecast_input.py $branchName
	else
		echo "No parameter required for forecast input job - ignoring the provided parameter"
		/data/venvs/${env}-forecast/bin/python3 ./scripts/aws_forecast_input.py $branchName
		parameter=''
	fi
	parameter=''
  echo "Switching to predictor job"
  executePredictorJob
}

executePredictorJob(){
    echo "Executing predictor job "

      if [[ $parameter == '' ]]; then
        echo 'no parameter defined for predictor job ... moving ahead with default'
        /data/venvs/${env}-forecast/bin/python3 ./scripts/aws_predictor.py $branchName
      else
        echo "Working on parameter $parameter"
        /data/venvs/${env}-forecast/bin/python3 ./scripts/aws_predictor.py $branchName $parameter
        parameter=''
      fi

    echo "Switching to forecast job"
    executeForecastJob
}

executeForecastJob(){
    echo "Executing Forecast job "

      if [[ $parameter == '' ]]; then
				echo 'no parameter defined for forecast job ... moving ahead with default'
        /data/venvs/${env}-forecast/bin/python3 ./scripts/aws_predictor.py $branchName
      else
        echo "Working on parameter $parameter"
				/data/venvs/${env}-forecast/bin/python3 ./scripts/aws_predictor.py $branchName $parameter
        parameter=''
      fi

    echo "Switching to forcast Export job"
    executeOutputJob
}

executeOutputJob(){
  echo "Executing Forecast Export job "

    if [[ $parameter == '' ]]; then
			echo 'no parameter defined for forecast export job ... moving ahead with default'
      /data/venvs/${env}-forecast/bin/python3 ./scripts/aws_forecast_output.py $branchName
    else
      echo "Working on parameter $parameter"
      /data/venvs/${env}-forecast/bin/python3 ./scripts/aws_forecast_output.py $branchName $parameter
      parameter=''
    fi

}

#######################################################################
############################# Main Function ###########################
#######################################################################

setEnv
prepareVirtualEnv
$startingPoint
