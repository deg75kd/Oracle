-- ##############
-- # START/STOP #
-- ##############

startup mount exclusive;
FORCE
RESTRICT
PFILE=filename
QUIET
MOUNT [dbname] 
OPEN [open_db_options] [dbname]
NOMOUNT

STARTUP RESTRICT MOUNT

SHUTDOWN [ABORT | IMMEDIATE | NORMAL | TRANSACTIONAL [LOCAL]]

-- automated startup/shutdown scripts (AIX)
/nomove/app/oracle/db/11g/6/bin/dbstart
/nomove/app/oracle/db/11g/6/bin/dbshut

-- automated startup/shutdown scripts (Linux)
/etc/init.d/dbora
-- calls:
$ORA_HOME/bin/dbstart $ORA_HOME
$ORA_HOME/bin/dbshut $ORA_HOME


-- ###############
-- # SYSTEM INFO #
-- ###############

-- find DB name
select name from v$database;

-- find DB ID
select dbid from v$database;

-- find DB creation time
select created from v$database;

-- find log mode
select log_mode from v$database;

-- find open status
select open_mode from v$database;
select status, shutdown_pending from v$instance;

-- find OS
select platform_name from v$database;

-- is flashback on
select flashback_on from v$database;

-- find host name
select host_name from v$instance;

-- find DB version
select version from v$instance;

-- find out when DB started
select startup_time from v$instance;

-- find SCN
select current_scn from v$database;

-- find block size
sho parameter db_block_size

select tablespace_name, block_size
from dba_tablespaces
order by 1;


-- #######################
-- # PLUGGABLE DATABASES #
-- #######################

/*----------------- INFORMATION -----------------*/
-- (parameter queries below)

-- what are you connected to
sho con_name
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM   dual;

-- what are the PDBs (if connected to one, you can only see it)
sho pdbs
select name, open_mode from v$pdbs;

-- Determining Whether a Database is a CDB
SELECT CDB FROM V$DATABASE;



/*----------------- CONNECTIONS -----------------*/

-- connect to CDB
export ORACLE_SID=cdb1
sqlplus / as sysdba

-- connect using tnsnames
CONN system/password@cdb1

-- work in CDB root (this is always the name)
alter session set container=cdb$root;

-- work in a PDB (these names vary)
alter session set container=pdb1;

/*----------------- START/STOP -----------------*/

-- open all PDBs from CDB
alter pluggable database all open;

-- trigger to start all PDBs on startup
create or replace trigger Sys.After_Startup after startup on database 
 begin 
    execute immediate 'alter pluggable database all open'; 
 end After_Startup;
 /
 
-- close a PDB
alter pluggable database &what_pdb close immediate;
-- close all PDBs
alter pluggable database all close immediate;

-- modify the state of a PDB (from PDB or CDB)
-- to open/close all use "ALL" for the PDB name
ALTER PLUGGABLE DATABASE &what_pdb OPEN;
ALTER PLUGGABLE DATABASE &what_pdb CLOSE;
ALTER PLUGGABLE DATABASE &what_pdb OPEN READ WRITE [RESTRICTED] [FORCE];
ALTER PLUGGABLE DATABASE &what_pdb OPEN READ ONLY [RESTRICTED] [FORCE];
ALTER PLUGGABLE DATABASE &what_pdb OPEN UPGRADE [RESTRICTED];
ALTER PLUGGABLE DATABASE &what_pdb CLOSE [IMMEDIATE];

-- save state of PDB for next CDB restart
ALTER PLUGGABLE DATABASE pdb1 SAVE STATE;

-- dro pPDB
DROP PLUGGABLE DATABASE &what_pdb INCLUDING DATAFILES;


/*----------------- CHANGES -----------------*/
-- must be connected to CDB
-- these tasks can also be accomplished with standard ALTER DATABASE when connected to PDB

-- unplug a PDB
ALTER PLUGGABLE DATABASE &what_pdb
UNPLUG INTO '&what_file';

-- modify the settings of a PDB
ALTER PLUGGABLE DATABASE &what_pdb

-- bring datafiles of PDB online/offline
ALTER PLUGGABLE DATABASE &what_pdb

-- backup/recover PDB
ALTER PLUGGABLE DATABASE &what_pdb

-- drop a PDB (must be closed)
ALTER PLUGGABLE DATABASE &what_pdb CLOSE;
drop pluggable database &what_pdb including datafiles;

