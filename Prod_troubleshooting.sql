/* --- Process Limit --- */
-- Reference: Oracle Doc ID 1287854.1

-- If lots of inactive sessions, email EWMAdmin and application team

col sid format 99990
col serial# format 999990
col spid format a8
col "OS USER" format a15
col program format a40
col username format a20
col machine format a25
col "WAIT SEC" format 9999990
set markup html on
set linesize 200 pagesize 30
set termout off
spool processes_sessions.html
select s.sid, s.serial#, p.spid, p.username "OS USER", s.program, 
   s.username, s.status, s.machine, s.seconds_in_wait "WAIT SEC"
FROM v$session s full outer join v$process p
  ON p.addr=s.paddr
order by p.background asc, p.program, s.status, s.username;
spool off
set termout on
set markup html off

-- sessions group by status, machine, username and program
break on status on machine
compute sum of "CT" on status skip 1
col program format a40
col username format a20
col machine format a25
set markup html on
set linesize 200 pagesize 30
set termout off
spool session_status.html
select s.status, s.machine, s.username, s.osuser, count(*) "CT"
FROM v$session s, v$process p
WHERE p.addr=s.paddr and s.machine<>'uxp34' and s.username not in ('SYS','SYSTEM')--and s.status='INACTIVE'
group by s.status, s.machine, s.username, s.osuser
order by s.status, s.machine, s.username, s.osuser;
spool off
set termout on
set markup html off

-- inactive session grouped by inactive time and username
clear breaks
break on report
compute sum of "CT" on report
select (CASE WHEN last_call_et<7200 THEN '0-2 hours'
	WHEN last_call_et<14400 THEN '2-4 hours'
	WHEN last_call_et<21600 THEN '4-6 hours'
	WHEN last_call_et<28800 THEN '6-8 hours'
	WHEN last_call_et<36000 THEN '8-10 hours'
	ELSE 'Over 10 hours'
	END) "INACTIVE TIME"
	,username, count(*) "CT"
from v$session 
where status='INACTIVE' 
group by (CASE WHEN last_call_et<7200 THEN '0-2 hours'
	WHEN last_call_et<14400 THEN '2-4 hours'
	WHEN last_call_et<21600 THEN '4-6 hours'
	WHEN last_call_et<28800 THEN '6-8 hours'
	WHEN last_call_et<36000 THEN '8-10 hours'
	ELSE 'Over 10 hours'
	END) ,username
order by 1;

-- see biggest inactive groups
break on status
compute sum of "CT" on status;
col "OS USER" format a15
col program format a40
col username format a20
col machine format a25
select s.status, p.username "OS USER", s.username, s.program, 
   s.machine, count(*) "CT"
FROM v$session s, v$process p
WHERE p.addr=s.paddr and s.status='INACTIVE'
group by s.status, p.username, s.username, s.program, s.machine
having count(*)>=10
order by s.status, p.username, s.username, s.program, s.machine;

-- memory usage of inactive sessions
col machine format a25
col username format a15
col "PGA MB" format 999,999,990
col "PGA MAX" format 999,999,990
break on machine skip 1 on report
compute sum of "PROCS" "PGA MB" "PGA MAX" on report
select s.machine, s.username, count(*) "PROCS", sum(p.pga_alloc_mem)/1024/1024 "PGA MB", sum(p.pga_max_mem)/1024/1024 "PGA MAX"
FROM v$session s, v$process p
WHERE p.addr=s.paddr and s.status='INACTIVE'
group by s.machine, s.username
order by s.machine, s.username;

-- If there are a lot of INACTIVE sessions, they may need to be killed off.
set lines 150 pages 1000
select s.status, count(*) "CT"
FROM v$session s, v$process p
WHERE p.addr=s.paddr
group by s.status order by s.status;

-- kill sessions inactive more than 12 hours = 43200 seconds
set head off
set pages 0
spool kill_inactive.sql
select 'ALTER SYSTEM KILL SESSION '''||sid||','||serial#||''';'
from v$session where status='INACTIVE' and last_call_et>43200;
spool off

-- If there are many PROGRAM entries from the same program, check if the program has a timeout setting.
-- A network or DB slowdown could cause timeouts.
select s.status, s.program, count(*) "CT"
FROM v$session s, v$process p
WHERE p.addr=s.paddr
group by s.status, s.program order by s.status, s.program;

select s.machine, count(*) "CT"
FROM v$session s, v$process p
WHERE p.addr=s.paddr and s.status='INACTIVE' and s.program='&what_program'
group by s.machine order by s.machine;

