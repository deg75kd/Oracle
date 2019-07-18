-- #######
-- # SGA #
-- #######

-- see how the sga memory is allocated
col bytes format 999,999,999,990
col name format a40
select * from v$sgainfo;

-- see SGA usage
alter session set nls_date_format='DD-MON hh24:mi:ss';
set lines 150 pages 200
col component format a25
col "MIN MB" format 999,999
col "CUR MB" format 999,999
col "MAX MB" format 999,999
col "SGA" format a6
break on report;
break on "SGA";
compute sum label "TOTAL" of "CUR MB" "MIN MB" "MAX MB" on "SGA";
select 'SGA' "SGA", component, (current_size/1024/1024) "CUR MB", (min_size/1024/1024) "MIN MB", (max_size/1024/1024) "MAX MB", last_oper_type, last_oper_time Changed
from v$memory_dynamic_components 
where component not in ('PGA Target','SGA Target') and max_size > 0
order by "SGA", component;


-- see info on last 800 completed SGA resize ops
-- doesn't include in-progress changes
alter session set nls_date_format='DD-MON hh24:mi:ss';
set lines 120 pages 200
column component format a25 
column "Final MB" format 99,999,999 
column "Init MB" format 99,999,999 
column Completed format A25 
SELECT COMPONENT ,OPER_TYPE, (initial_size/1024/1024) "Init MB", (FINAL_SIZE/1024/1024) "Final MB"
, status, to_char(end_time,'dd-MON hh24:mi:ss') Completed
FROM V$SGA_RESIZE_OPS order by end_time asc;

-- from Oracle
col component for a25 head "Component" 
col status format a10 head "Status" 
col parameter for a25 heading "Parameter" 
col "Initial" format 999,999,999,999
col "Final" format 999,999,999,999
col changed head "Changed At" 
select component, parameter, (initial_size/1024/1024) "Initial", (final_size/1024/1024) "Final", 
   status, to_char(end_time ,'mm/dd/yyyy hh24:mi:ss') changed 
from v$memory_resize_ops 
where end_time>=to_date('&what_time','YYYYMMDDHH24MI') order by 6;

-- when ASMM active, __shared_pool_size, __large_pool_size, etc. added to spfile
alter session set nls_date_format='DD-MON hh24:mi:ss';
set lines 120 pages 200
col component format a25
col "USER MB" format 999,999
col "CUR MB" format 999,999
break on report;
break on "SGA";
compute sum label "TOTAL" of "CUR MB" "MIN MB" "MAX MB" on "SGA";
select component, (current_size/1024/1024) "CUR MB", (user_specified_size/1024/1024) "USER MB",
  last_oper_type, last_oper_time Changed
from V$SGA_DYNAMIC_COMPONENTS order by component;

-- buffer cache hit ratio
SELECT name, physical_reads, db_block_gets, consistent_gets,
	1 - (physical_reads / (db_block_gets + consistent_gets)) "Hit Ratio"
FROM V$BUFFER_POOL_STATISTICS;
-- OR --
select (1 - (pr / (cg + bg))) "BUFFER CACHE HIT RATIO"
from
	(select
		max( decode( name, 'db block gets from cache', value, null ) ) bg,
		max( decode( name, 'consistent gets from cache', value, null ) ) cg,
		max( decode( name, 'physical reads cache', value, null ) ) pr
	from
		(SELECT name, value
		FROM V$SYSSTAT
		WHERE name IN ('db block gets from cache', 'consistent gets from cache', 'physical reads cache')
		)
	);

-- SHARED_POOL_RESERVED_MIN_ALLOC
SELECT nam.ksppinm NAME,
       val.ksppstvl VALUE 
FROM x$ksppi nam,
     x$ksppsv val
WHERE nam.indx = val.indx
AND nam.ksppinm LIKE '%shared%'
ORDER BY 1;

-- which process is requesting too much memory (need more info)
col name format a30
select sid,name,value
from v$statname n,v$sesstat s
where n.STATISTIC# = s.STATISTIC# and
name like 'session%memory%'
order by 3 asc;

