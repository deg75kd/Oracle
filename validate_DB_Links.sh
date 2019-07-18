############################ Verify Database Links ############################

function check_links_fnc {
	PDBName=$1
	
	# get database link names
	vDBLinks=$($ORACLE_HOME/bin/sqlplus -S "system/ic3_cr34m@$PDBName" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT distinct db_link FROM dba_db_links;
EXIT;
RUNSQL
)

	for linkname in ${vDBLinks[@]}
	do
        # find owners of links with that name
        vLinkOwner=$($ORACLE_HOME/bin/sqlplus -S "system/ic3_cr34m@$PDBName" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
SELECT owner FROM dba_db_links where db_link='${linkname}';
EXIT;
RUNSQL
)
        for ownername in ${vLinkOwner[@]}
        do
			# check public links
			if [[ $ownername = "PUBLIC" ]]
			then
				vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/ic3_cr34m@$PDBName" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dual@${linkname};
EXIT;
RUNSQL
)
				# echo $vLinkTest
				if [[ $vLinkTest != "1" ]]
				then
					# increase failed link count
					vFailedLinkCt=`expr $vFailedLinkCt + 1`
					# check if HS link
					vHSLinkCheck=$($ORACLE_HOME/bin/sqlplus -S "system/ic3_cr34m@$PDBName" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select '1' from dba_db_links where host like '%HS%' and db_link='${linkname}';
EXIT;
RUNSQL
)

					# report failures
					if [[ $vHSLinkCheck != "1" ]]
					then
						echo "Public link $linkname is broken!" | tee -a $OutputLog
					else
						echo "Heterogeneous link $linkname is broken!" | tee -a $OutputLog
					fi
					echo "$vLinkTest"
				fi

			# check schema-owned links
			else
				vLinkTest=$($ORACLE_HOME/bin/sqlplus -S "system/ic3_cr34m@$PDBName" << RUNSQL
set pagesize 0 linesize 32767 feedback off verify off heading off echo off trimspool on define on flush off
alter user $ownername grant connect through system;
connect system[${ownername}]/ic3_cr34m@$PDBName
select '1' from dual@${linkname};
connect system/ic3_cr34m@$PDBName
alter user $ownername revoke connect through system;
EXIT;
RUNSQL
)

				if [[ $vLinkTest != "1" ]]
				then
					# increase failed link count
					vFailedLinkCt=`expr $vFailedLinkCt + 1`
					# report failures
					echo "Link $linkname owned by $ownername is broken!" | tee -a $OutputLog
					echo "$vLinkTest"
				fi
			fi
        done
	done
}

############################ MAIN PROGRAM ############################
export ORACLE_HOME=/app/oracle/product/db/12c/1
OutputLog="/home/oracle/DB_Links_List.log"
DBLIST="/home/oracle/KSK/database.lst"

# remove existing files
rm $DBLIST
rm $OutputLog

# set failed DB link count
vFailedLinkCt=0

# list current databases on server
ps -eo args | grep ora_pmon_ | sed 's/ora_pmon_//' | grep -Ev "grep|sed" | sort >> $DBLIST

while read DBInstance
do
	echo "Checking database instance $DBInstance" | tee -a $OutputLog
	
	# set environment variables
	unset LIBPATH
	export ORACLE_SID=$DBInstance
	export ORAENV_ASK=NO
	export PATH=/usr/local/bin:$PATH
	. /usr/local/bin/oraenv
	export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
	export LIBPATH=$ORACLE_HOME/lib
	
	# get database version
	ORACLE_VERSION=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select substr(version,1,instr(version,'.')-1) from v\\$instance;
exit;
EOF`
# echo "DB version is $ORACLE_VERSION"

	# find PDBs in 12c databases
	if [[ $ORACLE_VERSION = "12" ]]
	then
		# find all PDBs
		PDBLIST=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
SET HEAD OFF
SET FEEDBACK OFF
select lower(name) from v\\$pdbs where name!='PDB\\$SEED';
EOF`

		for pdbname in ${PDBLIST[@]}
		do
			# call function to check links
			echo "Checking pluggable database $pdbname" | tee -a $OutputLog
			check_links_fnc $pdbname
		done
	else
		# call function to check links
		check_links_fnc $DBInstance
	fi
done < $DBLIST

# report number of failed links
if [[ $vFailedLinkCt -gt 0 ]]
then
	echo "" | tee -a $OutputLog
	echo "ERROR: $vFailedLinkCt link(s) are not working." | tee -a $OutputLog
else
	echo "" | tee -a $OutputLog
	echo "All database links are working" | tee -a $OutputLog
fi
