/*---------------------------------------------------------------------
UNDO_RETENTION
low threshold value of undo retention
For AUTOEXTEND undo tablespaces, the system retains undo for at least the time specified in this parameter, 
  and automatically tunes the undo retention period to satisfy the undo requirements of the queries
For fixed- size undo tablespaces, the system automatically tunes for the maximum possible undo retention period, 
  based on undo tablespace size and usage history, 
  and ignores UNDO_RETENTION unless retention guarantee is enabled.
If an active transaction requires undo space and the undo tablespace does not have available space, 
	then the system starts reusing unexpired undo space. 
	This action can potentially cause some queries to fail with a "snapshot too old" message.

A RETENTION value of GUARANTEE indicates that unexpired undo in all undo segments in the undo tablespace should be retained 
	even if it means that forward going operations that need to generate undo in those segments fail.
To ensure the success of long-running queries or flashback operations, you can enable retention guarantee.
  If it’s enabled, the minimum undo retention period is guaranteed.  
  The DB will cause transactions to fail due to a lack of space rather than write over unexpired undo
---------------------------------------------------------------------*/

##############
# UNDO FILES #
##############

-- get sizes of undo datafiles
SET LINES 150
SET PAGES 100
col file_id format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id "ID", file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from dba_data_files where tablespace_name like 'UNDO%' order by file_name;

-- get initial & next size of each datafile of a tablespace
col file_id format 990
col file_name format a75
col size format 9,990
col next format 9,990
select ddf.file_id "ID", ddf.file_name, vdf.create_bytes/1024/1024 "SIZE", 
  (ddf.increment_by*vdf.block_size)/1024/1024 "NEXT"
from v$datafile vdf, dba_data_files ddf
where ddf.file_id=vdf.file# and ddf.tablespace_name='&ts_name' 
order by ddf.file_name;

-- add undo datafile
ALTER TABLESPACE UNDO ADD DATAFILE '&df_name' SIZE 8G;

-- add extensible undo datafile
ALTER TABLESPACE UNDO
ADD DATAFILE '&df_name' SIZE 256M AUTOEXTEND ON NEXT 256M MAXSIZE 8G;

-- change max size of datafile
ALTER DATABASE DATAFILE &df_num AUTOEXTEND ON MAXSIZE 16G;

-- change the size of a fixed datafile
ALTER DATABASE DATAFILE &df_num RESIZE 256M;

-- make a DF autoextensible
ALTER DATABASE DATAFILE &df_num AUTOEXTEND ON NEXT 256M MAXSIZE 6G;

-- make a file not autoextensible
ALTER DATABASE DATAFILE &df_num AUTOEXTEND OFF;

-- create undo tablespace
CREATE UNDO TABLESPACE undotbs01 
DATAFILE 'D:\ORADATA\DEVC\WM\ORACLE\ORADATA\WMDEVC\UNDOTBS01.DBF' SIZE 1G REUSE AUTOEXTEND ON NEXT 512M MAXSIZE 10G
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;


###################
# RECLAIMING UNDO #
###################

-- Problem:		When trying to shrink undo, getting ORA-03297: file contains used data beyond requested RESIZE value
-- per How to Shrink the datafile of Undo Tablespace (Doc ID 268870.1)

create undo tablespace UNDO_RBS1 datafile 'undorbs1.dbf' size <new size>;
alter system set undo_tablespace=undo_rbs1;
drop tablespace undo_rbs0 including contents;

-- NOTES:
-- Dropping the old tablespace may give ORA-30013: undo tablespace '%s' is currently in use. This error indicates you must wait for the undo tablespace to become unavailable. In other words, you must wait for existing transaction to commit or rollback.
-- on some platforms, disk space is not freed to the OS until the database is restarted.  The disk space will remain "allocated" from the OS perspective until the database restart.


#################
# UNDO SEGMENTS #
#################

-- get names & status of undo segments
set lines 120 pages 200
select tablespace_name, segment_name, segment_id, status 
from dba_rollback_segs order by segment_id;

-- get sizes of undo segments
col "RS KB" format 99,999.90
select usn, rssize/1024 "RS KB" from v$rollstat;

-- see if retention guaranteed
select tablespace_name, retention from dba_tablespaces;


##############
# UNDO USAGE #
##############

-- find ORA-01555 snapshot too old errors
alter session set nls_date_format='DD-MON-YY HH24:MI';
select begin_time
	,ssolderrcnt		ORA_01555_cnt
	,nospaceerrcnt		no_space_cnt
	,txncount			max_num_txns
	,maxquerylen		max_query_len
	,expiredblks		blck_in_expired
