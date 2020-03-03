#!/usr/bin/bash
#================================================================================================#
# Filename:    
# Purpose:     
# History:     // - Original
# Parameters:  $1 - 
#              $2 - 
#              $3 - 
#              $4 - 
#================================================================================================#

###----------------------------------------------------------------------------------------------###
###------------------------------- Main Program -------------------------------------------------###
###----------------------------------------------------------------------------------------------###

HOST=`hostname`
vToday=$(date '+%Y%m%d')
vBaseName=$(basename $0 | awk -F. '{ print ($1)}')
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOGDIR="${SCRIPTDIR}/logs"
LOGFILE="${LOGDIR}/${vBaseName}_${vToday}.log"
DBLIST="${LOGDIR}/dblist_${HOST}.log"
TEMPLOGFILE="/tmp/${vBaseName}_${vToday}.log"
EXITCODE=0

# user inputs
existing_user=$1
new_user=$2
new_user_password=$3

# Create log directory if it does not exist
if [ -d $LOGDIR ]
then
	echo "Directory $LOGDIR exists" | tee -a $TEMPLOGFILE
else
	echo "Making directory $LOGDIR" | tee -a $TEMPLOGFILE
	mkdir $LOGDIR
	if [ $? -ne 0 ]
	then
		echo "" | tee -a $TEMPLOGFILE
		echo "WARNING: There was an error creating $LOGDIR!" | tee -a $TEMPLOGFILE
		LOGFILE=$TEMPLOGFILE
	fi
fi
# Delete log files if they exist
if [[ -e $LOGFILE ]]
then
	rm $LOGFILE
	if [ $? -ne 0 ]
	then
		echo "" | tee -a $TEMPLOGFILE
		echo "ERROR: There was an error deleting $LOGFILE!" | tee -a $TEMPLOGFILE
		EXITCODE=1
		exit $EXITCODE
	fi
fi
if [[ -e $DBLIST ]]
then
	rm $DBLIST
	if [ $? -ne 0 ]
	then
		echo "" | tee -a $TEMPLOGFILE
		echo "ERROR: There was an error deleting $DBLIST!" | tee -a $TEMPLOGFILE
		EXITCODE=1
		exit $EXITCODE
	fi
fi

# get tier
vTier=`hostname | tr 'A-Z' 'a-z' | awk '{ print substr( $0, length($0) - 2, length($0) ) }' | cut -c 1`

# log file header
date | tee -a $LOGFILE

# list current databases on server
echo "===== Currently running DBs =====" | tee -a $LOGFILE
ps -eo args | grep ora_pmon_ | sed 's/ora_pmon_//' | grep -Ev "grep|sed" | sort | tee -a $LOGFILE
echo "=================================" | tee -a $LOGFILE
ps -eo args | grep ora_pmon_ | sed 's/ora_pmon_//' | grep -Ev "grep|sed" | sort >> $DBLIST
SIDLIST=$(cat $DBLIST)

# loop through all running databases
for dbname in ${SIDLIST[@]}
do
	# set environment variables
	unset LIBPATH
	export ORACLE_SID=$dbname
	export ORAENV_ASK=NO
	export PATH=/usr/local/bin:$PATH
	. /usr/local/bin/oraenv
	export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
	export LIBPATH=$ORACLE_HOME/lib
	
	# get database version
	echo "Now checking version of $dbname" | tee -a $LOGFILE
	ORACLE_VERSION=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
set pagesize 0 linesize 32767 feedback off verify off heading off echo off
select substr(version,1,instr(version,'.')-1) from v\\$instance;
exit;
EOF`
	echo "$dbname is on Oracle version $ORACLE_VERSION" | tee -a $LOGFILE

	# find PDBs in 12c databases
	if [[ $ORACLE_VERSION = "12" ]]
	then
		echo "Checking container database $dbname..." | tee -a $LOGFILE
		# find all PDBs
		PDBLIST=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
SET HEAD OFF
SET FEEDBACK OFF
select lower(name) from v\\$pdbs where name!='PDB\\$SEED';
EOF`
		for pdbname in ${PDBLIST[@]}
		do
			RUNSQL=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
alter session set container=$pdbname;
select 'CREATE USER $new_user IDENTIFIED BY "$new_user_password" DEFAULT TABLESPACE '||du.default_tablespace||
  ' TEMPORARY TABLESPACE '||du.temporary_tablespace||
  ' PROFILE '||du.profile||';'
from dba_users du join user\\$ us on du.username=us.name
where du.username=upper('$existing_user');

-- get grant role statement
select 'GRANT '||granted_role||' TO $new_user;'
from dba_role_privs where grantee=upper('$existing_user');

-- get default role statement
select 'ALTER USER '||grantee||' DEFAULT ROLE $new_user;'
from dba_role_privs where grantee=upper('$existing_user') and default_role='YES';

-- get quota statement
select 'ALTER USER $new_user QUOTA '||
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end
  ||' ON '||tablespace_name||';'
from dba_ts_quotas where username=upper('$existing_user');

-- get sys priv statement
select 'GRANT '||privilege||' TO $new_user;'
from dba_sys_privs where grantee=upper('$existing_user');

-- get obj priv statement
select 'GRANT '||privilege||' ON '||owner||'.'||table_name||' TO $new_user;'
from dba_tab_privs where grantee=upper('$existing_user');

EOF`
			echo "In $pdbname it is $RUNSQL" | tee -a $LOGFILE
		done
	elif [[ $ORACLE_VERSION = "11" ]]
	then
		RUNSQL=`$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
SET HEAD OFF
SET FEEDBACK OFF
alter session set nls_date_format='HH:MI AM';
select sysdate from dual;
EOF`
		echo "In $dbname it is $RUNSQL" | tee -a $LOGFILE
	else
		echo "The version ($ORACLE_VERSION) of $dbname is incompatible with the SQL tuning script"
	fi
done

# count errors and set exit code
ERRCT=$(cat $LOGFILE | grep ERROR | wc -l)
echo "There were $ERRCT errors"
if [[ $ERRCT -gt 0 ]]
then
	EXITCODE=-1
fi

# summary
if [[ $EXITCODE -eq 0 ]]
then
	echo "$0 completed with NO errors" | tee -a $LOGFILE
	echo "Log file written to $LOGFILE"
else
	echo "$0 completed with errors" | tee -a $LOGFILE
	echo "Log file written to $LOGFILE"
fi

exit $EXITCODE