-- hide seed from CDB views
alter system set exclude_seed_cdb_view=TRUE scope=both;
alter session set exclude_seed_cdb_view=TRUE;

-- show seed in CDB views
alter system set exclude_seed_cdb_view=FALSE scope=both;
alter session set exclude_seed_cdb_view=FALSE;



/*----------------- CHANGE ROOT -----------------*/

alter session set container=pdb$seed;
alter session set "_oracle_script"=true;
shut immediate
startup
create tablespace AUDIT_DATA datafile '/oradata/orpcdb1/pdbseed/audit_data01.dbf' size 200M;
shut immediate 
startup open read only
alter session set "_oracle_script"=false;



select pdb_name, status
from cdb_pdbs;


-- #############################
-- # INITIALIZATION PARAMETERS #
-- #############################

/*----------------- QUERIES -----------------*/
-- name of spfile
show parameter spfile

-- default location of init.ora file
$ORACLE_HOME/dbs

-- parameters in effect
show parameters
-- parameters in spfile
show spparameters

-- parameter values in effect
col name format a30
col display_value format a50
select name, display_value, ismodified "MOD", isadjusted "ORA-MOD"
from v$parameter where name like '%&search4me%';

V$PARAMETER2

-- parameter values in spfile
col name format a30
col display_value format a50
select name, display_value, ismodified "MOD", isadjusted "ORA-MOD"
from v$spparameter where name like '%&search4me%';

-- compare active parameters to spfile
set lines 150 pages 200
col name format a30
col "VALUE" format a50
col "SPFILE" format a50
select coalesce(init.name,sp.name) "NAME", init.display_value "VALUE", sp.display_value "SPFILE"
from v$parameter init, v$spparameter sp
where init.name=sp.name
and lower(init.display_value) not like '%edma%'
order by 1;

-- parameter values in effect for the instance (use in a PDB)
col name format a30
col display_value format a50
select con_id, name, display_value, ismodified "MOD", isadjusted "ORA-MOD"
from V$SYSTEM_PARAMETER where name like '%&search4me%';

V$SYSTEM_PARAMETER2

-- parameters set for a PDB
col container_name for a10
col parameter for a20
col value$ for a30
select container.name container_name, par.name PARAMETER, par.value$
from pdb_spfile$ par, v$containers container
where par.pdb_uid = container.con_uid
and container.name='&pdb_name';

-- querying hidden underscore parameters
set linesize 150 pages 200
col Parameter format a50
col Session_Value format a20
col Instance_Value format a20
SELECT a.ksppinm "Parameter",
       b.ksppstvl "Session_Value",
       c.ksppstvl "Instance_Value"
FROM   x$ksppi a,
       x$ksppcv b,
       x$ksppsv c
WHERE  a.indx = b.indx
AND    a.indx = c.indx
AND    a.ksppinm LIKE '/_%' escape '/'
ORDER BY 1;

-- look for certain parameter
set linesize 150 pages 200
col Parameter format a50
col Session_Value format a20
col Instance_Value format a20
SELECT a.ksppinm "Parameter",
       b.ksppstvl "Session_Value",
       c.ksppstvl "Instance_Value"
FROM   x$ksppi a,
       x$ksppcv b,
       x$ksppsv c
WHERE  a.indx = b.indx
AND    a.indx = c.indx
AND    a.ksppinm LIKE '/_%' escape '/'
AND    a.ksppinm LIKE '%&what_parameter%'
ORDER BY 1;

-- hidden (underscore) parameters with details
set lines 150 pages 200
col Parameter format a50
col Session_Value format a20
col "Default" format a5
col description format a50
SELECT
  x.ksppinm "Parameter",
  y.ksppstvl "Session_Value",
  ksppstdf "Default",
  decode(bitand(ksppstvf,   7),
    1,   'MODIFIED_BY(SESSION)',
    4,   'MODIFIED_BY(SYSTEM)',
    'FALSE') is_modified,
  ksppdesc description
FROM x$ksppi x,
  x$ksppcv y
WHERE x.inst_id = userenv('Instance')
 AND y.inst_id = userenv('Instance')
 AND x.ksppinm LIKE '/_%' escape '/'
 AND x.ksppinm NOT LIKE '/_/_%' escape '/'
 AND x.indx = y.indx
-- AND x.ksppinm LIKE '%optim%'
 AND ksppstdf='FALSE'
