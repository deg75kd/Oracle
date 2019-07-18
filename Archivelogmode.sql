-- see if db in archivelog mode
select log_mode from v$database;

-- force a archive log switch
alter system switch logfile;


-- ###############################
-- # Put DB into ARCHIVELOG mode #
-- ###############################

-- stop db instance
SHUTDOWN IMMEDIATE;

-- start in mount mode
STARTUP MOUNT;

-- set up log destination
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1 = 'LOCATION=/mnt/netapp/dev/arch01' scope=both;

-- put db in archivelog mode
ALTER DATABASE ARCHIVELOG;

-- restart database
ALTER DATABASE OPEN;



-- ##################################
-- # Take DB out of ARCHIVELOG mode #
-- ##################################

-- stop db instance
SHUTDOWN IMMEDIATE;

-- start in mount mode
STARTUP MOUNT;

-- put db in archivelog mode
ALTER DATABASE NOARCHIVELOG;


-- restart database
ALTER DATABASE OPEN;


-- #################################
-- # Queries #
-- #################################

-- see all logs
select NAME from V$ARCHIVED_LOG 
where NAME is not null order by 1;

-- see details of logs
alter session set nls_date_format='MM/DD/YYYY HH24:MI';
col name format a50
col first_change# format 999999999999990
select name, sequence#, first_change#, first_time
from V$ARCHIVED_LOG 
where dest_id=1 and name is not null
order by sequence#, first_change#;

-- get delete command
set lines 150 pages 0
set trimspool on
spool /tmp/remove_archive_logs_idevt.sh
select 'rm '||NAME from V$ARCHIVED_LOG 
where NAME is not null order by 1;
spool off

-- check for archive logs that have not been backed up
set lines 150 pages 200
alter session set nls_date_format='MM/DD/YY HH24:MI';
col NAME format a60
col FIRST_CHANGE# format 99999999999990
select THREAD#, SEQUENCE#, FIRST_CHANGE#, FIRST_TIME, NAME, BACKUP_COUNT, DELETED
from V$ARCHIVED_LOG
where BACKUP_COUNT=0 and FIRST_TIME >= to_date('&what_start','MM/DD/YY HH24:MI')
order by 1,2;


-- #################################
-- # Estimate size of archive logs #
-- #################################

-- log switches & MB for past 90 days
break on report;
COMPUTE AVG LABEL 'Average' -
        MAX LABEL 'Maximum' -
        OF DAILY_MB ON report;
SELECT log_hist.*,
	ROUND(log_hist.log_switches * log_file.avg_log_size / 1024 / 1024) DAILY_MB
FROM (
	SELECT TO_CHAR(first_time,'YYYY-MM-DD') DAY, COUNT(1) log_switches
	FROM v$log_history
	WHERE first_time >= (sysdate-90)
	GROUP BY TO_CHAR(first_time,'YYYY-MM-DD')
	ORDER BY DAY DESC
) log_hist,
(SELECT AVG(bytes) avg_log_size FROM v$log) log_file
order by log_hist.DAY;

-- log switches & MB by day of week
break on report;
compute sum label "TOTAL" of "TTL_MB" on report;
col "MB" format 999,990
with lh as
	(select to_char(lh.first_time,'DY') "DY", count(*) "REDOLOGS"
	 from v$log_history lh
	 group by to_char(lh.first_time,'DY')),
vl as
	(select (max(bytes)/1024/1024) "MB"
	 from v$log)
select lh.DY, lh.REDOLOGS, (lh.REDOLOGS * vl.MB) "TTL_MB"
from lh, vl
order by 1;

select to_char(lh.first_time,'DD-MON-RR') "DY", count(*) "REDOLOGS"
from v$log_history lh
group by to_char(lh.first_time,'DD-MON-RR')
	 
-- average log switches per day & week
with lh as
	(select to_char(lh.first_time,'DD-MON-RR') "DY", count(*) "REDOLOGS"
	 from v$log_history lh
	 group by to_char(lh.first_time,'DD-MON-RR')),
vl as
	(select (max(bytes)/1024/1024) "MB"
	 from v$log)
select count(lh.DY) "DAYS", sum(lh.REDOLOGS) "TTL_LOGS", (sum(lh.REDOLOGS) * vl.MB) "TTL_MB", 
	((sum(lh.REDOLOGS) * vl.MB) / count(lh.DY)) "MB/DAY", ((sum(lh.REDOLOGS) * vl.MB) / count(lh.DY) * 7) "MB/WEEK"
from lh, vl
group by vl.MB;

-- average log switches per hour & day
with lh as
	(select to_char(lh.first_time,'DD-MON-RR HH24') "HR", count(*) "REDOLOGS"
	 from v$log_history lh
	 group by to_char(lh.first_time,'DD-MON-RR HH24')),
vl as
	(select (max(bytes)/1024/1024) "MB"
	 from v$log)
select count(lh.HR) "HOURS", sum(lh.REDOLOGS) "TTL_LOGS", (sum(lh.REDOLOGS) * vl.MB) "TTL_MB", 
	((sum(lh.REDOLOGS) * vl.MB) / count(lh.HR)) "MB/HOUR", ((sum(lh.REDOLOGS) * vl.MB) / count(lh.HR) * 24) "MB/DAY"
from lh, vl
group by vl.MB;

alter session set nls_date_format='DD-MON-RR HH24';
select to_char(lh.first_time,'YYYYMMDD HH24') "DY", count(*) "REDOLOGS"
from v$log_history lh
group by to_char(lh.first_time,'YYYYMMDD HH24') order by 1;

-- max number of logs per day for GoldenGate
with lh as
	(select max(REDOLOGS) "MAXLOGS", avg(REDOLOGS) "AVGLOGS" from (
		select to_char(lh.first_time,'DD-MON-RR HH24')||':00' "HR", count(*) "REDOLOGS"
		from v$log_history lh
		group by to_char(lh.first_time,'DD-MON-RR HH24')||':00')
	),
vl as
	(select (max(bytes)/1024/1024) "MB"
	 from v$log)
select round(lh.AVGLOGS*24,1) "DAILY_LOG_AVG", round(vl.MB*lh.AVGLOGS*24,0) "DAILY_MB_AVG", lh.MAXLOGS*24 "DAILY_LOG_MAX", vl.MB*lh.MAXLOGS*24 "DAILY_MB_MAX"
from lh, vl;
