-- ##############
-- # FIND VIEWS #
-- ##############

select object_name 
from dba_objects 
where owner='SYSMAN' and object_type='VIEW' and object_name like '%&what_view%'
order by 1;

-- ##############
-- # JOB CHECKS #
-- ##############

select job_name ,scheduled_time changed_time from joblist  where job_name in (
	'ACTURIS CHECK DBA JOBS.1',
	'DQI LOGFILE SWITCH',
	'RMAN ACTURIS9 BACKUP ARCHIVELOGS.1',
	'RMAN ADMN BACKUP ARCHIVELOGS.2',
	'RMAN DBGRID10 BACKUP ARCHIVELOGS.1',
	'RMAN DQI BACKUP ARCHIVELOGS_UPDATED',
	'RMAN DW3 BACKUP ARCHIVELOGS.1',
	'RMAN DW3 DELETE ONLINE ARCHLOGS1',
	'RMAN FLEXI9 BACKUP ARCHIVELOGS.2',
	'RMAN LOGDB BACKUP ARCHIVELOGS',
	'RMAN LOGDB DELETE DB BACKUP AND ARCHLOG',
	'RMAN LOGDB DELETE ONLINE ARCHLOGS',
	'RMAN LOGDB LEVEL 0',
	'RMAN LOGDB LEVEL 1',
	'RMAN WM9 BACKUP ARCHIVELOGS')
 minus 
 select distinct job_name,to_char(scheduled_time,'HH24:MI:SS') from SYSMAN.MGMT$JOB_EXECUTION_HISTORY  WHERE status='Scheduled' and job_name in (
	'ACTURIS CHECK DBA JOBS.1',
	'DQI LOGFILE SWITCH',
	'RMAN ACTURIS9 BACKUP ARCHIVELOGS.1',
	'RMAN ADMN BACKUP ARCHIVELOGS.2',
	'RMAN DBGRID10 BACKUP ARCHIVELOGS.1',
	'RMAN DQI BACKUP ARCHIVELOGS_UPDATED',
	'RMAN DW3 BACKUP ARCHIVELOGS.1',
	'RMAN DW3 DELETE ONLINE ARCHLOGS1',
	'RMAN FLEXI9 BACKUP ARCHIVELOGS.2',
	'RMAN LOGDB BACKUP ARCHIVELOGS',
	'RMAN LOGDB DELETE DB BACKUP AND ARCHLOG',
	'RMAN LOGDB DELETE ONLINE ARCHLOGS',
	'RMAN LOGDB LEVEL 0',
	'RMAN LOGDB LEVEL 1',
	'RMAN WM9 BACKUP ARCHIVELOGS');

-- ###############################
-- # SEARCHES FOR SCHEDULED JOBS #
-- ###############################

-- find scheduled PROD jobs
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
--break on target;
SPOOL PROD_OEM_Jobs.xls;
select jeh.TARGET, jeh.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly ('||to_char(jeh.NEXT_RUN,'DY')||')'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(jeh.NEXT_RUN,'MM/DD/RR') "NEXT_DAY", to_char(jeh.NEXT_RUN,'HH24:MI') "NEXT_TIME", jeh.status
from SYSMAN.MGMT$JOBS mj,
  (select job_id, job_name, target_name "TARGET", max(scheduled_time) "NEXT_RUN", status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
   where scheduled_time >= sysdate and status not in ('17','Waiting') 
   and target_name is not null and job_type!='Backup'
   group by job_id, job_name, target_name, status) jeh
where jeh.job_id=mj.job_id
order by jeh.TARGET, jeh.job_name;

-- find scheduled PROD RMAN jobs
col TARGET format a20
col SCHEDULE format a15
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
--break on target;
SPOOL PROD_OEM_Jobs_RMAN.xls;
select jeh.TARGET, jeh.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly ('||to_char(jeh.NEXT_RUN,'DY')||')'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(jeh.NEXT_RUN,'MM/DD/RR') "NEXT_DAY", to_char(jeh.NEXT_RUN,'HH24:MI') "NEXT_TIME", jeh.status
from SYSMAN.MGMT$JOBS mj,
  (select job_id, job_name, target_name "TARGET", max(scheduled_time) "NEXT_RUN", status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
   where scheduled_time >= sysdate and status not in ('17','Waiting') 
   and target_name is not null and job_type='Backup' and job_name like '%HOT_FULL%'
   group by job_id, job_name, target_name, status) jeh
