-- ###################
-- # GENERAL QUERIES #
-- ###################

-- total size of the DB
set lines 150 pages 1000
col "MB" format 9,999,990
compute sum label "TOTAL" of files "MB" on report;
select count(file_id) files, sum(bytes/1024/1024) "MB"
from
	(select file_id, bytes from dba_data_files
	union all
	select file_id, bytes from dba_temp_files)
;

-- from CDB
set lines 150 pages 1000
col "MB" format 9,999,990
compute sum label "TOTAL" of files "MB" "MaxB" on report;
select count(file_id) files, sum(bytes/1024/1024) "MB"
from
	(select file_id, bytes from cdb_data_files
	union all
	select file_id, bytes from cdb_temp_files)
;

-- get sizes of all tablespaces
set lines 150 pages 1000
col "MB" format 9,999,990
col "MaxB" format 99,999,990
clear breaks
break on report
compute sum label "TOTAL" of files "MB" "MaxB" on report;
select tablespace_name, count(file_id) files, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_data_files group by tablespace_name
union
select tablespace_name, count(file_id), sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_temp_files group by tablespace_name 
order by tablespace_name;

-- from a CDB
set lines 150 pages 1000
col "MB" format 9,999,990
col "MaxB" format 99,999,990
clear breaks
break on report
compute sum label "TOTAL" of files "MB" "MaxB" on report;
select con_id, tablespace_name, count(file_id) files, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from CDB_DATA_FILES group by con_id, tablespace_name
union
select con_id, tablespace_name, count(file_id), sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from CDB_TEMP_FILES group by con_id, tablespace_name 
order by con_id, tablespace_name;


-- find all datafiles for a tablespace
SET HEAD ON
SET LINES 150
SET PAGES 200
col file_id format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id, file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from dba_data_files
where tablespace_name=upper('&ts_name') 
order by file_name;

SET HEAD ON
SET LINES 150
SET PAGES 200
col file_id format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select con_id, file_id, file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from CDB_DATA_FILES
where tablespace_name=upper('&ts_name') 
order by file_name;

-- get all data files
SET LINES 150
SET PAGES 200
col tablespace_name format a30
col file_id format 990
col file_name format a65
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on REPORT;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select tablespace_name, file_id, file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from DBA_DATA_FILES
order by tablespace_name, file_id;

SET LINES 150
SET PAGES 200
col tablespace_name format a30
col file_id format 990
col file_name format a65
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on REPORT;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select con_id, tablespace_name, file_id, file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from CDB_DATA_FILES
order by con_id, tablespace_name, file_id;


-- get size info for the temp tablespace
SET HEAD ON
SET LINES 150
SET PAGES 200
col "ID" format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id "ID", file_name, (bytes/1024/1024) MB, 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB, autoextensible
from dba_temp_files order by file_name;

-- from CDB
SET HEAD ON
SET LINES 150
SET PAGES 200
col "ID" format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id "ID", file_name, (bytes/1024/1024) MB, 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB, autoextensible
from cdb_temp_files order by file_name;

-- get disk sizes
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
col disk format a40
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select disk, sum(bytes/1024/1024) "MB", sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxMB"
from (
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from dba_data_files
    union all
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from dba_temp_files
) group by disk order by disk;

-- from CDB
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
col disk format a40
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select disk, sum(bytes/1024/1024) "MB", sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxMB"
from (
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from cdb_data_files
    union all
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from cdb_temp_files
) group by disk order by disk;


-- includes online redo logs
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
col disk format a40
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select disk, sum(bytes/1024/1024) "MB", sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxMB"
from (
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from dba_data_files
    union all
    select substr(file_name,1,instr(file_name,'/',-1)-1) disk, bytes, maxbytes
    from dba_temp_files
	union all
	select substr(f.member,1,instr(f.member,'/',-1)-1) disk, l.bytes, l.bytes
	from v$log l join v$logfile f on l.group#=f.group#
) group by disk order by disk;

