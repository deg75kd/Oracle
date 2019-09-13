-- all registered DBs
select db_key, name
from rman.rc_database
order by name;

-- historical info of backups
col object_type format a20
col row_type format a20
col status format a15
col "MB" format 999,990
select to_char(start_time,'DD-MON-YY HH24:MI') "START", object_type, row_level, 
row_type, operation, status, MBYTES_PROCESSED "MB"
from RMAN.RC_RMAN_STATUS
where db_name=upper('&what_db') --and start_time>=(sysdate-1)
order by start_time, row_level;

-- MB processed
set lines 150 pages 200
col "MB" format 99,999,990
col "HOURS" format 99,999.90
col "MB/MIN" format 99,999.90
col OBJECT_TYPE format a20
col STATUS format a10
select to_char(start_time,'DD-MON-YY HH24:MI') "START", OBJECT_TYPE, STATUS, MBYTES_PROCESSED "MB", 
	(END_TIME-START_TIME)*24 "HOURS", MBYTES_PROCESSED/((END_TIME-START_TIME)*24*60) "MB/MIN"
from RMAN.RC_RMAN_STATUS
where db_name=upper('&what_db') and status='COMPLETED' and row_level=0
order by start_time;

-- timings and throughput for full backups (minus restore ops)
col "TIME" format a15
col "GB_IN" format 99,999.90
col "GB_OUT" format 99,999.90
col "MB_IN/SEC" format 9,999.90
col "MB_OUT/SEC" format 9,999.90
SELECT start_time, 
	round(input_bytes/1024/1024/1024,2) as "GB_IN", 
	round(output_bytes/1024/1024/1024,2) as "GB_OUT" , 
	case 
		when 24*60*(end_time - start_time) > 3600*4 then to_char(round(24*(end_time - start_time),2)) || ' hr' 
		when 24*60*60*(end_time - start_time) > 60*5 then to_char(round(24*60*(end_time - start_time),1)) || ' min'
		else to_char(round(24*60*60*(end_time - start_time),0)) || ' sec'
	end "TIME",
	round((input_bytes/1024/1024) / case 
		when (end_time - start_time) = 0 then 1 
		else 24*60*60*(end_time - start_time) end,2) "MB_IN/SEC",
		round((output_bytes/1024/1024) / case 
		when (end_time - start_time) = 0 then 1 
		else 24*60*60*(end_time - start_time) end,2) "MB_OUT/SEC"
FROM RMAN.RC_RMAN_STATUS
WHERE OBJECT_TYPE IS NOT NULL AND operation = 'BACKUP' and object_type = 'DB INCR'
and db_name=upper('&what_db') and START_TIME > trunc(to_date('&what_date','MM/DD/YYYY'))
order by start_time;

-- status of full backups
set lines 150 pages 200
alter session set nls_date_format='MM/DD/YY HH24:MI';
col "TIME" format a10
select DB_NAME, START_TIME, END_TIME, STATUS, INPUT_TYPE, TIME_TAKEN_DISPLAY "TIME"
from rman.RC_RMAN_BACKUP_JOB_DETAILS 
where db_name=upper('&what_db') and INPUT_TYPE='DB INCR' order by start_time;

-- report of all completed backups
set lines 150 pages 200
alter session set nls_date_format='MM/DD/YY HH24:MI';
col "TIME" format a10
col OUTPUT_BYTES_DISPLAY format a20
select DB_NAME, START_TIME, END_TIME, TIME_TAKEN_DISPLAY "TIME", OUTPUT_BYTES_DISPLAY
from rman.RC_RMAN_BACKUP_JOB_DETAILS 
where STATUS='COMPLETED' and INPUT_TYPE='DB INCR' 
order by db_name, start_time;

