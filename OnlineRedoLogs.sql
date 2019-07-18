-- switch to next redo log
ALTER SYSTEM SWITCH LOGFILE;

-- find logging details of redo logs
alter session set nls_date_format='DD-MON HH24:MI';
set numf 9999999999990
col member format a50
select l.group#, f.member, l.status, l.first_change#, l.first_time, l.archived
from v$log l join v$logfile f on l.group#=f.group#
order by l.group#, f.member;

-- find size info of redo logs
set lines 150 pages 200
col member format a50
col "MB" format 9,990
select l.group#, f.member, (l.bytes/1024/1024) "MB", l.blocksize
from v$log l join v$logfile f on l.group#=f.group#
order by l.group#, f.member;

-- size by mount point
set lines 150 pages 200
col mount format a40
select substr(f.member,1,instr(f.member,'/',-1)-1) mount, count(f.member) "LOGS", avg(l.bytes/1024/1024) "AvgMB", sum(l.bytes/1024/1024) "TotalMB"
from v$log l join v$logfile f on l.group#=f.group#
group by substr(f.member,1,instr(f.member,'/',-1)-1) order by 1;

-- add redo log group
ALTER DATABASE ADD LOGFILE 
GROUP &what_group '&what_file' SIZE 300M BLOCKSIZE 512;
-- reuse file
ALTER DATABASE ADD LOGFILE 
GROUP &what_group '&what_file' SIZE 512M BLOCKSIZE 512 REUSE;

-- add file to existing group
ALTER DATABASE ADD LOGFILE MEMBER '&what_file' TO GROUP &what_group ;
-- resuse file
ALTER DATABASE ADD LOGFILE MEMBER '&what_file' REUSE TO GROUP &what_group ;

ALTER DATABASE ADD LOGFILE 
GROUP 5 'D:\ORADATA\DEVEM12\REDO05.LOG' 
  SIZE 300M BLOCKSIZE 512,
GROUP 6 'D:\ORADATA\DEVEM12\REDO06.LOG' 
  SIZE 300M BLOCKSIZE 512;


-- drop redo log
ALTER DATABASE DROP LOGFILE MEMBER '&what_file';
ALTER DATABASE DROP LOGFILE GROUP &what_group;


-- clear logfile
ALTER DATABASE CLEAR LOGFILE 'filename';

-- see redo logs and SCNs
set lines 150 pages 200
set numf 9999999999990
col member format a50
SELECT V1.GROUP#, MEMBER, SEQUENCE#, FIRST_CHANGE#  
FROM V$LOG V1, V$LOGFILE V2 
WHERE V1.GROUP# = V2.GROUP#; 

-- see time for logs
set lines 150 pages 200
set numf 9999999999990
col member format a50
SELECT V1.GROUP#, MEMBER, SEQUENCE#, FIRST_CHANGE#, to_char(FIRST_TIME,'HH24:MI:SS') "FIRST_TIME"
FROM V$LOG V1, V$LOGFILE V2 
WHERE V1.GROUP# = V2.GROUP#
ORDER BY FIRST_CHANGE#, MEMBER;


SELECT rf.FILE#, rf.CHANGE#, df.name
FROM V$RECOVER_FILE rf, v$datafile df
where rf.file#=df.file# order by rf.file#;

-- calculate recommended size of redo logs
SELECT(SELECT ROUND(AVG(BYTES) / 1024 / 1024, 2) FROM V$LOG) AS "Redo size (MB)"
	,ROUND((20 / AVERAGE_PERIOD) * (SELECT AVG(BYTES) FROM V$LOG) / 1024 / 1024, 2) AS "Recommended Size (MB)"
FROM (
	SELECT AVG((NEXT_TIME - FIRST_TIME) * 24 * 60) AS AVERAGE_PERIOD
	FROM V$ARCHIVED_LOG
	WHERE FIRST_TIME > SYSDATE - 3 AND TO_CHAR(FIRST_TIME, 'HH24:MI') BETWEEN '&START_OF_PEAK_HOURS' AND '&END_OF_PEAK_HOURS'
);