-- find tablespaces by datafile/disk name
SET LINES 150
SET PAGES 200
col file_name format a70
col tablespace_name format a20
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
undefine DF_NAME
SELECT file_name, tablespace_name, bytes/1024/1024 MB, decode(maxbytes,0,bytes,maxbytes)/1024/1024 MaxMB, autoextensible
  FROM dba_data_files
  WHERE upper(file_name) like upper('%&&DF_NAME%') 
UNION
  SELECT file_name, tablespace_name, bytes/1024/1024 MB, decode(maxbytes,0,bytes,maxbytes)/1024/1024 MaxMB, autoextensible
  FROM dba_temp_files
  WHERE upper(file_name) like upper('%&&DF_NAME%') 
ORDER BY tablespace_name, file_name;

-- get disk sizes by tablespace
col "MB" format 9,999,990
col "MaxB" format 9,999,990
col disk format a40
clear breaks
break on disk skip 1
compute sum label "TOTAL" of "MB" "MaxB" on disk;
select substr(file_name,1,instr(file_name,'/',-1)) disk, tablespace_name, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_data_files group by substr(file_name,1,instr(file_name,'/',-1)), tablespace_name
union
select substr(file_name,1,instr(file_name,'/',-1)) disk, tablespace_name, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_temp_files group by substr(file_name,1,instr(file_name,'/',-1)), tablespace_name 
order by disk, tablespace_name;

-- more detailed
set lines 150 pages 200
col maxb format 999,999,990
col free format 999,999,990
col "(gr)" format 999,999,990
col OK format a3
break on tablespace_name on report
compute sum label "TOTAL" of "maxb" "free" "(gr)" on report;
select 
  a.tablespace_name, a.disk, sum(round(a.maxb/1024/1024)) maxb
  ,sum(round((a.left+nvl(b.freebytes,0))/1024/1024)) "free"
  ,sum(round(left/1024/1024)) "(gr)"
  ,sum(round((a.left+nvl(b.freebytes,0))/a.maxb,2)*100) pct_free
from 
  (select 
      file_id, substr(file_name,1,instr(file_name,'/',-1)-1) disk
	  ,tablespace_name, bytes now
	  ,decode(maxbytes,0,bytes,maxbytes) maxb
	  ,decode(maxbytes,0,bytes,maxbytes)-bytes left
    from dba_data_files) a,
  (select sum(bytes) freebytes, tablespace_name, file_id
    from dba_free_space
	group by tablespace_name, file_id) b
where a.file_id=b.file_id(+)
  and a.maxb>0
group by a.tablespace_name, a.disk
order by a.tablespace_name, a.disk;

-- sizes grouped by tablespace and disk
clear computes
clear breaks
break on disk_name skip 1
col disk_name format a50
SELECT disk_name, tablespace_name, sum(bytes)/1024/1024 MB, sum(decode(maxbytes,0,bytes,maxbytes)/1024/1024) MaxMB
FROM	(SELECT tablespace_name, substr(file_name,1,instr(file_name,'/',-1)-1) disk_name, bytes, maxbytes
	 FROM dba_data_files
	UNION ALL
	 SELECT tablespace_name, substr(file_name,1,instr(file_name,'/',-1)-1) disk_name, bytes, maxbytes
	 FROM dba_temp_files)
GROUP BY CUBE (disk_name, tablespace_name)
ORDER BY disk_name, tablespace_name;

-- see all files that match string
set define off
set define on
set verify off
select name from V$CONTROLFILE where upper(name) like upper('%&&file_name%')
UNION
select member from V$LOGFILE where upper(member) like upper('%&&file_name%')
UNION
select name from V$DATAFILE where upper(name) like upper('%&&file_name%')
UNION
select name from V$TEMPFILE where upper(name) like upper('%&&file_name%')
UNION
select filename from V$LOGMNR_LOGFILE where upper(filename) like upper('%&&file_name%')
UNION
select name from V$ARCHIVED_LOG where upper(name) like upper('%&&file_name%');

