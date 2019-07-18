###############
# JOB QUERIES #
###############

/*-- DBMS Scheduler Job Queries--*/
-- views
USER_SCHEDULER_JOBS
USER_SCHEDULER_JOB_LOG
USER_SCHEDULER_JOB_RUN_DETAILS
USER_SCHEDULER_SCHEDULES

-- get schedule jobs showing inline & out-of-line actions
set lines 150 pages 1000
alter session set nls_timestamp_format='DD-MON-RR HH24:MI';
col job_name format a25
col state format a10
col "LAST" format a15
col "NEXT" format a15
col "F" format 90
col "ACTION" format a45
select sj.job_name, to_char(sj.last_start_date,'DD-MON-RR HH24:MI') "LAST", sj.failure_count "F",
to_char(sj.next_run_date,'DD-MON-RR HH24:MI') "NEXT", sj.state, NVL2(sj.job_action, sj.job_action, sp.program_action) "ACTION"
from dba_scheduler_jobs sj left outer join DBA_SCHEDULER_PROGRAMS sp
  on sj.program_name=sp.program_name
--where sj.owner not in ('SYS','APEX_040000','ORACLE_OCM')
order by last_start_date, next_run_date;

-- get jobs & their schedules
col job_name format a30
col schedule_name format a27
col "REPEAT INTERVAL" format a60
select sj.job_name, sj.schedule_name, NVL2(sj.repeat_interval, sj.repeat_interval, ss.repeat_interval) "REPEAT INTERVAL"
from dba_scheduler_jobs sj left outer join dba_scheduler_schedules ss
  on sj.schedule_name=ss.schedule_name
where sj.owner not in ('SYS','APEX_040000','ORACLE_OCM')
order by job_name;

-- get all schedules
col schedule_name format a27
col REPEAT_INTERVAL format a60
select owner, schedule_name, repeat_interval
from dba_scheduler_schedules
order by 1,2;

-- find out which jobs failed
select log_id, log_date, status, error# from USER_SCHEDULER_JOB_RUN_DETAILS
where status!='SUCCEEDED';
select log_id, log_date, status, error# from DBA_SCHEDULER_JOB_RUN_DETAILS
where status!='SUCCEEDED';

-- get details of failed jobs
select additional_info from USER_SCHEDULER_JOB_RUN_DETAILS where log_id=8945;

-- get details for failures
select job_name, to_char(actual_start_date,'DD-MON-YY HH24:MI') "START", run_duration, additional_info
from dba_scheduler_job_run_details
where job_name='&what_job' and status!='SUCCEEDED'
order by actual_start_date;

-- find last week's worth of history of a job
select job_name, to_char(log_date,'DD-MON-YY HH24:MI'), status, error# from DBA_SCHEDULER_JOB_RUN_DETAILS
where job_name like upper('%&what_job%') and log_date >= (systimestamp - 7)
order by job_name asc, log_date desc;

-- get details of job run
col run_duration format a13
col cpu_used format a16
col additional_info format a30
select to_char(actual_start_date,'DD-MON-YY HH24:MI') "START", run_duration, cpu_used, additional_info
from dba_scheduler_job_run_details
where job_name='&what_job'
order by actual_start_date;

-- get run times for apex jobs
col job_name format a25
col run_duration format a13
col cpu_used format a16
col additional_info format a30
select job_name, to_char(actual_start_date,'DD-MON-YY HH24:MI') "START", run_duration, cpu_used, additional_info
from dba_scheduler_job_run_details
where job_name in ('GET_ACT_TBL_NMS_CNTS_JOB','GET_FLX_TBL_NMS_CNTS_JOB','GET_DW3_TBL_NMS_CNTS_JOB')
order by job_name;

-- get last job durations
col RUN_DURATION format a13
select job_name, to_char(actual_start_date,'DD-MON-YY HH24:MI') "START DATE", RUN_DURATION
from dba_scheduler_job_run_details where owner not in ('SYS','APEX_040000','ORACLE_OCM')
order by 1 asc, 2 asc;


alter session set nls_date_format='DD-MON-RR HH24:MI';
col schedule_name format a30
select job_name, schedule_name, state, last_start_date, next_run_date from dba_scheduler_jobs where job_name='GET_TS_SIZES_JOB';


select job_name, schedule_name, state, last_start_date, next_run_date, program_name, repeat_interval,
enabled, failure_count, last_run_duration, raise_events, comments, flags
from dba_scheduler_jobs where job_name='GET_TS_SIZES_JOB';


