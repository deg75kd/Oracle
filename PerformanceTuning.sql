-- #################
-- # EXPLAIN PLANS #
-- #################

-- Get the explain plan for a SQL statement (not executed)
EXPLAIN PLAN FOR...
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', NULL,'TYPICAL'));

-- get plan for last statement
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', NULL,'TYPICAL'));

-- Get execution plan from cursor
SELECT * FROM table (DBMS_XPLAN.DISPLAY_CURSOR('&what_sqlid'));
   sql_id           IN  VARCHAR2  DEFAULT  NULL,
   cursor_child_no  IN  NUMBER    DEFAULT  0, 
   format           IN  VARCHAR2  DEFAULT  'TYPICAL'

-- Get execution plan from AWR data (does not work if query just executed)
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('&what_sqlid',&what_plan,NULL,'TYPICAL'));
   sql_id            IN      VARCHAR2,
   plan_hash_value   IN      NUMBER DEFAULT NULL,
   db_id             IN      NUMBER DEFAULT NULL,
   format            IN      VARCHAR2 DEFAULT TYPICAL

-- Get execution plan from SQL set
SELECT * FROM table (DBMS_XPLAN.DISPLAY_SQLSET('&what_sqlset','&what_sqlid', &what_plan));
   sqlset_name      IN  VARCHAR2, 
   sql_id           IN  VARCHAR2,
   plan_hash_value  IN NUMBER := NULL,
   format           IN  VARCHAR2  := 'TYPICAL', 
   sqlset_owner     IN  VARCHAR2  := NULL
   
 -- Get adaptive plans
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(FORMAT => 'ADAPTIVE'));
 -- show expected and actual values
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(format => 'adaptive allstats last'));


-- Save the plan for a SQL statement
EXPLAIN PLAN SET STATEMENT_ID ='KEVIN' FOR...
@explain.sql KEVIN

-- Get SQLID of last statement
SELECT distinct Q.SQL_ID, Q.PLAN_HASH_VALUE, Q.SQL_TEXT
FROM V$SESSION S, V$SQL Q
WHERE S.PREV_SQL_ID = Q.SQL_ID and s.sid =(select SID from V$mystat where rownum<=1);

-- check for adaptive cursor sharing
COL BIND_SENSI FORMAT a10
COL BIND_AWARE FORMAT a10
COL BIND_SHARE FORMAT a10
SELECT SQL_ID, PLAN_HASH_VALUE, CHILD_NUMBER, EXECUTIONS, BUFFER_GETS, IS_BIND_SENSITIVE AS "BIND_SENSI", 
       IS_BIND_AWARE AS "BIND_AWARE", IS_SHAREABLE AS "BIND_SHARE"
FROM   V$SQL
WHERE  
SQL_TEXT LIKE '%&what_sql%';
--SQL_ID='&what_sqlid';



-- #########
-- # HINTS #
-- #########

SELECT /*+ INDEX EP1_10 IMIDVER1_10 */
	a.*, b.DEVID, b.CLIPID, c.DEVID as ID_604, c.DOCPUBLICID 
FROM (kovis_gkpr.EP1_10 a LEFT OUTER JOIN kovis_gkpr.EP1_CENTERA b ON a.ID_14 = b.MID AND a.ID_11 = b.VERSION) 


EXPLAIN PLAN FOR
SELECT /*+ INDEX EP1_10 IMIDVER1_10 */
	a.*, b.DEVID, b.CLIPID, c.DEVID as ID_604, c.DOCPUBLICID 
FROM (kovis_gkpr.EP1_10 a LEFT OUTER JOIN kovis_gkpr.EP1_CENTERA b ON a.ID_14 = b.MID AND a.ID_11 = b.VERSION) 
	LEFT OUTER JOIN kovis_gkpr.EP1_KEYFILE c ON a.ID_14 = c.MASTERID AND a.ID_11 = c.VERSION 
WHERE ID_1=0 AND 
	ID_2=0 AND 
	ID_3=914 AND 
	ID_4=0 AND 
	ID_5=643 AND 
	ID_6=0 AND 
	ID_7=0 AND 
	ID_8=0 AND 
	ID_10=0 AND 
	(ID_15 IS NULL OR ID_15 > SYSDATE) AND 
	ID_12 > -1
ORDER BY ID_11 ASC;

SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', NULL,'TYPICAL'));
	
	
-- #################################
-- # AUTOMATIC WORKLOAD REPOSITORY #
-- #################################

/*--- QUERIES ---*/