-- historical time and size of full backups
alter session set nls_date_format='MM/DD/YYYY HH24:MI';
set lines 150 pages 200
col "SIZE_IN" format a10
col "SIZE_OUT" format a10
col "TIME" format a10
col "IN/SEC" format a10
col "OUT/SEC" format a10
select START_TIME, INPUT_BYTES_DISPLAY "SIZE_IN", OUTPUT_BYTES_DISPLAY "SIZE_OUT", TIME_TAKEN_DISPLAY "TIME", INPUT_BYTES_PER_SEC_DISPLAY "IN/SEC", OUTPUT_BYTES_PER_SEC_DISPLAY "OUT/SEC"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where db_name=upper('&what_db') and status='COMPLETED' and INPUT_TYPE='DB INCR'
order by start_time;

-- size of all archivelogs in past 8 days
select db_name, sum(INPUT_BYTES)/1024/1024/1024
from rman.RC_RMAN_BACKUP_JOB_DETAILS
--where upper(db_name) in ('BLCDWSP','BLCNAVP','BPAP','CIGFDSP','CNOFDWP','FDLZP','FNP8P','IDWP','OBIEEP','TRECSCP','DSRP','LPERFP')
where db_name=upper('&what_db')
and status='COMPLETED' and INPUT_TYPE='ARCHIVELOG' and START_TIME>=(sysdate-8)
group by db_name
order by db_name;

-- size of archivelogs by day
alter session set nls_date_format='MM/DD/YYYY';
select db_name, to_char(START_TIME,'YYYY/MM/DD'), round(sum(INPUT_BYTES)/1024/1024/1024,2) "GB"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where db_name=upper('&what_db')
and status='COMPLETED' and INPUT_TYPE='ARCHIVELOG'
group by db_name, to_char(START_TIME,'YYYY/MM/DD')
order by db_name, to_char(START_TIME,'YYYY/MM/DD');

-- size of archivelogs by week
select db_name, to_char(START_TIME,'WW') "WEEK", count(START_TIME) "BACKUPS", 
	round(sum(INPUT_BYTES)/1024/1024/1024,2) "IN_GB",
	round(sum(OUTPUT_BYTES)/1024/1024/1024,2) "OUT_GB"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where db_name=upper('&what_db')
and status='COMPLETED' and INPUT_TYPE='ARCHIVELOG'
group by db_name, to_char(START_TIME,'WW')
order by db_name, to_char(START_TIME,'WW');


-- size of all full backups in past 8 days
select db_name, sum(OUTPUT_BYTES)/1024/1024/1024
from rman.RC_RMAN_BACKUP_JOB_DETAILS
--where upper(db_name) in ('BLCDWSP','BLCNAVP','BPAP','CIGFDSP','CNOFDWP','FDLZP','FNP8P','IDWP','OBIEEP','TRECSCP','DSRP','LPERFP')
where upper(db_name)='&what_db'
and status='COMPLETED' and INPUT_TYPE like 'DB%' --and START_TIME>=(sysdate-8)
group by db_name
order by db_name;

-- max & avg of all DB backups
set colsep ,
set echo off
set pages 0 lines 1000
set trimspool on
spool /tmp/full_backup_sizes_uat.csv
col MaxGB format 9,999.00
col AvgGB format 9,999.00
select db_name, max(OUTPUT_BYTES)/1024/1024/1024 "MaxGB", avg(OUTPUT_BYTES)/1024/1024/1024 "AvgGB"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where status='COMPLETED' and INPUT_TYPE like 'DB%'
-- and upper(db_name)='&what_db'
group by db_name
order by db_name;

-- DB sizes (not accurate)
set colsep ,
set echo off
set pages 0 lines 1000
set trimspool on
col MaxGB format 9,999.00
spool /tmp/database_sizes_ut.csv
select db_name, max(INPUT_BYTES)/1024/1024/1024 "MaxGB"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where status='COMPLETED' and INPUT_TYPE='DB INCR'
--and upper(db_name)='CDSGD'
group by db_name order by db_name;

select db_name, max(START_TIME) "LAST_BACKUP"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where status='COMPLETED' and INPUT_TYPE='DB INCR'
group by db_name having max(START_TIME) >= (sysdate-21)
order by db_name;

