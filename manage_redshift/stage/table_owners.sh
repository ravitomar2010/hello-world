#!/bin/bash
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_stage/rootpassword" --with-decryption --profile stage --output text --query Parameter.Value`
hostname=axiom-rnd-dwh.hyke.ai
user=axiom_rnd
tableListSql="select schemaname,tablename,tableowner from pg_tables where schemaname not like 'pg_catalog' and schemaname not like 'information_schema' and schemaname not like 'public'"

initBaseDB(){
	filename=tmptablelist3.txt
	dbname=axiom_rnd

	echo "Getting table list from redshift"
	psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$tableListSql" > tmptablelist.txt

	cat "" > tmpsqlfile.txt

	cat tmptablelist.txt | tail -n +3  > tmptablelist2.txt
	nooflines=`cat tmptablelist2.txt | wc -l`
	#echo "no of lines are $nooflines"
	expectednooflines=$(( nooflines - 2 ))
	#echo "Expected no of lines are $expectednooflines"
	head -n $expectednooflines tmptablelist2.txt  > tmptablelist3.txt

	while read line; do
		if [[ $line == "" ]]; then	 #if1
		    echo "Skipping empty line"
	  else
	      #echo "line is $line"
				schemaName=`echo $line | cut -d '|' -f1`
				#echo "schemaname is $schemaName"
				tableName=`echo $line | cut -d '|' -f2`
				#echo "TableName is $tableName"
				tableOwner=`echo $line | cut -d '|' -f3`
				#echo "tableowner is $tableOwner"
				checkOwners $schemaName $tableName $tableOwner
				#transferOwnership
	  fi
	  done < $filename

		transferOwnership
}

initHykeDB(){
	filename=tmptablelist6.txt
	dbname=hyke

	echo "Getting table list from redshift"
	psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$tableListSql" > tmptablelist4.txt

	cat "" > tmpsqlfile.txt

	cat tmptablelist4.txt | tail -n +3  > tmptablelist5.txt
	nooflines=`cat tmptablelist5.txt | wc -l`
	#echo "no of lines are $nooflines"
	expectednooflines=$(( nooflines - 2 ))
	#echo "Expected no of lines are $expectednooflines"
	head -n $expectednooflines tmptablelist5.txt  > tmptablelist6.txt

	while read line; do
		if [[ $line == "" ]]; then	 #if1
		    echo "Skipping empty line"
	  else
	      #echo "line is $line"
				schemaName=`echo $line | cut -d '|' -f1`
				#echo "schemaname is $schemaName"
				tableName=`echo $line | cut -d '|' -f2`
				#echo "TableName is $tableName"
				tableOwner=`echo $line | cut -d '|' -f3`
				#echo "tableowner is $tableOwner"
				checkOwners $schemaName $tableName $tableOwner
				#transferOwnership
	  fi
	  done < $filename

		transferOwnership
}

checkOwners(){
	local_schemaName=$1
	local_tableName=$2
	local_tableOwner=$3

	#echo "Working on $local_tableName"

	if [[ $local_schemaName == *"dbo"* ]]; then
		temp_schema_name=`echo $local_schemaName | rev | cut -c 5- | rev`
    #userentryflag=`cat users_list.txt  | grep "batch_$temp_schema_name" | wc -l`
		expectedOwner="batch_$temp_schema_name"
		#echo "ExpectedOwner is $expectedOwner for table $local_tableName in schema $local_schemaName"
	elif [[ $local_schemaName == *"stage"* ]]; then
		temp_schema_name=`echo $local_schemaName | rev | cut -c 7- | rev`
    #userentryflag=`cat users_list.txt  | grep "batch_$temp_schema_name" | wc -l`
		expectedOwner="batch_$temp_schema_name"
		#echo "ExpectedOwner is $expectedOwner for table $local_tableName in schema $local_schemaName"
	else
		temp_schema_name=`echo $local_schemaName`
		expectedOwner="batch_$temp_schema_name"
		#echo "ExpectedOwner is $expectedOwner for table $local_tableName in schema $local_schemaName"
	fi

	if [[ $expectedOwner == $local_tableOwner ]]; then
			#echo "Working in schema $local_schemaName owner matching to $expectedOwner"
			echo " "
	else
			#echo "Schema name is $local_schemaName Expected user is $expectedOwner but actual owner is $local_tableOwner"
			sql="alter table $local_schemaName.$local_tableName owner to $expectedOwner;"
			echo "SQL is $sql"
			echo "$sql" >> tmpsqlfile.txt
	fi

}

transferOwnership(){
	echo "Transferring Ownership for dbname $dbname"
	psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -f tmpsqlfile.txt
}
################################################################
################### Initiation #################################
################################################################

initBaseDB
initHykeDB

echo "Cleanup"
rm -rf tmp*