-- View created baselines
COL "ID" FORMAT 9990
COL "START_ID" FORMAT 999990
COL "END_ID" FORMAT 999990
COLUMN baseline_name FORMAT A20
SELECT baseline_id "ID", baseline_name, baseline_type, moving_window_size, START_SNAP_ID "START_ID",
	TO_CHAR(start_snap_time, 'DD-MON-YYYY HH24:MI') AS start_snap_time,
	END_SNAP_ID "END_ID",
	TO_CHAR(end_snap_time, 'DD-MON-YYYY HH24:MI') AS end_snap_time
FROM   dba_hist_baseline
ORDER BY baseline_id;

-- Find first snapshot from yesterday
select min(SNAP_ID)
from DBA_HIST_SNAPSHOT
where BEGIN_INTERVAL_TIME >= TRUNC(sysdate-1);

-- Find first snapshot from today
select min(SNAP_ID)
from DBA_HIST_SNAPSHOT
where BEGIN_INTERVAL_TIME >= TRUNC(sysdate);

-- Get the current retention and window size
SELECT retention FROM dba_hist_wr_control;
SELECT moving_window_size
FROM   dba_hist_baseline
WHERE  baseline_type = 'MOVING_WINDOW';

-- get interval and retention periods
SELECT extract(day from snap_interval) *24*60+extract(hour from snap_interval) *60+extract(minute from snap_interval) snapshot_Interval,
	extract(day from retention) *24*60+extract(hour from retention) *60+extract(minute from retention) retention_Interval
FROM dba_hist_wr_control;

SELECT db.name, extract(hour from wr.snap_interval) *60 + extract(minute from wr.snap_interval) "Interval (min)",
	extract(day from wr.retention) "Retention Days"
FROM dba_hist_wr_control wr, v$database db
where wr.dbid=db.dbid;


/*--- DBMS_WORKLOAD_REPOSITORY ---*/
  
-- take an AWR snapshot (useful for bouncing DBs)
EXEC dbms_workload_repository.create_snapshot;

-- set AWR retention policy retention and snapshot interval (in minutes)
exec DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(44640,60);


-- ########
-- # ADDM #
-- ########

-- findings discovered by all advisors
-- Each row for ADDM tasks in the related DBA_ADVISOR_FINDINGS view has a corresponding row in this view
-- type is INFORMATION, SYMPTOM, ERROR or PROBLEM
col finding_name format a40
select task_id, task_name, finding_id, finding_name, type, message, more_info
from DBA_ADDM_FINDINGS
where type!='INFORMATION' and task_name='&what_task'
order by task_id, type_id, finding_name;

DBA_ADDM_INSTANCES
DBA_ADDM_SYSTEM_DIRECTIVES
DBA_ADDM_TASK_DIRECTIVES
DBA_ADVISOR_FINDINGS

-- advisor actions
select task_id, task_name, rec_id, command, attr1, message
from DBA_ADVISOR_ACTIONS
where task_id=&what_taskid
order by task_id, rec_id;

-- advisor actions w/sql
col sql_text format a48
select daa.task_id, daa.task_name, daa.command, daa.message, vs.sql_text
from DBA_ADVISOR_ACTIONS daa left outer join v$sql vs on daa.attr1=vs.sql_id
where task_id=&what_taskid
order by task_id, rec_id;

--
select task_id, task_name, advisor_name, execution_end, dbname, begin_time, end_time
from DBA_ADDM_TASKS
where status='COMPLETED' and execution_end>=(sysdate-1)
task_id=

-- daily report
col command format a25
col message format a105
col "CT" format 990
select daa.command, daa.message, count(dat.task_id) "CT"
from DBA_ADVISOR_ACTIONS daa, DBA_ADDM_TASKS dat
where daa.task_id=dat.task_id
and dat.status='COMPLETED' and dat.execution_end>=(sysdate-1)
group by daa.command, daa.message
order by daa.command, daa.message;

SET DEFINE OFF
SET ECHO OFF
SET ESCAPE OFF
SET FEEDBACK ON
SET HEAD ON 
SET SERVEROUTPUT ON SIZE 1000000
SET TERMOUT ON
SET TIMING OFF
SET LINES 250
SET PAGES 250
SET TRIMSPOOL ON
break on command on message;
col command format a30
col message format a100
col task_name format a23
SPOOL C:\Users\cnozk7\Oracle\ADDM_FINDINGS_blcdwsp_12aug15.log
select daa.command, daa.message, dat.task_name
from DBA_ADVISOR_ACTIONS daa, DBA_ADDM_TASKS dat
where daa.task_id=dat.task_id and dat.status='COMPLETED' 
  and dat.execution_end>=(sysdate-1) and dat.how_created='AUTO'