-- SGA advisor over specific period
set lines 150 pages 200
break on "TIME" skip 1
select to_char(ash.BEGIN_INTERVAL_TIME,'MM/DD HH24:MI') "TIME", sta.SGA_SIZE, sta.SGA_SIZE_FACTOR, TRUNC(sta.ESTD_DB_TIME/1000) "DB_TIME"
from dba_hist_sga_target_advice sta, DBA_HIST_ASH_SNAPSHOT ash
where sta.SNAP_ID=ash.SNAP_ID --and sta.SGA_SIZE_FACTOR>=1
and ash.BEGIN_INTERVAL_TIME between to_date('&when_start','MM/DD HH24MI') and to_date('&when_end','MM/DD HH24MI')
order by 1,2;

-- only see with more memory
set lines 150 pages 200
break on "TIME" skip 1
select to_char(ash.BEGIN_INTERVAL_TIME,'MM/DD HH24:MI') "TIME", sta.SGA_SIZE, sta.SGA_SIZE_FACTOR, TRUNC(sta.ESTD_DB_TIME/1000) "DB_TIME"
from dba_hist_sga_target_advice sta, DBA_HIST_ASH_SNAPSHOT ash
where sta.SNAP_ID=ash.SNAP_ID and sta.SGA_SIZE_FACTOR>=1
and ash.BEGIN_INTERVAL_TIME between to_date('&when_start','MM/DD HH24MI') and to_date('&when_end','MM/DD HH24MI')
order by 1,2;


-- check spfile settings
col name format a30
col display_value format a15
select name, display_value from v$spparameter
where name in ('sga_max_size','sga_target','streams_pool_size','db_cache_size','java_pool_size','large_pool_size','shared_pool_size','memory_max_target','memory_target')
and display_value is not null
order by 1;


-- #######
-- # PGA #
-- #######

-- see all PGA stats
select * from v$pgastat;

-- see max pga allocated
select round(value/1024/1024,0)||' MB' "MAX PGA" from v$pgastat where name='maximum PGA allocated';

-- see how the pga memory is allocated
select sum(value)/1024/1024 Mb 
from v$sesstat s, v$statname n
where n.STATISTIC# = s.STATISTIC# and
name = 'session pga memory';

-- see PGA usage
col "USED MB" format 99,999
col "MAX MB" format 99,999
select pid, serial#, category, (used/1024/1024) "USED MB", (max_allocated/1024/1024) "MAX MB"
from v$process_memory;

-- see processes using more than 1MB of PGA
col "USED MB" format 99,999
col "MAX MB" format 99,999
col "ALLOCATED" format 99,999
col "FREEABLE" format 99,999
col program format a20
col machine format a20
select s.sid, s.serial#, s.program, s.machine, pm.category, (pm.allocated/1024/1024) "ALLOCATED", 
	(p.pga_freeable_mem/1024/1024) "FREEABLE", (pm.used/1024/1024) "USED MB", (pm.max_allocated/1024/1024) "MAX MB"
from v$process_memory pm, v$process p, v$session s
where pm.pid=p.pid and p.addr=s.paddr and pm.used >= 1048576 
order by pm.allocated desc;

-- see PGA usage by username
col "USED MB" format 99,999
col "MAX MB" format 99,999
col "ALLOCATED" format 99,999
col program format a20
col machine format a20
select pm.pid, pm.serial#, pm.category, (pm.allocated/1024/1024) "ALLOCATED", (pm.used/1024/1024) "USED MB", (pm.max_allocated/1024/1024) "MAX MB",
	s.program, s.machine
from v$process_memory pm, v$process p, v$session s
where pm.pid=p.pid and p.addr=s.paddr and s.username='&what_user'
order by 1,2;

-- which process is requesting too much memory (need more info)
set lines 150 pages 1000
col name format a30
col program format a30
col machine format a15
col username format a15
col "MB" format 99,999.90
select se.sid, se.serial#, n.name, (st.value/1024/1024) "MB", 
  se.program, se.machine, se.username
from v$statname n,v$sesstat st, v$session se
where n.STATISTIC# = st.STATISTIC# and n.name like 'session pga memory%'
order by value asc;

-- most recent changes in PGA
col component for a25 head "Component" 
col status format a10 head "Status" 
col parameter for a25 heading "Parameter" 
col "Initial" format 999,999,999,999
col "Final" format 999,999,999,999
col changed head "Changed At" 
select component, parameter, (initial_size/1024/1024) "Initial", (final_size/1024/1024) "Final", 
   status, to_char(end_time ,'mm/dd/yyyy hh24:mi:ss') changed 
from v$memory_resize_ops where component='PGA Target' order by 6;

-- #######
-- # ALL #
-- #######