/*-- Automated Maintenance Tasks --*/

DBA_AUTOTASK_CLIENT_JOB

-- check status of automated tasks
set lines 150 pages 200
col client_name format a40
col consumer_group format a30
select client_name, status, consumer_group
from DBA_AUTOTASK_CLIENT
order by client_name;

select con_id, client_name, status, consumer_group
from CDB_AUTOTASK_CLIENT
order by con_id, client_name;

select CLIENT_NAME, OPERATION_NAME, STATUS from DBA_AUTOTASK_OPERATION where client_name like '%stats%';

-- check task windows
col "NEXT_TIME" format a15
COL "STATUS" format a8
col "OPT_STAT" format a8
col "SEG_ADV" format a8
col "SQL_ADV" format a8
select WINDOW_NAME, to_char(WINDOW_NEXT_TIME,'DD-MON-YY HH24:MI') "NEXT_TIME", AUTOTASK_STATUS "STATUS",
	OPTIMIZER_STATS "OPT_STAT", SEGMENT_ADVISOR "SEG_ADV", SQL_TUNE_ADVISOR "SQL_ADV"
from DBA_AUTOTASK_WINDOW_CLIENTS
order by WINDOW_NEXT_TIME;

-- task windows with start/end times
select win.WINDOW_NAME, to_char(win.WINDOW_NEXT_TIME,'HHPM') "START", to_char((win.WINDOW_NEXT_TIME + sch.DURATION),'HHAM') "END",
	win.AUTOTASK_STATUS "STATUS", win.OPTIMIZER_STATS "OPT_STAT", win.SEGMENT_ADVISOR "SEG_ADV", win.SQL_TUNE_ADVISOR "SQL_ADV"
from DBA_AUTOTASK_WINDOW_CLIENTS win, 
	(select WINDOW_NAME, DURATION, min(START_TIME) from DBA_AUTOTASK_SCHEDULE group by WINDOW_NAME, DURATION) sch
where win.WINDOW_NAME=sch.WINDOW_NAME and win.WINDOW_NAME in ('WEDNESDAY_WINDOW','THURSDAY_WINDOW','FRIDAY_WINDOW','MONDAY_WINDOW','TUESDAY_WINDOW')
order by WINDOW_NEXT_TIME;

-- check history of tasks in time period
col client_name format a40
col job_status format a20
col job_name format a30
select client_name, job_name, job_status, to_char(job_start_time,'DD-MON-YY HH24:MI') "START_TIME", to_char((job_start_time + job_duration),'DD-MON-YY HH24:MI') "END_TIME"
from DBA_AUTOTASK_JOB_HISTORY
where job_start_time between to_date('&what_start','MMDDYY HH24MI') and to_date('&what_end','MMDDYY HH24MI')
order by client_name, job_start_time;

DBA_AUTOTASK_CLIENT_HISTORY

-- disable auto job
DBMS_AUTO_TASK_ADMIN.DISABLE (
   client_name       IN    VARCHAR2,
   operation         IN    VARCHAR2,
   window_name       IN    VARCHAR2);
   
exec DBMS_AUTO_TASK_ADMIN.DISABLE('AUTO OPTIMIZER STATS COLLECTION',NULL, NULL);
exec DBMS_AUTO_TASK_ADMIN.DISABLE('AUTO SPACE ADVISOR',NULL, NULL);
exec DBMS_AUTO_TASK_ADMIN.DISABLE('SQL TUNING ADVISOR',NULL, NULL);

col client_name format a40
SELECT CLIENT_NAME, STATUS FROM DBA_AUTOTASK_CLIENT; 

-- enable auto job
DBMS_AUTO_TASK_ADMIN.ENABLE (
   client_name       IN    VARCHAR2,
   operation         IN    VARCHAR2,
   window_name       IN    VARCHAR2);

exec DBMS_AUTO_TASK_ADMIN.ENABLE ('auto optimizer stats collection','auto optimizer stats job',NULL);

/*-- 10g Job Queries--*/
-- get list of all DB jobs
alter session set nls_date_format='DD-MON-RR HH24:MI';
col job format 99990
col last_date format a16
col next_date format a16
col schema_user format a20
col what format a50
col "F" format 90
select job, schema_user, to_char(last_date,'DD-MON-RR HH24:MI') "LAST_DATE", to_char(next_date,'DD-MON-RR HH24:MI') "NEXT_DATE", broken, failures "F", what
from dba_jobs
order by schema_user, last_date;

