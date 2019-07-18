-- ##############################
-- # HISTORICAL SESSION QUERIES #
-- ##############################

V$ACTIVE_SESSION_HISTORY may have less than 24 hours worth of info
DBA_HIST_ACTIVE_SESS_HISTORY retains info longer

-- ASH size & # of emergency flushes since startup
select total_size,awr_flush_emergency_count from v$ash_info;

-- most recent logins by user
select us.username, max(ash.SAMPLE_TIME) "LOGIN"
from v$active_session_history ash, dba_users us
where us.user_id=ash.user_id
group by us.username
order by 1;
-- DBA_HIST
select us.username, max(ash.SAMPLE_TIME) "LOGIN"
from DBA_HIST_ACTIVE_SESS_HISTORY ash, dba_users us
where us.user_id=ash.user_id
group by us.username
order by 1;

-- find historical session info
-- will return a lot of rows if osuser not specified
-- end time is NOT inclusive
ALTER SESSION SET nls_timestamp_format = 'DDMon HH24:MI:SS';
set pages 1000 lines 120
col "TIME" format a14
COL "MODULE" format a25
col "ACTION" format a30
col "SID" format 99990
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", 
a.session_id "SID", a.module "MODULE", a.action "ACTION"
FROM  V$ACTIVE_SESSION_HISTORY a
where a.session_id in (&what_sids) and
a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME";

-- same but shows SQL instead of action
ALTER SESSION SET nls_timestamp_format = 'DDMon HH24:MI:SS';
set pages 1000 lines 120
col "TIME" format a14
col "SID" format 99990
COL "MODULE" format a22
col "SQL TEXT" format a73
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", a.session_id "SID", a.module "MODULE", sq.sql_text "SQL TEXT"
FROM  V$ACTIVE_SESSION_HISTORY a left outer join v$sql sq on a.sql_id=sq.sql_id
where a.session_id in (&what_sids) and
a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME", a.session_id;
-- DBA_HIST_ACTIVE_SESS_HISTORY
ALTER SESSION SET nls_timestamp_format = 'DDMon HH24:MI:SS';
set pages 1000 lines 120
col "TIME" format a14
col "SID" format 99990
COL "MODULE" format a22
col "SQL TEXT" format a73
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", a.session_id "SID", a.module "MODULE", sq.sql_text "SQL TEXT"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a left outer join v$sql sq on a.sql_id=sq.sql_id
where a.session_id in (&what_sids) and
a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME", a.session_id;

-- find session running specific SQL ID
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", a.session_id "SID", a.module "MODULE", sq.sql_text "SQL TEXT"
FROM  V$ACTIVE_SESSION_HISTORY a left outer join v$sql sq on a.sql_id=sq.sql_id
where lower(sq.sql_text) like '%&what_sql%' and
a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME", a.session_id;
-- DBA_HIST_ACTIVE_SESS_HISTORY
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", a.session_id "SID", a.module "MODULE", a.sql_id, TOP_LEVEL_SQL_ID
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a
where (a.sql_id='&what_sqlid' OR TOP_LEVEL_SQL_ID='&&what_sqlid') and
a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME", a.session_id;

-- find program & SQL text for given session
ALTER SESSION SET nls_timestamp_format = 'DDMon HH24:MI:SS';
set pages 1000 lines 120
col "TIME" format a14
col "SID" format 99990
col "SER#" format 999990
col program format a20
col action format a15
col "SQL TEXT" format a60
SELECT  distinct to_char(a.sample_time,'DDMon HH24:MI:SS') "TIME", a.session_id "SID", a.session_serial# "SER#",
a.program, a.action, s.sql_text "SQL TEXT"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a LEFT OUTER JOIN v$sql s ON a.sql_id=s.sql_id 
where a.user_id <> 0 and a.session_id=&whatsid and
  a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME";