where jeh.job_id=mj.job_id
order by "NEXT_DAY", "NEXT_TIME", jeh.TARGET, jeh.job_name;

-- find PROD full backups and length of last run
col TARGET format a20
col SCHEDULE format a15
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL PROD_RMAN_Jobs_Time.xls;
WITH suc AS
	(select job_id, max(start_time) "LAST_START", max(end_time) "LAST_END"
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
	 where status='Succeeded' and target_name is not null and job_name like '%HOT_FULL%'
	 group by job_id),
sch AS
	(select job_id, job_name, target_name "TARGET", max(scheduled_time) "NEXT_RUN", status
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
	 where scheduled_time >= sysdate and status not in ('17','Waiting') 
	 and target_name is not null and job_type='Backup' and job_name like '%HOT_FULL%'
	 group by job_id, job_name, target_name, status)
select sch.TARGET, sch.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly ('||to_char(sch.NEXT_RUN,'DY')||')'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(sch.NEXT_RUN,'MM/DD/RR HH24:MI') "NEXT_SCHED", ROUND((suc.LAST_END-suc.LAST_START)*24,2) "LAST_HRS"
from SYSMAN.MGMT$JOBS mj, suc, sch
where mj.job_id=suc.job_id and suc.job_id=sch.job_id
order by sch.NEXT_RUN, sch.TARGET, sch.job_name;

-- same without date and DB name
WITH suc AS
	(select job_id, max(start_time) "LAST_START", max(end_time) "LAST_END"
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
	 where status='Succeeded' and target_name is not null and job_name like '%PROD%HOT_FULL%'
	 group by job_id),
sch AS
	(select job_id, job_name, target_name "TARGET", max(scheduled_time) "NEXT_RUN", status
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
	 where scheduled_time >= sysdate and status not in ('17','Waiting') 
	 and target_name is not null and job_type='Backup' and job_name like '%PROD%HOT_FULL%'
	 group by job_id, job_name, target_name, status)
select sch.job_name, to_char(sch.NEXT_RUN,'HH:MI AM') "NEXT_SCHED", ROUND((suc.LAST_END-suc.LAST_START)*24,2) "LAST_HRS"
from SYSMAN.MGMT$JOBS mj, suc, sch
where mj.job_id=suc.job_id and suc.job_id=sch.job_id
order by "NEXT_SCHED";

-- same as above on specific hosts
-- hosts: 'uxorap01.conseco.com', 'uxp33.conseco.com', 'uxorap02.conseco.com', 'uxp34.conseco.com', 'lxoccp01.conseco.com'
col TARGET format a20
col SCHEDULE format a15
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL PROD_RMAN_Jobs_Time.xls;
WITH suc AS
	(select jeh1.job_id, max(jeh1.start_time) "LAST_START", max(jeh1.end_time) "LAST_END"
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh1, SYSMAN.MGMT$TARGET mt1
	 where jeh1.TARGET_GUID=mt1.TARGET_GUID and jeh1.status='Succeeded' --and jeh1.job_name like '%HOT_FULL%'
	 and jeh1.target_name is not null and mt1.HOST_NAME in (&&what_hosts)
	 group by jeh1.job_id),
sch AS
	(select jeh2.job_id, jeh2.job_name, jeh2.target_name "TARGET", max(jeh2.scheduled_time) "NEXT_RUN", jeh2.status
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh2, SYSMAN.MGMT$TARGET mt2
	 where jeh2.TARGET_GUID=mt2.TARGET_GUID and jeh2.scheduled_time >= sysdate
	 and jeh2.target_name is not null and jeh2.job_type='Backup' --and jeh2.job_name like '%HOT_FULL%' 
	 and jeh2.status not in ('17','Waiting') and mt2.HOST_NAME in (&&what_hosts)
	 group by jeh2.job_id, jeh2.job_name, jeh2.target_name, jeh2.status)
select sch.TARGET, sch.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN 'Every '||to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN 'Every '||to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and 'Every '||mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly ('||to_char(sch.NEXT_RUN,'DY')||')'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(sch.NEXT_RUN,'MM/DD/RR HH24:MI') "NEXT_SCHED", ROUND((suc.LAST_END-suc.LAST_START)*24,2) "LAST_HRS"
from SYSMAN.MGMT$JOBS mj, suc, sch
where mj.job_id=suc.job_id and suc.job_id=sch.job_id
order by sch.NEXT_RUN, sch.TARGET, sch.job_name;
undefine what_hosts