-- get used, unused & totals by tablespace
col "Total MB" format 99,999,990
col "Free MB" format 99,999,990
col "Used MB" format 99,999,990
Select distinct (d.tablespace) tablespace_name, f.unused "Free MB", 
	(d.used - f.unused) "Used MB", d.used "Total MB", trunc((f.unused/d.used)*100) "PCT FREE"
  From
    (select b.tablespace_name tablespace, round (sum(nvl(b.bytes/1024/1024,0))) used
     from dba_data_files b
     group by  b.tablespace_name order by 1
    ) d ,
    (select a.tablespace_name tabsp, round(sum(nvl(a.bytes/1024/1024,0))) unused
     from dba_free_space a
     group by  a.tablespace_name order by 1
    ) f
  Where f.tabsp(+) = d.tablespace
  Order by "PCT FREE" asc;
  
-- similar to above with TEMP space included
Select distinct (d.tablespace) tablespace_name, NVL2((d.used – f.unused), (d.used – f.unused), d.used) "Used", d.used "Total"
From
	(select b.tablespace_name tablespace, round (sum(nvl(b.bytes/1024/1024,0))) used
	 from dba_data_files b
	 group by  b.tablespace_name 
	union
	 select c.tablespace_name tablespace, round (sum(nvl(c.bytes/1024/1024,0))) used
	 from dba_temp_files c
	 group by  c.tablespace_name
	 order by 1
    ) d ,
	(select a.tablespace_name tabsp, round(sum(nvl(a.bytes/1024/1024,0))) unused
	 from dba_free_space a
	 group by  a.tablespace_name order by 1
    ) f
Where f.tabsp(+) = d.tablespace
Order By 1;

-- get details of all extents of a table
SELECT	f.block_id, --starting block # of extent
	(f.bytes/1024/1024) AS "Ext (MB)", --size of extent in bytes
	f.blocks --size of extent in blocks
FROM	dba_extents f
WHERE	f.tablespace_name='&what_tbs'
ORDER BY f.block_id;

break on report;
compute sum label "TOTAL" of "MB" on report;
col "OBJECT" format a50
col "MB" format 9,999,990
select owner||'.'||segment_name "OBJECT", (sum(bytes)/1048576) "MB" from dba_segments 
where tablespace_name='&what_tbs' 
group by owner||'.'||segment_name order by owner||'.'||segment_name;


-- ###############
-- # ALERT CHECK #
-- ###############

set lines 150 pages 200
select 
  a.tablespace_name, (a.allocated-b.freebytes) used, a.maxb
  , round((a.left+b.freebytes)/a.maxb,2)*100 pct_free
  , floor((a.allocated-b.freebytes)/0.8) newmax
  , floor((a.allocated-b.freebytes)/0.8)-a.maxb add_mb
  , case when round((a.left+b.freebytes)/a.maxb,2)*100<=10 then '!! alert !!'
	end "CHANGE"
from 
  (select df.tablespace_name
	  ,round(sum(df.bytes)/1024/1024) allocated
      ,round(sum(decode(df.maxbytes,0,bytes,df.maxbytes))/1024/1024) maxb
      ,round(sum(decode(df.maxbytes,0,bytes,df.maxbytes))/1024/1024)-round(sum(df.bytes)/1024/1024) left
    from dba_data_files df where df.tablespace_name not like '%UNDO%'
    group by df.tablespace_name) a,
  (select 
      nvl(round(sum(bytes)/1024/1024),0) freebytes, tablespace_name 
    from dba_free_space where tablespace_name not like '%UNDO%'
    group by tablespace_name) b
where a.tablespace_name=b.tablespace_name(+) and a.maxb>0 and round((a.left+b.freebytes)/a.maxb,2)*100<=10
order by 1;


-- ############
-- # RESIZING #
-- ############

/************************ QUERIES *************************************************************/

-- what's in a tablespace
set pagesize 100
set linesize 120
col segment_type format a30
col "MB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" on report;
select segment_type, count(segment_name) "NUMBER", (sum(bytes)/1024/1024) AS "MB"
from dba_segments where tablespace_name='&ts_name'
group by segment_type order by segment_type;