from v$undostat
where begin_time > sysdate - 1 and ssolderrcnt > 0
order by begin_time;

/* To fix ORA-01555:
	a)	ensure code does not contain COMMIT statements within cursor loops
	b)	tune SQL statement
	c)	ensure stats are up-to-date
	d)	increase UNDO_RETENTION parameter
	
-- https://www.tekstream.com/oracle-error-messages/ora-01555-snapshot-too-old/
•Use large optimal values for rollback segments.
•Use a large database block size to maximize rollback segment transaction table slots.
•Optimize queries to read fewer data and take less time to reduce the risk of consistent get rollback failure.
•Increase the size of your UNDO tablespace, and set the UNDO tablespace in GUARANTEE mode.
•Do not run discrete queries and sensitive queries simultaneously unless the data is mutually exclusive.
•If possible, schedule queries during off-peak hours to ensure consistent read blocks do not need to rollback changes.
•Reduce transaction slot reuse by performing less commits, especially in PL/SQL queries.
•Avoid committing inside a cursor loop.
•Do not fetch between commits, especially if the data queried by the cursor is being changed in the current session.
•When exporting tables, export with CONSISTENT = no parameter.
*/

-- find undo data used in past 2 hours
alter session set nls_date_format='DD-MON-YY HH24:MI';
col "TXNs" format 999,999
col "STL_BLK" format 99,999
col "ACTIVE MB" format 99,999,999
col "UNEXP MB" format 99,999,999
col "EXP MB" format 99,999,999
col "USED MB" format 99,999,999
WITH tbs_blk AS
  (select block_size from dba_tablespaces where contents='UNDO')
