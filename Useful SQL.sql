-- *********************
-- *********************
-- *********************
-- ** USEFUL COMMANDS **
-- *********************
-- *********************

-- Guardium wrapper
SELECT 'GuardAppEvent:Start', 'GuardAppEventStrValue:S1418582', 'GuardAppEventUserName:cnozk7' from DUAL;
SELECT 'GuardAppEvent:Start', 'GuardAppEventStrValue:C0036730', 'GuardAppEventUserName:cnozk7' from DUAL;
Then execute the SQL commands (Alter, create, select, etc.)
Then end with 
SELECT 'GuardAppEvent:Released' from DUAL;

/*--- USERENV parameters ---*/

-- find the DB name as any user
SELECT SYS_CONTEXT ('USERENV', 'DB_NAME') FROM DUAL;
SELECT SYS_CONTEXT ('USERENV', 'DB_UNIQUE_NAME') FROM DUAL;
-- find username
SELECT SYS_CONTEXT ('USERENV', 'CURRENT_USER') FROM DUAL;
-- find SID
SELECT SYS_CONTEXT ('USERENV', 'SID') FROM DUAL;
-- DB domain from init param
SELECT SYS_CONTEXT ('USERENV', 'DB_DOMAIN') FROM DUAL;
-- host from where client connected
SELECT SYS_CONTEXT ('USERENV', 'HOST') FROM DUAL;
-- find name of script
set appinfo on
select sys_context('USERENV', 'MODULE') from dual;
select substr(sys_context('USERENV', 'MODULE'),5) from dual;

-- for pluggable databases
SELECT SYS_CONTEXT ('USERENV', 'CON_NAME') FROM DUAL;

/*--------------------------*/

-- add date to spool file
column filename new_val filename
select 'my_script_name_'||to_char(sysdate, 'yyyymmdd' ) filename from dual; 
spool &filename

-- add DB SID to spool file
column filename new_val filename
select 'my_script_name_'||name filename from v$database; 
spool &filename

-- add PDB name to spool file
column filename new_val filename
select 'my_script_name_'||name filename from v$containers; 
spool &filename

-- add name, regardless of cdb or pdb
column filename new_val filename
SELECT case SYS_CONTEXT('USERENV', 'CON_NAME')
	when 'CDB$ROOT' then 'my_script_name_'||SYS_CONTEXT('USERENV', 'DB_NAME')
	else 'my_script_name_'||SYS_CONTEXT('USERENV', 'CON_NAME')
end filename FROM DUAL;
spool &filename

-- add date & DB name to spool file
column filename new_val filename
select 'my_script_name_'||name||'_'||to_char(sysdate, 'yyyymmdd' ) filename from v$database; 
spool &filename

-- spool to Excel file
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET LINES 1000
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL User_Billing_Summary.xls;

-- spool to CSV file
set colsep ,
set echo off
set pages 0 lines 1000
set trimspool on
spool file.csv

-- run SQL without qualifying the owner name of objects
ALTER SESSION SET CURRENT_SCHEMA = audit_gkpr;

-- get current version of DB components
select * from v$version;
select banner from v$version;

-- get the SID
select instance from v$thread;