SELECT(SELECT ROUND(AVG(BYTES) / 1024 / 1024, 2) FROM V$LOG) AS "Redo size (MB)"
	,ROUND((20 / AVERAGE_PERIOD) * (SELECT AVG(BYTES) FROM V$LOG) / 1024 / 1024, 2) AS "Recommended Size (MB)"
FROM (
	SELECT AVG((NEXT_TIME - FIRST_TIME) * 24 * 60) AS AVERAGE_PERIOD
	FROM V$ARCHIVED_LOG
);


-- ####################
-- # resize redo logs #
-- ####################

    GROUP# MEMBER                                                 MB  BLOCKSIZE
---------- -------------------------------------------------- ------ ----------
         1 /move/dsrm_redo01/oralog/redo0101.log                  50        512
         1 /move/dsrm_redo02/oralog/redo0102.log                  50        512
         2 /move/dsrm_redo01/oralog/redo0201.log                  50        512
         2 /move/dsrm_redo02/oralog/redo0202.log                  50        512
         3 /move/dsrm_redo01/oralog/redo0301.log                  50        512
         3 /move/dsrm_redo02/oralog/redo0302.log                  50        512

-- add new groups with new size
ALTER DATABASE ADD LOGFILE 
GROUP 4 '/move/dsrm_redo01/oralog/redo0401.log' 
  SIZE 1000M BLOCKSIZE 512,
GROUP 4 '/move/dsrm_redo02/oralog/redo0402.log' 
  SIZE 1000M BLOCKSIZE 512;
  
ALTER DATABASE ADD LOGFILE 
GROUP 5 '/move/dsrm_redo01/oralog/redo0501.log' 
  SIZE 1000M BLOCKSIZE 512,
GROUP 5 '/move/dsrm_redo02/oralog/redo0502.log' 
  SIZE 1000M BLOCKSIZE 512;
  
ALTER DATABASE ADD LOGFILE 
GROUP 6 '/move/dsrm_redo01/oralog/redo0601.log' 
  SIZE 1000M BLOCKSIZE 512,
GROUP 6 '/move/dsrm_redo02/oralog/redo0602.log' 
  SIZE 1000M BLOCKSIZE 512;
  
-- repeat this until the group members are inactive
alter system checkpoint;
select * from v$log;

alter database drop logfile group 1;
alter database drop logfile group 2;
alter database drop logfile group 3;

-- confirm groups 1-3 have been removed
select * from v$log;

-- delete the old logs
rm /move/dsrm_redo01/oralog/redo0101.log
rm /move/dsrm_redo02/oralog/redo0102.log
rm /move/dsrm_redo01/oralog/redo0201.log
rm /move/dsrm_redo02/oralog/redo0202.log
rm /move/dsrm_redo01/oralog/redo0301.log
rm /move/dsrm_redo02/oralog/redo0302.log


-- #######################
-- # redo log generation #
-- # SR 3-15542794431    #
-- #######################

-- archive log count per hour
SET MARKUP HTML ON SPOOL ON HEAD "<TITLE>ARCHIVED LOG GENERATION - INFO </title> - 
<STYLE TYPE='TEXT/CSS'><!--BODY {background: ffffc6} --></STYLE>" 
SET ECHO ON 

--spool /nomove/app/oracle/scripts/12cupgrade/logs/ARCHIVED_LOGS_0117.html
column filename new_val filename
--select '/app/oracle/scripts/12cupgrade/logs/ARCHIVED_LOGS_'||to_char(sysdate,'mondd')||'.html' filename from dual;
select '/tmp/'||name||'_ARCHIVED_LOGS_'||to_char(sysdate,'mondd')||'.html' filename from v$database;
spool &filename

