-- ###############
-- # MOST USEFUL #
-- ###############

-- process count by machine
break on report;
compute sum of count(*) on report;
col machine format a30
select machine, count(*) from v$session group by machine order by machine;

-- find number of sessions per machine for SQL statements
select machine, count(*) from v$session where sql_id in ('606yhvf1a66ar','08vacu533shgw') group by machine order by 2 desc;

-- kill all sessions for a machine
select 'alter system kill session '''||sid||','||serial#||''' immediate;'
from v$session where machine = '&what_machine';

-- find systems info for blocking sessions (only shows blocking session info)
set lines 120 pages 200
col sid format 9990
col "SER" format 99990
col "Description" format a35
col osuser format a12
col program format a15
col machine format a20
col process format a12
select distinct blkr.machine, blkr.process, blkr.sid, blkr.serial#, blkr.osuser, blkr.program,
  decode(blkr.state,'WAITING','Waiting '||blkr.seconds_in_wait||'s for '||blkr.event,'SQL') "Description"
from v$session blkr, v$session blkd where blkd.blocking_session=blkr.sid
order by blkr.machine, blkr.process;

-- try this to see current/previous SQL ID
select distinct blkr.machine, blkr.process, blkr.sid, blkr.serial#, blkr.osuser, blkr.program,
decode(blkr.state,'WAITING','Waiting '||blkr.seconds_in_wait||'s '||decode(blkr.event,'SQL*Net message from client',NVL2(blkr.sql_id,'SQL: '||blkr.sql_id,'Prev: '||blkr.prev_sql_id),blkr.event),
  blkr.sql_id) "Description"
from v$session blkr, v$session blkd where blkd.blocking_session=blkr.sid
order by blkr.machine, blkr.process;

-- find sessions that are working
SET LINES 150 PAGES 1000
COLUMN username FORMAT A19
COLUMN program FORMAT A20
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
ALTER SESSION SET NLS_DATE_FORMAT='MM/DD/RR HH24:MI';
SELECT DISTINCT s.sid, s.serial# "SER", s.username, s.osuser, s.logon_time, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program not like 'oracle%' and s.username!='DBSNMP' and event not like '%SQL*Net%' --and s.osuser!='dejesusk'
ORDER BY "Description" DESC, s.osuser, s.username, s.program, s.sid;

--ORDER BY s.seconds_in_wait DESC, s.osuser, s.username, s.program, s.sid;

col "Description" format a20
SELECT s.sid, s.serial# "SER", s.username, s.osuser, s.program,
(s.state||' '||s.seconds_in_wait||'s') "Description", s.sql_id
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program not like 'ORACLE.EXE%' and s.username!='DBSNMP' --and s.osuser!='dejesusk'
ORDER BY s.osuser, s.username, s.program, s.sid;

-- find RMAN sessions
SET LINES 150 PAGES 1000
COLUMN username FORMAT A19
COLUMN program FORMAT A20
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
ALTER SESSION SET NLS_DATE_FORMAT='MM/DD/RR HH24:MI';
SELECT DISTINCT s.sid, s.serial# "SER", s.username, s.osuser, s.logon_time, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program like '%rman%';

-- find sessions performing INSERT, UPDATE, DELETE, MERGE statements
SELECT s.sid, s.serial# "SER", s.username, s.osuser, s.logon_time, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program not like 'ORACLE.EXE%' and s.username!='DBSNMP' and s.osuser!='dejesusk'
  AND (upper(q.sql_text) like 'INSERT%' OR upper(q.sql_text) like 'DELETE%' OR upper(q.sql_text) like 'UPDATE%' OR upper(q.sql_text) like 'MERGE%')
ORDER BY s.osuser, s.username, s.program, s.sid;

-- find sessions blocking other sessions
-- BLK01
col "BLOCKED" format format 9990
col serial# format 99990
col "BLOCKER" format 9990
col "BLKR_SER" format 99990
col object_name format a20
col "BLKR_OS" format a16
col osuser format a16
col bl_module format a20
col locked_mode format a8
with blocked as (
 select sid blocked, serial#, username, osuser, blocking_session
 from v$session
 where blocking_session is not null
),
blocking as (
 select sid blocking, serial# bl_serial#, osuser bl_os, module bl_module
 from v$session
),
obj_info as (
 select l.session_id, o.object_name, l.object_id,
 decode(l.locked_mode,   1, 'No Lock',
        2, 'RowShare',
        3, 'RowExcl',
        4, 'ShrdTab',
        5, 'ShrRwExc',
        6, 'Exclusve') locked_mode
 from v$locked_object l, dba_objects o
 where o.object_id = l.object_id
)
select blocked "BLOCKED", serial#, osuser, blocking "BLOCKER", bl_serial# "BLKR_SER", bl_os "BLKR_OS", bl_module, object_name, locked_mode
from blocked join blocking on blocking = blocking_session
  left outer join obj_info on session_id = blocking_session
order by blocking, blocked;


-- ###########################
-- # ACTIVE SESSION QUERIES  #
-- ###########################

-- find sessions by OS user
SET LINESIZE 120 PAGESIZE 200
COLUMN username FORMAT A19
COLUMN program FORMAT A20
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
SELECT s.sid, s.serial# "SER", s.username, s.osuser, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),
  q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE lower(s.osuser) like '%&what_osuser%'
ORDER BY s.osuser, s.program;

-- find session by DB username
SET LINESIZE 120 PAGESIZE 200
COLUMN username FORMAT A19
COLUMN program FORMAT A20
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
SELECT s.sid, s.serial# "SER", s.username, s.osuser, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),
  q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.username=upper('&what_username')
ORDER BY s.osuser, s.program;