-- find jobs that have exceed a certain time
set lines 150 pages 200
alter session set nls_date_format='MM/DD/RR HH24:MI';
select suc.job_name, suc.SCHEDULED_TIME, suc.END_TIME, ROUND((suc.end_time-suc.start_time)*24,2) "LAST_HRS"
from SYSMAN.MGMT$JOB_EXECUTION_HISTORY suc
where ROUND((suc.end_time-suc.start_time)*24,2) > 0.5 and job_name like 'BACKUP%ARCH%RUBRIK%'
order by suc.job_name, suc.SCHEDULED_TIME;


-- find scheduled jobs on select databases
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
break on target;
SPOOL PROD_OEM_Jobs_03oct13.xls;
select jeh.TARGET, jeh.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", jeh.NEXT_RUN, jeh.status
from SYSMAN.MGMT$JOBS mj,
  (select job_id, job_name, substr(target_name,1,instr(target_name,'.')-1) "TARGET", max(to_char(scheduled_time,'DY DDth @ HH:MI pm')) "NEXT_RUN", status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
   where scheduled_time between sysdate and trunc(sysdate+3) and target_name in ('ACTURIS9_agentacturis10g.prod.uk.acturis.com',
   'DQI_proddqi10g.prod.uk.acturis.com') and status!='17'
   group by job_id, job_name, substr(target_name,1,instr(target_name,'.')-1), status) jeh
where jeh.job_id=mj.job_id
order by jeh.TARGET, jeh.job_name;

-- find scheduled jobs on select hosts
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
break on target;
SPOOL PROD_OEM_Jobs_03oct13.xls;
select jeh.TARGET, jeh.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", jeh.NEXT_RUN, jeh.status
from SYSMAN.MGMT$JOBS mj,
  (select jh.job_id, jh.job_name, substr(jh.target_name,1,instr(jh.target_name,'.')-1) "TARGET", max(to_char(jh.scheduled_time,'DY DDth @ HH:MI pm')) "NEXT_RUN", jh.status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jh, SYSMAN.MGMT$TARGET mt1
   where jh.TARGET_GUID=mt1.TARGET_GUID and jh.scheduled_time between sysdate and trunc(sysdate+3) and jh.status!='17' 
   and jh.TARGET_TYPE in ('oracle_pdb','oracle_database') and mt1.HOST_NAME in (&&what_hosts)
   group by jh.job_id, jh.job_name, substr(jh.target_name,1,instr(jh.target_name,'.')-1), jh.status) jeh
where jeh.job_id=mj.job_id
order by jeh.TARGET, jeh.job_name;

select jh.job_id, jh.job_name, substr(jh.target_name,1,instr(jh.target_name,'.')-1) "TARGET", max(to_char(jh.scheduled_time,'DY DDth @ HH:MI pm')) "NEXT_RUN", jh.status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jh, SYSMAN.MGMT$TARGET mt1
   where jh.TARGET_GUID=mt1.TARGET_GUID and jh.scheduled_time between sysdate and trunc(sysdate+3) and jh.STATE_CYCLE='SCHEDULED'
   and jh.job_name='STATS_ALLDBS_UT_WEEKLY_DATABASE_GATHER'
   group by jh.job_id, jh.job_name, substr(jh.target_name,1,instr(jh.target_name,'.')-1), jh.status;

select start_time, status from SYSMAN.MGMT$JOB_EXECUTION_HISTORY where job_name='STATS_ALLDBS_UT_WEEKLY_DATABASE_GATHER' order by 2;


-- find successful jobs for given time
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
break on target;
SPOOL PROD_OEM_Jobs_03oct13.xls;
select jeh.TARGET, jeh.job_name, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", jeh.NEXT_RUN, jeh.status
from SYSMAN.MGMT$JOBS mj,
  (select jeh.job_id, jeh.job_name, substr(jeh.target_name,1,instr(jeh.target_name,'.')-1) "TARGET", 
		max(to_char(jeh.scheduled_time,'DY DDth @ HH:MI pm')) "NEXT_RUN", jeh.status
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh, SYSMAN.MGMT_JOB_CREDENTIALS jc
   where jeh.scheduled_time between sysdate and trunc(sysdate+3) 
	and jeh.status!='17' and jc.user_name='FLX'
   group by jeh.job_id, jeh.job_name, substr(jeh.target_name,1,instr(jeh.target_name,'.')-1), jeh.status) jeh
