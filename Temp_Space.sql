#############
# TEMPFILES #
#############

/*** Tempfile queries ***/

-- get size info for all tempfiles of a tablespace
SET HEAD ON
SET LINES 150
SET PAGES 1000
col "ID" format 990
col file_name format a60
col "TS" format a20
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id "ID", file_name, tablespace_name "TS",(bytes/1024/1024) MB, 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB, autoextensible
from dba_temp_files order by file_name;

SET HEAD ON
SET LINES 150
SET PAGES 1000
col "ID" format 990
col file_name format a60
col "TS" format a20
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select con_id, file_id "ID", file_name, tablespace_name "TS",(bytes/1024/1024) MB, 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB, autoextensible
from cdb_temp_files order by con_id, file_name;

-- summary of totals for each PDB
select con_id, tablespace_name "TS", count(file_id) "FILES", (sum(bytes)/1024/1024) MB, 
(decode(sum(maxbytes),0,sum(bytes),sum(maxbytes))/1024/1024) MaxMB
from cdb_temp_files 
group by con_id, tablespace_name order by con_id, tablespace_name;



-- all for a CDB
col NAME format a60
col "MB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB"on REPORT;
select CON_ID, FILE#, NAME, TS#, (bytes/1024/1024) MB
from v$tempfile order by 1,2;


-- only see default tablesapce
select dtf.file_id "ID", dtf.file_name, dtf.tablespace_name "TS",(dtf.bytes/1024/1024) MB, 
(decode(dtf.maxbytes,0,dtf.bytes,dtf.maxbytes)/1024/1024) MaxMB, dtf.autoextensible
from dba_temp_files dtf, database_properties dp
where dtf.tablespace_name=dp.PROPERTY_VALUE and dp.PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE'
order by dtf.file_name;

col PROPERTY_VALUE format a30
select CON_ID, PROPERTY_VALUE from cdb_properties where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE' order by con_id;

col PROPERTY_VALUE format a30
select PROPERTY_VALUE from database_properties where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';


-- for a specific tablespace
select file_id "ID", file_name, tablespace_name "TS",(bytes/1024/1024) MB, 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB, autoextensible
from dba_temp_files where tablespace_name=upper('&what_ts') order by file_name;

-- query tablespaces with tempfiles (mounted)
set linesize 120
set pagesize 200
col "Tablespace" format a25
col "Tempfile" format a70
select t.name AS "Tablespace", d.name AS "Tempfile"
from v$tablespace t join v$tempfile d
on t.ts#=d.ts#
order by t.name asc, d.name asc;


-- find temp files
select name from V$TEMPFILE where name like '%&file_name%';

-- get initial & next size of tempfiles
col file_id format 990
col file_name format a75
select ddf.file_id "ID", ddf.file_name, vdf.create_bytes/1024/1024 "SIZE", 
  (ddf.increment_by*vdf.block_size)/1024/1024 "NEXT"
from v$tempfile vdf, dba_temp_files ddf
where ddf.file_id=vdf.file# order by ddf.file_name;

-- find a users temp space
select temporary_tablespace from dba_users where username='&what_user';


-- ####################
-- # Tempfile Changes #
-- ####################