-- find details of a specific job
col job format 99990
col schema_user format a20
col what format a50
col interval format a40
select job, schema_user, interval, what from dba_jobs where job=&what_job;

-- find intervals of all jobs
col job format 99990
col schema_user format a20
col what format a50
col interval format a40
select job, schema_user, interval, what from dba_jobs order by 2, 1;

-- find runtime for job (cumulative time)
col job format 99990
col schema_user format a20
col last_date format a16
col "TOTAL_TIME" format a10
select job, schema_user, to_char(last_date,'DD-MON-RR HH24:MI') "LAST_DATE", total_time,
	TO_CHAR(TRUNC(total_time/3600),'FM9900') || ':' ||
    TO_CHAR(TRUNC(MOD(total_time,3600)/60),'FM00') || ':' ||
    TO_CHAR(MOD(total_time,60),'FM00') "TOTAL_TIME"
from dba_jobs where job=&what_job;


/*-- Scheduler Windows --*/
--DBA_SCHEDULER_WINDOWS

select window_name, resource_plan, start_date, duration, repeat_interval, enabled 
from DBA_SCHEDULER_WINDOWS 
order by 1;


################
# CREATE A JOB #
################

/*-- Create Scheduler Job --*/
-- create program using stored procedure
BEGIN
  DBMS_SCHEDULER.create_program (
    program_name        => 'get_ts_sizes_prog',
    program_type        => 'STORED_PROCEDURE',
    program_action      => 'APEX_TABLE_OWNER.GET_TS_SIZES_PRC',
    number_of_arguments => 0,
    enabled             => TRUE,
    comments            => 'Program to add TS sizes from QA to apex table');
END;
/

-- create program with inline procedure
BEGIN
  DBMS_SCHEDULER.create_program (
    program_name        => 'sql_history_prog',
    program_type        => 'PLSQL_BLOCK',
    program_action      => 'BEGIN EXECUTE IMMEDIATE ''INSERT INTO actd00.sql_history (SELECT * FROM v$sql WHERE sql_id NOT IN (SELECT sql_id FROM actd00.sql_history))''; COMMIT; END;',
    number_of_arguments => 0,
    enabled             => TRUE,
    comments            => 'Loads new entries in v$sql into actd00.sql_history');
END;
/

-- create program using procedure that accepts parameters
BEGIN
  DBMS_SCHEDULER.create_program (
    program_name        => 'audit_hist_prog',
    program_type        => 'STORED_PROCEDURE',
    program_action      => 'APEX_TABLE_OWNER.GET_AUDIT_HIST_v2_PRC',
    number_of_arguments => 1,
    enabled             => FALSE,
    comments            => 'Program to add audit data from QA bus stop to apex table');
	
  DBMS_SCHEDULER.define_program_argument (
    program_name		=> 'audit_hist_prog',
    argument_position	=> 1,
    argument_type		=> 'VARCHAR2',
    DEFAULT_VALUE		=> 'NO');
	
  DBMS_SCHEDULER.enable ('audit_hist_prog');
END;
/

-- Create the schedule.
BEGIN
  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'post_qa_refresh_sched',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=WEEKLY;INTERVAL=1;BYDAY=THU;BYHOUR=18;BYMINUTE=0',
    end_date        => NULL,
    comments        => 'Repeats every week at 6pm after a QA refresh');
END;
/

-- Create job
BEGIN
  DBMS_SCHEDULER.create_job (
    job_name      => 'get_ts_sizes_job',
    program_name  => 'get_ts_sizes_prog',
    schedule_name => 'post_qa_refresh_sched',
    enabled       => TRUE);
END;
/

-- create a job using a procedure that accepts parameters
BEGIN
  DBMS_SCHEDULER.create_job (
    job_name      => 'norm_audit_hist_job',
    program_name  => 'audit_hist_prog',
    schedule_name => 'norm_busstop_sched',
    enabled       => FALSE);
	
  DBMS_SCHEDULER.set_job_argument_value (
    job_name			=> 'norm_audit_hist_job',
	argument_position	=> 1,
	argument_value		=> 'NO');
	
  DBMS_SCHEDULER.enable ('norm_audit_hist_job');
END;
/


###############
# JOB ACTIONS #
###############

-- run job immediately
exec DBMS_SCHEDULER.RUN_JOB (job_name => 'get_ts_sizes_job');