order by daa.command, daa.message, dat.task_name;
SPOOL OFF


-- ##################
-- # Other Advisors #
-- ##################

DBA_ADVISOR_FINDINGS
select * from dba_advisor_executions where task_name='&what_task';

SELECT DBMS_AUTO_SQLTUNE.REPORT_AUTO_TUNING_TASK('EXEC_45474', 'EXEC_45474', 'TEXT', 'TYPICAL', 'ALL') 
FROM DUAL; 

-- find advisor tasks
alter session set nls_date_format='DD-MON-YY HH24:MI';
select task_id, task_name, advisor_name, execution_end
from DBA_ADVISOR_TASKS
where status in ('COMPLETED','ERROR') and execution_end>=(sysdate-1/24);

-- advisor recommendations
select finding_id, type, rank, benefit_type, benefit
from DBA_ADVISOR_RECOMMENDATIONS
where task_name='&what_task'
order by finding_id;

-- advisor actions
select task_id, task_name, rec_id, command, attr1, message
from DBA_ADVISOR_ACTIONS
where task_id=&what_taskid
order by task_id, rec_id;

-- advisor actions w/sql
col sql_text format a48
select daa.task_id, daa.task_name, daa.command, daa.message, vs.sql_text
from DBA_ADVISOR_ACTIONS daa left outer join v$sql vs on daa.attr1=vs.sql_id
where task_id=&what_taskid
order by task_id, rec_id;


-- ##################
-- # SQL Tuning API #
-- ##################

-- list existing SQL tuning sets
select name, created, statement_count
from DBA_SQLSET
order by 1;

-- find details of SQL tuning set
select * from DBA_SQLSET where name='&what_sts';

-- run SQL tuning script
@$ORACLE_HOME/rdbms/admin/sqltrpt.sql

/*--- create sql baseline ---*/
DBMS_SQLTUNE.CREATE_SQL_PLAN_BASELINE (
   task_name            IN VARCHAR2,
   object_id            IN NUMBER := NULL,
   plan_hash_value      IN NUMBER,
   owner_name           IN VARCHAR2 := NULL); 
   
begin
	DBMS_SQLTUNE.CREATE_SQL_PLAN_BASELINE (
		task_name		=> 'SPB_f22mx39m9nn3v',
		plan_hash_value	=> 3363548498);
end;
/

/*--- create SQL tuning set ---*/

-- procedure
DBMS_SQLTUNE.CREATE_SQLSET (
   sqlset_name  IN  VARCHAR2,
   description  IN  VARCHAR2 := NULL
   sqlset_owner IN  VARCHAR2 := NULL);

   -- function
 DBMS_SQLTUNE.CREATE_SQLSET (
   sqlset_name  IN  VARCHAR2 := NULL,
   description  IN  VARCHAR2 := NULL,
   sqlset_owner IN  VARCHAR2 := NULL)
 RETURN VARCHAR2;

EXEC DBMS_SQLTUNE.CREATE_SQLSET(- 
  sqlset_name => 'my_workload', -
  description => 'complete application workload');

/*--- load SQL into tuning set ---*/
DBMS_SQLTUNE.LOAD_SQLSET (
   sqlset_name       IN  VARCHAR2,
   populate_cursor   IN  sqlset_cursor,
   load_option       IN VARCHAR2 := 'INSERT', 
   update_option     IN VARCHAR2 := 'REPLACE', 
   update_condition  IN VARCHAR2 :=  NULL,
   update_attributes IN VARCHAR2 :=  NULL,
   ignore_null       IN BOOLEAN  :=  TRUE,
   commit_rows       IN POSITIVE :=  NULL,
   sqlset_owner      IN VARCHAR2 := NULL);
   
-- NOTES
-- load_option
	-- INSERT (default) - add only new statements
	-- UPDATE - update existing the SQL statements and ignores any new statements
	-- MERGE - this is a combination of the two other options. This option inserts new statements and updates the information of the existing ones.
-- update_option - only considered if load_option is UPDATE or MERGE
	-- REPLACE (default) - update the statement using the new statistics, bind list, object list, and so on.
	-- ACCUMULATE - when possible combine attributes otherwise just replace the old values by the new provided ones.
   
