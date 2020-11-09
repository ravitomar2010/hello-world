#/bin/bash

# repo=$1
# branch=$2
step_function=${stepFunction}
definition_stack=(${step_function})
state_stack=()
dag_file="/data/airflow/dags/${step_function}.py"
needStartAt=true
final_str=""

createDagFile(){

if [ -f ${dag_file} ]
then
        sudo rm ${dag_file}
fi
sudo tee -a ${dag_file} > /dev/null <<EOT
from datetime import timedelta
from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from airflow.operators.dummy_operator import DummyOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(2)
}
dag = DAG(
    '${step_function}',
    default_args=default_args,
    description='DAG for ${step_function}',
    schedule_interval=None
)

START = DummyOperator(task_id='start', dag=dag)

END = DummyOperator(task_id='end', dag=dag)

EOT
}

writeToFile(){
    current_state=$1
    path=$2
sudo tee -a ${dag_file} >> /dev/null <<EOT
${current_state} = BashOperator (
    task_id='${current_state}',
    depends_on_past=False,
    bash_command='python3 ${path}',
    dag=dag,
)
EOT
}

parallelBranchesHandle() {
branch_state_stack=()
index=0
branch=$(echo "${branches}" | jq .[0])
branches_str=""
while [[ ${branch} != null ]]
do
        echo ${branch}
        start_at=$(echo ${branch} | jq -r .StartAt)
        branch_state_stack+=(${start_at})
        parallel_str=""
        while [ ${#branch_state_stack[@]} -ne 0 ]
        do
                current_state_name=${branch_state_stack[-1]}
                unset branch_state_stack[-1]

                states=$(echo ${branch} | jq -r .States)
                parallel_state=$(echo ${branch} | jq -r .States."\"$current_state_name\"")
                parallel_next=$(echo ${parallel_state} | jq -r .Next)
                resource=$(echo ${parallel_state} | jq -r .Resource)

                if [[ ${resource} == *'arn:aws:lambda'* ]]
                then
                        echo "Current state ${current_state_name} invokes a lambda"
                        repo=$(echo ${resource} | cut -d'-' -f4-| rev | cut -d'-' -f2- | rev)
                        lambda=$(echo ${resource} | sed 's/:$LATEST//g' | rev | cut -d':' -f1 | cut -d'-' -f1 | rev)
                        
                        parallel_str+="${current_state_name} >> "
                        path="/data/lambdaPipeline/${repo}/lambda/${lambda}/$lambda.py"
                        writeToFile ${current_state_name} ${path}
                fi

                if [[ ${parallel_next} != null ]]
                then
                        branch_state_stack+=(${parallel_next})
                        exit
                else
                        break
                fi
        done

        index=`expr $index + 1`
        branch=$(echo "${branches}" | jq .[${index}])
        parallel_str=$(echo ${parallel_str} | sed '$ s/>>$//g')
        # parallel_str="[${parallel_str}]"
        # branches_str+="${parallel_str}"

        branches_str+="${parallel_str}, "
done
branches_str=$(echo ${branches_str} | sed '$ s/,$//g')
branches_str="[${branches_str}]"

final_str+="${branches_str} >> "
}


createDagFile

while [ ${#definition_stack[@]} -ne 0 ]
do
    step_function=${definition_stack[-1]}
    echo "Current step function: ${step_function}"
    sf_arn=$(aws stepfunctions list-state-machines --profile stage --query stateMachines[?name==\`${step_function}\`].stateMachineArn --output text)
    definition=$(aws stepfunctions describe-state-machine --state-machine-arn ${sf_arn} --profile stage --query definition --output json )
    definition=$(echo $definition | sed 's/\\n//g' | sed 's/\\t//g' | sed 's/\\//g' | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev )

    echo "definition stack: ${definition_stack[@]}"
    if [ ${needStartAt} == true ]
    then
        echo "need start at: ${needStartAt}"
        start_at=$(echo "$definition" | jq -r '.StartAt')
        state_stack+=(${start_at})
        echo "Updated state_stack. state stack= ${state_stack[@]}"
    fi

    needStartAt=false

    while [ ${#state_stack[@]} -ne 0 ]
    do
        echo "-------------------------------------------------------------------------"
        current_state=${state_stack[-1]}
        unset state_stack[-1]
        state=$(echo $definition | jq -r .States."\"$current_state\"")

        #check for branches
        branches=$(echo $state | jq -r .Branches)
        if [[ ${branches} != null ]]
        then
            parallelBranchesHandle

            next=$(echo $state | jq -r .Next)
            if [ ${next} != null ]
            then
                state_stack+=(${next})
            else
                #pop def stack
                unset definition_stack[-1]
            fi
        else
            resource=$(echo $state | jq -r .Resource)
            next=$(echo $state | jq -r .Next)

            if [ ${next} != null ]
            then
                state_stack+=(${next})
            else
                #pop def stack
                unset definition_stack[-1]
            fi

            if [[ ${resource} == *'arn:aws:lambda'* ]]
            then
                echo "Current state ${current_state} invokes a lambda"
                repo=$(echo ${resource} | cut -d'-' -f4-| rev | cut -d'-' -f2- | rev)
                lambda=$(echo ${resource} | sed 's/:$LATEST//g' | rev | cut -d':' -f1 | cut -d'-' -f1 | rev)
                #echo "${lambda}"
                final_str+="${current_state} >> "
                path="/data/lambdaPipeline/${repo}/lambda/${lambda}/$lambda.py"
                writeToFile ${current_state} ${path}

            elif [ ${resource} == "arn:aws:states:::lambda:invoke" ]
            then
                function_name=$(echo $state | jq -r .Parameters.FunctionName)
                repo=$(echo ${resource} | cut -d'-' -f4-| rev | cut -d'-' -f2- | rev)
                lambda=$(echo ${function_name} | sed 's/:$LATEST//g' | rev | cut -d':' -f1 | cut -d'-' -f1 | rev)
                final_str+="${current_state} >> "
                path="/data/lambdaPipeline/${repo}/lambda/${lambda}/$lambda.py"
                writeToFile ${current_state} ${path}

            else
                #echo "Found nested sf"
                state_machine_arn=$(echo $state | jq -r .Parameters.StateMachineArn)
                next_step_function_name=$(echo ${state_machine_arn} | sed 's/:$LATEST//g' | rev | cut -d':' -f1 | rev)
                #echo "next_step_function_name: ${next_step_function_name}"
                definition_stack+=(${next_step_function_name})
                #echo "Updated definition stack"
                #echo "def_stack: ${definition_stack[@]}"
                needStartAt=true
                # break
            fi
        fi

        if [[ ${needStartAt} == true || ${next} == null ]]
        then
            break
        fi
    done

    echo "START >> ${final_str} END" | sudo tee -a ${dag_file} >> /dev/null
    # if [ ${#state_stack[@]} -eq 0 ]
    # then
    #     break
    # fi
done