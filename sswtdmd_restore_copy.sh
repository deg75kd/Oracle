#!/usr/bin/bash

vCDBName="csswtdmd"
vCtrlBkp="/rbkbak/ora_sswtdmd_arch_ch0/control_CSSWTDMD_c-2630075607-20190821-02"
vBkpTime="21-AUG-2019 02:00"
vOutputLog="/app/oracle/scripts/logs/sswtdmd_restore_copy.log"

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

echo "" | tee -a $vOutputLog
echo "Copying backup files" | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSTEM_FNO-1_7st3f27e /database/csswtdmd01/oradata/system01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSTEM_FNO-2_1jt28vtl /database/csswtdmd01/oradata/pdbseed/system01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSAUX_FNO-3_7pt3f258 /database/csswtdmd01/oradata/sysaux01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSAUX_FNO-4_1it28vte /database/csswtdmd01/oradata/pdbseed/sysaux01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-UNDO_FNO-5_82t3f29t /database/csswtdmd01/oradata/undo.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-USERS_FNO-6_87t3f2ak /database/csswtdmd01/oradata/users01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-USERS_FNO-7_1ut28vv6 /database/csswtdmd01/oradata/pdbseed/users01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-TOOLS_FNO-8_81t3f29q /database/csswtdmd01/oradata/tools01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-TOOLS_FNO-12_1kt28vts /database/csswtdmd01/oradata/pdbseed/tools01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-UNDO_FNO-13_83t3f2a0 /database/sswtdmd01/oradata/undo01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSTEM_FNO-14_7vt3f28s /database/sswtdmd01/oradata/system01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SYSAUX_FNO-15_7tt3f27t /database/sswtdmd01/oradata/sysaux01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-USERS_FNO-16_88t3f2ao /database/sswtdmd01/oradata/users01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-TOOLS_FNO-17_80t3f29b /database/sswtdmd01/oradata/tools01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-GGS_FNO-18_84t3f2a3 /database/sswtdmd01/oradata/ggs01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-PRVDRLR6DB_DATA_FNO-19_7rt3f26l /database/sswtdmd01/oradata/prvdrlr6db_data01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SSWDB_DATA_FNO-20_7ut3f28d /database/sswtdmd01/oradata/sswdb_data01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-SSWLRDB_DATA_FNO-21_85t3f2aa /database/sswtdmd01/oradata/sswlrdb_data01.dbf | tee -a $vOutputLog
cp /rbkbak/ora_sswtdmd_ch0/data_D-CSSWTDMD_I-2630075607_TS-LOGON_AUDIT_DATA_FNO-22_86t3f2ad /database/sswtdmd01/oradata/logon_audit_data01.dbf | tee -a $vOutputLog

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
RECOVER DATABASE UNTIL TIME "TO_DATE('$vBkpTime','DD-MON-YYYY HH24:MI')";

ALTER DATABASE OPEN RESETLOGS;
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