-- populate the tuning set from the cursor cache
DECLARE
 cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
 OPEN cur FOR
   SELECT VALUE(P)
     FROM table(
       DBMS_SQLTUNE.SELECT_CURSOR_CACHE(
         'parsing_schema_name <> ''SYS'' AND elapsed_time > 5000000',
          NULL, NULL, NULL, NULL, 1, NULL,
         'ALL')) P;
 
DBMS_SQLTUNE.LOAD_SQLSET(sqlset_name => 'my_workload',
                        populate_cursor => cur);
 
END;
/ 

SELECT * 
FROM table(DBMS_SQLTUNE.SELECT_CURSOR_CACHE('sql_id = ''4rm4183czbs7j'''));


/*--- collect SQL statements from the AWR ---*/
DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY (
  begin_snap        IN NUMBER,
  end_snap          IN NUMBER,
  basic_filter      IN VARCHAR2 := NULL,
  object_filter     IN VARCHAR2 := NULL,
  ranking_measure1  IN VARCHAR2 := NULL,
  ranking_measure2  IN VARCHAR2 := NULL,
  ranking_measure3  IN VARCHAR2 := NULL,
  result_percentage IN NUMBER   := 1,
  result_limit      IN NUMBER   := NULL,
  attribute_list    IN VARCHAR2 := NULL,
  recursive_sql     IN VARCHAR2 := HAS_RECURSIVE_SQL)
 RETURN sys.sqlset PIPELINED;
 
-- NOTES
-- basic_filter - NULL captures only statements of the type CREATE TABLE, INSERT, SELECT, UPDATE, DELETE, and MERGE
-- attribute_list - possible values are TYPICAL - BASIC (default), BASIC, ALL, comma-separated list (EXECUTION_STATISTICS, SQL_BINDS, SQL_PLAN_STATISTICS)
-- result_limit - the top SQL from the (filtered) source ranked by the ranking measure

-- return as a query
select * from table(dbms_sqltune.select_workload_repository(73112, 73113, null, null, 'CPU_TIME', null, null, null, 10));

-- select specific columns
select SQL_ID, ELAPSED_TIME, CPU_TIME, BUFFER_GETS, DISK_READS,
	DIRECT_WRITES, EXECUTIONS, OPTIMIZER_COST, COMMAND_TYPE, PLAN_HASH_VALUE
from table(dbms_sqltune.select_workload_repository(73112, 73113, null, null, 'CPU_TIME', null, null, null, 10));


-- select statements from snapshots 1-2
DECLARE
  cur sys_refcursor;
BEGIN
  OPEN cur FOR
    SELECT VALUE (P) 
    FROM table(dbms_sqltune.select_workload_repository(1,2)) P;
 
  -- Process each statement (or pass cursor to load_sqlset)
 
  CLOSE cur;
END;
/

/*--- read contents of sql set ---*/
DBMS_SQLTUNE.SELECT_SQLSET (
  sqlset_name         IN   VARCHAR2,
  basic_filter        IN   VARCHAR2 := NULL,
  object_filter       IN   VARCHAR2 := NULL,
  ranking_measure1    IN   VARCHAR2 := NULL,
  ranking_measure2    IN   VARCHAR2 := NULL,
  ranking_measure3    IN   VARCHAR2 := NULL,
  result_percentage   IN   NUMBER   := 1,
  result_limit        IN   NUMBER   := NULL)
  attribute_list      IN   VARCHAR2 := NULL,
  plan_filter         IN   VARCHAR2 := NULL,
  sqlset_owner        IN   VARCHAR2 := NULL,
  recursive_sql       IN   VARCHAR2 := HAS_RECURSIVE_SQL)
 RETURN sys.sqlset PIPELINED;

DECLARE
  cur sys_refcursor;
BEGIN
  OPEN cur FOR
    SELECT VALUE (P) 
    FROM table(dbms_sqltune.select_sqlset('STS_7698_7720')) P;
 
	-- Process each statement (or pass cursor to load_sqlset)
  CLOSE cur;
END;
/

COLUMN SQL_TEXT FORMAT a60
COLUMN SCH FORMAT a10
COLUMN ELAPSED FORMAT 999999999
SELECT SQL_ID, PARSING_SCHEMA_NAME AS "SCH", SQL_TEXT
	--, ELAPSED_TIME AS "ELAPSED", BUFFER_GETS
FROM TABLE( DBMS_SQLTUNE.SELECT_SQLSET( 'STS_7737_7747_2' ) );