ORDER BY 1;


--select name, value from v$spparameter where name like '\_%' escape '\' order by name;

/*----------------- CREATING -----------------*/
-- create pfile from spfile with default name/location
CREATE PFILE FROM SPFILE;
-- create pfile from spfile
create pfile='D:\path\to\backup.ora' from spfile;
CREATE PFILE='/u01/oracle/dbs/test_init.ora' FROM SPFILE='/u01/oracle/dbs/test_spfile.ora';
-- create pfile from parameter in memory
CREATE PFILE='/u01/oracle/dbs/test_init.ora' FROM MEMORY;

-- create spfile from pfile
create spfile from pfile='D:\path\to\backup.ora';
CREATE SPFILE FROM PFILE='/u01/oracle/dbs/init.ora';
CREATE SPFILE='/u01/oracle/dbs/test_spfile.ora' FROM PFILE='/u01/oracle/dbs/test_init.ora';
-- create spfile from parameters in memory
CREATE SPFILE FROM MEMORY;

/*----------------- CHANGES -----------------*/
-- change a parameter on next restart (only option for static params)
ALTER SYSTEM SET &p_name = &p_setting scope=spfile;
-- change a parameter in memory (non-persistent)
ALTER SYSTEM SET &p_name = &p_setting scope=memory;
-- change a parameter in memory and spfile
ALTER SYSTEM SET &p_name = &p_setting scope=both;
-- change hidden parameter (must use double-quotes)
ALTER SYSTEM RESET "&p_name";
-- change parameter and add comment
ALTER SYSTEM 
     SET LOG_ARCHIVE_DEST_4='LOCATION=/u02/oracle/rbdb1/',MANDATORY,'REOPEN=2'
         COMMENT='Add new destination on Nov 29'
         SCOPE=SPFILE;

-- clearing parameters (non-CDB and CDB$ROOT)
ALTER SYSTEM RESET &p_name scope=spfile;	-- removes parameter; uses default on next startup
ALTER SYSTEM RESET &p_name scope=memory;	-- uses default now but does not remove parameter from spfile
alter system reset &p_name scope=both;		-- removes parameter and uses default immediately

-- clearing parameters (PDB - I think container means PDB)
ALTER SYSTEM RESET &p_name scope=spfile;	-- removes parameter from container's spfile; will inherit the parameter value from its root upon the next PDB open
ALTER SYSTEM RESET &p_name scope=memory;	-- if parameter in container's spfile, default is used but change not stored
											-- if parameter NOT in container's spfile, container inherits value from root
alter system reset &p_name scope=both;		-- removes parameter from container's spfile and inherits value from root

-- change parameter for DB including SID
alter system set log_archive_dest_1='LOCATION="D:\oradata\ADMN\archlogs_02", valid_for=(ONLINE_LOGFILE,ALL_ROLES)' scope=both sid='admn';
alter system set log_archive_dest_1='LOCATION="D:\oradata\ADMN\archlogs_02", valid_for=(ONLINE_LOGFILE,ALL_ROLES)' scope=both sid='*';


-- ##################
-- # SYSTEM CHANGES #
-- ##################

/* MEMORY */

-- flush memory
ALTER SYSTEM FLUSH SHARED_POOL;
ALTER SYSTEM FLUSH BUFFER_CACHE;
-- for users without this priv
exec sys.flushbuffer_pool.FLUSHBUFFER_POOL;

-- flush a single SQL statement
select ADDRESS, HASH_VALUE from V$SQLAREA where SQL_ID='&what_sqlid';

ADDRESS 	 HASH_VALUE
---------------- ----------
000000085FD77CF0  808321886

exec DBMS_SHARED_POOL.PURGE ('000000085FD77CF0, 808321886', 'C');


/* LOG FILES */

-- issue a checkpoint
ALTER SYSTEM CHECKPOINT;

-- switch to next redo log
ALTER SYSTEM SWITCH LOGFILE;

-- manually archive online redo log file group
-- by sequence#
ALTER SYSTEM ARCHIVE LOG SEQUENCE &what_logseq;
-- by SCN
ALTER SYSTEM ARCHIVE LOG CHANGE &what_scn;
-- current log group
ALTER SYSTEM ARCHIVE LOG CURRENT;
-- by group# (use DBA_LOG_GROUPS to find it)
ALTER SYSTEM ARCHIVE LOG GROUP &what_loggrp;
-- by filename
ALTER SYSTEM ARCHIVE LOG LOGFILE '&what_logfile';
-- the next full group that hasn't been archived
ALTER SYSTEM ARCHIVE LOG NEXT;
-- every full group that hasn't been archived
ALTER SYSTEM ARCHIVE LOG ALL;