SELECT LOG_HISTORY.*, SUM_ARCH.GENERATED_MB, SUM_ARCH_DEL.DELETED_MB, (SUM_ARCH.GENERATED_MB - SUM_ARCH_DEL.DELETED_MB) "REMAINING_MB" 
FROM ( 
	SELECT TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY, 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '00', 1, NULL)) "00-01", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '01', 1, NULL)) "01-02", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '02', 1, NULL)) "02-03", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '03', 1, NULL)) "03-04", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '04', 1, NULL)) "04-05", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '05', 1, NULL)) "05-06", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '06', 1, NULL)) "06-07", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '07', 1, NULL)) "07-08", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '08', 1, NULL)) "08-09", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '09', 1, NULL)) "09-10", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '10', 1, NULL)) "10-11", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '11', 1, NULL)) "11-12", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '12', 1, NULL)) "12-13", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '13', 1, NULL)) "13-14", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '14', 1, NULL)) "14-15", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '15', 1, NULL)) "15-16", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '16', 1, NULL)) "16-17", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '17', 1, NULL)) "17-18", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '18', 1, NULL)) "18-19", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '19', 1, NULL)) "19-20", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '20', 1, NULL)) "20-21", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '21', 1, NULL)) "21-22", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '22', 1, NULL)) "22-23", 
		SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '23', 1, NULL)) "23-00", 
		COUNT (*) TOTAL 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' --and COMPLETION_TIME >= sysdate-14
	GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')
) LOG_HISTORY, ( 
	SELECT TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY, SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2)) GENERATED_MB 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' 
	GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')
) SUM_ARCH, ( 
	SELECT TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY, SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2)) DELETED_MB 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' AND DELETED = 'YES' 
	GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')
) SUM_ARCH_DEL 
WHERE LOG_HISTORY.DAY = SUM_ARCH.DAY AND SUM_ARCH.DAY = SUM_ARCH_DEL.DAY(+) 
ORDER BY TO_DATE (LOG_HISTORY.DAY, 'DD/MM/YYYY'); 

spool off 
SET MARKUP HTML OFF 
SET ECHO ON 


-- archive log sizes per hour
SET MARKUP HTML ON SPOOL ON HEAD "<TITLE>ARCHIVED LOG GENERATION - INFO </title> - 
<STYLE TYPE='TEXT/CSS'><!--BODY {background: ffffc6} --></STYLE>" 
SET ECHO ON
col DAY format a6
column filename new_val filename
select '/tmp/'||name||'_ARCHIVED_LOGS_'||to_char(sysdate,'mondd')||'.html' filename from v$database;
spool &filename

SELECT TO_CHAR (COMPLETION_TIME, 'MM/DD') DAY, 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '00', (blocks * block_size) / (1024 * 1024), NULL)), 0) "00-01", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '01', (blocks * block_size) / (1024 * 1024), NULL)), 0) "01-02", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '02', (blocks * block_size) / (1024 * 1024), NULL)), 0) "02-03", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '03', (blocks * block_size) / (1024 * 1024), NULL)), 0) "03-04", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '04', (blocks * block_size) / (1024 * 1024), NULL)), 0) "04-05", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '05', (blocks * block_size) / (1024 * 1024), NULL)), 0) "05-06", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '06', (blocks * block_size) / (1024 * 1024), NULL)), 0) "06-07", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '07', (blocks * block_size) / (1024 * 1024), NULL)), 0) "07-08", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '08', (blocks * block_size) / (1024 * 1024), NULL)), 0) "08-09", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '09', (blocks * block_size) / (1024 * 1024), NULL)), 0) "09-10", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '10', (blocks * block_size) / (1024 * 1024), NULL)), 0) "10-11", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '11', (blocks * block_size) / (1024 * 1024), NULL)), 0) "11-12", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '12', (blocks * block_size) / (1024 * 1024), NULL)), 0) "12-13", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '13', (blocks * block_size) / (1024 * 1024), NULL)), 0) "13-14", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '14', (blocks * block_size) / (1024 * 1024), NULL)), 0) "14-15", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '15', (blocks * block_size) / (1024 * 1024), NULL)), 0) "15-16", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '16', (blocks * block_size) / (1024 * 1024), NULL)), 0) "16-17", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '17', (blocks * block_size) / (1024 * 1024), NULL)), 0) "17-18", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '18', (blocks * block_size) / (1024 * 1024), NULL)), 0) "18-19", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '19', (blocks * block_size) / (1024 * 1024), NULL)), 0) "19-20", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '20', (blocks * block_size) / (1024 * 1024), NULL)), 0) "20-21", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '21', (blocks * block_size) / (1024 * 1024), NULL)), 0) "21-22", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '22', (blocks * block_size) / (1024 * 1024), NULL)), 0) "22-23", 
	ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '23', (blocks * block_size) / (1024 * 1024), NULL)), 0) "23-00",
	ROUND ( SUM( (blocks * block_size) / (1024 * 1024)), 0) "MB",
	COUNT(*) "TOTAL"