SET LONG 10000000
COLUMN SQL_TEXT FORMAT a120
SELECT sts.SQL_ID, sts.PARSING_SCHEMA_NAME AS "SCH", hst.SQL_TEXT
FROM TABLE( DBMS_SQLTUNE.SELECT_SQLSET( 'STS_7737_7747' ) ) sts, DBA_HIST_SQLTEXT hst
WHERE sts.SQL_ID=hst.SQL_ID
ORDER BY 1;


/*--- Create SQL Tuning Task ---*/

-- several different forms exist
DBMS_SQLTUNE.CREATE_TUNING_TASK(
  sqlset_name       IN VARCHAR2,
  basic_filter      IN VARCHAR2 :=  NULL,
  object_filter     IN VARCHAR2 :=  NULL,
  rank1             IN VARCHAR2 :=  NULL,
  rank2             IN VARCHAR2 :=  NULL,
  rank3             IN VARCHAR2 :=  NULL,
  result_percentage IN NUMBER   :=  NULL,
  result_limit      IN NUMBER   :=  NULL,
  scope             IN VARCHAR2 :=  SCOPE_COMPREHENSIVE,
  time_limit        IN NUMBER   :=  TIME_LIMIT_DEFAULT,
  task_name         IN VARCHAR2 :=  NULL,
  description       IN VARCHAR2 :=  NULL
  plan_filter       IN VARCHAR2 :=  'MAX_ELAPSED_TIME',
  sqlset_owner      IN VARCHAR2 :=  NULL)
RETURN VARCHAR2;

-- NOTES
-- time_limit - the maximum duration in seconds for the tuning session
 
-- Tune our statements in order by buffer gets, time limit of one hour
-- the default ranking measure is elapsed time.
EXEC :sts_task := DBMS_SQLTUNE.CREATE_TUNING_TASK( -
  sqlset_name  => 'my_workload', -
  rank1        => 'BUFFER_GETS', -
  time_limit   => 3600, -
  description  => 'tune my workload ordered by buffer gets');


/*--- Execute SQL Tuning Task ---*/
DBMS_SQLTUNE.EXECUTE_TUNING_TASK(
   task_name         IN VARCHAR2,
   execution_name    IN VARCHAR2               := NULL,
   execution_params  IN dbms_advisor.argList   := NULL,
   execution_desc    IN VARCHAR2               := NULL);

EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK(:stmt_task);


/*--- View Results ---*/
DBMS_SQLTUNE.REPORT_TUNING_TASK(
   task_name       IN   VARCHAR2,
   type            IN   VARCHAR2   := 'TEXT',
   level           IN   VARCHAR2   := 'TYPICAL',
   section         IN   VARCHAR2   := ALL,
   object_id       IN   NUMBER     := NULL,
   result_limit    IN   NUMBER     := NULL,
   owner_name      IN    VARCHAR2  := NULL,
   execution_name  IN  VARCHAR2    := NULL)
RETURN CLOB;

-- Get the whole report for the single statement case.
SET LINES 120
SET PAGES 200
SET LONG 100000
SET SERVEROUTPUT ON
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK(:stmt_task) from dual;

-- Show me the summary for the sts case.
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('&what_task', 'TEXT', 'TYPICAL', 'SUMMARY') FROM DUAL;

-- Show me the findings for the statement I'm interested in.
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('&what_task', 'TEXT', 'ALL', 'FINDINGS', &what_object_id) from dual;


/*--- Accept profile recommendation ---*/
DBMS_SQLTUNE.ACCEPT_SQL_PROFILE (
   task_name    IN  VARCHAR2,
   object_id    IN  NUMBER   := NULL,
   name         IN  VARCHAR2 := NULL,
   description  IN  VARCHAR2 := NULL,
   category     IN  VARCHAR2 := NULL);
   task_owner   IN VARCHAR2  := NULL,
   replace      IN BOOLEAN   := FALSE,
   force_match  IN BOOLEAN   := FALSE,
   profile_type IN VARCHAR2  := REGULAR_PROFILE);

-- get object id from DBMS_SQLTUNE.REPORT_TUNING_TASK
BEGIN
	DBMS_SQLTUNE.ACCEPT_SQL_PROFILE (
		task_name => '&what_task',
		object_id => &what_object_id,
		task_owner => 'SYSTEM',
		replace => TRUE);
END;
/


-- create script to execute tuning tasks
DBMS_SQLTUNE.SCRIPT_TUNING_TASK(
  task_name         IN VARCHAR2,
  rec_type          IN VARCHAR2  := REC_TYPE_ALL,
  object_id         IN NUMBER    := NULL,
  result_limit      IN NUMNBER   := NULL,
  owner_name        IN VARCHAR2  := NULL,
  execution_name    IN VARCHAR2  := NULL)
 RETURN CLOB;