-- If there are many SPID entries without a SID/SERIAL#, this is an OS problem. The SPIDs need to be
-- killed using ORAKILL. Use the below replacing 9552 with the SPID value.
-- D:\Oracle\Product\11.2.0\dbhome_11203\BIN\orakill ACTURIS9 9552
select p.spid, p.username "OS USER", p.program, p.terminal
FROM v$session s, v$process p
WHERE p.addr=s.paddr and s.sid is null
order by p.background asc, p.username, p.program, p.terminal;

-- list all sessions & processes, even orphaned ones
set markup html on
set linesize 200 pagesize 30
set termout off
spool processes_sessions.html
select s.sid, s.serial#, p.spid, p.username "OS USER", s.program, 
s.username, s.status, s.machine, s.seconds_in_wait "WAIT SEC" 
FROM v$session s full outer join v$process p 
ON p.addr=s.paddr 
order by p.background asc, p.program, s.status, s.username;
spool off
set head on pages 1000
set termout on
set markup html off

-- find orphaned processes
select p.spid, p.username "OS USER", p.program, p.terminal
FROM v$process p 
WHERE p.addr not in (select paddr from v$session)
order by 1;

-- kill orphaned processes
set head off
set pages 0
spool /tmp/kill_procs_custsvcp.ksh
select 'kill -9 '||p.spid
FROM v$process p 
WHERE p.addr not in (select paddr from v$session)
order by 1;
spool off


/* --- Failed/Broken Jobs --- */

col job_name format a25
col status format a10
col "LAST" format a15
col "NEXT" format a15
col "F" format 90
col "ACTION" format a45
select jrd.log_id, sj.job_name, to_char(jrd.log_date,'DD-MON-RR HH24:MI') "LOG DATE", jrd.status, 
  NVL2(sj.job_action, sj.job_action, sp.program_action) "ACTION"
from dba_scheduler_jobs sj left outer join DBA_SCHEDULER_PROGRAMS sp on sj.program_name=sp.program_name
  join dba_scheduler_job_run_details jrd on sj.job_name=jrd.job_name
where sj.owner not in ('SYS','APEX_040000','ORACLE_OCM') and jrd.status not in ('SUCCEEDED','SCHEDULED','RUNNING')
  and jrd.log_date >= (systimestamp - 1/24)
order by jrd.log_date;

alter session set nls_date_format='DD-MON-RR HH24:MI';
col job format 99990
col last_date format a16
col next_date format a16
col schema_user format a20
col what format a50
col "F" format 90
select job, schema_user, to_char(last_date,'DD-MON-RR HH24:MI') "LAST_DATE", to_char(next_date,'DD-MON-RR HH24:MI') "NEXT_DATE", broken, failures "F", what
from dba_jobs where broken='Y' or failures>0
order by schema_user, last_date;


/* --- Cumulative Logons --- */

select machine, count(*) from v$session group by machine order by 2 desc;


/* --- Apply Lag --- */

-- returns "IDLE" if recovery not enabled
SELECT RECOVERY_MODE FROM V$ARCHIVE_DEST_STATUS WHERE DEST_ID=1;
-- this should return "MRP" or "MRP0" if recovery is enabled (if disabled, no "MRP" listed)
SELECT PROCESS, STATUS, sequence# FROM V$MANAGED_STANDBY;


/* --- Corrupt Data Blocks --- */
-- Info from Oracle items [ID 556733.1] and [ID 819533.1]

-- Run as SYSDBA
-- Verify absolute file number (AFN)
select file_id AFN, relative_fno, file_name from dba_data_files where file_name='&what_file';

-- Identify corrupt object
select * from dba_extents where file_id = &AFN and &BL between block_id AND block_id + blocks - 1;

-- Create the repair table in a given tablespace:
set serveroutput on
BEGIN
   DBMS_REPAIR.ADMIN_TABLES (
   TABLE_NAME => 'REPAIR_TABLE',
   TABLE_TYPE => dbms_repair.repair_table,
   ACTION => dbms_repair.create_action,
   TABLESPACE => 'FLX_TABLES_X4M');
END;
/ 

-- Identify corrupted blocks for schema.object:
DECLARE num_corrupt INT;
BEGIN
   num_corrupt := 0;
   DBMS_REPAIR.CHECK_OBJECT (
   SCHEMA_NAME => 'FLXADM',
   OBJECT_NAME => 'ACT_TROS',
   REPAIR_TABLE_NAME => 'REPAIR_TABLE',
   corrupt_count => num_corrupt);
   DBMS_OUTPUT.PUT_LINE('number corrupt: ' || TO_CHAR (num_corrupt));
