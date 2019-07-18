SET MARKUP HTML ON SPOOL ON HEAD "<TITLE>ARCHIVED LOG GENERATION - INFO </title> - 
<STYLE TYPE='TEXT/CSS'><!--BODY {background: ffffc6} --></STYLE>" 
SET ECHO OFF
SET PAGES 200
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