-- refresh dates general (doesn't always work)
alter session set nls_date_format='DD-MON-YY HH24:MI';
select sequence#, first_time from v$log_history
where sequence# in ((select min(sequence#) from v$log_history),(select max(sequence#) from v$log_history));

-- find location for alert files
sho parameter background_dump_dest;

-- find location for log or Oracle errors
sho parameter user_dump_dest;

-- create pfile from spfile
create pfile='D:\path\to\backup.ora' from spfile;

-- force a archive log switch
alter system switch logfile;


-- compute the sum of a select statement
break on report;
compute sum label "TOTAL" of "KB" on report;
select segment_name, segment_type, (bytes/1024) AS "KB"
from user_segments order by segment_type, segment_name;
-- sum of 2 or more columns
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;

-- add 2 calculation to report
COMPUTE AVG LABEL 'Average' -
        MAX LABEL 'Maximum' -
        OF MINIMUM ON report
-- for multiple columns
COMPUTE AVG LABEL 'Average' -
        MAX LABEL 'Maximum' -
        OF MINIMUM MAXIMUM AVERAGE ON report

-- compute subtotals (doesn't have grand total)
break on table_name skip 1;
compute sum of "MB" on table_name;

-- skip duplicates in a column
break on column_name;
-- same + add blank row
break on column_name skip 1;
-- skip duplicates in multiple columns
break on "INDEX" on index_type on status;

-- skip duplicates of 1 column & compute sum of others
break on "SGA";
compute sum label "TOTAL" of "CUR MB" "MIN MB" "MAX MB" on "SGA";

-- add a line break
select 'A' || chr(10) || 'B' from dual;
select 'A' ||chr(13)||chr(10)|| 'B' from dual;


-- find lowest 5 rows ranked by a certain column
select name, price
from (
  select name, price, row_number() over (order by price) r
  from items
) where r between 1 and 5; 

-- find top 5 rows ranked by a certain column
select name, price
from (
  select name, price, row_number() over (order by price desc) r
  from items
) where r between 1 and 5; 


-- find duplicate rows
select grantee, owner, table_name, privilege, count(*)
from dba_tab_privs
where grantee in (select username from dba_users)
group by grantee, owner, table_name, privilege
having count(*) > 1;


-- flush buffers
ALTER SYSTEM FLUSH BUFFER_CACHE;
ALTER SYSTEM FLUSH SHARED_POOL;
-- 10g only (?)
exec sys.FLUSHBUFFER_POOL.FLUSHBUFFER_POOL;
exec sys.FLUSH_POOL.flush_pool;


-- set the time format
ALTER SESSION SET nls_date_format = 'YYYY-MM-DD HH24:MI:SS';

-- convert seconds column to hh:mi:ss (time)
TO_CHAR(TRUNC(last_call_et/3600),'FM9900') || ':' ||
    TO_CHAR(TRUNC(MOD(last_call_et,3600)/60),'FM00') || ':' ||
    TO_CHAR(MOD(last_call_et,60),'FM00') "INACTIVE_TIME"
	
-- convert CLOB to VARCHAR2
dbms_lob.substr( clob_column, for_how_many_bytes, from_which_byte );

-- Get the plan for a SQL statement
EXPLAIN PLAN FOR...
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', NULL,'TYPICAL'));

-- Save the plan for a SQL statement
EXPLAIN PLAN SET STATEMENT_ID ='KEVIN' FOR...
@explain.sql KEVIN


-- flashback queries
-- see data from 10 minutes ago
select * from emp as of timestamp to_timestamp(sysdate-10/1440);
-- see data from an hour ago
select * from emp as of timestamp to_timestamp(sysdate-1/24);

-- find national character set and other nls params
select * from nls_database_parameters;
select * from nls_instance_parameters;
select * from nls_session_parameters;
-- get character set
select value from nls_database_parameters where parameter='NLS_CHARACTERSET';

-- query only rows in a partition
select * from actqueue.queue_completed partition (QUEUE_COMP_0811);

-- use alias in group by clause
select count, alias_column  
from 
  (select count(*) as count, (select * from....) as alias_column  
  from table) 
group by alias_column;


-- ###############
-- # Connections #
-- ###############

-- EZ Connect
CONNECT username/password@[//]host[:port][/service_name]

-- connect string (uses tnanames.ora)
username/password@connectstring 

-- full connect string (bypasses tnsnames.ora)
sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=10.60.41.52)(PORT=1521))(CONNECT_DATA=(SID=DW3DEVB))) as sysdba
sqlplus sysman@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=AmsDvG1GSADB1.dev.int.acturis.com)(PORT=1521))(CONNECT_DATA=(SID=DEVEM12)))
sqlplus sysman@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=10.63.41.57)(PORT=1521))(CONNECT_DATA=(SID=DEVEM12)))
conn system@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lxgrcm01.conseco.com)(PORT=1521))(CONNECT_DATA=(SID=GRCM)))
conn system@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lxgrcm02.conseco.com)(PORT=1521))(CONNECT_DATA=(SID=GRCCM)))
sqlplus cnozk7@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lxorainvp01.conseco.ad)(PORT=1521))(CONNECT_DATA=(SID=prod)))

sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=uxp33.conseco.com)(PORT=1521))(CONNECT_DATA=(SID=blcfdsp))) as sysdba
sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=uxm33.conseco.com)(PORT=1521))(CONNECT_DATA=(SID=prodm))) as sysdba
sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=lxoracls01.conseco.com)(PORT=1521))(CONNECT_DATA=(SID=orcl))) as sysdba
sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.11.190.90)(PORT=1521))(CONNECT_DATA=(SID=orcl))) as sysdba
sqlplus sys@(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.11.190.90)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=orcl))) as sysdba

-- bypass listener (local only)
set ORACLE_SID=BLCFDSP
sqlplus sys as sysdba


-- ##########################################################################################

-- CPU time
dbms_utility.get_cpu_time;
-- using in code
begin
	:cpu := dbms_utility.get_cpu_time;
end;
/
... (code here that you want to time)
select dbms_utility.get_cpu_time-:cpu cpu_hsecs from dual;	-- returns cpu time in 1/100ths of a second


-- enclose string with normal formatting
select q'|select 'run_pre_acturis_tst_disable.sql' from dual;|' from dual;
-- as opposed to:
select 'select ''run_pre_acturis_tst_disable.sql'' from dual;' from dual;

-- assigned variables passed to script
SET DEFINE ON
DEFINE SYSPWD=&1
DEFINE HOSTNAME=&2
DEFINE AVOPWD=&3

-- prompt for variables
set verify off
ACCEPT ACTURISDB PROMPT 'Enter ACTURISDB SID: ' ;
ACCEPT ACTD00_EXPORT_PASSWORD PROMPT 'Enter ACTD00_EXPORT Password: 'Hide ;

-- undefine variable (useful with &&)
undefine AVOPWD;

-- hide the variable values; good for passwords
set verify off

-- standard Acturis header
SET DEFINE OFF
SET ECHO OFF
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON 
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING ON 
SET TRIMSPOOL ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- get DDL to create an object (definition)
set long 10000000
select DBMS_METADATA.GET_DDL (
object_type     IN VARCHAR2,
name            IN VARCHAR2,
schema          IN VARCHAR2 DEFAULT NULL,
version         IN VARCHAR2 DEFAULT 'COMPATIBLE',
model           IN VARCHAR2 DEFAULT 'ORACLE',
transform       IN VARCHAR2 DEFAULT 'DDL')
from dual;
-- example
set long 10000000
COL "DDL"  FORMAT A1000
select DBMS_METADATA.GET_DDL('&what_type','&what_obj','&what_owner') "DDL" from dual;
select DBMS_METADATA.GET_DDL('TABLE','&what_obj','&what_owner') "DDL" from dual;
select dbms_metadata.get_ddl('DB_LINK','&what_dblink','&what_owner') "DDL" from dual;
select DBMS_METADATA.GET_DDL('TABLESPACE','&what_obj') "DDL" from dual;
select DBMS_METADATA.GET_DDL('USER','&what_obj') "DDL" from dual;
select DBMS_METADATA.GET_DDL('ROLE','&what_obj') "DDL" from dual;

set long 10000000
COL "DDL"  FORMAT A1000
select DBMS_METADATA.GET_DDL('VIEW','PRICING_REVIEW_BASE_VIEW','CCMEOM') "DDL" from dual;


-- compile all invalid objects
@$ORACLE_HOME/rdbms/admin/utlrp.sql

-- see error in pl/sql code
set serveroutput on
show errors procedure &what_procedure;
show errors function &what_function;
show errors package body &what_pkg;
show errors trigger &what_trigger;
show errors view &what_view;

-- find pl/sql error in a package for object owner
set lines 250
select text from user_source where name='&whatpkg' and line=&whatline;

-- see the code of a pl/sql object
set lines 250 pages 0
select text from dba_source where name='&what_object' and owner='&what_owner' order by line;


-- allow DDL to wait for locks
-- waits so many seconds, up to 1m
ALTER SESSION SET ddl_lock_timeout=&secs;


-- force password change for yourself
-- login as normal
password





-- find app errors (acturis only)
set lines 120 pages 200
alter session set nls_date_format='DD-MM HH24:MI';
col sourcefile format a40
select logid, tmstamp, sourcefile, sourceline, msg
from actd00.miserror
where tmstamp > (sysdate - 1/24) 
order by tmstamp;