-- find distinct sql id of session
SELECT  distinct a.session_id SID, a.session_serial# SER, to_char(a.sample_time,'DDmon HH24:MI') "TIME", sql_id
FROM  V$ACTIVE_SESSION_HISTORY a
where session_id=&sesid and session_serial#=&sesser and 
  a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME";

-- check all connections from a user
set pages 1000 lines 120
col "TIME" format a15
COL "MODULE" format a25
col "ACTION" format a30
col machine format a30
col username format a30
SELECT  to_char(a.sample_time,'DD-MON HH24:MI:SS') "TIME", du.username, a.machine, a.module "MODULE", a.action "ACTION"
FROM  V$ACTIVE_SESSION_HISTORY a, dba_users du
where a.user_id=du.user_id and du.username=UPPER('&what_user')
order by 1,3;

SELECT  to_char(a.sample_time,'DD-MON HH24:MI:SS') "TIME", du.username, a.machine, a.module "MODULE", a.action "ACTION"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a, dba_users du
where a.user_id=du.user_id and du.username=UPPER('&what_user')
and a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by a.sample_time;

-- estimate last login for given user
ALTER SESSION SET nls_timestamp_format = 'DD-Mon-YY HH24:MI';
set pages 1000 lines 120
col "TIME" format a14
col "SID" format 99990
col "SER#" format 999990
col program format a20
col action format a15
col "SQL TEXT" format a60
SELECT  distinct a.sample_time "TIME", a.session_id "SID", a.session_serial# "SER#",
a.program, a.action, s.sql_text "SQL TEXT"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a
where a.user_id <> 0 and a.session_id=&whatsid and
  a.sample_time between to_date('&when_start','YYYYMMDDHH24MISS') and to_date('&when_end','YYYYMMDDHH24MISS')
order by "TIME";


-- find parallel query coordinators running through sqlplus
SELECT distinct a.session_id SID, a.session_serial# SER, qc_session_id QC_SID, qc_session_serial# QC_SER, 
  to_char(a.sample_time,'MM-DD HH24:MI') "TIME", sql_id
FROM  V$ACTIVE_SESSION_HISTORY a
where module='SQL*Plus' and a.sample_time > to_date('&when_start','YYYYMMDDHH24MISS')
order by "TIME";




-- get info on waits
SELECT  distinct to_char(a.sample_time,'MM-DD HH24:MI') "TIME", a.time_waited,
s.machine, s.terminal, a.module "MODULE", v$sql.sql_text "SQL TEXT"
FROM  V$ACTIVE_SESSION_HISTORY a , v$session s, v$sql
where s.user# = a.user_id and a.sql_id=v$sql.sql_id
and a.SESSION_STATE='WAITING' and a.WAIT_TIME>30 and s.sid=989;

-- get details on ITL waits
-- will return a lot of rows on a busy system
col object_name format a30
Select s.sid SID, s.serial# Serial#, l.type type, 
   ' ' object_name, lmode held, request request
from v$lock l, v$session s, v$process p
where s.sid = l.sid and s.username <> ' ' and
   s.paddr = p.addr and l.type <> 'TM' and
   (l.type <> 'TX' or l.type = 'TX' and l.lmode <> 6)
union
select s.sid SID, s.serial# Serial#, l.type type,
   object_name object_name, lmode held, request request
from v$lock l, v$session s, v$process p, sys.dba_objects o
where s.sid = l.sid and o.object_id = l.id1 and
   l.type = 'TM' and s.username <> ' ' and s.paddr = p.addr
union
select s.sid SID, s.serial# Serial#, l.type type,
   '(Rollback='||rtrim(r.name)||')' object_name,
   lmode held, request request
from v$lock l, v$session s, v$process p, v$rollname r
where s.sid = l.sid and l.type = 'TX' and
   l.lmode = 6 and trunc(l.id1/65536) = r.usn and
   s.username <> ' ' and s.paddr = p.addr
order by 5, 6;