-- see breakdown of items > 1 MB in size
col "SEGMENT" format a45
col segment_type format a30
col "MB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" on report;
select owner||'.'||segment_name "SEGMENT", segment_type, (sum(bytes)/1024/1024) AS "MB"
  from dba_segments where tablespace_name='&ts_name'
group by owner||'.'||segment_name, segment_type
  having sum(bytes) >= 1048576
order by owner||'.'||segment_name;

-- find 5 outermost segments in a file
col "SEGMENT" format a45
col segment_type format a30
col block_id format 999999990
select owner||'.'||segment_name "SEGMENT", segment_type, block_id from
  (select owner, segment_name, segment_type, block_id
   from dba_extents
   where file_id = (select file_id from dba_data_files
      where upper(file_name) = upper('&what_file') )
   order by block_id desc)
where rownum <= 10;

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

-- get initial & next size of tempfiles
col file_id format 990
col file_name format a75
select ddf.file_id "ID", ddf.file_name, vdf.create_bytes/1024/1024 "SIZE", 
  (ddf.increment_by*vdf.block_size)/1024/1024 "NEXT"
from v$tempfile vdf, dba_temp_files ddf
where ddf.file_id=vdf.file# order by ddf.file_name;

/************************ ADD *****************************************************************/

-- Add a datafile
ALTER TABLESPACE &ts_name ADD DATAFILE '&df_name' SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 32000M;

-- add tempfile
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 256m AUTOEXTEND ON NEXT 256M MAXSIZE 16G;
-- doesn't extend
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 4G;
-- use existing file not associated to DB
ALTER TABLESPACE TEMP ADD TEMPFILE '&df_name' SIZE 4G REUSE;

-- find how much space to add MB
x >= (0.11 max - free) / 0.89

/************************ DROP ****************************************************************/

-- drop a datafile, by name or number
ALTER TABLESPACE &ts_name DROP DATAFILE '&df_name';
ALTER TABLESPACE &ts_name DROP DATAFILE &df_num;

-- drop tempfile
alter database tempfile '&temp_name' drop including datafiles;
ALTER database tempfile &temp_num drop including datafiles;

/************************ MANUAL RESIZE *******************************************************/

-- resize a file
ALTER DATABASE DATAFILE &df_num RESIZE &new_size;
ALTER DATABASE TEMPFILE &df_num RESIZE &new_size;

-- make a file autoextensible
ALTER DATABASE DATAFILE &df_num AUTOEXTEND ON NEXT 256M MAXSIZE 32000M;
ALTER DATABASE TEMPFILE &tf_num AUTOEXTEND ON NEXT 256M MAXSIZE 16G;

-- increase/decrease the max size of a file
ALTER DATABASE DATAFILE &df_num AUTOEXTEND ON MAXSIZE 16G;
ALTER DATABASE TEMPFILE &df_num AUTOEXTEND ON MAXSIZE 16G;

-- make a file not autoextensible
ALTER DATABASE DATAFILE &df_num AUTOEXTEND OFF;
ALTER DATABASE DATAFILE '&df_name' AUTOEXTEND OFF;
ALTER DATABASE TEMPFILE &df_num AUTOEXTEND OFF;
ALTER DATABASE TEMPFILE '&df_name' AUTOEXTEND OFF;

-- make all files of a TS not autoextensible
SET SERVEROUTPUT ON
BEGIN
  FOR r1 IN (SELECT file_id FROM dba_data_files WHERE file_name like 'D:\ORADATA\DW3\DW3_L2_02\%') LOOP
    --DBMS_OUTPUT.PUT_LINE('alter database datafile '||r1.file_id||' AUTOEXTEND OFF');
    EXECUTE IMMEDIATE 'alter database datafile '||r1.file_id||' AUTOEXTEND OFF';
  END LOOP;
END;
/

set lines 500
set trimspool on
set pages 0
set head off
spool autoextoff.out
select 'alter database datafile '||file_id||' AUTOEXTEND OFF;'
from dba_data_files where file_name like 'D:\ORADATA\DW3\DW3_L3\%';
spool off
@autoextoff.out