where jeh.job_id=mj.job_id
order by jeh.TARGET, jeh.job_name;

-- get projected jobs based on current scheduled & week prior
col target format a25
col job_name format a45
col schedule format a10
with rj as
	(select distinct job_id from SYSMAN.MGMT$JOB_EXECUTION_HISTORY
	 where end_time+(to_number(substr(sessiontimezone,2,2))/24) >= (to_date('&&start_time','YYYYMMDD HH24MI')-7) 
	   and start_time+(to_number(substr(sessiontimezone,2,2))/24) <= (to_date('&&end_time','YYYYMMDD HH24MI')-7)
	 and status!='17'),
nj as
	(select distinct job_id
	 from SYSMAN.MGMT$JOB_EXECUTION_HISTORY
	 where scheduled_time between to_date('&&start_time','YYYYMMDD HH24MI') and to_date('&&end_time','YYYYMMDD HH24MI'))
select distinct jeh.job_name, substr(jeh.target_name,1,instr(jeh.target_name,'.')-1) "TARGET", 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(jeh.scheduled_time,'DY DDth @ HH24:MI') "NEXT_RUN"
from SYSMAN.MGMT$JOBS mj, SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh, rj, nj
where jeh.job_id=mj.job_id and mj.job_id in (rj.job_id, nj.job_id) and jeh.status='Scheduled' and jeh.target_name is not null
order by jeh.job_name;

-- max duration of specific job
col target format a25
col job_name format a45
col schedule format a10
select job_name, ceil(max((end_time-start_time)*24*60)) "DUR (m)"
from SYSMAN.MGMT$JOB_EXECUTION_HISTORY 
where job_name='&what_job' and end_time<sysdate
group by job_name
order by job_name;

-- find all RMAN jobs
col target_name format a25
col job_name format a45
col schedule format a10
select distinct jeh.job_name, jeh.TARGET_NAME, 
  CASE WHEN mj.schedule_type='Interval' and mj.interval<60 THEN 'Every '||to_char(mj.interval)||' min'
       WHEN mj.schedule_type='Interval' THEN 'Every '||to_char(mj.interval/60)||' hrs'
       WHEN mj.schedule_type='Daily' and mj.interval=1 THEN 'Daily'
       WHEN mj.schedule_type='Daily' and mj.interval!=1 THEN mj.interval||' days'
       WHEN mj.schedule_type='Weekly' THEN 'Weekly'
       WHEN mj.schedule_type='Monthy' THEN 'Monthly'
       ELSE 'Unknown'
  END "SCHEDULE", to_char(jeh.scheduled_time,'DY DDth @ HH24:MI') "NEXT_RUN"
from SYSMAN.MGMT$JOBS mj, SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh
where jeh.job_id=mj.job_id and jeh.status='Scheduled' and jeh.target_name is not null and --mj.job_type='RMANScript'
mj.job_type='Backup'
order by jeh.job_name;

-- report of RMAN backup job status over past week
set lines 150 pages 200
col target_name format a40
select target_name, "JOB_NAME",
  sum(decode( "JOB_STATUS", 'Succeeded', 1, 0)) "Succeeded",
  sum(decode( "JOB_STATUS", 'Failed', 1, 0)) "Failed",
  sum(decode( "JOB_STATUS", 'Skipped', 1, 0)) "Skipped",
  sum(decode( "JOB_STATUS", 'n/a', 1, 0)) "No OEM Job"
from (
  select tgt.target_name, nvl(job_hist.job_name, 'n/a') "JOB_NAME", nvl(job_hist.status, 'n/a') "JOB_STATUS"
  from (
    select target_name, job_name, status
    from SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh
    where jeh.target_type like '%database%'
    and jeh.job_type='Backup' and jeh.job_name like '%FULL%'
    and jeh.start_time >= (sysdate-7)
    and jeh.status not in ('Scheduled','Waiting')
  ) job_hist
  full outer join (
    select TARGET_NAME
    from SYSMAN.MGMT$TARGET
    where TARGET_TYPE='oracle_database'
  ) tgt
  on tgt.target_name=job_hist.target_name
)
group by target_name, "JOB_NAME"
having sum(decode( "JOB_STATUS", 'Succeeded', 1, 0))<4
order by 1,2;