-- Wrap with a call to DBMS_ADVISOR.CREATE_FILE to put it into a file
-- Get a script for all actions recommended by the task.
SELECT DBMS_SQLTUNE.SCRIPT_TUNING_TASK(:stmt_task) FROM DUAL;
-- Get a script of just the sql profiles we should create.
SELECT DBMS_SQLTUNE.SCRIPT_TUNING_TASK(:stmt_task, 'PROFILES') FROM DUAL;
-- get a script of just stale / missing stats
SELECT DBMS_SQLTUNE.SCRIPT_TUNING_TASK(:stmt_task, 'STATISTICS') FROM DUAL;
-- Get a script with recommendations about just one SQL statement when we have tuned an entire STS.
SELECT DBMS_SQLTUNE.SCRIPT_TUNING_TASK(:sts_task, 'ALL', 5) FROM DUAL;


/*--- Export SQL profiles to another database ---*/

-- check existing SQL profiles
col name format a40
select name, to_char(created,'MM/DD/RR') "CREATED", to_char(last_modified,'MM/DD/RR') "MODIFIED", type, status, force_matching
from DBA_SQL_PROFILES
order by created;

col sql_profile_name format a40
select distinct s.sql_id, p.name sql_profile_name
from dba_sql_profiles p, DBA_HIST_SQLSTAT s
where p.name=s.sql_profile
and s.sql_id='&what_sql'
order by 1;


-- 1. Create a staging table
DBMS_SQLTUNE.CREATE_STGTAB_SQLPROF (
   table_name            IN VARCHAR2,
   schema_name           IN VARCHAR2 := NULL,
   tablespace_name       IN VARCHAR2 := NULL);
EXEC DBMS_SQLTUNE.CREATE_STGTAB_SQLPROF (table_name => 'PROFILE_STGTAB');

-- 2. Load profiles to staging table
DBMS_SQLTUNE.PACK_STGTAB_SQLPROF (
   profile_name          IN VARCHAR2 := '%',
   profile_category      IN VARCHAR2 := 'DEFAULT',
   staging_table_name    IN VARCHAR2,
   staging_schema_owner  IN VARCHAR2 := NULL);
EXEC DBMS_SQLTUNE.PACK_STGTAB_SQLPROF (profile_category => '%', staging_table_name => 'PROFILE_STGTAB');

-- 3. Export staging table (& import to dest DB)
-- 4. Create staging table in dest DB (might be created during DP import)
EXEC DBMS_SQLTUNE.CREATE_STGTAB_SQLPROF (table_name => 'PROFILE_STGTAB');

-- 5. Unpack staging table
DBMS_SQLTUNE.UNPACK_STGTAB_SQLPROF (
   profile_name          IN VARCHAR2 := '%',
   profile_category      IN VARCHAR2 := 'DEFAULT',
   replace               IN BOOLEAN,
   staging_table_name    IN VARCHAR2,
   staging_schema_owner  IN VARCHAR2 := NULL);
EXEC DBMS_SQLTUNE.UNPACK_STGTAB_SQLPROF(replace => TRUE, staging_table_name => 'PROFILE_STGTAB');


-- #######################
-- # SQL Plan Management #
-- #######################

/*--- Queries ---*/

-- sql baselines in use
set lines 150 pages 200
col sql_handle format a30
col plan_name format a30
col sql_text format a40
select sql_handle, plan_name, origin, enabled, accepted, fixed, autopurge, to_char(last_modified,'MM/DD/RR') "MODIFIED", to_char(last_executed,'MM/DD/RR') "EXECUTED"
from dba_sql_plan_baselines
where enabled='YES' and accepted='YES'
order by 1;

-- find sql_handle for statement
select sql_handle, sql_text
from dba_sql_plan_baselines
where upper(sql_text) like upper('&what_query');

-- find details of sql plans
col module format a40
col optimizer_cost format 999999999990
select plan_name, sql_handle, optimizer_cost, enabled, accepted, fixed, module
from dba_sql_plan_baselines
where sql_handle='&what_handle';

-- mapping to SQLID
SELECT sql_handle, plan_name
FROM dba_sql_plan_baselines
WHERE signature IN (
   SELECT exact_matching_signature FROM v$sql WHERE sql_id='&what_sql');
   
select distinct sql_id, plan_hash_value, exact_matching_signature, sql_plan_baseline 
from v$sql
where sql_id='&what_sql';