-- see SGA/PGA usage
set lines 120 pages 200
col component format a25
col "MIN MB" format 999,999
col "CUR MB" format 999,999
col "MAX MB" format 999,999
break on report;
compute sum label "TOTAL" of "CUR MB" "MIN MB" "MAX MB" on report;
select component, (current_size/1024/1024) "CUR MB", (min_size/1024/1024) "MIN MB", (max_size/1024/1024) "MAX MB", last_oper_type
from v$memory_dynamic_components where component in ('PGA Target','SGA Target')
order by 1,2;

-- get memory size not including process stack & code size
select round(sum(bytes)/1024/1024,0) MB from
      (select bytes from v$sgastat
        union
        select value bytes from
             v$sesstat s,
             v$statname n
        where
             n.STATISTIC# = s.STATISTIC# and
             n.name = 'session pga memory'
       );

-- all initialization parameter settings
col name format a30
col "P-VAL" format a12
col "SP-VAL" format a12
select p.name, p.display_value "P-VAL", sp.display_value "SP-VAL"
from v$parameter p left outer join v$spparameter sp on p.name=sp.name
where (p.name like 'db_%cache_size' or p.name in
('memory_max_target','memory_target','sga_max_size','sga_target','shared_pool_size','streams_pool_size','large_pool_size','java_pool_size','pga_aggregate_target')
	) and p.display_value!='0'
order by p.name;

-- AMM/SGA/PGA only
select
	CASE
		WHEN AMM_MAX >= AMM THEN AMM_MAX
		ELSE AMM
	END "AMM",
	CASE
		WHEN SGA_MAX >= SGA THEN SGA_MAX
		ELSE SGA
	END "SGA",
	PGA
from (
	select
		max( decode( name, 'memory_max_target', used, null ) ) "AMM_MAX",
		max( decode( name, 'memory_target', used, null ) ) "AMM",
		max( decode( name, 'pga_aggregate_target', used, null ) ) "PGA",
		max( decode( name, 'sga_max_size', used, null ) ) "SGA_MAX",
		max( decode( name, 'sga_target', used, null ) ) "SGA"
	from (
		select p.name, 
			CASE 
				WHEN p.value >= NVL2(sp.value,sp.value,0) THEN p.value/1024/1024
				ELSE sp.value/1024/1024
			END "USED"
		from v$parameter p left outer join v$spparameter sp on p.name=sp.name
		where p.name in
		('memory_max_target','memory_target','sga_max_size','sga_target','pga_aggregate_target')
	)
);

-- total memory allocated (SGA+PGA)
SELECT NVL2(TOTALMEM, TOTALMEM, (SGAMAX + PGA_AGG))/1024/1024 "TOTAL MB"
FROM
	(SELECT
		max( decode( name, 'memory_max_target', value, null ) ) "TOTALMEM",
		max( decode( name, 'sga_max_size', value, null ) ) "SGAMAX",
		max( decode( name, 'pga_aggregate_target', value, null ) ) "PGA_AGG"
	FROM
		(select name, value
		from v$spparameter
		where name in ('memory_max_target','sga_max_size','pga_aggregate_target')));
		
-- SGA/PGA numbers taking AMM into account
select CASE
		WHEN (SGA+PGA)>AMM THEN AMM-PGA
		ELSE SGA
	END "SGA",
	PGA
from (
	select CASE
			WHEN AMM_MAX >= AMM THEN AMM_MAX
			ELSE AMM
		END "AMM",
		CASE
			WHEN SGA_MAX >= SGA THEN SGA_MAX
			ELSE SGA
		END "SGA",
		PGA
	from (
		select
			max( decode( name, 'memory_max_target', used, null ) ) "AMM_MAX",
			max( decode( name, 'memory_target', used, null ) ) "AMM",
			max( decode( name, 'pga_aggregate_target', used, null ) ) "PGA",
			max( decode( name, 'sga_max_size', used, null ) ) "SGA_MAX",
			max( decode( name, 'sga_target', used, null ) ) "SGA"
		from (
			select p.name, 
				CASE 
					WHEN p.value >= NVL2(sp.value,sp.value,0) THEN p.value/1024/1024
					ELSE sp.value/1024/1024
				END "USED"
			from v$parameter p left outer join v$spparameter sp on p.name=sp.name
			where p.name in
			('memory_max_target','memory_target','sga_max_size','sga_target','pga_aggregate_target')
		)
	)
);