-- find jobs scheduled against OEM groups
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET PAGES 0
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL /tmp/OEM_group_jobs.xls
select jt.TARGET_NAME, jt.JOB_NAME
from sysman.MGMT$JOB_TARGETS jt
where jt.TARGET_TYPE='composite' and jt.JOB_TYPE='SQLScript'
order by 1;
spool off

-- find job scheduled with specific named credentials
select JOB_NAME, CRED_NAME, TIER, count(TARGET_NAME) "TGT_CT"
from (
	select j.JOB_NAME, nc.CRED_NAME, jeh.TARGET_NAME,
		case upper(substr(tgt.HOST_NAME,9,1))
			when 'P' then 'PROD'
			when 'Q' then 'UAT'
			when 'M' then 'UAT'
			when 'T' then 'SIT'
			when 'D' then 'UT'
			else '?'
		end TIER
	from SYSMAN.MGMT$JOBS j, 
		SYSMAN.EM_JOB_CREDENTIALS jc, 
		sysman.EM_NC_CREDS nc, 
		SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh,
		SYSMAN.MGMT$TARGET tgt
	where j.JOB_ID=jc.JOB_ID and jc.CREDENTIAL_REF=nc.CRED_GUID and j.JOB_ID=jeh.JOB_ID and jeh.TARGET_GUID=tgt.TARGET_GUID
	and nc.CRED_NAME in ('NC_DB_SYS','NC_DB_SYSTEM')
	and jeh.STATUS in ('Running','Scheduled')
) 
group by JOB_NAME, CRED_NAME, TIER;



-- ###########
-- # TARGETS #
-- ###########

-- list all DB targets
set lines 150 pages 200
col TARGET_NAME format a100
select TARGET_NAME, HOST_NAME
from SYSMAN.MGMT$TARGET
where TARGET_TYPE in ('oracle_pdb','oracle_database')
order by 1;

-- DB targets plus other details
col TARGET_NAME format a30
col HOST_NAME format a20
col TARGET_TYPE format a20
col ROOT format a5
col Department format a20
col Lifecycle format a20
col Version format a20

SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET PAGES 0
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL /tmp/OEM_DB_targets.xls

SELECT upper(TARGET_NAME), upper(HOST_NAME), TIER, TARGET_TYPE,
  max(decode( PROPERTY_NAME, 'IS_ROOT', PROPERTY_VALUE, null )) "ROOT",
  max(decode( PROPERTY_NAME, 'orcl_gtp_department', PROPERTY_VALUE, null )) "Department",
  max(decode( PROPERTY_NAME, 'orcl_gtp_lifecycle_status', PROPERTY_VALUE, null )) "Lifecycle",
  max(decode( PROPERTY_NAME, 'orcl_gtp_target_version', PROPERTY_VALUE, null )) "Version"
FROM (
  select tgt.TARGET_NAME, 
  	substr(tgt.HOST_NAME,1,instr(tgt.HOST_NAME,'.')-1) "HOST_NAME",
  	case upper(substr(tgt.HOST_NAME,9,1))
  		when 'P' then 'PROD'
  		when 'Q' then 'FTSE'
  		when 'M' then 'UAT'
  		when 'T' then 'SIT'
  		when 'D' then 'UT'
  		else '?'
  	end TIER,
  	case tgt.TARGET_TYPE
		when 'oracle_database' then 'instance'
		when 'oracle_pdb' then 'PDB'
		else '?'
	end "TARGET_TYPE",
	prp.PROPERTY_NAME, prp.PROPERTY_VALUE
  from SYSMAN.MGMT$TARGET tgt, sysman.MGMT$TARGET_PROPERTIES prp
  where tgt.TARGET_GUID=prp.TARGET_GUID
  and tgt.TARGET_TYPE in ('oracle_pdb','oracle_database')
  and prp.PROPERTY_NAME in ('orcl_gtp_department','orcl_gtp_lifecycle_status','orcl_gtp_target_version','IS_ROOT'))
GROUP BY TARGET_NAME, HOST_NAME, TIER, TARGET_TYPE
ORDER BY 1;
spool off