/* RESTRICTED SESSION */

-- enable restricted session
ALTER SYSTEM ENABLE RESTRICTED SESSION;
-- disable restricted session
ALTER SYSTEM DISABLE RESTRICTED SESSION;

-- check if in restricted mode
select logins from v$instance;


/* CONTROL FILE BACKUP */

alter database backup controlfile to trace; 

-- #####################
-- # DATABASE SETTINGS #
-- #####################

-- change default tablespace
ALTER DATABASE DEFAULT TABLESPACE &ts_name;

-- change default temp tablespace
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE &temp_name;

-- change global name
ALTER DATABASE RENAME GLOBAL_NAME TO &new_global_name.&new_domain;

-- change date/time settings for session
ALTER SESSION SET NLS_DATE_FORMAT="DD-MON-YY HH24:MI";


-- #######################
-- # Oracle Installation #
-- #######################

-- find DB version
select banner from v$version;
SELECT version FROM V$INSTANCE;

-- find patch sets / version
set lines 150 pages 200
col "ACTION_TIME" format a10
col action format a18
col comments format a40
select to_char(action_time,'DD-MON-YY') "ACTION_TIME", action, version, bundle_series, comments
from registry$history order by action_time desc;
 
-- find installed components
set lines 120 pages 200
col comp_name format a40
col status format a15
select comp_name,status,version from dba_registry;

-- see options
col PARAMETER format a40
col VALUE format a40
select * from v$option order by parameter;

select fus.name, ins.version, fus.currently_used 
from dba_feature_usage_statistics fus, v$instance ins
where fus.version=ins.version
order by 1;

-- check if diagnostic and tuning pack enabled
select name, value
from v$parameter where name = 'control_management_pack_access';

-- multimedia/spatial
select version, status from dba_registry where comp_id='JAVAVM';
select version, status from dba_registry where comp_id='XDB';
select version, status from dba_registry where comp_id='XML';

-- Oracle Warehouse Builder
select username from dba_users where username like '%OWBSYS%';

-- find DB host
select host_name from v$instance;


-- #####################
-- # System Statistics #
-- #####################

-- MB sent/received via db link
col "DBLINK_MB" format 999,990
select sum(value)/1024/1024 "DBLINK_MB"
from dba_hist_sysstat 
where stat_name in ('bytes sent via SQL*Net to dblink','bytes received via SQL*Net from dblink');


DBA_HIST_OSSTAT
DBA_HIST_SESS_TIME_STATS
DBA_HIST_SQLSTAT
DBA_HIST_WAITSTAT


-- ##################
-- # Character Sets #
-- ##################

select *
from nls_database_parameters
where PARAMETER in ('NLS_NCHAR_CHARACTERSET','NLS_CHARACTERSET');

select * from nls_instance_parameters;
select * from nls_session_parameters;


-- ##########################
-- # change system password #
-- ##########################

-- login as sysdba
SQL> passw system
Changing password for system
New password:
Retype new password:
Password changed
SQL> quit


-- ##########################
-- # relink binaries        #
-- ##########################

-- You must relink the product executables every time you apply an operating system patch or after an operating system upgrade.
$ORACLE_HOME/bin/relink
$ORACLE_HOME/bin/relink all

-- ##################
-- # Drop database  #
-- ##################

shutdown immediate
startup mount restrict
drop database;

-- drop DB w/PDBs
select name, dbid, open_mode from V$CONTAINERS order by con_id;
alter pluggable database all close;
DROP PLUGGABLE DATABASE &vPDBName INCLUDING DATAFILES;

shutdown immediate;
startup restrict mount;
DROP DATABASE;

-- ##############
-- # Linux RHEL #
-- ##############

/*--- set hugepages ---*/
/home/oracle/hugepage_settings.sh
Recommended settings: vm.nr_hugepages = 17861

-- root
sudo su -
cd /etc
vi sysctl.conf
(add)	vm.nr_hugepages = 17861

-- reboot server
-- verify
cat /proc/meminfo
HugePages_Total