-- see execution plan
SELECT PLAN_TABLE_OUTPUT
FROM   V$SQL s, DBA_SQL_PLAN_BASELINES b, 
       TABLE(
       DBMS_XPLAN.DISPLAY_SQL_PLAN_BASELINE(b.sql_handle,b.plan_name,'basic') 
       ) t
WHERE  s.EXACT_MATCHING_SIGNATURE=b.SIGNATURE
AND    b.PLAN_NAME=s.SQL_PLAN_BASELINE
AND    s.SQL_ID='&what_sql';


/*--- Using the API ---*/

-- fix a plan baseline
declare
   l_plans	pls_integer;
begin
   l_plans := dbms_spm.alter_sql_plan_baseline (
      sql_handle		=> 'SYS_SQL_f6b17b4c27a47aa1',
      plan_name			=> 'SYS_SQL_PLAN_27a47aa15003759b',
      attribute_name	=> 'fixed',
      attribute_value	=> 'YES'
   );
end;
/

-- load plans from SQL tuning set
declare
   l_sqlset	pls_integer;
begin
	l_sqlset := DBMS_SPM.LOAD_PLANS_FROM_SQLSET (
		sqlset_name		=> 'ADDM_1441219267129',
		basic_filter	=> 'sql_id IN (''f22mx39m9nn3v'',''ftd3arfbsrjpw'')',
		fixed			=> 'NO',
		enabled			=> 'YES',
		commit_rows		=> 1000);
	DBMS_OUTPUT.PUT_LINE('There were '||l_sqlset||' plans loaded.');
end;
/

-- allow optimizer to evolve (mark better plans as accepted) for specific statements
set serveroutput on
set long 10000
declare
	report	clob;
begin
	report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE (
		sql_handle	=> 'SYS_SQL_PLAN_27a47aa15003759b');
	DBMS_OUTPUT.PUT_LINE(report);
end;
/

select sqlset_id, sqlset_owner, plan_hash_value, optimizer_cost
from DBA_SQLSET_STATEMENTS
where sqlset_name='ADDM_1441219267129' and sql_id='f22mx39m9nn3v';

/*--- Moving baselines between DBs ---
1. Use the DBMS_SPM.*_STGTAB_BASELINE procedures to create staging table
2. Export/import staging table with DP
*/

-- create staging table
DBMS_SPM.CREATE_STGTAB_BASELINE (
   table_name        IN VARCHAR2,
   table_owner       IN VARCHAR2 := NULL,
   tablespace_name   IN VARCHAR2 := NULL);

exec DBMS_SPM.CREATE_STGTAB_BASELINE ('STGTAB_BASELINE','GGTEST','GGS');

-- pack baselines into staging table
DBMS_SPM.PACK_STGTAB_BASELINE (
   table_name       IN VARCHAR2,
   table_owner      IN VARCHAR2 := NULL,
   sql_handle       IN VARCHAR2 := NULL,
   plan_name        IN VARCHAR2 := NULL,
   sql_text         IN CLOB     := NULL,
   creator          IN VARCHAR2 := NULL,   origin           IN VARCHAR2 := NULL,
   enabled          IN VARCHAR2 := NULL,
   accepted         IN VARCHAR2 := NULL,
   fixed            IN VARCHAR2 := NULL,
   module           IN VARCHAR2 := NULL,
   action           IN VARCHAR2 := NULL)
RETURN NUMBER;

declare
	my_plans	pls_integer;
begin
	my_plans := DBMS_SPM.PACK_STGTAB_BASELINE (
		table_name	=> 'STGTAB_BASELINE',
		table_owner	=> 'GGTEST',
		enabled		=> 'YES',
		accepted	=> 'YES');
	dbms_output.put_line(my_plans);
end;
/

-- unpack baselines from staging table into SQL management base
DBMS_SPM.UNPACK_STGTAB_BASELINE (
   table_name       IN VARCHAR2,
   table_owner      IN VARCHAR2 := NULL,
   sql_handle       IN VARCHAR2 := NULL,
   plan_name        IN VARCHAR2 := NULL,
   sql_text         IN CLOB     := NULL,
   creator          IN VARCHAR2 := NULL,   origin           IN VARCHAR2 := NULL,
   enabled          IN VARCHAR2 := NULL,
   accepted         IN VARCHAR2 := NULL,
   fixed            IN VARCHAR2 := NULL,
   module           IN VARCHAR2 := NULL,
   action           IN VARCHAR2 := NULL)
RETURN NUMBER;


-- ####################
-- # INTERNAL QUERIES #
-- ####################