-- validate departments
select TARGET_NAME, substr(HOST_NAME,1,instr(HOST_NAME,'.')-1) "HOST_NAME", PROPERTY_VALUE
from (
  select tgt.TARGET_NAME, tgt.HOST_NAME, upper(substr(tgt.HOST_NAME,6,3)) "HOST_DEPT", prp.PROPERTY_VALUE,
    case 
      when (upper(substr(tgt.HOST_NAME,6,3)) = prp.PROPERTY_VALUE) then ''
  	else 'NO'
    end "MATCH"
  from SYSMAN.MGMT$TARGET tgt, sysman.MGMT$TARGET_PROPERTIES prp
  where tgt.TARGET_GUID=prp.TARGET_GUID
    and tgt.TARGET_TYPE in ('oracle_pdb','oracle_database')
    and prp.PROPERTY_NAME='orcl_gtp_department'
)
where MATCH='NO'
order by 1;
TARGET_NAME                    HOST_NAME            PROPERTY_VALUE
------------------------------ -------------------- --------------------
CAEDBT_AEDBT                   lxorainft01          FIN
CIDEVT                         LXORACPNT01
CIDWT                          lxoradwst01

-- validate lifecycle status
select TARGET_NAME, PROPERTY_VALUE
from (
  select tgt.TARGET_NAME, 
  	tgt.HOST_NAME,
    	case upper(substr(tgt.HOST_NAME,9,1))
    		when 'P' then 'Production'
    		when 'Q' then 'Stage'
    		when 'M' then 'Stage'
    		when 'T' then 'Test'
    		when 'D' then 'Development'
    		else '?'
    	end TIER,
  	prp.PROPERTY_VALUE
  from SYSMAN.MGMT$TARGET tgt, sysman.MGMT$TARGET_PROPERTIES prp
  where tgt.TARGET_GUID=prp.TARGET_GUID
    --and upper(tgt.TARGET_NAME) like '%BPA%'
    and tgt.TARGET_TYPE in ('oracle_pdb','oracle_database')
    and prp.PROPERTY_NAME='orcl_gtp_lifecycle_status'
)
where TIER != PROPERTY_VALUE
order by 1;
no rows selected



SYSMAN.EM_JOB_CREDENTIALS
-- SYSMAN.MGMT_CREDENTIALS
--SYSMAN.MGMT_ENTERPRISE_CREDENTIALS
--SYSMAN.MGMT_HOST_CREDENTIALS
--SYSMAN.MGMT_TARGET_CREDENTIALS
--SYSMAN.MGMT_VIEW_USER_CREDENTIALS
--select * from SYSMAN.MGMT_CREDENTIALS2 where rownum=1;
select * from SYSMAN.MGMT_CREDENTIAL_SETS where rownum=1;
select * from SYSMAN.MGMT_CREDENTIAL_TYPES where rownum=1;
select * from SYSMAN.MGMT_CREDENTIAL_TYPE_REF where rownum=1;
--select * from SYSMAN.MGMT_JOB_CRED_PARAMS where rownum=1;
select * from SYSMAN.MGMT_JOB_EXEC_CRED_INFO where rownum=1;


-- ##########################
-- # CORRECTIVE ACTION JOBS #
-- ##########################

-- corrective action views
SYSMAN.MGMT$CA_TARGETS
SYSMAN.MGMT$CA_EXECUTIONS

-- list of CA jobs
col ca_name format a40
col ca_description format a50
col target_name format a15
select ca_name, ca_description, target_name, ca_id
from SYSMAN.MGMT$CA_TARGETS
order by 1,3;

-- CA executions
col ca_name format a40
col target_name format a15
alter session set nls_date_format='DD-MON-YY HH24:MI';
select ca_name, target_name, start_time, status -- , triggering_severity, ca_id, execution_id
from SYSMAN.MGMT$CA_EXECUTIONS
order by ca_name, target_name, start_time;


-- ####################
-- # TIMEZONE QUERIES #
-- ####################

-- find timezone of a job
alter session set nls_date_format='DD-MON-YY HH24:MI';
col job_name format a40
col timezone format a40
select jeh.job_name, 
  NVL2(jeh.scheduled_time, jeh.scheduled_time, jeh.start_time) "RUNTIME", 
  mj.TIMEZONE_REGION||' '||mj.TIMEZONE_TYPE "TIMEZONE"
  --NVL2(mj.TIMEZONE_REGION, mj.TIMEZONE_REGION, mj.TIMEZONE_TYPE) "TIMEZONE"