-- sizes of all DB backups in history
col "OutGB" format 9,990.00
col "InGB" format 9,990.00
select db_name, START_TIME, INPUT_TYPE, status, (INPUT_BYTES)/1024/1024/1024 "InGB", (OUTPUT_BYTES)/1024/1024/1024 "OutGB"
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where upper(db_name)='&what_db' and INPUT_TYPE like 'DB%' 
order by 1,2;

-- size & times of all DB backups in history
col "OutGB" format 9,990.00
col "InGB" format 9,990.00
col TIME_TAKEN_DISPLAY format a20
select db_name, START_TIME, INPUT_TYPE, status, 
	(INPUT_BYTES)/1024/1024/1024 "InGB", (OUTPUT_BYTES)/1024/1024/1024 "OutGB",	TIME_TAKEN_DISPLAY
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where upper(db_name)='&what_db' and INPUT_TYPE like 'DB%' 
order by 1,2;

-- see times compared to average
col TIME_TAKEN_DISPLAY format a20
undefine what_db
select jd.db_name, jd.START_TIME, jd.TIME_TAKEN_DISPLAY, TRUNC(jd.ELAPSED_SECONDS/av.avg_sec*100) "PCT_AVG"
from rman.RC_RMAN_BACKUP_JOB_DETAILS jd,
(	select avg(ELAPSED_SECONDS) avg_sec
	from rman.RC_RMAN_BACKUP_JOB_DETAILS
	where upper(db_name)='&&what_db' and INPUT_TYPE like 'DB%' and status='COMPLETED') av
where jd.status='COMPLETED' and upper(db_name)='&&what_db' and INPUT_TYPE like 'DB%' 
order by 1,2;

-- see times compared to average for all tier DBs
col TIME_TAKEN_DISPLAY format a20
break on db_name skip 1
select jd.db_name, jd.START_TIME, jd.TIME_TAKEN_DISPLAY, TRUNC(jd.ELAPSED_SECONDS/av.avg_sec*100) "PCT_AVG"
from rman.RC_RMAN_BACKUP_JOB_DETAILS jd,
(	select db_name, avg(ELAPSED_SECONDS) avg_sec
	from rman.RC_RMAN_BACKUP_JOB_DETAILS
	where upper(db_name) like '%M' and INPUT_TYPE like 'DB%' and status='COMPLETED'
	group by db_name) av
where av.db_name=jd.db_name and jd.status='COMPLETED' and INPUT_TYPE like 'DB%' 
order by 1,2;

-- resync events in past 24 hours
alter session set nls_date_format='DD-MON-YY HH24:MI';
col controlfile_change# format 999999999999990
select db_name, resync_time, controlfile_change#, controlfile_time, resync_type, db_status
from RMAN.RC_RESYNC
where db_name=upper('&what_db') and resync_time>=(sysdate-1)
order by resync_time;

-- details of backup archive logs
col next_change# format 999999999999990
col filesize_display format a10
select db_name, sequence#, next_change#, next_time, id1, filesize_display
from RMAN.RC_BACKUP_ARCHIVELOG_DETAILS
where db_name=upper('&what_db')
order by 1,2;

-- details of backup set pieces
col handle format a60
col size_bytes_display format a10
select db_name, set_count, piece#, set_stamp, handle, backup_type, size_bytes_display
from RMAN.RC_BACKUP_PIECE_DETAILS
where db_name=upper('&what_db') and handle not like '%control%'
and completion_time>=to_date('17-AUG-15 0800','DD-MON-YY HH24MI')
order by 1,2,3;

-- verify latest archive log backup
break on db_name skip 1
col handle format a70
select pc.db_name, al.sequence#, pc.handle, pc.completion_time
from RMAN.RC_BACKUP_ARCHIVELOG_DETAILS al left outer join RMAN.RC_BACKUP_PIECE_DETAILS pc
	on al.session_key=pc.session_key