V$SYSMETRIC - metric values for both the long duration (60-second) and short duration (15-second)

-- wait time ratios
select  METRIC_NAME,
        VALUE
from    SYS.V_$SYSMETRIC
where   METRIC_NAME IN ('Database CPU Time Ratio',
                        'Database Wait Time Ratio') AND
        INTSIZE_CSEC = 
        (select max(INTSIZE_CSEC) from SYS.V_$SYSMETRIC); 
		
-- performance of past hour by minute
alter session set nls_date_format='DD-MON-YY HH24:MI';
select  end_time,
        value
from    sys.v_$sysmetric_history
where   metric_name = 'Database CPU Time Ratio'
order by 1;
	
--
select  CASE METRIC_NAME
            WHEN 'SQL Service Response Time' then 'SQL Service Response Time (secs)'
            WHEN 'Response Time Per Txn' then 'Response Time Per Txn (secs)'
            ELSE METRIC_NAME
            END METRIC_NAME,
                CASE METRIC_NAME
            WHEN 'SQL Service Response Time' then ROUND((MINVAL / 100),2)
            WHEN 'Response Time Per Txn' then ROUND((MINVAL / 100),2)
            ELSE MINVAL
            END MININUM,
                CASE METRIC_NAME
            WHEN 'SQL Service Response Time' then ROUND((MAXVAL / 100),2)
            WHEN 'Response Time Per Txn' then ROUND((MAXVAL / 100),2)
            ELSE MAXVAL
            END MAXIMUM,
                CASE METRIC_NAME
            WHEN 'SQL Service Response Time' then ROUND((AVERAGE / 100),2)
            WHEN 'Response Time Per Txn' then ROUND((AVERAGE / 100),2)
            ELSE AVERAGE
            END AVERAGE
from    SYS.V_$SYSMETRIC_SUMMARY 
where   METRIC_NAME in ('CPU Usage Per Sec',
                      'CPU Usage Per Txn',
                      'Database CPU Time Ratio',
                      'Database Wait Time Ratio',
                      'Executions Per Sec',
                      'Executions Per Txn',
                      'Response Time Per Txn',
                      'SQL Service Response Time',
                      'User Transaction Per Sec')
ORDER BY 1

-- historical performance of a SQL statement (per execution)
select hss.SQL_ID, hss.PLAN_HASH_VALUE, hss.SQL_PROFILE, min(snp.BEGIN_INTERVAL_TIME),
	DECODE(sum(hss.EXECUTIONS_DELTA),0,0,ROUND(sum(hss.CPU_TIME_DELTA/1000000)/sum(hss.EXECUTIONS_DELTA),2)) "CPU_SEC", 
	DECODE(sum(hss.EXECUTIONS_DELTA),0,0,ROUND(sum(hss.ELAPSED_TIME_DELTA/1000000)/sum(hss.EXECUTIONS_DELTA),2)) "ELAPSED_SEC",
	sum(hss.EXECUTIONS_DELTA) "EXEC"
from DBA_HIST_SQLSTAT hss, DBA_HIST_SNAPSHOT snp
where snp.SNAP_ID=hss.SNAP_ID and hss.SQL_ID='&what_sql' and snp.BEGIN_INTERVAL_TIME >= to_date('&what_date','YYYYMMDD')
group by hss.SQL_ID, hss.PLAN_HASH_VALUE, hss.SQL_PROFILE order by 4 asc;

--
select hss.PARSING_SCHEMA_NAME, hss.SQL_ID,
	ROUND(sum(hss.CPU_TIME_DELTA/1000000),2) "CPU_SEC", 
	ROUND(sum(hss.ELAPSED_TIME_DELTA/1000000),2) "ELAPSED_SEC",
	ROUND(sum(hss.SORTS_DELTA),2) "SORTS",
	ROUND(sum(hss.BUFFER_GETS_DELTA),2) "BUFFER_GETS",
	sum(hss.EXECUTIONS_DELTA) "EXEC"
from DBA_HIST_SQLSTAT hss, DBA_HIST_SNAPSHOT snp
where snp.SNAP_ID=hss.SNAP_ID 
and snp.BEGIN_INTERVAL_TIME between to_date('&what_start','YYYYMMDD HH24MI') and to_date('&what_end','YYYYMMDD HH24MI')
and hss.PARSING_SCHEMA_NAME not in ('SYS','SYSTEM','INSIGHT','DBSNMP')
group by hss.PARSING_SCHEMA_NAME, hss.SQL_ID order by 1,2;