-- stop a running job
exec DBMS_SCHEDULER.STOP_JOB (job_name => 'APEX_LINK_OWNER.GET_ROW_COUNTS_JOB');
   force            IN BOOLEAN DEFAULT FALSE
   commit_semantics IN VARCHAR2 DEFAULT 'STOP_ON_FIRST_ERROR');

-- force stop
BEGIN
  DBMS_SCHEDULER.STOP_JOB (
	job_name => 'FLXADM.REPORTING_NIGHTLY_JOBS',
	force    => TRUE);
  DBMS_SCHEDULER.STOP_JOB (
	job_name => 'FLXADM.REFRESH_REPORTING_TRANS',
	force    => TRUE);
END;
/


##############
# EDIT A JOB #
##############

/*-- Edit Scheduler Job --*/
-- edit program
BEGIN
  -- change scheduled start time
  DBMS_SCHEDULER.set_attribute (
    name      => 'audit_hist_prog',
    attribute => 'program_action',
    value     => 'APEX_TABLE_OWNER.GET_AUDIT_HIST_v3_PRC');
END;
/


-- drop job
exec DBMS_SCHEDULER.DROP_JOB ('sql_history_job');

-- drop program
exec DBMS_SCHEDULER.DROP_PROGRAM ('sql_history_prog');

-- drop schedule
exec DBMS_SCHEDULER.DROP_SCHEDULE ('failure_sched');

-- disable a program, job, chain, window, database destination, external destination, file watcher, or group
exec DBMS_SCHEDULER.DISABLE ('APEX_LINK_OWNER.GET_ROW_COUNTS_JOB');

-- enable a program, job, chain, window, database destination, external destination, file watcher, or group
exec DBMS_SCHEDULER.enable ('DW3.OVERRUN_CHECK_CONTROLLER');


##############
# SCHEDULES  #
##############
-- see DBMS_SCHEDULER document for calendar syntax

-- create schedule
BEGIN
  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'GET_AUDIT_HIST_SCHED_EXCP',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=WEEKLY;INTERVAL=1;BYDAY=THU;BYHOUR=8;BYMINUTE=0',
    end_date        => NULL,
    comments        => 'Remove Thur morning run of Audit History schedule');
END;
/

BEGIN
  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'DAILY_2000',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=20;BYMINUTE=0;BYSECOND=0',
    end_date        => NULL,
    comments        => 'Every day at 8 pm');
END;
/

BEGIN
  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'DAILY_0800_MINUS_THU',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYDAY=SUN,MON,TUE,WED,FRI,SAT;BYHOUR=8;BYMINUTE=0;BYSECOND=0',
    end_date        => NULL,
    comments        => 'Every day except Thur at 8 am');
END;
/


-- edit schedule
BEGIN
  DBMS_SCHEDULER.set_attribute (
    name      => 'GET_AUDIT_HIST_SCHED',
    attribute => 'repeat_interval',
    value     => 'DAILY_2000,DAILY_0800_MINUS_THU');
END;
/

BEGIN
  DBMS_SCHEDULER.set_attribute (
    name      => 'GET_AUDIT_HIST_SCHED_EXCP',
    attribute => 'repeat_interval',
    value     => 'FREQ=WEEKLY;BYDAY=THU;BYHOUR=8;BYMINUTE=0;BYSECOND=0');
END;
/


/* sample schedules */
-- every Thur at 8:00
FREQ=WEEKLY;INTERVAL=1;BYDAY=THU;BYHOUR=8;BYMINUTE=0
-- every day at 8:00 and 20:00
FREQ=DAILY;INTERVAL=1;BYHOUR=8,20;BYMINUTE=0
-- the 1st of every month at 00:05
FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1;BYHOUR=0;BYMINUTE=5
-- every 10 minutes
FREQ=MINUTELY;INTERVAL=10
-- the 15th and 30th of every month at 8:00, 13:00 and 18:00 except Jan 15
freq=monthly;bymonthday=15,30;byhour=8,13,18;byminute=0;bysecond=0;exclude=jan_fifteenth