-- shrink a tablespace as much as possible
ALTER TABLESPACE &ts_name SHRINK SPACE;
-- set min size
ALTER TABLESPACE &ts_name SHRINK SPACE KEEP 100M;

-- shrink a tempfile as much as possible
ALTER TABLESPACE &ts_name SHRINK TEMPFILE '&tf_name';
-- set a min size
ALTER TABLESPACE &ts_name SHRINK TEMPFILE '&tf_name' KEEP 100M;

/************************ RESIZE SCRIPTS ******************************************************/

-- resize all files of a TS
set lines 500
set trimspool on
set pages 0
set head off
spool tbs_shrink.out
select 'alter database datafile '||file_id||' resize '||trunc((bytes*90/100))||';'
from dba_data_files where tablespace_name = 'DQI_TABLES_X4M' order by file_id;
spool off
@tbs_shrink.out

-- resize all DB files except SYS
whenever sqlerror continue;
set lines 500
set trimspool on
set pages 0
set head off
spool db_shrink.out
select 'alter database datafile '||file_id||' resize '||trunc((bytes*75/100))||';'
from dba_data_files where tablespace_name NOT IN 
('SYSAUX','SYSTEM','TEMP','UNDOTBS') order by file_id;
spool off
@db_shrink.out

-- resize specific files
set lines 500
set trimspool on
set pages 0
set head off
spool tbs_shrink.out
select 'alter database datafile '||file_id||' resize '||trunc((bytes*90/100))||';'
from dba_data_files where file_id in (60) order by file_id;
spool off
@tbs_shrink.out



/************************ KYTE RESIZE *********************************************************/

-- find possible savings by resizing datafiles (takes awhile)
-- added minimum value but not quite precise
set verify off
column file_name format a60 word_wrapped
column smallest format 9,999,990 heading "Smallest|Poss."
column currsize format 9,999,990 heading "Current|Size"
column savings  format 9,999,990 heading "Poss.|Savings"
break on report
compute sum of savings on report
column value new_val blksize
select value from v$parameter where name = 'db_block_size';
select c.tablespace_name,
       sum(greatest(ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024), ((c.min_extents*c.initial_extent+a.bytes-a.user_bytes)/1024/1024) )) smallest,
       sum(ceil( a.blocks*&&blksize/1024/1024)) currsize,
       sum(ceil( a.blocks*&&blksize/1024/1024) - greatest(ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024), ((c.min_extents*c.initial_extent+a.bytes-a.user_bytes)/1024/1024) )) savings
from dba_data_files a, dba_tablespaces c,
     ( select file_id, max(block_id+blocks-1) hwm
         from dba_extents
        group by file_id ) b
where a.file_id = b.file_id(+) and a.tablespace_name=c.tablespace_name
  group by c.tablespace_name order by c.tablespace_name;


-- actual resizing
set lines 200 pages 0
set head off
set trimspool off
spool tbs_shrink.out;