SELECT begin_time, end_time, txncount "TXNs", --UNXPBLKREUCNT "UNXP REUSED", 
(ACTIVEBLKS * (select block_size from tbs_blk)/ 1024/1024) "ACTIVE MB",
(UNEXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "UNEXP MB", 
(EXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "EXP MB",
(undoblks * (select block_size from tbs_blk) / 1024/1024) "USED MB" 
FROM v$undostat where begin_time>(sysdate-2/24)
ORDER BY begin_time asc;

-- in specific time range
alter session set nls_date_format='DD-MON-YY HH24:MI';
col "TXNs" format 999,999
col "STL_BLK" format 99,999
col "ACTIVE MB" format 99,999,999
col "UNEXP MB" format 99,999,999
col "EXP MB" format 99,999,999
col "USED MB" format 99,999,999
WITH tbs_blk AS
  (select block_size from dba_tablespaces where contents='UNDO')
SELECT begin_time, end_time, txncount "TXNs", --UNXPBLKREUCNT "UNXP REUSED", 
(ACTIVEBLKS * (select block_size from tbs_blk)/ 1024/1024) "ACTIVE MB",
(UNEXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "UNEXP MB", 
(EXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "EXP MB",
(undoblks * (select block_size from tbs_blk) / 1024/1024) "USED MB" 
FROM v$undostat where begin_time between to_date('&when_start','YYYYMMDDHH24MI') and to_date('&when_end','YYYYMMDDHH24MI')
ORDER BY begin_time asc;

-- use DBA_HIST_UNDOSTAT for older data
alter session set nls_date_format='DD-MON-YY HH24:MI';
col "TXNs" format 999,999
col "STL_BLK" format 99,999
col "ACTIVE MB" format 99,999,999
col "UNEXP MB" format 99,999,999
col "EXP MB" format 99,999,999
col "USED MB" format 99,999,999
WITH tbs_blk AS
  (select block_size from dba_tablespaces where contents='UNDO')
SELECT begin_time, TUNED_UNDORETENTION, SSOLDERRCNT "ORA-01555", MAXQUERYLEN, MAXQUERYSQLID,
(ACTIVEBLKS * (select block_size from tbs_blk)/ 1024/1024) "ACTIVE MB",
(UNEXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "UNEXP MB", 
(EXPIREDBLKS * (select block_size from tbs_blk) / 1024/1024) "EXP MB",
(undoblks * (select block_size from tbs_blk) / 1024/1024) "USED MB" 
FROM DBA_HIST_UNDOSTAT where begin_time between to_date('&when_start','YYYYMMDDHH24MI') and to_date('&when_end','YYYYMMDDHH24MI')
ORDER BY begin_time asc;


-- current amount of undo by type
col "MB" format 999,990
select u.status, (sum(u.bytes)/1024/1024) "MB"
from dba_undo_extents u
group by u.status order by u.status;

select segment_name,
   round(nvl(sum(act),0)/(1024*1024*1024),3 ) "ACT GB BYTES",
   round(nvl(sum(unexp),0)/(1024*1024*1024),3) "UNEXP GB BYTES",
   round(nvl(sum(exp),0)/(1024*1024*1024),3) "EXP GB BYTES",
   NO_OF_EXTENTS
   from ( select segment_name, nvl(sum(bytes),0) act,00 unexp, 00 exp, count(*) NO_OF_EXTENTS
   from DBA_UNDO_EXTENTS
   where status='ACTIVE' and tablespace_name = 'UNDOTBS4'
   group by segment_name
   union
   select segment_name,00 act, nvl(sum(bytes),0) unexp, 00 exp , count(*) NO_OF_EXTENTS
   from DBA_UNDO_EXTENTS
   where status='UNEXPIRED' and tablespace_name = 'UNDOTBS4'
   group by segment_name
   union
   select segment_name, 00 act, 00 unexp, nvl(sum(bytes),0) exp, count(*) NO_OF_EXTENTS
   from DBA_UNDO_EXTENTS
   where status='EXPIRED' and tablespace_name = 'UNDOTBS4'
   group by segment_name
   ) group by segment_name, NO_OF_EXTENTS having NO_OF_EXTENTS >= 30 order by 5 desc;

break on report
compute sum label Total of Extent_Count Extent_MB on report
col Extent_MB format 999,999.00
SELECT segment_name, bytes/1024 "Extent_Size_KB", count(extent_id) "Extent_Count", bytes * count(extent_id) / power(1024, 2) "Extent_MB" 
FROM dba_undo_extents 
WHERE segment_name = '_SYSSMU375_247595031$' 
group by segment_name, bytes order by 1, 3 desc;


-- percentage used
select (SUM(t.USED_UBLK*16384/1024/1024))/SUM(ud.Mbytes)*100 "% USED"
from v$transaction t, 
  (select sum(bytes/1024/1024) Mbytes 
   from dba_data_files 
   where tablespace_name IN 
     (select tablespace_name from dba_tablespaces where contents = 'UNDO')
  ) ud;

select (SUM(t.USED_UBLK*ts.block_size)/1024/1024) "MB"
from v$transaction t, dba_tablespaces ts where contents='UNDO';


-- find transactions using undo
alter session set nls_date_format='HH24:MI:SS';
col sid format 9990
col username format a20
col osuser format a20
col "USED MB" format 99,999,999
break on sid on username;
select s.sid, s.username, s.osuser, s.sql_id, t.start_time, 
  (t.used_ublk*(select block_size from dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  r.segment_name
from v$transaction t, v$session s, dba_rollback_segs r
where t.ses_addr=s.saddr and t.xidusn=r.segment_id
order by "USED MB" desc;

SELECT s.sid, s.serial#, s.username, u.segment_name, count(u.extent_id) "Extent Count", t.used_ublk, t.used_urec, s.program
FROM v$session s, v$transaction t, dba_undo_extents u
WHERE s.taddr = t.addr and u.segment_name like '_SYSSMU'||t.xidusn||'_%$' and u.status = 'ACTIVE'
GROUP BY s.sid, s.serial#, s.username, u.segment_name, t.used_ublk, t.used_urec, s.program
ORDER BY t.used_ublk desc, t.used_urec desc, s.sid, s.serial#, s.username, s.program;


-- find SQL of transactions using undo
set long 10000
col sid format 9990
col username format a20
col osuser format a20
col "USED MB" format 99,999,999
col sql_fulltext format a55
select s.sid, s.username, s.osuser, 
  (t.used_ublk*(select block_size from sys.dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  sq.sql_fulltext
from sys.v_$transaction t, sys.v_$session s, sys.dba_rollback_segs r, sys.v_$sql sq
where t.ses_addr=s.saddr and t.xidusn=r.segment_id and s.sql_id=sq.sql_id
order by "USED MB" desc;

-- see undo usage by session
col "SER#" format 99999
col "Undo (MB)" format 9,990
col "Max (MB)" format 9,990
SELECT vs.sid
      ,vs.serial# "SER#"
      ,vs.osuser
      ,vs.schemaname
      ,ROUND(SUM(vt.used_ublk*dts.block_size/1024/1024),2) "Undo (MB)"
      ,ddf.mb "Max (GB)"
      ,ROUND(SUM(DECODE(ddf.mb,0,0,100*vt.used_ublk*dts.block_size/1024/1024/ddf.mb)),2) "Used %"
      ,SUM(vt.used_ublk) "Blocks Used"
FROM   v$transaction vt
      ,dba_tablespaces dts
      ,(SELECT tablespace_name
              ,SUM(GREATEST(maxbytes,bytes))/1024/1024 mb
        FROM   dba_data_files
        GROUP BY tablespace_name
       ) ddf
      ,v$session vs
WHERE  dts.tablespace_name = 'UNDOTBS1'
AND    ddf.tablespace_name = 'UNDOTBS1'
AND    vt.addr = vs.taddr
GROUP BY ddf.mb
      ,vs.sid
      ,vs.serial#
      ,vs.osuser
      ,vs.schemaname;


select s.sid, s.username, s.osuser, t.start_time, 
  (t.used_ublk*(select block_size from dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  s.sql_id
from v$transaction t, v$session s
where t.ses_addr=s.saddr
order by "USED MB" desc;


-- get undo retention period for last 4 days
select to_char(begin_time, 'DD-MON-RR HH24:MI') begin_time,
to_char(end_time, 'DD-MON-RR HH24:MI') end_time, tuned_undoretention
from v$undostat order by end_time;


SELECT ROUND(SUM((used_ublk*8192)/1024/1024/1024),2), used_ublk, SYSDATE
  FROM   sys.v_$transaction
  GROUP BY used_ublk, SYSDATE;

-- bytes for a transaction to rollback
SET SERVEROUTPUT ON;
DECLARE
  v_sid		NUMBER := 1521;
  v_byt1	NUMBER;
  v_time1	DATE;
  v_byt2	NUMBER;
  v_time2	DATE;
BEGIN
  SELECT USED_UBLK, sysdate INTO v_byt1, v_time1
    FROM v$transaction d, v$session e 
    WHERE d.addr = e.taddr AND e.sid=v_sid;
  DBMS_LOCK.SLEEP(60);
  SELECT USED_UBLK, sysdate INTO v_byt2, v_time2
    FROM v$transaction d, v$session e 
    WHERE d.addr = e.taddr AND e.sid=v_sid;
  DBMS_OUTPUT.PUT_LINE('Minutes remaining: '||v_byt2/(v_byt1 - v_byt2)*(60/(v_TIME2 - v_TIME1)));
END;
/


#############
# USAGE JOB #
#############

-- starting job
exec actd00.admin_upgrd_checks_pkg.undospace_start;

-- stopping job
exec actd00.admin_upgrd_checks_pkg.undospace_stop;

-- procedure details
PROCEDURE undo_log_prc
IS
BEGIN
  INSERT INTO ADMIN_ACTD00_undo_log
  (used_undo_gb
  ,used_ublks
  ,timestamp
  )
  SELECT ROUND(SUM((used_ublk*8192)/1024/1024/1024),2)
        ,used_ublk
        ,SYSDATE
  FROM   sys.v_$transaction
  GROUP BY used_ublk, SYSDATE;
  COMMIT;
END undo_log_prc;


insert into dejesusk.active_undo
(select s.sid, s.username, s.osuser, 
  (t.used_ublk*(select block_size from sys.dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  sq.sql_fulltext, sysdate
from sys.v_$transaction t, sys.v_$session s, sys.dba_rollback_segs r, sys.v_$sql sq
where t.ses_addr=s.saddr and t.xidusn=r.segment_id and s.sql_id=sq.sql_id);

alter session set nls_date_format='mm/dd/yy hh24:mi';
set long 10000
col mb format 999,990
col sql_fulltext format a70
select tmstamp, username, mb, sql_fulltext from dejesusk.active_undo order by tmstamp;


#############
# DROP UNDO #
#############

-- if ORA-03262: the file is non-empty given when trying to drop datafiles
-- create undo tablespace
CREATE UNDO TABLESPACE undotbs01 
DATAFILE 'D:\oradata\DEVEM12\UNDOTBS1.DBF' SIZE 1G AUTOEXTEND ON NEXT 512M MAXSIZE 8G;

-- change undo tablespace
alter system set undo_tablespace='UNDOTBS01' scope=both;

-- drop old tablespace
DROP TABLESPACE undotbs1 INCLUDING CONTENTS AND DATAFILES;

-- may have to bounce DB to delete files