where pc.completion_time>=to_date('17-AUG-15 0800','DD-MON-YY HH24MI')
and (al.db_name,al.sequence#) in 
	(select db_name, max(sequence#)
	 from RMAN.RC_BACKUP_ARCHIVELOG_DETAILS
	 where db_name in ('FDLZP','TRECSCP','HARP','CUSTSVCP','HYPEPMP','HUBP','APMP','FNP8P')
	 group by db_name)
order by pc.db_name, al.sequence#, pc.handle;


-- summary of backup archive logs
select db_key, db_name, num_distinct_files_backed, max_next_change#, max_next_time, output_bytes_display
from RMAN.RC_BACKUP_ARCHIVELOG_SUMMARY
where db_name=upper('&what_db');

-- from Jake
set lines 150 pages 200
col status form a14 
col time form a22
SELECT object_type, status, start_time, end_time, 
	round(input_bytes/1024/1024/1024,0) as Input_GB, 
	round(output_bytes/1024/1024/1024,0) as output_GB , 
	case 
		when 24*(end_time - start_time) > 1 then to_char(round(24*(end_time - start_time),2)) || ' hour' 
		when 24*60*(end_time - start_time) > 1 then to_char(round(24*60*(end_time - start_time),1)) || ' minutes' 
		else to_char(round(24*60*60*(end_time - start_time),0)) || ' seconds' 
	end as time , 
	round((input_bytes/1024/1024) / case 
		when (end_time - start_time) = 0 then 1 
		else 24*60*60*(end_time - start_time) end,0) 
	as "Througput MB/s" 
FROM v$rman_status 
WHERE OBJECT_TYPE IS NOT NULL AND operation = 'BACKUP' and object_type = 'DB INCR' 
-- AND start_time > sysdate - 1 
order by start_time, object_type desc;

-- to see all DBs
col object_type format a15
col time format a12
col status format a10
SELECT db_name, object_type, status, start_time, end_time, 
	round(input_bytes/1024/1024/1024,0) as Input_GB, 
	round(output_bytes/1024/1024/1024,0) as Output_GB , 
	case 
		when 24*(end_time - start_time) > 1 then to_char(round(24*(end_time - start_time),2)) || ' hour' 
		when 24*60*(end_time - start_time) > 1 then to_char(round(24*60*(end_time - start_time),1)) || ' minutes' 
		else to_char(round(24*60*60*(end_time - start_time),0)) || ' seconds' 
	end as time , 
	round((input_bytes/1024/1024) / case 
		when (end_time - start_time) = 0 then 1 
		else 24*60*60*(end_time - start_time) end,0) 
	as "Througput MB/s" 
FROM RMAN.RC_RMAN_STATUS
WHERE OBJECT_TYPE IS NOT NULL AND operation = 'BACKUP' AND start_time > sysdate - 7 
-- and object_type = 'DB INCR' 
and object_type = 'ARCHIVELOG' 
order by db_name, start_time desc, object_type desc;

-- find long-running archive log backups
set lines 150 pages 200
col object_type format a15
col status format a10
break on db_name
SELECT db_name, status, count(*) "BACKUPS"
FROM RMAN.RC_RMAN_STATUS
WHERE operation = 'BACKUP' and object_type = 'ARCHIVELOG' 
--and db_name='CEDMAM'
and (end_time - start_time) > 1/48
group by db_name, status having count(*) > 2
order by db_name, status;

select db_name, min(start_time) 
from RMAN.RC_RMAN_STATUS 
--where db_name in ('CBLCDWSP','CDSRP','CIDWP')
where db_name in ('CBLCDWSM','CDSRM','CEDMAM','CIDWM','FNP8M')
group by db_name order by 1;

-- compression ratio
set lines 150 pages 200
alter session set nls_date_format='MM/DD/YY HH24:MI';
col "TIME" format a10
select DB_NAME, START_TIME, END_TIME, STATUS, INPUT_TYPE, TIME_TAKEN_DISPLAY "TIME", COMPRESSION_RATIO
from rman.RC_RMAN_BACKUP_JOB_DETAILS 
where db_name=upper('&what_db') and INPUT_TYPE='DB INCR' order by start_time;


RC_BACKUP_FILES
RC_RMAN_BACKUP_JOB_DETAILS

V$RMAN_OUTPUT
RC_BACKUP_FILES
RC_BACKUP_PIECE
RC_BACKUP_SET
RC_BACKUP_SET_DETAILS
RC_BACKUP_SET_SUMMARY
RC_DATAFILE
RC_RMAN_BACKUP_JOB_DETAILS
RC_TABLESPACE
RC_UNUSABLE_BACKUPFILE_DETAILS


-- data is really old
select db_key, db_name, name, sequence#, archived, completion_time
from RMAN.RC_ARCHIVED_LOG
where db_name=upper('&what_db') and completion_time>=(sysdate-1)
order by sequence#;


-- RMAN performance
select file# fno, used_change_tracking BCT, incremental_level INCR, 
datafile_blocks BLKS, block_size blksz, blocks_read READ,  
round((blocks_read/datafile_blocks) * 100,2) "%READ",  
blocks WRTN, round((blocks/datafile_blocks)*100,2) "%WRTN"  
from rman.rc_backup_datafile  
where completion_time between  
to_date('&what_start', 'dd:mon:rr hh24:mi:ss') and  
to_date('&what_end', 'dd:mon:rr hh24:mi:ss')  
and db_name=upper('&what_db')
order by file#; 

select completion_time, file# fno, used_change_tracking BCT, incremental_level INCR, 
datafile_blocks BLKS, block_size blksz, blocks_read READ,  
round((blocks_read/datafile_blocks) * 100,2) "%READ",  
blocks WRTN, round((blocks/datafile_blocks)*100,2) "%WRTN"  
from rman.rc_backup_datafile  
where db_name=upper('&what_db')
order by file#, completion_time;

-- use this w/o catalog
select file# fno, used_change_tracking BCT, incremental_level INCR, 
datafile_blocks BLKS, block_size blksz, blocks_read READ,  
round((blocks_read/datafile_blocks) * 100,2) "%READ",  
blocks WRTN, round((blocks/datafile_blocks)*100,2) "%WRTN"  
from v$backup_datafile  
where completion_time between  
to_date('<date1>', 'dd:mon:rr hh24:mi:ss') and  
to_date('<date2>', 'dd:mon:rr hh24:mi:ss')  
order by file#; 

Points to note:

High %READ:Low %WRTN indicates a disk bottleneck - we are scanning many more blocks then we are writing: 

For releases < 10gR2 check for files that are oversized for growth with very little data and consider reducing the size of the datafiles
If this is an incremental backup use Block Change Tracking if available otherwise, a high filesperset value (use fewer channels), allowing many more files to be scanned in parallel by a single channel may give better throughput
For 10R2 DISK or OSB backups check for large, empty pre-allocated extents .which contain very little data
%READ=%WRTN means we are writing out what we read in and this should be enough to stream the tape output. If not, how many channels have been allocated? Too many channels may result in fewer files processed per channel and this may not be enough to keep the tape streaming especially if the disk transfer rate is much lower than tape. 

-- from Mahipal
select DB_NAME,status,to_char(start_time,'DD-MON HH24:MI') StartTime, 
   to_char(end_time,'DD-MON HH24:MI') EndTime,
   round(((end_time-start_time)*1440),2) RunMin,
round(input_bytes/1048576,2) Read_MB, round(output_bytes/1048576,2) Write_MB, input_type 
  from RC_RMAN_BACKUP_JOB_DETAILS
where start_time > sysdate-15  and input_type not in ('ARCHIVELOG','DATAFILE FULL') 
 and db_name=upper('&what_db') order by start_time;

 
-- check if BCT enabled
set lines 150 pages 200
col filename format a60
select status, filename, round(bytes/1048576,0) "MB"
from V$BLOCK_CHANGE_TRACKING;

-- find RMAN sessions on the DB
SET LINES 150 PAGES 1000
COLUMN username FORMAT A19
COLUMN program FORMAT A30
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
ALTER SESSION SET NLS_DATE_FORMAT='MM/DD/RR HH24:MI';
SELECT DISTINCT s.sid, s.serial# "SER", s.username, s.logon_time, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program like '%rman%';