from SYSMAN.MGMT$JOBS mj, SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh
where jeh.job_id=mj.job_id and jeh.job_name='&what_job'
  and jeh.scheduled_time >= (sysdate-7)
order by 1,2;

-- find timezone for job runs in a given period
break on job_name
select jeh.job_name, 
  NVL2(jeh.scheduled_time, jeh.scheduled_time, jeh.start_time) "RUNTIME", 
  mj.TIMEZONE_REGION||' '||mj.TIMEZONE_TYPE "TIMEZONE"
  --NVL2(mj.TIMEZONE_REGION, mj.TIMEZONE_REGION, mj.TIMEZONE_TYPE) "TIMEZONE"
from SYSMAN.MGMT$JOBS mj, SYSMAN.MGMT$JOB_EXECUTION_HISTORY jeh
where jeh.job_id=mj.job_id
  and jeh.scheduled_time between to_date('20131026 0000','YYYYMMDD HH24MI') and to_date('20131028 0000','YYYYMMDD HH24MI')
  and jeh.job_name in (
	'ACTURIS CHECK DBA JOBS.1',
	'DGDB3 LOG APPLY OFF AND FLUSH.1',
	'DQI LOGFILE SWITCH',
	'RMAN ACTURIS9 BACKUP ARCHIVELOGS.1',
	'RMAN ADMN BACKUP ARCHIVELOGS.2',
	'RMAN DBGRID10 BACKUP ARCHIVELOGS.1',
	'RMAN DQI BACKUP ARCHIVELOGS_UPDATED',
	'RMAN DW3 BACKUP ARCHIVELOGS.1',
	'RMAN DW3 DELETE ONLINE ARCHLOGS1',
	'RMAN FLEXI9 BACKUP ARCHIVELOGS.2',
	'RMAN LOGDB BACKUP ARCHIVELOGS',
	'RMAN LOGDB DELETE DB BACKUP AND ARCHLOG',
	'RMAN LOGDB DELETE ONLINE ARCHLOGS',
	'RMAN LOGDB LEVEL 0',
	'RMAN LOGDB LEVEL 1',
	'RMAN WM9 BACKUP ARCHIVELOGS')
order by 1,2;


-- ##############
-- # JOB OUTPUT #
-- ##############

-- pulling output from a job that runs on multiple DBs
set long 100000
alter session set nls_date_format='DD-MON-YY HH24:MI:SS';
col TARGET_NAME format a12
set pages 0
--col "SUBSTRING" format a100
SET ECHO OFF;
SET ESCAPE OFF;
SET TRIMSPOOL ON;
SET MARKUP HTML ON ENTMAP ON SPOOL ON PREFORMAT OFF;
SPOOL /tmp/PARAM_CHECK_ALLDBS_UAT_IO_PARAMS.3.html
select TARGET_NAME, START_TIME, output
--SUBSTR(output, INSTR(output, 'SQL>', 1)) "SUBSTRING"
from SYSMAN.MGMT$JOB_STEP_HISTORY 
where job_name='&what_job' and start_time >= to_date('&start_time','YYYYMMDDHH24MI')
--and target_name in ('blctdmd','cdsinfod')
order by target_name, start_time;

--only one output result
set long 100000
select START_TIME, target_name, SUBSTR(output, INSTR(output, 'SQL>', -1)-5, 4) "SUBSTRING"
--select START_TIME ||','|| target_name ||','|| output 
--select START_TIME, target_name, INSTR(output, '----------', -1)
--select START_TIME, target_name, SUBSTR(output, 229, 3)
--select START_TIME, target_name, SUBSTR(output, INSTR(output, '----------', -1) + &addchar, 10)
--select START_TIME, target_name, INSTR(output, 'SQL>', -1) "INSTR", SUBSTR(output, INSTR(output, 'SQL>', -1)-5, 4)
from SYSMAN.MGMT$JOB_STEP_HISTORY 
where job_name='&what_job' and target_name='oscrd' --rownum=1
--and start_time BETWEEN to_date('07/24/2016 18:00','MM/DD/YYYY HH24:MI') AND to_date('07/24/2016 20:00','MM/DD/YYYY HH24:MI') 
--and target_name in ('blctdmd','cdsinfod')
order by target_name, start_time;