-- see changes since last stats gather
select * from dba_tab_modifications where table_name='&&tabl_name';


-- using bind variables in SQL (can only be set in pl/sql block)
variable deptno number
exec :deptno := 10
select * from emp where deptno = :deptno;

-- using bind variables in pl/sql
create or replace procedure dsal(p_empno in number)
as
  begin
    update emp
    set sal=sal*2
    where empno = p_empno;
    commit;
  end;
/

-- using bind variables in dynamic SQL
-- instead of:
execute immediate
     'update emp set sal = sal*2 where empno = '||p_empno;
-- use:
execute immediate
     'update emp set sal = sal*2 where empno = :x' using p_empno;


-- get list of users with default password
select * from dba_users_with_defpwd;

-- get same list with account status
select d.username, account_status
from dba_users_with_defpwd d, dba_users u
where u.username = d.username;


-- find oracle home (? substituted with oracle_home)
@?\1.sql

-- group data in 10 minute intervals
select date1, TO_CHAR((TimeVal-MOD(TimeVal,60))/60,'fm00')||TO_CHAR(MOD(TimeVal,60),'fm00')
  , count(*) from
(
select trunc(timestamp) "DATE1", 
  FLOOR ((TO_NUMBER(TO_CHAR(timestamp,'hh24'))*60+TO_NUMBER(TO_CHAR(timestamp,'mi'))
  )/10 
 )*10 TimeVal
from listener_log
)
group by date1, TO_CHAR((TimeVal-MOD(TimeVal,60))/60,'fm00')||TO_CHAR(MOD(TimeVal,60),'fm00');


-- SQL*Plus error handling
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- simple case statement
CASE credit_limit 
	WHEN 100 THEN 'Low'
	WHEN 5000 THEN 'High'
	ELSE 'Medium' 
  END AS credit

-- searched case statement
CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE"
  
-- case statement in WHERE clause
where 
	CASE
		WHEN pFreq='monthly' THEN ROUND(ADD_MONTHS(sysdate,-1),'MM')
		WHEN pFreq='weekly' THEN TRUNC(NEXT_DAY(sysdate-14,'SUN'))
		WHEN pFreq='daily' THEN TRUNC(sysdate-1)
	END < BEGIN_INTERVAL_TIME

-- nested case statement
CASE WHEN metric_name='db_inst_cpu_usage' THEN
	CASE
		WHEN to_char(rollup_timestamp,'HH24') < '06' THEN 'CPUNIGHT2'
		WHEN to_char(rollup_timestamp,'HH24') < '12' THEN 'CPUDAY1'
		WHEN to_char(rollup_timestamp,'HH24') < '18' THEN 'CPUDAY2'
		WHEN to_char(rollup_timestamp,'HH24') <= '23' THEN 'CPUNIGHT1'
		ELSE 'OTHER'
	END
WHEN metric_name='memory_usage' THEN
	CASE
		WHEN to_char(rollup_timestamp,'HH24') < '06' THEN 'MEMNIGHT2'
		WHEN to_char(rollup_timestamp,'HH24') < '12' THEN 'MEMDAY1'
		WHEN to_char(rollup_timestamp,'HH24') < '18' THEN 'MEMDAY2'
		WHEN to_char(rollup_timestamp,'HH24') <= '23' THEN 'MEMNIGHT1'
		ELSE 'OTHER'
	END
END "DB_PERIOD"
  
-- pivot sql query results
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

-- take an AWR snapshot (useful for bouncing DBs)
EXEC dbms_workload_repository.create_snapshot;

-- pause code for set time (seconds)
exec dbms_lock.sleep( x )
/


-- fill a table with random data
create table random
(
	f_name varchar2(40)
) tablespace CONFLUENCE_D;

INSERT INTO random
SELECT  dbms_random.string('U',trunc(dbms_random.value(30,40))) FROM  dual
CONNECT BY level <= 10000;

-- find distinct combo of 2 columns
select count(count(*)) as "distinct count"
from testdata
group by col1, col2;

-- as analytic function
select col1, col2, count(*) over () as "distinct count"
from testdata
group by col1, col2;