http://awads.net/wp/2011/02/02/25-unique-ways-to-schedule-a-job-using-the-oracle-scheduler/
-- Mon-Fri at 22:00
FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=22; BYMINUTE=0; BYSECOND=0
-- every Fri at 9:00
FREQ=DAILY; BYDAY=FRI; BYHOUR=9; BYMINUTE=0; BYSECOND=0;
FREQ=WEEKLY; BYDAY=FRI; BYHOUR=9; BYMINUTE=0; BYSECOND=0;
FREQ=YEARLY; BYDAY=FRI; BYHOUR=9; BYMINUTE=0; BYSECOND=0;
-- every other Fri
FREQ=WEEKLY; INTERVAL=2; BYDAY=FRI;
-- Run on the last day of every month.
FREQ=MONTHLY; BYMONTHDAY=-1
-- Run every January 10, 11, 12, 13 and 14 (Both examples are equivalent):
FREQ=YEARLY; BYDATE=0110,0111,0112,0113,0114
FREQ=YEARLY; BYDATE=0110+SPAN:5D
-- Run on the second Wednesday of each month:
FREQ=MONTHLY; BYDAY=2WED
-- Run on the last Friday of the year:
FREQ=YEARLY; BYDAY=-1FRI
-- Run on the last workday of every month, excluding company holidays:
FREQ=MONTHLY; BYDAY=MON,TUE,WED,THU,FRI; EXCLUDE=COMPANY_HOLIDAYS; BYSETPOS=-1


############
# DBMS_JOB #
############

/* must be run as job owner */

-- submit a new job
-- You must issue a COMMIT statement immediately after the statement
DBMS_JOB.SUBMIT ( 
   job       OUT BINARY_INTEGER,
   what      IN  VARCHAR2,
   next_date IN  DATE DEFAULT sysdate,
   interval  IN  VARCHAR2 DEFAULT 'null',
   no_parse  IN  BOOLEAN DEFAULT FALSE,
   instance  IN  BINARY_INTEGER DEFAULT any_instance,
   force     IN  BOOLEAN DEFAULT FALSE);
   
SET SERVEROUTPUT ON
VARIABLE jobno number;
BEGIN
   DBMS_JOB.SUBMIT(
      :jobno, 
      'dbms_ddl.analyze_object(''TABLE'',''SQLTUNE'', ''SQL_TUNE_STAGING'', ''ESTIMATE'', NULL, 50);',
      SYSDATE, 
	  'SYSDATE + 1'
	);
   COMMIT;
END;
/
print jobno

-- change next run date
Exec dbms_job.next_date(509,sysdate+8/24)

-- To make it run:
Exec dbms_job.next_date(569,sysdate)

-- mark it as broken
exec DBMS_JOB.BROKEN (1,FALSE,sysdate);
exec DBMS_JOB.BROKEN (1,TRUE,sysdate);

-- run it immediately
EXECUTE DBMS_JOB.RUN(569);

-- delete it
EXEC DBMS_JOB.REMOVE (7);

-- from Oracle docs
"Note that, once a job is started and running, there is no easy way to stop the job."



#########################
# DISABLE TEST FOR R6.0 #
#########################

-- APEX_LINK_OWNER @ ACTAPX
create table que_hora_es (lafecha DATE);

set serveroutput on
create procedure elreloj as
begin
  execute immediate 'insert into que_hora_es values (sysdate)';
  commit;
end;
/

exec elreloj;

BEGIN
  DBMS_SCHEDULER.create_program (
    program_name        => 'r60_testing_prog',
    program_type        => 'STORED_PROCEDURE',
    program_action      => 'APEX_LINK_OWNER.ELRELOJ',
    number_of_arguments => 0,
    enabled             => TRUE,
    comments            => 'Testing for enabling/disabling jobs');

  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'r60_testing_sched',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=14;BYMINUTE=30;BYSECOND=00',
    end_date        => NULL,
    comments        => 'Testing for enabling/disabling jobs');

  DBMS_SCHEDULER.create_job (
    job_name      => 'r60_testing_job',
    program_name  => 'r60_testing_prog',
    schedule_name => 'r60_testing_sched',
    enabled       => TRUE);
END;
/

-- disable
exec DBMS_SCHEDULER.DISABLE ('APEX_LINK_OWNER.R60_TESTING_JOB');

-- enable after window passes
exec DBMS_SCHEDULER.enable ('APEX_LINK_OWNER.R60_TESTING_JOB');

-- cleanup
exec DBMS_SCHEDULER.DROP_JOB ('r60_testing_job');
exec DBMS_SCHEDULER.DROP_SCHEDULE ('r60_testing_sched');
exec DBMS_SCHEDULER.DROP_PROGRAM ('r60_testing_prog');