select lower(db.name),
	CASE
		WHEN mem.AMM=0 THEN mem.SGA
		WHEN (mem.SGA+mem.PGA)>mem.AMM THEN mem.AMM-mem.PGA
		ELSE mem.SGA
	END "SGA",
	mem.PGA
from (
	select
		MAX( CASE name WHEN 'sga_max_size' THEN used WHEN 'sga_target' THEN used ELSE null END ) "SGA",
		MAX( CASE name WHEN 'memory_max_target' THEN used WHEN 'memory_target' THEN used ELSE null END ) "AMM",
		MAX( DECODE( name, 'pga_aggregate_target', used, null ) ) "PGA"
			from (
				select p.name, 
					CASE 
						WHEN p.value >= NVL2(sp.value,sp.value,0) THEN p.value/1024/1024
						ELSE sp.value/1024/1024
					END "USED"
				from v$parameter p left outer join v$spparameter sp on p.name=sp.name
				where p.name in
				('memory_max_target','memory_target','sga_max_size','sga_target','pga_aggregate_target')
			)
) mem, v$database db;


-- ##################
-- # MEMORY ADVISOR #
-- ##################

-- see effects of different settings for memory_target parameter
select * from v$memory_target_advice order by memory_size;

-- in MB
select * from v$sga_target_advice order by sga_size;

-- most recent SGA advisor numbers
SELECT SGA_SIZE "SGA_MB", SGA_SIZE_FACTOR, ESTD_DB_TIME, ESTD_PHYSICAL_READS
from v$sga_target_advice 
order by 1 asc;

SELECT SGA_SIZE "SGA_MB", SGA_SIZE_FACTOR, ESTD_DB_TIME, ESTD_PHYSICAL_READS
from dba_hist_sga_target_advice 
where SNAP_ID = (select max(SNAP_ID) from dba_hist_sga_target_advice)
order by 1 asc;



-- most recent PGA advisor numbers
SELECT PGA_TARGET_FOR_ESTIMATE/1024/1024 "PGA_TARGET_MB", PGA_TARGET_FACTOR, ESTD_PGA_CACHE_HIT_PERCENTAGE, ESTD_OVERALLOC_COUNT
from v$pga_target_advice
order by 1 asc;

SELECT PGA_TARGET_FOR_ESTIMATE/1024/1024 "PGA_TARGET_MB", PGA_TARGET_FACTOR, ESTD_PGA_CACHE_HIT_PERCENTAGE
from dba_hist_pga_target_advice 
where SNAP_ID = (select max(SNAP_ID) from dba_hist_pga_target_advice)
order by 1 asc;

-- PGA advisor over specific period
break on "TIME" skip 1
select to_char(ash.BEGIN_INTERVAL_TIME,'MM/DD HH24:MI') "TIME", ROUND(pta.PGA_TARGET_FOR_ESTIMATE/1024/1024) "PGA_TARGET_MB", pta.PGA_TARGET_FACTOR, pta.ESTD_PGA_CACHE_HIT_PERCENTAGE
from dba_hist_pga_target_advice pta, DBA_HIST_ASH_SNAPSHOT ash
where pta.SNAP_ID=ash.SNAP_ID and pta.PGA_TARGET_FACTOR>=1
and ash.BEGIN_INTERVAL_TIME between to_date('&what_start','MM/DD HH24MI') and to_date('&what_end','MM/DD HH24MI')
order by 1,2;




-- buffer cache advice
-- from Oracle docs
-- db_cache_advice parameter must be ON
COLUMN size_for_estimate          FORMAT 999,999,999,999 heading 'Cache Size (MB)'
COLUMN buffers_for_estimate       FORMAT 999,999,999 heading 'Buffers'
COLUMN estd_physical_read_factor  FORMAT 999.90 heading 'Estd Phys|Read Factor'
COLUMN estd_physical_reads        FORMAT 999,999,999 heading 'Estd Phys| Reads'
SELECT size_for_estimate, buffers_for_estimate, estd_physical_read_factor,
       estd_physical_reads
  FROM V$DB_CACHE_ADVICE
 WHERE name = 'DEFAULT'
   AND block_size = (SELECT value FROM V$PARAMETER WHERE name = 'db_block_size')
   AND advice_status = 'ON';