--
select START_TIME ||','|| target_name ||','|| SUBSTR(output, INSTR(output, 'SQL>', -1)-5, 4)
from SYSMAN.MGMT$JOB_STEP_HISTORY 
where job_name='SGA_ALLDBS_UT_METRIC_EXTENSION_TEST4'
order by target_name, start_time;

-- job parameters (does not show commands)
set lines 150 pages 200
set long 100000
alter session set nls_date_format='DD-MON-YY HH24:MI:SS';
col TARGET_NAME format a12
col "OUTPUT" format a80
col "SCALAR_VALUE" format a80
select jsh.TARGET_NAME, jsh.START_TIME, jsh.STEP_NAME, mjp.SCALAR_VALUE
from SYSMAN.MGMT$JOB_STEP_HISTORY jsh, SYSMAN.MGMT_JOB_PARAMETER mjp
where jsh.JOB_ID=mjp.JOB_ID and jsh.EXECUTION_ID=mjp.EXECUTION_ID
and jsh.job_name='&what_job' and jsh.start_time >= (sysdate - 3/24) and jsh.STEP_NAME='BackupOp'
order by jsh.target_name, jsh.start_time;

BACKUP_CSSWTDMD_UT_ARCHIVELOG_RUBRIK
BACKUP_CBLCNAVG_UT_ARCHIVELOG_RUBRIK

JOB_ID
EXECUTION_ID
STEP_ID
STEP_JOB_ID

select JOB_ID, EXECUTION_ID
from SYSMAN.MGMT$JOB_STEP_HISTORY jsh
where jsh.job_name='&what_job' and jsh.start_time >= (sysdate - 3/24) and jsh.STEP_NAME='BackupOp';
JOB_ID                           EXECUTION_ID
-------------------------------- --------------------------------
6A9B6E151D406355E053B7C1A8C02250 6ABE7448955A766DE053B7C1A8C03C27
6A9B6E151D406355E053B7C1A8C02250 6ABBEFA7B2660AEAE053B7C1A8C0A0CF

select * from SYSMAN.MGMT_JOB_PARAMETER mjp
where mjp.JOB_ID='6A9B6E151D406355E053B7C1A8C02250' and mjp.EXECUTION_ID='6ABE7448955A766DE053B7C1A8C03C27';


select table_name from dba_tables where table_name like 'MGMT$JOB%' order by 1;
select view_name from dba_views where view_name like 'MGMT$JOB%' order by 1;
MGMT$JOBS
MGMT$JOB_ANNOTATIONS
MGMT$JOB_EXECUTION_HISTORY
MGMT$JOB_NOTIFICATION_LOG
MGMT$JOB_RPT_CMD_TIME_BY_WK
MGMT$JOB_RPT_EXEC_STEPS_ACTIVE
MGMT$JOB_RPT_EXEC_TIME_BY_WK
MGMT$JOB_RPT_LOG_MESSAGES
MGMT$JOB_RPT_QUEUE_JOBS
MGMT$JOB_RPT_SYS_JOB
MGMT$JOB_STEP_HISTORY
MGMT$JOB_TARGETS

select view_name from dba_views where view_name like '%STEP%' and owner='SYSMAN' order by 1;
select view_name from dba_views where view_name like '%COMMAND%' and owner='SYSMAN' order by 1;

select table_name, column_name from dba_tab_cols where owner='SYSMAN' and column_name like '%PARAM%' order by 1,2;
SYSMAN.MGMT_JOB_STEP_PARAMS
SYSMAN.MGMT_JOB_PARAMETER
SYSMAN.MGMT_JOB_VALUE_PARAMS

-- ############################
-- # MOVING JOBS BETWEEN OEMS #
-- ############################


emcli describe_job -name="KILL LONG QUERY - DW3UAT - TEMP RUN.3" > D:\DBA\Kevin\KILLLONGQUERY-DW3UAT-TEMPRUN.3.out

set lines 250
set pages 0
set trimspool on
spool em_desc_all_jobs2.txt
select 'emcli describe_job -name="'||job_name||'" > D:\DBA\Kevin\'||replace(job_name,' ','_')||'.out'
from
  (select distinct job_name
   from SYSMAN.MGMT$JOB_EXECUTION_HISTORY
   where status='Succeeded' and job_type in ('OSCommand','SQLScript','RMANScript')
);
spool off