END;
/
 
-- Optionally display any corrupted block identified by check_object:
select BLOCK_ID, CORRUPT_TYPE, CORRUPT_DESCRIPTION 
from REPAIR_TABLE;
 
-- Mark the identified blocks as corrupted
DECLARE num_fix INT;
BEGIN
   num_fix := 0;
   DBMS_REPAIR.FIX_CORRUPT_BLOCKS (
   SCHEMA_NAME => 'FLXADM',
   OBJECT_NAME=> 'ACT_TROS',
   OBJECT_TYPE => dbms_repair.table_object,
   REPAIR_TABLE_NAME => 'REPAIR_TABLE',
   FIX_COUNT=> num_fix);
   DBMS_OUTPUT.PUT_LINE('num fix: ' || to_char(num_fix));
END;
/
 
-- Allow future DML statements to skip the corrupted blocks:
BEGIN
   DBMS_REPAIR.SKIP_CORRUPT_BLOCKS (
   SCHEMA_NAME => 'FLXADM',
   OBJECT_NAME => 'ACT_TROS',
   OBJECT_TYPE => dbms_repair.table_object,
   FLAGS => dbms_repair.SKIP_FLAG);
END;
/


/* --- Maximum Extents --- */
-- from http://devoem2.dev.int.acturis.com/E11882_01/server.112/e17120/schema006.htm

-- Export the data in the segment
expdp 'sys@wm9 as sysdba' DIRECTORY=DP_DIR DUMPFILE=BIZDOCCONTENT.DMP LOGFILE=BIZDOCCONTENT_exp.log CONTENT=ALL TABLES=TNREPO.BIZDOCCONTENT

-- Drop and re-create the segment, giving it a larger INITIAL storage parameter setting
-- use to get its definition
set long 10000000
select DBMS_METADATA.GET_DDL('&what_type','&what_obj','&what_owner') from dual;

-- Import the data back into the segment.
impdp 'sys@wm9 as sysdba' DIRECTORY=DP_EXP DUMPFILE=BIZDOCCONTENT.DMP LOGFILE=BIZDOCCONTENT_imp.log CONTENT=ALL TABLE_EXISTS_ACTION=TRUNCATE


/* --- Temp Space --- */

col sid_serial format a10
col username format a15
col osuser format a20
col spid format a6
col module format a20
col program format a20
col mb_used format 999990
col sort_ops format 9990
SELECT   S.sid || ',' || S.serial# sid_serial, S.username, S.osuser, P.spid, S.module,
         S.program, SUM (T.blocks) * TBS.block_size / 1024 / 1024 mb_used, COUNT(*) sort_ops
FROM     v$sort_usage T, v$session S, dba_tablespaces TBS, v$process P
WHERE    T.session_addr = S.saddr AND S.paddr = P.addr AND T.tablespace = TBS.tablespace_name
GROUP BY S.sid, S.serial#, S.username, S.osuser, P.spid, S.module, S.program, TBS.block_size, T.tablespace
ORDER BY mb_used desc;


/* --- Undo Space --- */

set long 10000
col sid format 9990
col "SER" format 99990
col osuser format a20
col "USED MB" format 99,999,999
col sql_fulltext format a55
select s.sid, s.serial# "SER", s.osuser, s.program,
  (t.used_ublk*(select block_size from sys.dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  sq.sql_fulltext
from sys.v_$transaction t, sys.v_$session s, sys.dba_rollback_segs r, sys.v_$sql sq
where t.ses_addr=s.saddr and t.xidusn=r.segment_id and s.sql_id=sq.sql_id
order by "USED MB" desc;


/* --- Missing Media File Count --- */

-- http://docs.oracle.com/cd/E11857_01/em.111/e16285/oracle_database.htm
-- Perform database recovery

-- find file(s) with errors
col file# format 990
col name format a75
SELECT file#, name, tablespace_name
FROM v$datafile_header 
WHERE error is not null AND error is 'OFFLINE NORMAL';


/* --- Datafiles Need Media Recovery --- */

-- http://docs.oracle.com/cd/E11857_01/em.111/e16285/oracle_database.htm
-- Perform database recovery

-- find file(s) with errors
col file# format 990
col name format a75
SELECT file#, name, tablespace_name
FROM v$datafile_header 
WHERE recover ='YES';