ALTER SESSION SET nls_timestamp_format = 'MM-DD HH24:MI';
set pages 200 lines 120
col "TIME" format a11
COL "MODULE" format a25
COL "MACHINE" format a25
SELECT  distinct to_char(a.sample_time,'MM-DD HH24:MI') "TIME", a.time_waited,
s.machine, s.terminal, a.module "MODULE"
FROM  V$ACTIVE_SESSION_HISTORY a , v$session s, V$EVENT_NAME e
where s.user# = a.user_id and a.event_id=e.event_id
and e.wait_class='Application' and a.sample_time>(sysdate-1);
and s.sid=989;

-- use this to find details on cleared alerts for DB waiting time
set pages 200 lines 120
COL sid format 99999
COL "MODULE" format a25
COL "MACHINE" format a40
select sid, machine, terminal, module 
from v$session where sid in
(select distinct a.blocking_session from v$active_session_history a, v$event_name e
 where a.event_id=e.event_id and e.wait_class='Application' and a.session_id=&what_sid);

-- think this shows sessions that were blocked
COL sid format 99999
COL "MODULE" format a25
COL "MACHINE" format a40
COL wait_class format a20
select sid, machine, terminal, module, wait_class
from v$session where sid in
(select distinct a.blocking_session from v$active_session_history a, v$event_name e
 where a.event_id=e.event_id and a.session_id=&blocked_sid);

--
ALTER SESSION SET nls_timestamp_format = 'MM-DD HH24:MI';
set lines 120 pages 200
col "TIME" format a11
COL "MODULE" format a25
col p1text format a10
col p2text format a10
col p3text format a10
SELECT distinct to_char(a.sample_time,'MM-DD HH24:MI') "TIME", a.module "MODULE", 
a.session_id, a.p1text, a.p1, a.p2text, a.p2, a.p3text, a.p3
FROM  V$ACTIVE_SESSION_HISTORY a, v$session s
where a.program like '%IntegrationQueue%' and s.machine like '%INTPROC6%' 
and s.user# = a.user_id and a.sample_time between (sysdate – 4/24) and (sysdate - 3/24);

-- historical query w/o depending on v$session
ALTER SESSION SET nls_timestamp_format = 'MM-DD HH24:MI';
set pages 1000 lines 120
col "TIME" format a11
col "SQL TEXT" format a118
col sample_time format a12
SELECT  a.sample_id, a.sample_time, v$sql.sql_text "SQL TEXT"
FROM  V$ACTIVE_SESSION_HISTORY a , v$sql
where a.sql_id=v$sql.sql_id and a.session_id=&WHATSID and a.session_serial#=&WHATSERIAL
and a.sample_time BETWEEN to_date('&WHENSTART','DD-MON-YY HH24:MI') AND to_date('&WHENEND','DD-MON-YY HH24:MI')
order by a.sample_time;

SELECT  a.sample_id, a.sample_time, a.sql_id
FROM  V$ACTIVE_SESSION_HISTORY a
where a.session_id=&WHATSID and a.session_serial#=&WHATSERIAL
and a.sample_time BETWEEN to_date('&WHENSTART','DD-MON-YY HH24:MI') AND to_date('&WHENEND','DD-MON-YY HH24:MI')
order by a.sample_time;



col "TIME" format a11
COL "MODULE" format a25
col "SQL TEXT" format a85
COL osuser format a12

-- find details between certain time
SELECT  a.sample_time "TIME", a.session_id "SID", a.session_serial# "SER#", s.osuser, s.username, a.sql_id
FROM  V$ACTIVE_SESSION_HISTORY a LEFT OUTER JOIN v$session s
  ON a.session_id=s.sid
where a.session_id=&WHATSID and a.sample_time BETWEEN to_date('&WHENSTART','DD-MON-YY HH24:MI') AND to_date('&WHENEND','DD-MON-YY HH24:MI')
order by a.sample_time;


SELECT  a.sample_time "TIME", a.session_id "SID", a.session_serial# "SER#", s.osuser, s.username, a.sql_id
FROM  V$ACTIVE_SESSION_HISTORY a LEFT OUTER JOIN v$session s
  ON a.session_id=s.sid