select 'alter database datafile '''||a.file_name||''' resize ' ||greatest(ceil( (nvl(b.hwm,1)*&&blksize)), (c.min_extents*c.initial_extent)+(a.bytes - a.user_bytes))|| ';'
from dba_data_files a, dba_tablespaces c,
     ( select file_id, max(block_id+blocks-1) hwm
         from dba_extents 
        group by file_id ) b
where a.file_id = b.file_id(+) and a.tablespace_name=c.tablespace_name
  and ceil( a.blocks*&&blksize/1024/1024) -
      ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024 ) > 0;

spool off;
@tbs_shrink.out;



	  
-- ###########
-- # CHANGES #
-- ###########

-- add DF after media failure w/o backup available
-- the file must already exist on disk and the name must exist in the DB
ALTER DATABASE CREATE DATAFILE '&df_name';

-- drop tablespace, its contents, and its datafiles
DROP TABLESPACE &ts_name INCLUDING CONTENTS AND DATAFILES;

-- drop everything in a TS w/o dropping the files
set lines 200 pages 0
spool drop_ts_objects.out
select DISTINCT 'DROP '||segment_type||' '||owner||'.'||segment_name||';'
  from dba_segments where tablespace_name='&ts_name';
spool off
@drop_ts_objects.out

-- take DF offline
-- filename can be subbed for df_num
ALTER DATABASE DATAFILE &df_num OFFLINE;
-- if DB in noarchivelog mode
ALTER DATABASE DATAFILE &df_num OFFLINE FOR DROP;

-- bring DF online
ALTER DATABASE DATAFILE &df_num ONLINE;

-- make TS read-only
ALTER TABLESPACE &ts_name READ ONLY;
-- make RS read/write
ALTER TABLESPACE &ts_name READ WRITE;
-- take TS offline
	-- NORMAL		flush all blocks out of SGA (default)
	-- TEMPORARY	performs checkpoint for all online files; offline files may require recovery to bring TS online
	-- IMMEDIATE	does not perform checkpoint; you MUST perform recovery to bring it online
ALTER TABLESPACE &ts_name OFFLINE [NORMAL | TEMPORARY | IMMEDIATE];
-- bring TS online
ALTER TABLESPACE &ts_name ONLINE;


/************************ RENAMING ************************************************************/

-- rename a datafile
-- DB must be mounted; if DB is open, DF must be offline
ALTER TABLESPACE &ts_name RENAME DATAFILE '&old_name' TO '&new_name';
ALTER DATABASE RENAME FILE '&oldname' TO '&newname';

-- Run this with the DB mounted or open
SPOOL Rename_datafiles.out
select 'ALTER DATABASE RENAME FILE '''||file_name||''' TO '''||replace(file_name,'D:\ORADATA\SDE\FLEXI_UPGRADE','D:\oradata\SDE\flexi')||''';' 
from dba_data_files where tablespace_name in ('FLX_TABLES_X4M','FLX_TABLES_X128M')
and file_name like 'D:\ORADATA\SDE\FLEXI_UPGRADE%';
SPOOL OFF;

-- Close the DB, move the files, then run this
@Rename_datafiles.out


-- 12c DB
set lines 1000 pages 0
set trimspool on
set echo off
set head off
SPOOL /tmp/rename_datafiles.out
select 'ALTER DATABASE RENAME FILE '''||file_name||''' TO '''||replace(file_name,'/database/cdsgd01','/database/Ecdsgd/cdsgd01')||''';' 
from cdb_data_files where file_name like '/database/cdsgd01/%';
select 'ALTER DATABASE RENAME FILE '''||file_name||''' TO '''||replace(file_name,'/database/dsgd01','/database/Edsgd/dsgd01')||''';' 
from cdb_data_files where file_name like '/database/dsgd01/%';
SPOOL OFF;
@/tmp/rename_datafiles.out


/************************ MOVING FILES ONLINE (12c) ************************************************************/

ALTER DATABASE MOVE DATAFILE '/database/v122b8d01/oradata/users01.dbf'
 TO '/database2/v122b8d02/oradata/users01.dbf';


/************************ MOVING OBJECTS ************************************************************/

select 'ALTER TABLE '||owner||'.'||segment_name||' MOVE;'
   from dba_extents
   where file_id in (6,10) and segment_type='TABLE';


select 'ALTER INDEX '||owner||'.'||segment_name||' REBUILD;'
   from dba_extents
   where file_id in (6,10) and segment_type='INDEX';


select 'ALTER INDEX '||owner||'.'||segment_name||' REBUILD PARTITION "'||partition_name||'";'
   from dba_extents
   where file_id = (select file_id from dba_data_files
      where file_name='D:\ORADATA\DEVEM12\MGMT.DBF')
   and segment_type='INDEX PARTITION';
   
   
-- ###################
-- # MOUNTED QUERIES #
-- ###################

-- see tablespace sizes
select ts.name, nvl(round(sum(df.bytes)/1024/1024),0) MB
from v$datafile df, v$tablespace ts
where df.ts#=ts.ts#
group by ts.name
union
select ts.name, nvl(round(sum(tf.bytes)/1024/1024),0) MB
from v$tempfile tf, v$tablespace ts
where tf.ts#=ts.ts#
group by ts.name
order by name;

-- query tablespaces and their datafiles
set lines 120 pages 200
col "Tablespace" format a25
col "Datafile" format a70
col "MB" format 9,999,990
select t.name AS "Tablespace", d.name AS "Datafile", (d.bytes/1024/1024) "MB"
from v$tablespace t join v$datafile d
on t.ts#=d.ts#
where t.name='&ts_name'
order by t.name asc, d.name asc;

-- query tablespaces with tempfiles
set linesize 120
set pagesize 200
col "Tablespace" format a25
col "Tempfile" format a70
select t.name AS "Tablespace", d.name AS "Tempfile"
from v$tablespace t join v$tempfile d
on t.ts#=d.ts#
order by t.name asc, d.name asc;

-- find TS and DF meeting conditions
col "Tablespace" format a25
col "Datafile" format a70
select d.name "Datafile", t.name "Tablespace"
from v$datafile d join v$tablespace t on t.ts#=d.ts# 
where instr(d.name,t.name)=0
and t.name NOT IN ('DW3_L3_X4M','UNDOTBS1');

-- find last SCN of all the datafiles
col name format a70
col checkpoint_change# format 999,999,999,990
select file#, name, checkpoint_change#
from v$datafile order by name;

-- check if the DB can read the datafiles
col name format a70
col checkpoint_change# format 999,999,999,990
select file#, name, checkpoint_change#, recover
from v$datafile_header;

-- find datafiles that can't be read
col file# format 990
col "Datafile" format a60
col checkpoint_change# format 999,999,999,990
col error format a42
select h.file#, df.name "Datafile", h.status, h.error
from v$datafile_header h join v$datafile df
on h.file#=df.file# where h.error IS NOT NULL;


-- ##########
-- # CREATE #
-- ##########

-- template
CREATE TABLESPACE &ts_name
DATAFILE '&df_name'
SIZE 512M
[RESUSE] /* if file exists, Oracle reuses file & applies new size */
AUTOEXTEND ON /* if set to OFF, can't use NEXT, MAXSIZE, or UNLIMITED */
NEXT 512M
MAXSIZE [8192M | UNLIMITED]
LOGGING
ONLINE
PERMANENT /* deprecated */
BLOCKSIZE 8192
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1048576
SEGMENT SPACE MANAGEMENT AUTO;

-- example
CREATE TABLESPACE ACT_TOOLS_X128K
DATAFILE 'D:\oradata\test\acturis\oracle\ACT_TOOLS_X128K01.DBF'
SIZE 256M AUTOEXTEND ON NEXT 256M MAXSIZE 16G;

-- multiple datafiles
create tablespace upgrade_x4m nologging
datafile
'D:\oradata\QA\flexi\oracle\flxdg\DATA\UPGRADE_X4M01.dbf' size 512M autoextend on next 512M maxsize 8G,
'D:\oradata\QA\flexi\oracle\flxdg\DATA\UPGRADE_X4M02.dbf' size 512M autoextend on next 512M maxsize 8G,
'D:\oradata\QA\flexi\oracle\flxdg\DATA\UPGRADE_X4M03.dbf' size 512M autoextend on next 512M maxsize 8G
extent management local uniform size 1m segment space management auto;

-- create undo tablespace
CREATE UNDO TABLESPACE undotbs01 
DATAFILE 'D:\ORADATA\DEVC\WM\ORACLE\ORADATA\WMDEVC\UNDOTBS01.DBF' SIZE 1G REUSE AUTOEXTEND ON NEXT 512M MAXSIZE 10G
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;

-- find definition of existing tablespace
set long 10000000
select DBMS_METADATA.GET_DDL('TABLESPACE','&what_tbs') from dual;
-- using my own schema
set long 10000000
select DBMS_METADATA.GET_DDL('TABLESPACE','&what_tbs','SYS') from dual;

-- find definition for all existing tablespaces
set lines 250
set pages 0
set long 10000000
set serveroutput on
set trimspool on
spool create_all_tablespaces.sql
BEGIN
	FOR i IN (select tablespace_name from dba_tablespaces)
	LOOP
		DBMS_OUTPUT.PUT_LINE (DBMS_METADATA.GET_DDL('TABLESPACE',i.tablespace_name));
	END LOOP;
END;
/
spool off


col "MB" format 9,999,990
col "MaxB" format 9,999,990
col disk format a40
clear breaks
break on disk skip 1
compute sum label "TOTAL" of "MB" "MaxB" on disk;
select substr(file_name,1,&&endstring) disk, tablespace_name, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_data_files group by substr(file_name,1,&&endstring), tablespace_name
union
select substr(file_name,1,&&endstring) disk, tablespace_name, sum(bytes/1024/1024) "MB", 
sum((decode(maxbytes,0,bytes,maxbytes)/1024/1024)) "MaxB"
from dba_temp_files group by substr(file_name,1,&&endstring), tablespace_name 
order by disk, tablespace_name;


select REGEXP_SUBSTR(file_name, '[^\]+$'), count(*)
from dba_data_files group by REGEXP_SUBSTR(file_name, '[^\]+$');

select file_name, REGEXP_SUBSTR(file_name, 'A.T+') disk from dba_data_files;


-- ######################
-- # 12c Upgrade Create #
-- ######################

select 'CREATE TABLESPACE '||tbs.TABLESPACE_NAME||' DATAFILE '''||replace(dbf.FILE_NAME,'/move','/database')||
	''' SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 32000M EXTENT MANAGEMENT '
	||tbs.EXTENT_MANAGEMENT|| ' UNIFORM SIZE 1048576 SEGMENT SPACE MANAGEMENT '||tbs.SEGMENT_SPACE_MANAGEMENT||';'
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf,
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_DATA_FILES
	group by TABLESPACE_NAME) mf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and mf.MIN_FILE=dbf.FILE_ID
and tbs.TABLESPACE_NAME not in ('SYSTEM','SYSAUX','USERS','UNDO','TOOLS')
order by 1;

select 'ALTER TABLESPACE '||tbs.TABLESPACE_NAME||' ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move','/database')||''' SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 32000M;'
from DBA_TABLESPACES tbs, DBA_DATA_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and (dbf.FILE_ID, tbs.TABLESPACE_NAME) not in
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_DATA_FILES
	group by TABLESPACE_NAME)