-- find all sessions except Oracle & SYSTEM
SET LINESIZE 120 PAGESIZE 200
COLUMN username FORMAT A19
COLUMN program FORMAT A20
col osuser format a15
col sid format 9990
col "SER" format 99990
col "Description" format a48
SELECT s.sid, s.serial# "SER", s.username, s.osuser, s.program,
decode(s.state,'WAITING','Waiting '||s.seconds_in_wait||'s for '||NVL2(q.sql_text, q.sql_text, event),
  q.sql_text) "Description"
FROM v$session s left outer join v$sql q on s.sql_id=q.sql_id
WHERE s.program not like 'ORACLE.EXE%' and s.osuser!='SYSTEM'
ORDER BY s.osuser, s.username, s.program;

-- long-running sessions
set lines 150 pages 200
col osuser format a15
col sid format 9990
col "Progress" format a102
SELECT s.sid, s.osuser, s.program
      ,to_char(l.start_time,'DD-MON-YY HH24MI') "Time Started"
      ,l.sofar " Work Done"
      ,l.totalwork "Total Work"
      ,RPAD(DECODE(l.totalwork,0,'N/A',ROUND(100*l.sofar/l.totalwork,2)||'%'),12) "% Complete"
      ,TO_CHAR(SYSDATE+(l.time_remaining/24/3600),'DD-MON-YY HH24MI') "Estimated Finish Time"
      ,RPAD(RPAD('<',DECODE(l.totalwork,0,0,ROUND(100*l.sofar/l.totalwork,2)),'|'),101)||'>' "Progress"
FROM v$session_longops l JOIN v$session s on l.sid=s.sid
WHERE l.sofar<>l.totalwork and s.status='ACTIVE'
ORDER BY l.start_time desc;

col sid format 9990
col opname format a30
col target format a40
col "Start" format a11
col "Est Finish Time" format a11
col "Complete" format a5
SELECT l.sid, l.opname, l.target
      ,to_char(l.start_time,'MM/DD HH24MI') "Start"
      ,l.sofar " Work Done"
      ,l.totalwork "Total Work"
      ,RPAD(DECODE(l.totalwork,0,'N/A',ROUND(100*l.sofar/l.totalwork,2)||'%'),12) "Complete"
      ,TO_CHAR(SYSDATE+(l.time_remaining/24/3600),'MM/DD HH24MI') "Est Finish Time"
FROM v$session_longops l
WHERE l.sofar<>l.totalwork --and s.status='ACTIVE'
ORDER BY l.start_time desc;

-- get top 5 session events by time waited
-- time_waited is total for session
set numformat 999,990.00
col sid format 9990
col "SER" format 99990
col event format a40
col wait_class format a20
col module format a25
col "Min" format 99,999.90
select ses.sid, ses.serial# "SER", ses.module, ses.event, (ev.time_waited/6000) "Min", ev.wait_class from 
  (select sid, event, time_waited, wait_class, row_number() over (order by time_waited desc) r
   from v$session_event where wait_class!='Idle') ev, v$session ses
where ev.sid=ses.sid and ev.r<6;

-- average time waited
select ses.sid, ses.serial# "SER", ses.module, ses.event, (ev.AVERAGE_WAIT/6000) "Min", ev.wait_class from 
  (select sid, event, AVERAGE_WAIT, wait_class, row_number() over (order by AVERAGE_WAIT desc) r
   from v$session_event where wait_class!='Idle') ev, v$session ses
where ev.sid=ses.sid and ev.r<6;


-- get top 10 sessions by logon time
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-RR HH24:MI';
COLUMN username FORMAT A20
COLUMN program FORMAT A25
col osuser format a15
col program format a15
SELECT s.sid, s.serial#, s.username, s.osuser, s.program,
	s.sql_id, s.status, s.logon_time
FROM v$session s, 
  (select sid, row_number() over (order by logon_time asc) r
   from v$session where status='ACTIVE' and program not like 'ORACLE.EXE%') ev
where ev.sid=s.sid and ev.r<11;

-- taken from metalink [ID 68738.1]
column sid format 9990
column seq# format 99990
column wait_time heading 'WTime' format 99990
column event format a30
column p1 format 99999999990
column p2 format 99999999990
column p3 format 9990 
select sid, seq#, event, wait_class, state, wait_time_micro/1000000
from V$session_wait
where wait_class!='Idle' and wait_time>=0
order by sid;



-- see info for a transaction
select addr, xidusn, xidslot, xidsqn from v$transaction;

-- see sessions with an active transaction
set linesize 120
col sid format 9990
col serial# format 99990
col osuser format a15
col program format a25
col log_io format 999990
col phy_io format 99990
col used_ublk format 9990
select vs.sid, vs.serial#, vs.osuser, vs.program, vt.status, vt.start_time,
	vt.log_io, vt.phy_io, vt.used_ublk
from v$transaction vt join v$session vs on vt.ses_addr=vs.saddr;

-- find sql statement of a session
set linesize 120
set pagesize 200
col sid format 9990
col serial# format 99990
col username format a20
col sql_text format a80
select ses.sid, ses.serial#, ses.username, sq.sql_text
from v$session ses, v$sql sq
where ses.sql_id=sq.sql_id and osuser!='SYSTEM' 
and ses.sid=&what_sid order by username, sql_text;

-- find sessions running a sql statement
set linesize 120
set pagesize 200
col sid format 9990
col serial# format 99990
col osuser format a15
col username format a25
col machine format a25
select ses.sid, ses.serial#, ses.username, ses.osuser, ses.machine, 
	TO_CHAR(TRUNC(ses.last_call_et/3600),'FM9900') || ':' ||
    TO_CHAR(TRUNC(MOD(ses.last_call_et,3600)/60),'FM00') || ':' ||
    TO_CHAR(MOD(ses.last_call_et,60),'FM00') "TOTAL_TIME"