where a.session_id=&WHATSID and a.session_serial#=&WHATSERIAL and a.sample_time BETWEEN to_date('&WHENSTART','DD-MON-YY HH24:MI') AND to_date('&WHENEND','DD-MON-YY HH24:MI')
order by a.sample_time;



#####################
# BLOCKING SESSIONS #
#####################

-- ASH blocking sessions (shows info for all sessions)
break on MY_TIME
col my_time format a8
column my_ses format a10
column my_state format a30
column my_blkr format a10
select to_char(a.sample_time, 'HH24:MI:SS') MY_TIME, NVL2(a.session_id,a.session_id||':'||a.session_serial#, NULL) MY_SES,
        DECODE(a.session_state, 'WAITING' ,a.event, a.session_state) MY_STATE, a.sql_id,
        a.blocking_session||':'||a.blocking_session_serial# MY_BLKR
from v$active_session_history a, dba_users u
where u.user_id = a.user_id and a.blocking_session is not null
and a.sample_time between to_date('&startwhen','YYYYMMDDHH24MISS') and to_date('&endwhen','YYYYMMDDHH24MISS') 
order by 1 asc;

select to_char(a.sample_time, 'HH24:MI:SS') MY_TIME, NVL2(a.session_id,a.session_id||':'||a.session_serial#, NULL) MY_SES,
        DECODE(a.session_state, 'WAITING' ,a.event, a.session_state) MY_STATE, a.sql_id,
        a.blocking_session||':'||a.blocking_session_serial# MY_BLKR
from v$active_session_history a
where a.sample_time between to_date('&startwhen','YYYYMMDDHH24MISS') and to_date('&endwhen','YYYYMMDDHH24MISS')
  and a.session_id=&what_scn --and event like '%lock%' and blocking_session is not null
order by 1 asc;

-- get info (w/SQL) for sessions with blocks
ALTER SESSION SET nls_timestamp_format = 'DD-MON HH24:MI:SS';
set pages 1000 lines 150
col "TIME" format a11
col "SID" format 99990
col "SER#" format 999990
col "BL_SID" format 99990
col "BL_SER" format 999990
col "SQL TEXT" format a60
SELECT  distinct to_char(a.sample_time,'MM-DD HH24:MI') "TIME", a.session_id "SID", a.session_serial# "SER#",
a.blocking_session "BL_SID", a.blocking_session_serial# "BL_SER", a.blocking_session_status "BL_STATUS", s.sql_text "SQL TEXT"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a LEFT OUTER JOIN v$sql s
  ON a.sql_id=s.sql_id 
where a.blocking_session is not null and a.user_id <> 0
and a.sample_time between to_date('&startwhen','YYYYMMDDHH24MISS') and to_date('&endwhen','YYYYMMDDHH24MISS')
order by "TIME";

SELECT  distinct a.sample_time, a.session_id "SID", a.session_serial# "SER#",
a.blocking_session "BL_SID", a.blocking_session_serial# "BL_SER", a.blocking_session_status "BL_STATUS", s.sql_text "SQL TEXT"
FROM  DBA_HIST_ACTIVE_SESS_HISTORY a LEFT OUTER JOIN v$sql s
  ON a.sql_id=s.sql_id 
where a.blocking_session is not null and a.user_id <> 0
and a.sample_time between to_date('&startwhen','YYYYMMDDHH24MISS') and to_date('&endwhen','YYYYMMDDHH24MISS')
order by a.sample_time;


-- historial blocks & blocking info
ALTER SESSION SET nls_timestamp_format = 'DD-MON HH24:MI:SS';
col blkd_time format a15
col "BLOCKER" format a12
col "BLOCKED" format a12
with blocked as (
 select sample_time blkd_time, session_id blocked, 
   session_serial# blkd_ser, blocking_session, sql_id
 from DBA_HIST_ACTIVE_SESS_HISTORY
 where blocking_session is not null
),
blocking as (
 select sample_time blkr_time, session_id blocking, 
   session_serial# blkr_ser, sql_id bl_sql
 from DBA_HIST_ACTIVE_SESS_HISTORY
)
select distinct blkd_time, blocking||':'||blkr_ser "BLOCKER", bl_sql, blocked||':'||blkd_ser "BLOCKED", sql_id
from blocked, blocking
where blocking = blocking_session and blkd_time=blkr_time
and blkd_time between to_date('&startwhen','YYYYMMDDHH24MISS') and to_date('&endwhen','YYYYMMDDHH24MISS')
order by blkd_time, blocker, blocked;


-- #############
-- # LOG MINER #
-- #############

-- can be used with online redo logs
column member format a60
select group#, member from v$logfile;
-- ...or archived logs
col name format a80
select sequence#, to_char(first_time,'HH24:MI') "TIME", name from V$ARCHIVED_LOG
where dest_id=1 and next_time>=to_date('&when_start','YYYYMMDDHH24MI') and first_time<=to_date('&when_end','YYYYMMDDHH24MI')
order by sequence#;
-- ...or (maybe) source logs
SELECT sequence#, to_char(first_time,'HH24:MI') "TIME", name
FROM dba_registered_archived_log
WHERE consumer_name='CDC$C_ACTURIS_CHGSET'
  AND next_time>=to_date('&when_start','YYYYMMDDHH24MI') and first_time<=to_date('&when_end','YYYYMMDDHH24MI')
order by sequence#;

exec dbms_logmnr.add_logfile('&my_member');
exec dbms_logmnr.start_logmnr(options => dbms_logmnr.dict_from_online_catalog);

-- find XIDs
select * from
  (select lpad(ltrim(to_char(p2,'XXXXXX')),6,'0')||'00'||
     ltrim(to_char(mod(p3,256),'XX'))||ltrim(to_char(trunc(p3/256),'XX'))||
     '0000' block_xid, to_char(p2,'XXXXXXXX') p2hex,
     to_char(p3,'XXXXXXXX') p3hex, trunc(p2/65536) usn,
     mod(p2,65536) slot, p3 sqn, xid wait_xid
from v$active_session_history
where event like 'enq: T%'
order by sample_time desc) where rownum < 2;

-- find blocking SQL (not accurate)
select username, session# sid, serial# , sql_redo 
from v$logmnr_contents 
where  XID = '&blocking_xid';

-- given "xid: 0x001d.01a.00823481 (29.26.8533121)"
-- use numbers in parenthesis for var below or convert hexadecimal parts to decimal
select operation,SQL_REDO,SQL_UNDO, scn, data_obj# , timestamp from v$logmnr_contents 
where xidusn=&xidusn and xidslt=&xidslt and xidsqn=&xidsqn;


exec DBMS_LOGMNR.END_LOGMNR;


###################
# SUMMARY QUERIES #
###################

-- show breakdown of clients by minute 
SELECT DB_MINUTE, 
  max( decode( machine, 'lxtcapp01.conseco.com', sessions, null ) ) "lxtcapp01.conseco.com",
  max( decode( machine, 'lxtcapp02.conseco.com', sessions, null ) ) "lxtcapp02.conseco.com",
  max( decode( machine, 'lxtcapp03.conseco.com', sessions, null ) ) "lxtcapp03.conseco.com",
  max( decode( machine, 'lxtcapp04.conseco.com', sessions, null ) ) "lxtcapp04.conseco.com",
  max( decode( machine, 'lxtcapp05.conseco.com', sessions, null ) ) "lxtcapp05.conseco.com",
  max( decode( machine, 'lxtcapp06.conseco.com', sessions, null ) ) "lxtcapp06.conseco.com",
  max( decode( machine, 'lxtcp01', sessions, null ) ) "lxtcp01",
  max( decode( machine, 'lxtcp02', sessions, null ) ) "lxtcp02",
  max( decode( machine, 'lxtcp03', sessions, null ) ) "lxtcp03",
  max( decode( machine, 'lxtcp04', sessions, null ) ) "lxtcp04",
  max( decode( machine, 'lxwas85p02', sessions, null ) ) "lxwas85p02",
  max( decode( machine, 'uxp33', sessions, null ) ) "uxp33"
FROM
  (SELECT  to_char(sample_time,'DDMon HH24:MI') "DB_MINUTE", machine, count(*) sessions
   FROM  V$ACTIVE_SESSION_HISTORY
   WHERE sample_time BETWEEN to_date('20141218123000','YYYYMMDDHH24MISS') AND to_date('20141218130000','YYYYMMDDHH24MISS')
   GROUP BY to_char(sample_time,'DDMon HH24:MI'), machine)
GROUP BY db_minute order by db_minute;

-- transactions per second (only in past hour)
select to_char(end_time,'DD-MON-YY HH24:MI') "MINUTE", to_char(value,'990.99') "Xactions/sec"
from SYS.V$SYSMETRIC_HISTORY
where metric_name='User Transaction Per Sec' and round(intsize_csec,-3)=6000
order by end_time, metric_name;

-- transactions per second in given time frame
select to_char(end_time,'DD-MON-YY HH24:MI') "MINUTE", to_char(value,'990.99') "Xactions/sec"
from DBA_HIST_SYSMETRIC_HISTORY
where metric_name='User Transaction Per Sec' and round(intsize,-3)=6000
  AND end_time >= sysdate-3/24
order by end_time, metric_name;

-- activities per second 
select DB_TIME, 
  max( decode( metric_name, 'Executions Per Sec', to_char(value,'9,990.99'), null ) ) "Executions Per Sec",
  max( decode( metric_name, 'I/O Requests per Second', to_char(value,'9,990.99'), null ) ) "I/O Requests per Second",
  max( decode( metric_name, 'Physical Reads Per Sec', to_char(value,'9,990.99'), null ) ) "Physical Reads Per Sec",
  max( decode( metric_name, 'Physical Writes Per Sec', to_char(value,'9,990.99'), null ) ) "Physical Writes Per Sec",
  max( decode( metric_name, 'User Calls Per Sec', to_char(value,'9,990.99'), null ) ) "User Calls Per Sec",
  max( decode( metric_name, 'User Transaction Per Sec', to_char(value,'9,990.99'), null ) ) "User Transaction Per Sec"
from (select to_char(end_time,'DD-MON-YY HH24:MI') "DB_TIME", metric_name, value
   from DBA_HIST_SYSMETRIC_HISTORY
   where lower(metric_name) like '%per sec%' and round(intsize,-3)=6000
   AND end_time >= sysdate-2/24)
group by DB_TIME order by DB_TIME;

-- session counts by username
SELECT u.username, a.program, a.machine, count(a.machine) "SESSIONS"
FROM DBA_USERS u LEFT OUTER JOIN DBA_HIST_ACTIVE_SESS_HISTORY a ON a.user_id=u.user_id
where a.sample_time >= (sysdate - 7)
  and u.username not in ('DBSNMP','SYS','SYSMAN','SYSTEM','SCOTT')
  and a.machine not in ('lxoracls01')
group by u.username, a.program, a.machine
order by u.username, a.program, a.machine;

-- session counts by username and most recent login
SELECT u.username, a.program, a.machine, count(a.machine) "SESSIONS", to_char(min(a.sample_time),'DD-MON-YY hh24:mi') "LAST LOGIN"
FROM DBA_USERS u LEFT OUTER JOIN DBA_HIST_ACTIVE_SESS_HISTORY a ON a.user_id=u.user_id
where a.sample_time >= (sysdate - 7)
  and u.username like '%CPA7YD%'
  --and a.machine not in ('lxoracls01')
group by u.username, a.program, a.machine
order by u.username, a.program, a.machine;