and tbs.TABLESPACE_NAME not in ('SYSTEM','SYSAUX','USERS','UNDO','TOOLS')
order by 1;

select 'CREATE TABLESPACE '||tbs.TABLESPACE_NAME||' DATAFILE '''||replace(dbf.FILE_NAME,'/move/','/database/')||
	case AUTOEXTENSIBLE
		when 'ON' then ''' SIZE '||BYTES||' AUTOEXTEND ON NEXT '||INCREMENT_BY||' MAXSIZE '||MAXBYTES
		else ''' SIZE '||BYTES
	end
	||' EXTENT MANAGEMENT '||tbs.EXTENT_MANAGEMENT|| ' UNIFORM SIZE 1048576 SEGMENT SPACE MANAGEMENT '||tbs.SEGMENT_SPACE_MANAGEMENT||';'
from DBA_TABLESPACES tbs, DBA_TEMP_FILES dbf,
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_TEMP_FILES
	group by TABLESPACE_NAME) mf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and mf.MIN_FILE=dbf.FILE_ID
and tbs.TABLESPACE_NAME!='TEMP'
order by 1;

select 'ALTER TABLESPACE '||tbs.TABLESPACE_NAME||' ADD DATAFILE '''||replace(dbf.FILE_NAME,'/move/','/database/')||''' SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 32000M;'
from DBA_TABLESPACES tbs, DBA_TEMP_FILES dbf
where tbs.TABLESPACE_NAME=dbf.TABLESPACE_NAME and (dbf.FILE_ID, tbs.TABLESPACE_NAME) not in
	(select min(FILE_ID) MIN_FILE, TABLESPACE_NAME
	from DBA_TEMP_FILES
	group by TABLESPACE_NAME)
and tbs.TABLESPACE_NAME not in ('SYSTEM','SYSAUX','USERS','UNDO','TOOLS')
order by 1;