FROM V$ARCHIVED_LOG 
WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-14
GROUP BY TO_CHAR (COMPLETION_TIME, 'MM/DD')
ORDER BY TO_CHAR (COMPLETION_TIME, 'MM/DD');

spool off 
SET MARKUP HTML OFF 
SET ECHO ON 


-- summary of last 90 days
set lines 150 pages 200
set numf 999,999,990
SELECT COUNT(LH.HOURS) "TTL-HRS", SUM(LH.TOTAL) "TTL-LOGS", ROUND(SUM(LH.GENERATED_MB),0) "TTL-MB", 
	ROUND(SUM(LH.GENERATED_MB)/COUNT(LH.HOURS),0) "MB/HR",
	ROUND(SUM(LH.GENERATED_MB)/COUNT(LH.HOURS)*6,0) "6HR (MB)",
	ROUND(SUM(LH.GENERATED_MB)/COUNT(LH.HOURS)*12,0) "12HR (MB)",
	ROUND(SUM(LH.GENERATED_MB)/COUNT(LH.HOURS)*18,0) "18HR (MB)"
FROM ( 
	SELECT COUNT(TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY HH24')) "HOURS", 
		COUNT (*) TOTAL, SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2)) GENERATED_MB 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-90
	GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY HH24')
) LH;

-- daily numbers
SELECT TO_CHAR (COMPLETION_TIME, 'MM/DD') DAY, ROUND ( SUM( (blocks * block_size) / (1024 * 1024)), 0) "MB", COUNT(*) "TOTAL"
FROM V$ARCHIVED_LOG 
WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-60
GROUP BY TO_CHAR (COMPLETION_TIME, 'MM/DD')
ORDER BY TO_CHAR (COMPLETION_TIME, 'MM/DD');

-- Rubrik estimate (only works in archivelog mode)
set lines 150 pages 200
set numf 999,999,990
SELECT COUNT(LH.DAY_TOTAL) "TTL-DAYS", ROUND(AVG(LH.GENERATED_MB),0) "AVG/DAY (MB)", ROUND(MAX(LH.GENERATED_MB),0) "MAX/DAY (MB)"
FROM ( 
	SELECT TO_CHAR (COMPLETION_TIME, 'YYYY-MM-DD') "DAY_TOTAL", 
		SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2)) GENERATED_MB 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-90
	GROUP BY TO_CHAR (COMPLETION_TIME, 'YYYY-MM-DD')
) LH;


SELECT TO_CHAR (COMPLETION_TIME, 'YYYY-MM-DD WW') "DAY_TOTAL", COUNT (*) TOTAL,
		SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2)) GENERATED_MB 
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-90
	GROUP BY TO_CHAR (COMPLETION_TIME, 'YYYY-MM-DD WW')
	
	
-- max hour in past

ROUND( SUM ( DECODE (TO_CHAR (COMPLETION_TIME, 'MMDDHH24'), '23', (blocks * block_size) / (1024 * 1024), NULL)), 0) "23-00"

SELECT max("MB") FROM (
	SELECT TO_CHAR(COMPLETION_TIME, 'MMDDHH24') "TIME", ROUND(sum((blocks * block_size) / (1024 * 1024)),0) "MB"
	FROM V$ARCHIVED_LOG 
	WHERE ARCHIVED = 'YES' and COMPLETION_TIME >= sysdate-14
	GROUP BY TO_CHAR(COMPLETION_TIME, 'MMDDHH24')
);