-- new temp tablespace
CREATE TEMPORARY TABLESPACE &ts_name
TEMPFILE '&df_name'
[SIZE 512M]
[REUSE] /* if file exists, Oracle reuses file & applies new size */
[AUTOEXTEND ON NEXT 512M MAXSIZE [8192M | UNLIMITED] | AUTOEXTEND OFF]
[TABLESPACE GROUP [&ts_group_name | '']
[EXTENT MANAGEMENT LOCAL [UNIFORM [SIZE 1048576]] | AUTOALLOCATE]
;

CREATE TEMPORARY TABLESPACE temp_demo
TEMPFILE '/move/idevt01/oradata/temp_demo01.dbf' SIZE 5M AUTOEXTEND OFF;


-- add tempfile to tablespace
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 128M AUTOEXTEND ON NEXT 128M MAXSIZE 16G;
-- use existing file
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 128M REUSE AUTOEXTEND ON NEXT 128M MAXSIZE 2G;

-- doesn't extend
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE &size;
-- use existing file not associated to DB
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 100M REUSE;

-- drop a tempfile
alter database tempfile '&df_name' drop;
alter database tempfile '&df_name' drop including datafiles;
-- drop 
ALTER database tempfile 10 drop including datafiles;

-- resize a DF
ALTER DATABASE TEMPFILE &df_num RESIZE &new_size;
-- alt way to shrink (shrinks it as much as possible)
alter tablespace TEMP shrink space keep 1G;

-- make a tempfile autoextensible
ALTER DATABASE TEMPFILE &tf_num AUTOEXTEND ON NEXT 128M MAXSIZE 16G;
-- turn autoextend off
ALTER DATABASE TEMPFILE &tf_num AUTOEXTEND OFF;


##############
# TEMP USAGE #
##############

/*** Temp Usage Queries ***/

-- see current temp space usage
set numf 999,999
select TABLESPACE_NAME, 
  ROUND((TABLESPACE_SIZE)/1024/1024,0) MB_TOTAL,
  ROUND((ALLOCATED_SPACE)/1024/1024,0) MB_USED,
  ROUND((FREE_SPACE)/1024/1024,0) MB_FREE,
  ROUND((ALLOCATED_SPACE/TABLESPACE_SIZE*100),0) PCT_USED
from DBA_TEMP_FREE_SPACE;

-- percentage of temp used (based on PROD metric)
select (SUM(t.USED_UBLK*ts.block_size)/1024/1024)/(sum(temp.bytes/1024/1024)) 
from v$transaction t, dba_temp_files temp, dba_tablespaces ts
where ts.tablespace_name='TEMP';

-- sort space by session
col sid_serial format a10
col username format a15
col osuser format a20
col spid format a10
col module format a20
col program format a20
col mb_used format 999990
col sort_ops format 9990
break on report;
compute sum label "TOTAL" of mb_used sort_ops on report;
SELECT   S.sid || ',' || S.serial# sid_serial, S.username, S.osuser, s.sql_id, P.spid, S.module,
         S.program, SUM (T.blocks) * TBS.block_size / 1024 / 1024 mb_used, COUNT(*) sort_ops
FROM     v$sort_usage T, v$session S, dba_tablespaces TBS, v$process P
WHERE    T.session_addr = S.saddr
AND      S.paddr = P.addr
AND      T.tablespace = TBS.tablespace_name
GROUP BY S.sid, S.serial#, S.username, S.osuser, s.sql_id, P.spid, S.module,
         S.program, TBS.block_size, T.tablespace
ORDER BY mb_used desc;

-- sort space by sql statement
col sid_serial format a10
col username format a15
col mb_used format 999990
col sql_text format a83
SELECT   S.sid || ',' || S.serial# sid_serial, S.username,
         T.blocks * TBS.block_size / 1024 / 1024 mb_used, s.sql_id, Q.sql_text
FROM     v$sort_usage T, v$session S, v$sqlarea Q, dba_tablespaces TBS
WHERE    T.session_addr = S.saddr
AND      T.sqladdr = Q.address (+)
AND      T.tablespace = TBS.tablespace_name
ORDER BY mb_used desc;

-- current temp usage (duplicate info to above)
col sid format 99990
col "MB" format 999,990
col username format a20
break on report;
compute sum label "TOTAL" of "MB" on report;
select u.session_num sid, u.username, u.sql_id, (u.blocks * blk.block_size)/1024/1024 "MB"
from v$sort_usage u,
  (SELECT block_size FROM dba_tablespaces WHERE contents = 'TEMPORARY') blk
order by "MB" desc, username asc;

-- same as first query
SELECT   A.tablespace_name tablespace, D.mb_total,
         SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_used,
         D.mb_total - SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_free
FROM     v$sort_segment A,
         (
         SELECT   B.name, C.block_size, SUM (C.bytes) / 1024 / 1024 mb_total
         FROM     v$tablespace B, v$tempfile C
         WHERE    B.ts#= C.ts#
         GROUP BY B.name, C.block_size
         ) D
WHERE    A.tablespace_name = D.name
GROUP by A.tablespace_name, D.mb_total;

-- gives MB_USED from above
SELECT ROUND(SUM( u.blocks * blk.block_size)/1024/1024,0)
FROM v$sort_usage u,
  (SELECT block_size
   FROM dba_tablespaces
   WHERE contents = 'TEMPORARY') blk;
   
-- diagnose "direct path read temp" event
set lines 150 pages 200
col "file#" format 99990
col "block#" format 9999999990
SELECT p1 "file#", p2 "block#", p3 "class#"
FROM v$session_wait
WHERE event = 'direct path read temp';

SELECT relative_fno, owner, segment_name, segment_type
FROM dba_extents
WHERE file_id = &file
AND &block BETWEEN block_id AND (block_id + &blocksize - 1);

To reduce the direct path read wait event and direct path read temp wait event:
•High disk sorts – If the sorts are too large to fit in memory and get sent to disk, this wait can occur.
•Parallel slaves – Parallel slaves are used for scanning data or parallel DML may be used to create and populate objects. These may lead to direct path read wait and direct path write wait respectively.
•Direct path loads – The direct path API is used to pass data to the load engine in the server and can cause the related direct path write wait.
•Server process ahead of I/O – The server process is processing buffers faster than the I/O system can return the buffers. This can indicate an overloaded I/O system
•Data Warehouse – Sorts in a data warehouse environment may always go to disk leading to high waits on direct path read temp and/or direct path write temp.


/*** Temp Usage Job ***/

-- starting job
exec actd00.admin_upgrd_checks_pkg.tempspace_start;

-- stopping job
exec actd00.admin_upgrd_checks_pkg.tempspace_stop;

-- procedure details
PROCEDURE temp_log_prc
IS
BEGIN
  INSERT INTO ADMIN_ACTD00_TEMPUSAGE VALUES
   (ADMIN_ACTD00_TEMPUSAGE_SEQ.nextval, SYSDATE,
                (SELECT ROUND(SUM( u.blocks * blk.block_size)/1024/1024,0)
  FROM v$sort_usage u,
   (SELECT block_size
    FROM dba_tablespaces
    WHERE contents = 'TEMPORARY') blk));
  COMMIT;
END temp_log_prc;

-- executing procedure
exec actd00.admin_ACTD00_tempundo_log_pkg.temp_log_prc;


-- queries
select to_char(tmstamp,'MM/DD/YY') "DATE", max(tempspace_mb)
from actd00.ADMIN_ACTD00_TEMPUSAGE 
where to_char(tmstamp,'HH24MI') between '2200' and '2240'
 and tmstamp >= (sysdate - 14)
group by to_char(tmstamp,'MM/DD/YY')
order by 1;


select to_char(tmstamp,'MM/DD/YY') "DATE", max(tempspace_mb)
from actd00.ADMIN_ACTD00_TEMPUSAGE 
where tmstamp >= (sysdate - 14)
group by to_char(tmstamp,'MM/DD/YY')
order by 1;


#############
# ESTIMATES #
#############

-- use plan
delete from plan_table;

explain plan for

 
select * from table( dbms_xplan.display );

select * from table( dbms_xplan.display('PLAN_TABLE',NULL,'ALL') );



EXEC DBMS_STATS.GATHER_TABLE_STATS ('DW3','',NULL,100);


alter index dw3.STAT_ANS_IDX01 compile;






