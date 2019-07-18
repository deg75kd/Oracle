#!/bin/bash

export ORACLE_BASE="/app/oracle"
vHome12c="${ORACLE_BASE}/product/db/12c/1"
vHome11g="${ORACLE_BASE}/product/db/11g/1"
vCDBPrefix="c"
MAXNAMELENGTH=8

# show running databases
/app/oracle/scripts/pmonn.pm

##################################################### prompts #####################################################

# Prompt for DB version
echo ""
echo -e "Select the Oracle version for this database: (a) 12c (b) 11g \c"
while true
do
	read vReadVersion
	if [[ "$vReadVersion" == "A" || "$vReadVersion" == "a" ]]
	then
		# set Oracle home
		export ORACLE_HOME=$vHome12c
		vDBVersion=12
		echo "You have selected Oracle version 12c"
		echo "The Oracle Home has been set to $vHome12c"
		break
	elif [[ "$vReadVersion" == "B" || "$vReadVersion" == "b" ]]
	then
		# set Oracle home
		export ORACLE_HOME=$vHome11g
		vDBVersion=11
		echo "You have selected Oracle version 11g"
		echo "The Oracle Home has been set to $vHome11g"
		break
	else
		echo -e "Select a valid database version: \c"  
	fi
done

# Prompt for DB name
echo ""
if [[ $vDBVersion -eq 12 ]]
then
	echo -e "Enter the pluggable database name: \c"
else
	echo -e "Enter the database name: \c"
fi
while true
do
	read vNewDB
	if [[ -n "$vNewDB" ]]
	then
		vPDBName=`echo $vNewDB | tr 'A-Z' 'a-z'`
		echo "The database name is $vPDBName"
		break
	else
		echo -e "Enter a valid database name: \c"  
	fi
done

# prompt for CDB name
if [[ $vDBVersion -eq 12 ]]
then
	echo ""
	echo -e "Enter the CDB name: \c"  
	while true
	do
		read vNewCDB
		if [[ -n "$vNewCDB" ]]
		then
			vCDBName=`echo $vNewCDB | tr 'A-Z' 'a-z'`
			echo "The CDB name is $vCDBName"
			break
		else
			echo -e "Enter a valid database name: \c"  
		fi
	done
	export ORACLE_SID=$vCDBName
else
	export ORACLE_SID=$vPDBName
fi

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "WARNING:"
if [[ $vDBVersion -eq 12 ]]
then
	echo "This will DROP cdb $vCDBName and $vPDBName"
else
	echo "This will DROP the database $vPDBName"
fi
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
echo -e "Do you wish to continue? (Y) or (N) \c"
while true
do
	read vConfirm
	if [[ "$vConfirm" == "Y" || "$vConfirm" == "y" ]]
	then
		echo "Continuing..."  | tee -a $vOutputLog
		break
	elif [[ "$vConfirm" == "N" || "$vConfirm" == "n" ]]
	then
		echo " "
		echo "Exiting at user's request..."  | tee -a $vOutputLog
		exit 2
	else
		echo -e "Please enter (Y) or (N).\c"  
	fi
done

##################################################### drop database #####################################################

unset LIBPATH
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib
echo "================================"
echo "Your Oracle Environment Settings:"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "ORACLE_SID            = ${ORACLE_SID}"
echo "ORACLE_HOME           = ${ORACLE_HOME}"
echo "TNS_ADMIN             = ${TNS_ADMIN}"
echo "LD_LIBRARY_PATH       = ${LD_LIBRARY_PATH}"
echo ""

if [[ $vDBVersion -eq 12 ]]
then
	# Drop pluggable and container databases
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
shutdown immediate;
startup;
select name, dbid, created from v\$database;
alter session set container=cdb\$root;
select name, dbid, open_mode from V\$CONTAINERS order by con_id;
alter pluggable database all close;
DROP PLUGGABLE DATABASE ${vPDBName} INCLUDING DATAFILES;

shutdown immediate;
startup restrict mount;
DROP DATABASE;
exit;
RUNSQL
else
	# Drop 11g database
	$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
shutdown immediate;
startup restrict mount;
select name, dbid, created from v\$database;
DROP DATABASE;
exit;
RUNSQL
fi
