#!/usr/bin/bash

vCDBName="csswtdmd"
vCtrlBkp="/rbkbak/ora_sswtdmd_arch_ch0/control_CSSWTDMD_c-2630075607-20190821-02"
vBkpTime="21-AUG-2019 02:00"
vOutputLog="/app/oracle/scripts/logs/sswtdmd_restore_normal.log"

rm $vOutputLog
date | tee -a $vOutputLog

export ORACLE_SID=$vCDBName
export ORACLE_HOME="/app/oracle/product/db/12c/1"
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:/usr/lib64
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export PATH=$PATH:/usr/contrib/bin:.:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin:.:${ORACLE_HOME}/bin:${ORACLE_HOME}/OPatch:${ORACLE_HOME}/opmn/bin:${ORACLE_HOME}/sysman/admin/emdrep/bin:${ORACLE_HOME}/perl/bin
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

echo "ORACLE_SID is $ORACLE_SID" | tee -a $vOutputLog
echo "ORACLE_HOME is$ORACLE_HOME" | tee -a $vOutputLog

# create dummy parameter file
rm $ORACLE_HOME/dbs/init${vCDBName}.ora
echo "db_name='${vCDBName}'" > $ORACLE_HOME/dbs/init${vCDBName}.ora

# connect to RMAN
date | tee -a $vOutputLog
echo "" | tee -a $vOutputLog
echo "Starting recovery" | tee -a $vOutputLog
$ORACLE_HOME/bin/rman >> ${vOutputLog} << RUNRMAN
CONNECT TARGET '/ as sysdba'

STARTUP NOMOUNT PFILE='$ORACLE_HOME/dbs/init${vCDBName}.ora';
RESTORE SPFILE TO '$ORACLE_HOME/dbs/spfile${vCDBName}.ora' FROM '$vCtrlBkp';

SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;

restore controlfile to '/database/${vCDBName}_redo01/oractl/control01.ctl' from '$vCtrlBkp';
restore controlfile to '/database/${vCDBName}_redo02/oractl/control02.ctl' from '$vCtrlBkp';

ALTER DATABASE MOUNT;

RUN
{
	SET UNTIL TIME "TO_DATE('$vBkpTime','DD-MON-YYYY HH24:MI')";
	RESTORE DATABASE;
	RECOVER DATABASE;
	ALTER DATABASE OPEN RESETLOGS;
}

RUNRMAN

# check if DB is open
date | tee -a $vOutputLog
echo "" | tee -a $vOutputLog
echo "Checking if database is open" | tee -a $vOutputLog
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << RUNSQL
set lines 150 pages 200
spool $vOutputLog append
select con_id, name, open_mode from v\$containers;
RUNSQL

date | tee -a $vOutputLog