from v$session ses, v$sql sq
where ses.sql_id=sq.sql_id and osuser!='SYSTEM' 
and sq.sql_id='&what_sql' order by ses.sid;
--and sq.sql_text like '%INDEX%FX03%';

-- find sessions executing PL/SQL statements
col sid format 9990
col serial# format 99990
col username format a20
col sql_text format a80
select ses.sid, ses.serial#, ses.username, sq.sql_text
from v$session ses, v$sql sq
where ses.sql_id=sq.sql_id and osuser!='SYSTEM' 
and (ses.command=47 or ses.plsql_object_id is not null) order by username, sql_text;

-- find bind variables for a sql statement
alter session set nls_date_format='DD-MON-YY HH24:MI:SS';
col name format a15
col value_string format a40
SELECT last_captured, NAME, VALUE_STRING
FROM v$sql_bind_capture WHERE sql_id='&what_sqlid' and VALUE_STRING is not null order by 1,2;

-- if query run more than 30 minutes ago, use:
col name format a30
col value_string format a40
alter session set nls_date_format='dd-mm-yy hh24:mi';
SELECT last_captured, NAME, VALUE_STRING
FROM DBA_HIST_SQLBIND WHERE sql_id='&what_sqlid' 
and value_string is not null
order by 1,2;

-- format for use (still have to massage date/number data)
col "VAR" format a50
alter session set nls_date_format='dd-mm-yy hh24:mi';
break on last_captured
SELECT last_captured, 'exec ' || NAME || ' := ''' || VALUE_STRING || '''' "VAR"
FROM DBA_HIST_SQLBIND
WHERE sql_id='9q3w65yzkaf3x' and value_string is not null --and rownum<11
order by last_captured, NAME;

-- find SQL of an error from miserror table
alter session set nls_date_format='DDMMYYYYHH24MISS';
select tmstamp from actd00.miserror where logid=&log_id;

set linesize 120
set pagesize 200
col sid format 9990
col serial# format 99990
col osuser format a15
col sql_text format a80
select ses.sid, ses.serial#, ses.username, ses.osuser, ses.program, ses.module
from v$session ses, v$sql sq
where ses.sql_id=sq.sql_id and osuser!='SYSTEM' 


-- from OEM
select module, count(*)
from v$active_session_history
where sample_time > sysdate - :"SYS_B_0"/:"SYS_B_1" AND sample_time < sysdate and service_hash = :1 group by module order by count(*) desc

-- also from OEM
select end_time, wait_class#, (time_waited_fg)/(intsize_csec/100), (time_waited)/(intsize_csec/100), 0
from v$waitclassmetric_history union all
select fg.end_time, -1, fg.value, bg.value, dbtime.value
from v$sysmetric_history bg, v$sysmetric_history fg, v$sysmetric_history dbtime
where bg.metric_name = 'Background CPU Usage Per Sec' and bg.group_id = 2 and 
fg.metric_name = 'CPU Usage Per Sec' and fg.group_id = 2 and 
dbtime.metric_name = 'Average Active Sessions' and dbtime.group_id = 2 and bg.end_time = fg.end_time and fg.end_time = dbtime.end_time order by end_time,wait_class#;


-- find out what's using temp space
V$SORT_USAGE
V$SORT_SEGMENT

select ( select username from v$session where saddr = session_addr) uname,
          v.* from v$sort_usage v;
		  
-- temp space usage by sorting/hashing
-- http://dbakevlar.com/2010/01/when-pga-size-is-not-enough/
select vs.sid, vs.osuser, vs. process, vs.sql_id, vtu.segtype, 
((vtu.blocks*8)/1024)MB, vtu.tablespace
from v$tempseg_usage vtu, v$session vs
where vtu.session_num=vs.serial#
and segtype in (‘HASH’,’SORT’)
order by blocks desc;

--
-- http://dbakevlar.com/2011/08/a-tale-of-session-parameter-settings/
select vst.sql_text, swa.sql_id, swa.sid, swa.tablespace
, swa.operation_type
, trunc(swa.work_area_size/1024/1024) "PGA MB"
, trunc(swa.max_mem_used/1024/1024)"Mem MB"
, trunc(swa.tempseg_size/1024/1024)"Temp MB"
from v$sql_workarea_active swa, v$session vs, v$sqltext vst
where swa.sid=vs.sid
and swa.sql_id=vs.sql_id
and vs.sql_id=vst.sql_id
and vst.piece=0
order by swa.operation_type;

-- find top 5 active sql statements by disk activity
-- SQL01
set long 5000
col sid format 9990
col sql_fulltext format a80
col osuser format a12
col "I/O" format 999,999,990
select sid, osuser, "I/O", sql_fulltext from
  (select ss.sid, ss.osuser, (sa.disk_reads+sa.direct_writes) "I/O", sa.sql_fulltext, 
    row_number() over (order by sa.disk_reads+sa.direct_writes desc) r
    from v$sqlarea sa, v$session ss
    where sa.sql_id=ss.sql_id)
where r<6;

-- OR -- try this one
select t5.sid, t5.osuser, t5."I/O", sq.sql_fulltext from
  (select ss.sid, ss.osuser, io.physical_reads "I/O", ss.sql_id,
    row_number() over (order by io.physical_reads desc) r
    from v$sess_io io left outer join v$session ss
    on io.sid=ss.sid) t5 left outer join v$sql sq
  on t5.sql_id=sq.sql_id
where r<6;


-- find top 10 files by historical I/O activity
-- IO01
col "READS" format 99,999,990
col "READS (m)" format 99,999.90
select file#, phyrds "READS", readtim/6000 "READS (m)", 
  avgiotim, lstiotim
from 
  (select file#, phyrds, readtim, avgiotim, lstiotim,
     row_number() over (order by phyrds desc) r
   from V$FILESTAT)
where r<11;

-- find top 10 files by time of last I/O action
-- IO02
col "READS" format 99,999,990
col "READS (m)" format 99,999.90
select file#, phyrds "READS", readtim/6000 "READS (m)", 
  avgiotim, lstiotim
from 
  (select file#, phyrds, readtim, avgiotim, lstiotim,
     row_number() over (order by lstiotim desc) r
   from V$FILESTAT)
where r<11;

-- find top 5 sql by parse calls & child cursors
-- SQL02
set long 5000
col sql_fulltext format a80
col parse_calls format 9,999,990
select sql_id, parse_calls, version_count, sql_fulltext
from
  (select sql_id, sql_fulltext, parse_calls, version_count
     , row_number() over (order by parse_calls desc) pc
     , row_number() over (order by version_count desc) vc
   from v$sqlarea)
where pc<6 or vc<6;


set long 5000
col sql_fulltext 
select sw.sid, sw.wait_time, sq.sql_fulltext
from v$session_wait sw, v$session ses, v$sqlarea sq
where sw.event='library cache lock' 
and sw.sid=ses.sid
and ses.sql_id=sq.sql_id;


username, lockwait, process, program, action

select sid, serial#, status, schemaname, osuser, machine, event, wait_time, blocking_session bl_sid, logon_time
from v$session where sid=


-- top 10 sessions by CPU w/physical & logical reads
set lines 150 pages 200
col sid format 99990
col osuser format a15
col cpu format 9999.90
col machine format a20
col username format a15
alter session set nls_date_format='DD-MON-YY HH24:MI';
SELECT s.sid, s.username, s.osuser, s.machine, ev.cpu, ev.physical_reads "PHYS", ev.logical_reads "LOGI", 
	ev.pga_memory, ev.begin_time, s.sql_id
FROM v$session s, 
  (select session_id, cpu, begin_time, physical_reads, logical_reads, pga_memory,
   row_number() over (order by cpu desc) r from v$sessmetric where cpu>0) ev
where ev.session_id=s.sid and ev.r<10;


-- find redo in use
col "SQL" for a50
col "Session" for a12
col "OS User" for a15
col "DB User" for a15
col "REDO(MB)" format 99999.0
SELECT s.sid||','||s.serial# "Session", s.status "Status", s.username "DB User", 
  s.osuser "OS User", ss.value/1024/1024 "REDO(MB)", sql.sql_text "SQL"
FROM   v$sesstat ss
JOIN   v$statname sn
  ON   ss.statistic# = sn.statistic#
JOIN   v$session s
  ON   ss.sid = s.sid
LEFT JOIN v$sqlarea sql
  ON s.sql_hash_value = sql.hash_value AND s.sql_address = sql.address
WHERE  sn.name = 'redo size' AND ss.value/1024/1024 > 1
ORDER BY ss.value DESC;

-- find session stats (incl. cpu usage)
select b.name, a.value
from v$sesstat a, v$statname b
where a.statistic# = b.statistic#  and a.sid=&what_sid
and lower(b.name) like '%what_stat%';

-- find sessions with resumable errors
col sid format 9990
col serial# format 99990
col timeout format 99990
col error_msg format a95
col sql_text format a119
select s.sid, s.serial#, r.timeout, r.error_msg, r.sql_text
from dba_resumable r join v$session s on r.session_id=s.sid;

-- find session with open db links
-- last # in GTXID matches up; last 3 numbers are XID
col origin format a10
col username format a15
col "WAITING" format a20
col "SESSION" format a10
col "GTXID" format a50
Select /*+ ORDERED */
--substr(s.indx,1,4)||'.'|| substr(s.ksuseser,1,5) "LSESSION" ,
s2.sid||','||s2.serial# "SESSION" ,
s2.username,
--substr(s.ksusemnm,1,9)||'-'|| substr(s.ksusepid,1,11)      "ORIGIN",
s.ksusemnm "ORIGIN",
--substr(g.K2GTITID_ORA,1,30) "GTXID",
g.K2GTITID_ORA "GTXID",
substr(
   decode(bitand(ksuseidl,11),
      1,'ACTIVE',
      0, decode( bitand(ksuseflg,4096) , 0,'INACTIVE','CACHED'),
      2,'SNIPED',
      3,'SNIPED',
      'KILLED'
   ),1,1
) "S",
substr(w.event,1,15) "WAITING"
from  x$k2gte g, x$ktcxb t, x$ksuse s, v$session_wait w, v$session s2
where  g.K2GTDXCB =t.ktcxbxba and   g.K2GTDSES=t.ktcxbses
and s.addr=g.K2GTDSES and w.sid=s.indx and s2.sid = w.sid
order by g.K2GTITID_ORA;

-- 
select s.sid SID, s.serial#, s.username, s.osuser
from v$session s
where s.process='&what_process';


-- ###############
-- # WAIT EVENTS #
-- ###############

buffer busy waits
• Buffer cache, DBWR
• Depends on buffer type. For example, waits for an index block may be caused by a primary key that is based on an ascending sequence.
• Examine V$SESSION while the problem is occurring to determine the type of block in contention. (BLK01)
 
free buffer waits
• Buffer cache, DBWR, I/O
• Slow DBWR (possibly due to I/O?) or Cache too small
• Check disk I/O load.
  Check buffer cache statistics for evidence of too small cache.
 
db file scattered read
• I/O, SQL statement tuning
• Poorly tuned SQL or Slow I/O system
• Investigate V$SQLAREA to see whether there are SQL statements performing many disk reads. (SQL01)
  Cross-check I/O system and V$FILESTAT for poor read time. (IO01 and IO02)
 
db file sequential read
• I/O, SQL statement tuning
• Poorly tuned SQL or Slow I/O system
• Investigate V$SQLAREA to see whether there are SQL statements performing many disk reads. (SQL01)
  Cross-check I/O system and V$FILESTAT for poor read time. (IO01 and IO02)
 
enqueue waits (waits starting with enq:)
• Locks
• Depends on type of enqueue
• Look at V$ENQUEUE_STAT. V$LOCK seems better (LOC02)
 
library cache latch waits: library cache, library cache pin, and library cache lock
• Latch contention (PIN01)
• SQL parsing or sharing
• Check V$SQLAREA to see whether there are SQL statements with a relatively high number of parse calls 
    or a high number of child cursors (column VERSION_COUNT). (SQL02)
  Check parse statistics in V$SYSSTAT and their corresponding rate for each second.
 
log buffer space
• Log buffer, I/O
• Log buffer small or Slow I/O system
• Check the statistic redo buffer allocation retries in V$SYSSTAT. 
  Check configuring log buffer section in configuring memory chapter. 
  Check the disks that house the online redo logs for resource contention.
 
log file sync
• I/O, over- committing
• Slow disks that store the online logs or Un-batched commits
• Check the disks that house the online redo logs for resource contention. 
  Check the number of transactions (commits + rollbacks) each second, from V$SYSSTAT.
 

•V$SESSION_WAIT displays the events for which sessions have just completed waiting or are currently waiting.
•V$SYSTEM_EVENT displays the total number of times all the sessions have waited for the events in that view.
•V$SESSION_EVENT is similar to V$SYSTEM_EVENT, but displays all waits for each session.

-- get top 5 events by percentage of total time
col "WAITS" format 999,999,990
col "TIME (s)" format 999,999,990
col "AVG" format 99,990
col "PCT" format 99.90
select event, total_waits "WAITS", trunc(time_waited/100) "TIME (s)", 
  "PCT", average_wait "AVG"
from 
  (select event, (se.time_waited/ttl.ttl_time)*100 "PCT", average_wait, time_waited,
     total_waits, row_number() over (order by se.time_waited/ttl.ttl_time desc) r
   from v$system_event se, 
     (select sum(time_waited) ttl_time from v$system_event
      where event is not null and event not like '%SQL*Net%') ttl
   where se.event is not null and se.event not like '%SQL*Net%')
where r<6;


-- ##############################
-- # LOCKING / BLOCKING QUERIES #
-- ##############################

-- V$LOCK provides overall view of the active locks
-- V$LOCKED_OBJECT details who has TM (DML) locks against which database objects
-- V$ACCESS : one row for each object locked by any user
-- V$DB_OBJECT_CACHE : one row for each object in the library cache
-- DBA_DDL_LOCKS  : one row for each object that is locked (exception made of the cursors)
-- V$SESSION_WAIT : each session waiting on a library cache pin or lock is blocked by some other session

-- find sessions blocking other sessions
-- BLK01
col "SID" format format 9990
col serial# format 99990
col "BL_SID" format 9990
col "BL_SER" format 99990
col object_name format a20
col "BL_OS" format a16
col osuser format a16
col bl_module format a20
col locked_mode format a8
with blocked as (
 select sid blocked, serial#, username, osuser, blocking_session
 from v$session
 where blocking_session is not null
),
blocking as (
 select sid blocking, serial# bl_serial#, osuser bl_os, module bl_module
 from v$session
),
obj_info as (
 select l.session_id, o.object_name, l.object_id,
 decode(l.locked_mode,   1, 'No Lock',
        2, 'RowShare',
        3, 'RowExcl',
        4, 'ShrdTab',
        5, 'ShrRwExc',
        6, 'Exclusve') locked_mode
 from v$locked_object l, dba_objects o
 where o.object_id = l.object_id
)
select blocked "SID", serial#, osuser, blocking "BL_SID", bl_serial# "BL_SER", bl_os "BL_OS", bl_module, object_name, locked_mode
from blocked join blocking on blocking = blocking_session
  left outer join obj_info on session_id = blocking_session
order by bl_sid, sid;

-- more details about session being blocked
select sid, serial#, username, osuser, blocking_session, seconds_in_wait
from v$session
where blocking_session is not null;

-- find sessions that are waiting for a lock
COL "Waiter" format a25
COL "Holder" format a25
COL "Lock" format a12
COL "Held" format a12
COL "Requested" format a12
SELECT 	dw.holding_session||':'||hs.serial#||' '||hs.osuser "Holder",
	dw.waiting_session||':'||ws.serial#||' '||ws.osuser "Waiter",
	ws.seconds_in_wait "Waited",
	lock_type "Lock",
	mode_held "Held",
	mode_requested "Requested"
FROM v$session ws, v$session hs, dba_waiters dw
WHERE dw.waiting_session=ws.sid and dw.holding_session=hs.sid
AND dw.holding_session!=dw.waiting_session;

-- get sql of blocking session
-- actually shows SID of blocker and SQL of blockee
set long 5000
col "BL_SID" format 9990
col sql_fulltext format 110
SELECT s.blocking_session "BL_SID", v$sql.sql_fulltext
FROM v$sql, v$session s, v$lock l
WHERE s.sql_id=v$sql.sql_id and s.blocking_session=l.sid;

-- find sessions that have requested locks on objects
-- LOC01
set pagesize 200
set linesize 120
col "User" format a20
col "Object" format a35
col "Type" format a10
col "Mode" format a15
select distinct v.session_id, s.serial#, v.os_user_name "User", 
   do.owner||'.'||do.object_name "Object", dl.mode_held "Mode"
from v$locked_object v, dba_objects do, dba_lock dl, v$session s
where v.object_id=do.object_id and v.session_id=dl.session_id
   and s.sid=v.session_id order by "User", "Object";

-- show users who have items locked
-- LOC02
column module format a20
column osuser format a15
column sid format 99999
column object format a25
column locked_mode format a11
col "BL_SID" format 9990
select distinct s.module, s.sid, s.serial#,
       s.osuser, k.ctime, o.object_name object,
case l.locked_mode when 1 then 'No Lock'
                   when 2 then 'Row Share'
                   when 3 then 'Row Exc'
                   when 4 then 'Shr Table'
                   when 5 then 'Shr Row Exc'
                   when 6 then 'Exclusive'
end locked_mode,
	blocking_session "BL_SID"
from v$session s, sys.v$locked_object l, dba_objects o, sys.v$lock k
where o.object_id = l.object_id
and l.session_id = s.sid
and k.sid = s.sid
and k.lmode = l.locked_mode
order by blocking_session NULLS LAST, object, osuser;

-- find session affected by library cache pins
-- PIN01
col sid format 99990
col "SER" format 999990
col username format a10
col event format a25
col "OBJECT" format a30
col "WAIT (s)" format 99990
set lines 150 pages 200
select
 distinct
   ses.ksusenum sid, ses.ksuseser "SER", ses.ksuudlna username,
   ob.kglnaown||'.'||ob.kglnaobj "OBJECT"
   ,pn.kglpncnt pin_cnt, pn.kglpnmod pin_mode, pn.kglpnreq pin_req
   , w.state, w.event, w.seconds_in_Wait "WAIT (s)"
 from
  x$kglpn pn,  x$kglob ob,x$ksuse ses 
   , v$session_wait w
where pn.kglpnhdl in
(select kglpnhdl from x$kglpn where kglpnreq >0 )
and ob.kglhdadr = pn.kglpnhdl
and pn.kglpnuse = ses.addr
and w.sid = ses.indx
order by seconds_in_wait asc;



-- OEM query for Blocking Session DB Time metric
WITH blocked_resources AS
(select id1, id2, SUM(ctime) as blocked_secs, MAX(request) as max_request
,COUNT(1) as blocked_count
from v$lock
where request > 0 group by id1, id2
)
,blockers AS
(select L.*, BR.blocked_secs, BR.blocked_count
from v$lock L, blocked_resources BR
where BR.id1 = L.id1 and BR.id2 = L.id2
and L.lmode > 0 and L.block <> 0
)
select B.id1||'_'||B.id2||'_'|| S.sid||'_'|| S.serial# as id,
'SID,SERIAL:'||S.sid||','||S.serial#||', LOCK_TYPE:'||
B.type||',PROGRAM:'||S.program||',MODULE:'||S.module||',ACTION:'||
S.action||',MACHINE:'||S.machine||',OSUSER:'||S.osuser||',USERNAME:'||
S.username as info, B.blocked_secs, B.blocked_count
from v$session S, blockers B
where B.sid = S.sid;

col object_name format a30
col lock_type format 15
col mode_held format a12
col mode_requested format a12
col blocking_others format a15
SELECT o.object_name, l.lock_type, l.mode_held,
l.mode_requested, l.blocking_others
FROM dba_lock l, dba_objects o
WHERE l.lock_id1 = o.object_id order by object_name, blocking_others;


-- basic info for locks (also shows info for session without locks)
select s.sid, s.state, s.event, s.sql_id, l.type, l.lmode
from v$session s, v$lock l
where s.sid = l.sid  (+) and s.username='&usrname'
order by s.sid;



-- ###############
-- # SQL QUERIES #
-- ###############

-- find sql of a problem session
select sql_fulltext from v$sql where sql_id='cn5hy5hms6snp';




-- #################
-- # SESSION VIEWS #
-- #################

V$SESSION
V$SESSION_WAIT
V$SESSION_EVENT
V$SESSION_WAIT_HISTORY		-- last 10 waits for active sessions
DBA_WAITERS			-- shows all the sessions that are waiting for a lock


-- #################
-- # KILL SESSIONS #
-- #################

-- ask the session to kill itself
ALTER SYSTEM KILL SESSION 'sid,serial#';
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;

-- kill dedicated server process
ALTER SYSTEM DISCONNECT SESSION 'sid,serial#' [IMMEDIATE | POST_TRANSACTION];
ALTER SYSTEM DISCONNECT SESSION '3632,3' IMMEDIATE;

/* Windows */
-- kill stubborn session
-- Usage:	orakill sid thread
-- example
SQL>
select d.name, spid, s.sid, s.serial#, osuser, s.program 
from v$database d, v$process p, v$session s where p.addr=s.paddr and s.sid=&what_sid;
NAME      SPID           SID SERIAL# OSUSER          PROGRAM
--------- ------------ ----- ------- --------------- ---------------
ACTRH5    9552          1985    1635 yangx           SQL Developer

C:\>
D:\Oracle\Product\11.2.0\dbhome_11203\BIN\orakill ACTRH5 9552

/* Unix */
-- kill stubborn session
SQL>
select d.name, spid, s.sid, s.serial#, osuser, s.program 
from v$database d, v$process p, v$session s where p.addr=s.paddr and s.status='KILLED';
NAME      SPID           SID SERIAL# OSUSER          PROGRAM
--------- ------------ ----- ------- --------------- ---------------
ACTRH5    9552          1985    1635 yangx           SQL Developer

$> kill -9 <SPID>


-- #####################
-- # ROLLBACK SESSIONS #
-- #####################

col "Wait Event" for a30
col "Wait Class" for a30
col "OS Program" for a20
col "Module" for a20
col "Action" for a20
col "PL/SQL" for a60
col "Operation" for a30
col "Options" for a30
col "Object" for a30
col "Session ID" for 999999

SELECT ash.session_id "Session ID"
      ,ash.session_serial# "Serial #"
      ,sess.osuser "User"
      ,sess.schemaname "Schema"
      ,ash.sql_plan_line_id "Plan Line"
      ,ash.sql_plan_operation "Operation"
      ,ash.sql_plan_options "Options"
      ,obj.object_name "Object"
      ,ash.sql_exec_start "SQL Start"
      ,LTRIM(proc.object_name||'.','.')||proc.procedure_name "PL/SQL"
      ,ash.event "Wait Event"
      ,ash.wait_class "Wait Class"
      ,ash.time_waited "Wait Time"
      ,CASE
         WHEN ash.in_connection_mgmt = 'Y' THEN
           'Connection Management'
         WHEN ash.in_parse = 'Y' THEN
           'Parse'
         WHEN ash.in_hard_parse = 'Y' THEN
           'Hard Parse'
         WHEN ash.in_sql_execution = 'Y' THEN
           'SQL'
         WHEN ash.in_plsql_rpc = 'Y' THEN
           'PL/SQL'
         WHEN ash.in_plsql_compilation = 'Y' THEN
           'PL/SQL Compliation'
         WHEN ash.in_java_execution = 'Y' THEN
           'Java'
         WHEN ash.in_bind = 'Y' THEN
           'Bind'
         WHEN ash.in_cursor_close = 'Y' THEN
           'Cusor Close'
         WHEN ash.in_sequence_load = 'Y' THEN
           'Sequence Load'
         ELSE
           NULL
       END "Execution"
      ,ash.module "Module"
      ,ash.action "Action"
      ,ROUND(ash.pga_allocated/1024/1024,2) "PGA (MB)"
      ,ROUND(ash.temp_space_allocated/1024/1024,2) "Temp (MB)"
      ,tr.used_ublk "Undo Blocks"
FROM   v$active_session_history ash
LEFT JOIN   v$session sess
  ON   ash.session_id = sess.sid
AND   ash.session_serial# = sess.serial#
LEFT JOIN   dba_procedures proc
  ON   ash.plsql_entry_subprogram_id = proc.subprogram_id
AND   ash.plsql_entry_object_id = proc.object_id
LEFT JOIN dba_objects obj
       ON ash.current_obj# = obj.object_id
LEFT JOIN (SELECT sess.sid
                 ,sess.serial#
                 ,SUM(tr.used_ublk) used_ublk
           FROM v$transaction tr
           JOIN v$session sess
             ON sess.taddr = tr.addr
           GROUP BY sess.sid
                 ,sess.serial#
          ) tr
  ON   sess.sid     = tr.sid
AND   sess.serial# = tr.serial#
WHERE  ash.sample_id = (SELECT MAX(sample_id) FROM v$active_session_history);


-- find transactions using undo
alter session set nls_date_format='HH24:MI:SS';
col sid format 9990
col "USED MB" format 99,999,999
break on sid on username;
select s.sid, s.username, t.start_time, 
  (t.used_ublk*(select block_size from dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  r.segment_name
from v$transaction t, v$session s, dba_rollback_segs r
where t.ses_addr=s.saddr and t.xidusn=r.segment_id;

SELECT s.sid, s.serial#, s.username, u.segment_name, count(u.extent_id) "Extent Count", t.used_ublk, t.used_urec, s.program
FROM v$session s, v$transaction t, dba_undo_extents u
WHERE s.taddr = t.addr and u.segment_name like '_SYSSMU'||t.xidusn||'_%$' and u.status = 'ACTIVE'
GROUP BY s.sid, s.serial#, s.username, u.segment_name, t.used_ublk, t.used_urec, s.program
ORDER BY t.used_ublk desc, t.used_urec desc, s.sid, s.serial#, s.username, s.program;
 
-- time for a transaction to rollback
set serveroutput on;
DECLARE
  v_sid		NUMBER := 175;
  v_blk1	PLS_INTEGER;
  v_blk2	PLS_INTEGER;
  v_hrs		PLS_INTEGER;
  v_min		PLS_INTEGER;
  v_sec		PLS_INTEGER;
  v_time	NUMBER;
BEGIN
  SELECT USED_UBLK INTO v_blk1
    FROM v$transaction d, v$session e 
    WHERE d.addr = e.taddr AND e.sid=v_sid;
  DBMS_LOCK.SLEEP(60);
  SELECT USED_UBLK INTO v_blk2
    FROM v$transaction d, v$session e 
    WHERE d.addr = e.taddr AND e.sid=v_sid;
  DBMS_OUTPUT.PUT_LINE('Total time: '||v_time);
  v_time := v_blk2/(v_blk1 - v_blk2)/3600;
  v_hrs := trunc (v_time, 0);
  v_time := (v_time - v_hrs)*60;
  v_min := trunc (v_time, 0);
  v_time := (v_time - v_min)*60;
  v_sec := trunc (v_time, 0);
  DBMS_OUTPUT.PUT_LINE('Time remaining '||v_hrs||':'||v_min||':'||v_sec);
END;
/


-- or manually
-- run this twice then use the following to estimate time in minutes
-- MB2 / ((MB1 - MB2) * (60 /(TIME2 - TIME1)))
select (USED_UBLK*8192/1024/1024) "MB", to_char(sysdate,'MI:SS') "TIME" from v$transaction t, v$session s
where t.SES_ADDR=s.SADDR and s.serial#=&what_serial;

-- get object & MB used for rollback
col "OS User" format a15
col "DB User" format a15
col "Object Name" format a40
col "MB" format 99,999.99
col "TIME" format a8
SELECT SUBSTR(a.os_user_name,1,8) "OS User"
, SUBSTR(a.oracle_username,1,16) "DB User"
, b.owner||'.'||b.object_name "Object Name"
, (USED_UBLK*8192/1024/1024) "MB"
,to_char(sysdate,'HH24:MI:SS') "TIME"
FROM v$locked_object a 
, dba_objects b 
, v$transaction d 
, v$session e 
WHERE a.object_id = b.object_id 
AND a.xidusn = d.xidusn 
AND a.xidslot = d.xidslot 
AND d.addr = e.taddr;

SELECT (USED_UBLK*8192/1024/1024) "MB"
,to_char(sysdate,'HH24:MI:SS') "TIME"
FROM v$transaction d, v$session e 
WHERE d.addr = e.taddr AND e.sid=192;

-- long-running sessions
col osuser format a15
col sid format 9990
col "Progress" format a102
SELECT s.sid, s.osuser
      ,l.start_time "Time Started"
      ,l.sofar " Work Done"
      ,l.totalwork "Total Work"
      ,RPAD(DECODE(l.totalwork,0,'N/A',ROUND(100*l.sofar/l.totalwork,2)||'%'),12) "% Complete"
      ,TO_CHAR(SYSDATE+(l.time_remaining/24/3600)) "Estimated Finish Time"
      ,RPAD(RPAD('<',DECODE(l.totalwork,0,0,ROUND(100*l.sofar/l.totalwork,2)),'|'),101)||'>' "Progress"
FROM v$session_longops l JOIN v$session s on l.sid=s.sid
WHERE l.sofar<>l.totalwork and s.status='ACTIVE'
ORDER BY l.start_time desc;


-- #################
-- # OTHER CHANGES #
-- #################

-- close a link to reduce overhead
ALTER SESSION CLOSE DATABASE LINK dblink;

-- allow for resumable space allocation
-- pauses transaction when it runs out of space rather than cancelling it
ALTER SESSION ENABLE RESUMABLE
[TIMEOUT x] [NAME string];

-- disable resumable space allocation
ALTER SESSION DISABLE RESUMABLE;


-- ###################
-- # MONITOR CURSORS #
-- ###################

-- get sql of open cursors for SID
col cursor_type format a50
select sql_text, cursor_type from v$open_cursor where sid=2851;

-- don't know if this is useful
COL USERNAME FORMAT A25
select a.value, s.username, s.sid, s.serial#
from v$sesstat a, v$statname b, v$session s
where a.statistic# = b.statistic#  and s.sid=a.sid
and b.name = 'opened cursors current' and s.username is not null;


-- find sessions with more than 50 cursors by SID
select sid, user_name, count(*) "CURSORS" 
from v$open_cursor 
group by sid, user_name having count(*) > 50
order by "CURSORS" desc;

-- find cursor count by sqlid
ctdemo> select count(*) "CURSORS" , sql_id, sql_text
from v$open_cursor
group by sql_id, sql_text having count(*) > 50
order by "CURSORS" desc;

-- find sql text
set long 1000000
col sql_fulltext format a110
select sql_fulltext from v$sql
where sql_id='&whatsqlid';


-- #####################
-- # INSTANCE RECOVERY #
-- #####################

-- how many parallel query servers are involved?
select rcvservers from v$fast_start_transactions;

V$FAST_START_TRANSACTIONS
V$FAST_START_SERVERS

select state, sum(undoblocksdone), sum(undoblockstotal), sum(cputime)
from V$FAST_START_TRANSACTIONS
group by state order by state;

-- long-running sessions
alter session set nls_date_format='DD-MON-YY HH24:MI';
col osuser format a15
col sid format 9990
col "Progress" format a102
SELECT s.sid, s.osuser
      ,l.start_time "Time Started"
      ,l.sofar " Work Done"
      ,l.totalwork "Total Work"
      ,RPAD(DECODE(l.totalwork,0,'N/A',ROUND(100*l.sofar/l.totalwork,2)||'%'),12) "% Complete"
      ,TO_CHAR(SYSDATE+(l.time_remaining/24/3600)) "Estimated Finish Time"
      ,RPAD(RPAD('<',DECODE(l.totalwork,0,0,ROUND(100*l.sofar/l.totalwork,2)),'|'),101)||'>' "Progress"
FROM v$session_longops l JOIN v$session s on l.sid=s.sid
WHERE l.sofar<>l.totalwork and s.status='ACTIVE'
ORDER BY l.start_time desc;


-- ###################
-- # PROCESS QUERIES #
-- ###################

col metric_unit for a30
Select trunc(end_time),max(maxval) as Maximum_Value,metric_unit
from dba_hist_sysmetric_summary 
where metric_unit in ('Number Of Processes','% Processes/Limit')
group by trunc(end_time), metric_unit order by 1,3;


Select trunc(hss.end_time), max(hss.maxval)*to_number(pr.value) as Maximum_Value, hss.metric_unit
from dba_hist_sysmetric_summary hss, dba_hist_snapshot sn, dba_hist_parameter pr
where sn.snap_id=pr.snap_id and hss.end_time between begin_interval_time and end_interval_time
  and hss.metric_unit='% Processes/Limit' and pr.parameter_name='processes'
group by trunc(hss.end_time), hss.metric_unit 
order by 1,3;

Select hss.end_time, (hss.max_value * to_number(pr.value) / 100) as Maximum_Value
from dba_hist_snapshot sn, dba_hist_parameter pr,
	(Select trunc(end_time) end_time, max(maxval) as Max_Value
	from dba_hist_sysmetric_summary 
	where metric_unit='% Processes/Limit'
	group by trunc(end_time)) hss
where sn.snap_id=pr.snap_id and hss.end_time between begin_interval_time and end_interval_time
  and pr.parameter_name='processes'
order by 1;


-- sessions
Select trunc(end_time),max(maxval) as Maximum_Value, metric_id, metric_unit
from dba_hist_sysmetric_summary 
where metric_unit='Sessions'
group by trunc(end_time), metric_id, metric_unit order by 1;