-- check individual buffer pools
SELECT size_for_estimate, buffers_for_estimate, estd_physical_read_factor, 
       estd_physical_reads
  FROM V$DB_CACHE_ADVICE
 WHERE name = 'KEEP'
   AND block_size = (SELECT value FROM V$PARAMETER WHERE name = 'db_block_size')
   AND advice_status = 'ON';

-- ESTD_OVERALLOC_COUNT should be zero
select (pga_target_for_estimate/1024/1024) "PGA_TARGET_MB", pga_target_factor "FACTOR",
	advice_status, ESTD_PGA_CACHE_HIT_PERCENTAGE, ESTD_OVERALLOC_COUNT
from v$pga_target_advice 
where pga_target_factor<=1
order by pga_target_for_estimate;

-- max SGA utilized
select max(sga_size)
from dba_hist_sga_target_advice
 where sga_size_factor = 1;
 
select max(estd_db_time)
from dba_hist_sga_target_advice
 where sga_size = &what_sga_size;

select max(estd_db_time)
from dba_hist_sga_target_advice
 where sga_size = &what_sga_size;

-- how far back data goes
select to_char(begin_interval_time,'DD-MON-YY') "ADV_DATE"
from DBA_HIST_SNAPSHOT
where snap_id = (select min(snap_id) from dba_hist_sga_target_advice);

-- min SGA with limited impact (perhaps x% decrease in DB time)


col sga_size_factor format 9.99
select to_char(hs.begin_interval_time,'DD-MON-YY') "ADV_DATE", sga_size, sga_size_factor, estd_db_time
from dba_hist_sga_target_advice st, DBA_HIST_SNAPSHOT hs
where st.snap_id=hs.snap_id and st.snap_id = 
	(select snap_id, max(sga_size)
	 from dba_hist_sga_target_advice
	 where sga_size_factor = 1
	 group by snap_id)
order by 1,2;

-- get advice details for a specific time period
col sga_size_factor format 9.99
col estd_db_time format 999,999,990
col ESTD_PHYSICAL_READS format 999,999,990
select to_char(hs.begin_interval_time,'DD-MON-YY HH24:MI') "ADV_TIME", st.sga_size, st.sga_size_factor, st.estd_db_time, st.ESTD_PHYSICAL_READS
from dba_hist_sga_target_advice st, DBA_HIST_SNAPSHOT hs
where st.snap_id=hs.snap_id and hs.BEGIN_INTERVAL_TIME between to_timestamp('&start_time','YYYYMMDD HH24MI') and to_timestamp('&end_time','YYYYMMDD HH24MI')
order by 1,2,3;


select min(sga_size)
from dba_hist_sga_target_advice
where ESTD_DB_TIME in (select min(ESTD_DB_TIME) from dba_hist_sga_target_advice);




select min(sga_size)
from dba_hist_sga_target_advice
where ESTD_DB_TIME in (select min(ESTD_DB_TIME) from dba_hist_sga_target_advice);

-- matches oldest date in OEM (on dsgp)
select min(start_time) from V$SGA_RESIZE_OPS;
01/09/2015

-- views w/snap_id column but no date
DBA_HIST_SGA				- matches oldest snapshot for AWR, but date is 2/17
DBA_HIST_SGA_TARGET_ADVICE	- same
DBA_HIST_SGASTAT			- same

DBA_HIST_SNAPSHOT			- has both snap_id and begin_interval_time


-- ##############
-- # KEEP CACHE #
-- ##############

/* When using automatic SGA management, the Keep Cache is dynamically allocated. Tables 
   can be altered to use this pool rather than the DEFAULT buffer pool */
   
-- manually set a minimum size
ALTER SYSTEM SET DB_KEEP_CACHE_SIZE=23G SCOPE=BOTH;

-- should be a bit larger than the sum of all of the tables configured to use it
select sum(blocks) from dba_tables where buffer_pool  = 'KEEP';
select con_id, sum(blocks) from cdb_tables where buffer_pool  = 'KEEP' group by con_id;

--  granule size is the value by which the cache is incremented or decremented
select granule_size/value
from v$sga_dynamic_components, v$parameter
where name = 'db_block_size'
and component like 'KEEP%';

-- minimum value = number of CPUs * granule size

-- find current size
select name, current_size from V$BUFFER_POOL;

-- set a table to use the keep cache
alter table mytab storage(buffer_pool keep);


select table_name, column_name from dba_tab_cols where data_type='DATE' and table_name in
(select table_name from dba_tab_cols where column_name='SNAP_ID' and table_name like 'DBA_%')
order by 1,2;