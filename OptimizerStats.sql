/* ----------------------- DBMS_STATS ----------------------- */

-- #######################
-- # Notes on DBMS_STATS #
-- #######################

1. Allows you to store statistics in your own tables (outside of the dictionary), 
   which does not affect the optimizer
2. You can maintain different sets of statistics within a single stattab by using 
   the statid parameter
3. For the SET and GET procedures, if stattab is not provided, 
   then the operation works directly on the dictionary statistics
4. If stattab is not NULL, then the SET or GET operation works on the specified user 
   statistics table, and not the dictionary
5. Whenever statistics in dictionary are modified, old versions of statistics are 
   saved automatically for future restoring
6. For GATHER_* procedures the statown, stattab, and statid parameters instruct the 
   package to back up current statistics in the specified table before gathering new 
   statistics


-- ################
-- # GATHER STATS #
-- ################

/*** SCHEMA STATS ***/
-- Gather new stats & load to dictionary
-- If stattab given, current stats backed up first
DBMS_STATS.GATHER_SCHEMA_STATS ( 
   ownname          VARCHAR2, 
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (get_param('ESTIMATE_PERCENT')), 
   block_sample     BOOLEAN  DEFAULT FALSE, 
   method_opt       VARCHAR2 DEFAULT get_param('METHOD_OPT'), 
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')), 
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'), 
   cascade          BOOLEAN  DEFAULT to_cascade_type(get_param('CASCADE')), 
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL, 
   options          VARCHAR2 DEFAULT 'GATHER', 
   statown          VARCHAR2 DEFAULT NULL, 
   no_invalidate    BOOLEAN  DEFAULT to_no_invalidate_type (
                                     get_param('NO_INVALIDATE'), 
   force            BOOLEAN DEFAULT FALSE,
   obj_filter_list  ObjectTab DEFAULT NULL);

-- degree			degree of parallelism
-- cascade			TRUE collects stats for indexes too
-- statid			allows set of stats to be stored in 1 table
-- stattab			specifies name of table to store stats in
-- estimate_percent	percentage of rows to estimate [0.000001,100]
	-- DBMS_STATS.AUTO_SAMPLE_SIZE has Oracle determine the appropriate sample size
-- method_opt		FOR ALL [INDEXED | HIDDEN] COLUMNS [size_clause]
	-- size_clause is defined as size_clause := SIZE {integer | REPEAT | AUTO | SKEWONLY}
	-- integer : Number of histogram buckets. Must be in the range [1,2048].
	-- REPEAT : Collects histograms only on the columns that already have histograms
	-- AUTO : Oracle determines the columns on which to collect histograms based on data distribution and the workload of the columns.
	-- SKEWONLY : Oracle determines the columns on which to collect histograms based on the data distribution of the columns. 
	-- default is FOR ALL COLUMNS SIZE AUTO
-- options
	-- GATHER: (Default) Gathers statistics on all objects in the schema.
	-- GATHER AUTO: Gathers all necessary statistics automatically
	-- GATHER STALE: Gathers statistics on stale objects 
	-- GATHER EMPTY: Gathers statistics on objects which currently have no statistics
	-- LIST AUTO: Returns a list of objects to be processed with GATHER AUTO
	-- LIST STALE: Returns list of stale objects
	-- LIST EMPTY: Returns list of objects which currently have no statistics

-- gather new schema stats to the dictionary
exec dbms_stats.gather_schema_stats('MS7',method_opt=>'FOR ALL COLUMNS SIZE 1',estimate_percent=>100,degree=>4,cascade=>TRUE);

-- save current stats & gather new stats to the dictionary
begin
  dbms_stats.gather_schema_stats(
    ownname=>		'MS7',
    method_opt=>	'FOR ALL COLUMNS SIZE 1',
    estimate_percent=>	100,
    degree=>		4,
    cascade=>		TRUE,
    stattab=>		'ADMIN_STATS_11G',
    statid=>		to_char(sysdate,'MONDDYYYY_HH24MI')
  );
end;
/


/*** TABLE STATS ***/
-- Gather new stats & load to dictionary
-- If stattab given, current stats backed up first
DBMS_STATS.GATHER_TABLE_STATS (
   ownname          VARCHAR2, 
   tabname          VARCHAR2, 
   partname         VARCHAR2 DEFAULT NULL,
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (get_param('ESTIMATE_PERCENT')), 
   block_sample     BOOLEAN  DEFAULT FALSE,
   method_opt       VARCHAR2 DEFAULT get_param('METHOD_OPT'),
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')),
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'), 
   cascade          BOOLEAN  DEFAULT to_cascade_type(get_param('CASCADE')),
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL,
   statown          VARCHAR2 DEFAULT NULL,
   no_invalidate    BOOLEAN  DEFAULT  to_no_invalidate_type (
                                     get_param('NO_INVALIDATE')),
   stattype         VARCHAR2 DEFAULT 'DATA',
   force            BOOLEAN  DEFAULT FALSE);

-- simple example
EXEC DBMS_STATS.GATHER_TABLE_STATS ('&schma_name','&tbl_name',NULL,100);


-- get current stats
select table_name, num_rows, blocks, avg_row_len, avg_cached_blocks, 
  avg_cache_hit_ratio, stale_stats, last_analyzed
from DBA_TAB_STATISTICS
where owner='&what_owner' and object_type='TABLE' and table_name='&what_table'
order by last_analyzed, table_name;

-- OR --
SET SERVEROUTPUT ON
DECLARE
   v_numrows	NUMBER := 0;
   v_numblks	NUMBER := 0;
   v_avglen	NUMBER := 0;
   v_cachedblk	NUMBER := 0;
   v_cachehit	NUMBER := 0;
BEGIN
  DBMS_STATS.GET_TABLE_STATS (
   ownname	=> '&schema_name', 
   tabname	=> '&tbl_name', 
   numrows	=> v_numrows, 
   numblks	=> v_numblks,
   avgrlen	=> v_avglen,
   statown	=> NULL,
   cachedblk	=> v_cachedblk,
   cachehit	=> v_cachehit);
  dbms_output.put_line ('Rows:  '||v_numrows);
  dbms_output.put_line ('Blocks:  '||v_numblks);
  dbms_output.put_line ('Avg length:  '||v_avglen);
  dbms_output.put_line ('Avg cached blocks:  '||v_cachedblk);
  dbms_output.put_line ('Avg cache hits:  '||v_cachehit);
END;
/


/*** INDEX STATS ***/
-- Gather new stats & load to dictionary
DBMS_STATS.GATHER_INDEX_STATS (
   ownname          VARCHAR2, 
   indname          VARCHAR2, 
   partname         VARCHAR2 DEFAULT NULL,
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (GET_PARAM('ESTIMATE_PERCENT')),
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL,
   statown          VARCHAR2 DEFAULT NULL,
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')),
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'),
   no_invalidate    BOOLEAN  DEFAULT to_no_invalidate_type 
                                               (GET_PARAM('NO_INVALIDATE')),
   force            BOOLEAN DEFAULT FALSE);

-- degree		of parallelism
-- granularity		of stats; not relevant to bitmap indexes
--			'ALL', 'AUTO', 'DEFAULT', 'GLOBAL', 'GLOBAL AND PARTITION', 'PARTITION', 'SUBPARTITION'
-- no_invalidate	doesn't invalidate dependent cursors if TRUEE; not relevant to bitmap indexes

exec DBMS_STATS.GATHER_INDEX_STATS('DW3', 'TRANSACTION_L2_IDX02', NULL, 100);


/*** DATABASE STATS ***/
-- Gather stats for all objects in the DB
DBMS_STATS.GATHER_DATABASE_STATS (
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (get_param('ESTIMATE_PERCENT')),
   block_sample     BOOLEAN  DEFAULT FALSE,
   method_opt       VARCHAR2 DEFAULT get_param('METHOD_OPT'),
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')),
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'), 
   cascade          BOOLEAN  DEFAULT to_cascade_type(get_param('CASCADE')),
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL,
   options          VARCHAR2 DEFAULT 'GATHER',
   objlist          OUT      ObjectTab,
   statown          VARCHAR2 DEFAULT NULL,
   gather_sys       BOOLEAN  DEFAULT TRUE,
   no_invalidate    BOOLEAN  DEFAULT to_no_invalidate_type (
                                     get_param('NO_INVALIDATE')),
   obj_filter_list ObjectTab DEFAULT NULL);
   
/* method_opt - controls column statistics collection and histogram creation
	FOR ALL COLUMNS SIZE AUTO (default)
	FOR ALL [INDEXED | HIDDEN] COLUMNS [size_clause]
	FOR COLUMNS [size clause] column [size_clause] [,column [size_clause]...]
		size_clause := SIZE {integer | REPEAT | AUTO | SKEWONLY}
			integer : Number of histogram buckets
			REPEAT : Collects histograms only on the columns that already have histograms
			SKEWONLY : Oracle determines the columns on which to collect histograms based on the data distribution of the columns
   granularity
	'AUTO'- Determines the granularity based on the partitioning type. This is the default value.
	'ALL' - Gathers all (subpartition, partition, and global) statistics
	'GLOBAL' - Gathers global statistics
	'GLOBAL AND PARTITION' - Gathers the global and partition level statistics.
	'PARTITION '- Gathers partition-level statistics
	'SUBPARTITION' - Gathers subpartition-level statistics
   cascade - Gather statistics on the indexes as well
   options
	GATHER: all objects in the schema
	GATHER AUTO: Oracle determines which objects need new statistics
	GATHER STALE: stale objects as determined by looking at the *_tab_modifications views
	GATHER EMPTY: objects which currently have no statistics
	LIST AUTO: Returns a list of objects to be processed with GATHER AUTO
	LIST STALE: Returns a list of stale objects as determined by looking at the *_tab_modifications views
	LIST EMPTY: Returns a list of objects which currently have no statistics
   no_invalidate
    TRUE - Does not invalidate the dependent cursors
	FALSE - invalidates the dependent cursors immediately 
	DBMS_STATS.AUTO_INVALIDATE - have Oracle decide when to invalidate dependent cursors
*/

-- example
exec DBMS_STATS.GATHER_DATABASE_STATS (estimate_percent =>100, degree=>4, cascade=>true, no_invalidate=>false, gather_sys=>TRUE);

-- gather stale stats job
BEGIN
	DBMS_STATS.GATHER_DATABASE_STATS( 
		CASCADE=> TRUE, 
		GATHER_SYS=> TRUE, 
		ESTIMATE_PERCENT=> 100, 
		DEGREE=> 8, 
		NO_INVALIDATE=> DBMS_STATS.AUTO_INVALIDATE, 
		GRANULARITY=> 'ALL', 
		METHOD_OPT=> 'FOR ALL COLUMNS SIZE AUTO', 
		OPTIONS=> 'GATHER STALE');
	END;
/

select con_id, count(*) from cdb_tables where LAST_ANALYZED is null and temporary='N' group by con_id order by con_id;
    CON_ID   COUNT(*)
---------- ----------
         1        120
         3        158

select owner, max(LAST_ANALYZED) from cdb_tables where LAST_ANALYZED is not null and temporary='N' and con_id=3 group by owner order by owner;
OWNER                          MAX(LAST_A
------------------------------ ----------
AEDBADMIN                      03/04/2018
APEX_040200                    02/16/2017
APPQOSSYS                      02/16/2017
CTXSYS                         02/12/2018
DBSNMP                         02/16/2017
DVSYS                          02/16/2017
FLOWS_FILES                    02/16/2017
GGS                            02/12/2018
GGTEST                         02/12/2018
GSMADMIN_INTERNAL              02/16/2017
LBACSYS                        02/12/2018
MDSYS                          02/12/2018
OJVMSYS                        02/12/2018
OLAPSYS                        02/12/2018
ORDDATA                        02/12/2018
ORDSYS                         02/16/2017
OUTLN                          02/16/2017
SQLTUNE                        02/12/2018
SYS                            03/04/2018
SYSTEM                         02/12/2018
WMSYS                          02/16/2017
XDB                            02/12/2018


select owner, count(*) from dba_tables where LAST_ANALYZED is null and temporary='N' group by owner order by owner;
OWNER                            COUNT(*)
------------------------------ ----------
DBSNMP                                  3
DVSYS                                   1
GGS                                     1
GSMADMIN_INTERNAL                       1
HARVEST                                36
MDSYS                                  17
ORDDATA                                19
SYS                                    68
SYSTEM                                  9
WMSYS                                   2
XDB                                     1


	
/*** DICTIONARY SCHEMAS ***/
-- Gather stats for dictionary schemas SYS, SYSTEM, etc.
DBMS_STATS.GATHER_DICTIONARY_STATS (
   comp_id          VARCHAR2 DEFAULT NULL, 
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (get_param('ESTIMATE_PERCENT')),
   block_sample     BOOLEAN  DEFAULT FALSE,
   method_opt       VARCHAR2 DEFAULT get_param('METHOD_OPT'),
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')),
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'),
   cascade          BOOLEAN  DEFAULT to_cascade_type(get_param('CASCADE')),
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL,
   options          VARCHAR2 DEFAULT 'GATHER AUTO', 
   objlist    OUT   ObjectTab,
   statown          VARCHAR2 DEFAULT NULL,
   no_invalidate    BOOLEAN  DEFAULT to_no_invalidate_type (
                                     get_param('NO_INVALIDATE')),
   obj_filter_list ObjectTab DEFAULT NULL);
   
   
/*** SYSTEM STATS ***/

DBMS_STATS.GATHER_SYSTEM_STATS (
   gathering_mode   VARCHAR2 DEFAULT 'NOWORKLOAD',
   interval         INTEGER  DEFAULT NULL,
   stattab          VARCHAR2 DEFAULT NULL,
   statid           VARCHAR2 DEFAULT NULL,
   statown          VARCHAR2 DEFAULT NULL);


/*** FIXED OBJECT STATS ***/

DBMS_STATS.GATHER_FIXED_OBJECTS_STATS (
   stattab        VARCHAR2 DEFAULT NULL,
   statid         VARCHAR2 DEFAULT NULL,
   statown        VARCHAR2 DEFAULT NULL, 
   no_invalidate  BOOLEAN  DEFAULT to_no_invalidate_type (
                                     get_param('NO_INVALIDATE'))); 
   
BEGIN
   DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
END;
/


-- ##########
-- # EXPORT #
-- ##########

-- Transfer stats from the dictionary to a user stats table

DBMS_STATS.EXPORT_SCHEMA_STATS (
   ownname         VARCHAR2,
   stattab         VARCHAR2, 
   statid          VARCHAR2 DEFAULT NULL,
   statown         VARCHAR2 DEFAULT NULL,
   stat_category   VARCHAR2 DEFAULT DEFAULT_STAT_CATEGORY);

EXEC DBMS_STATS.EXPORT_SCHEMA_STATS('MS7','ADMIN_STATS_11G',to_char(sysdate,'MONDDYYYY_HH24MI'));


-- ##########
-- # IMPORT #
-- ##########

-- Transfer stats from a user stats table to the dictionary

DBMS_STATS.IMPORT_SCHEMA_STATS (
   ownname         VARCHAR2,
   stattab         VARCHAR2, 
   statid          VARCHAR2 DEFAULT NULL,
   statown         VARCHAR2 DEFAULT NULL,
   no_invalidate   BOOLEAN DEFAULT to_no_invalidate_type(
                                    get_param('NO_INVALIDATE')),
   force           BOOLEAN DEFAULT FALSE,
   stat_category   VARCHAR2 DEFAULT DEFAULT_STAT_CATEGORY);

-- no_invalidate	Does not invalidate the dependent cursors if set to TRUE. 
--			The procedure invalidates the dependent cursors immediately 
--			if set to FALSE. 
 

EXEC DBMS_STATS.IMPORT_SCHEMA_STATS('MS7','ADMIN_STATS_11G','JUL122012_1629');

BEGIN
  DBMS_STATS.IMPORT_SCHEMA_STATS(
    ownname		=> 'DQI',
    stattab 		=> 'DQI_STATS',
    no_invalidate	=> FALSE);
END;
/

-- transfer table stats from a user table to the dictionary
exec dbms_stats.import_table_stats(ownname=>'TNREPO', stattab=>'DQI_STATS', tabname=>'TMP_CHILD');


-- ###############
-- # STATS TABLE #
-- ###############

-- Create stats table
DBMS_STATS.CREATE_STAT_TABLE (
   ownname  VARCHAR2, 
   stattab  VARCHAR2,
   tblspace VARCHAR2 DEFAULT NULL);

EXEC DBMS_STATS.CREATE_STAT_TABLE('MS7','ADMIN_STATS_11G_BACKUP','MS_META_DATA_X4M');

-- Delete stats table



-- ###############
-- # LOCK/UNLOCK #
-- ###############

-- Locking freezes current set of stats or keep them empty





EXEC DBMS_STATS.CREATE_STAT_TABLE('MS7','ADMIN_STATS_11G_BACKUP','MS_META_DATA_X4M');

insert into ms7.admin_stats_11g_backup 
  select * from ms7.admin_stats_11g;
commit;

EXEC DBMS_STATS.EXPORT_SCHEMA_STATS('MS7','ADMIN_STATS_11G');


-- ###########
-- # QUERIES #
-- ###########

select table_name, num_rows, blocks, avg_row_len, avg_cached_blocks, 
  avg_cache_hit_ratio, stale_stats, last_analyzed
from DBA_TAB_STATISTICS
where owner='&what_owner' and object_type='TABLE' and table_name='&what_table'
order by last_analyzed, table_name;

-- find stale stats
col "TABLE" format a50
select owner||'.'||table_name "TABLE", stale_stats, last_analyzed
from DBA_TAB_STATISTICS
where stale_stats='YES' and owner not in ('SYS','SYSTEM')
order by owner, table_name;


/* ----------------------- AUTOMATIC OPTIMIZER STATS COLLECTION ----------------------- */

-- ###########
-- # QUERIES #
-- ###########

select client_name, status, consumer_group
from DBA_AUTOTASK_CLIENT
order by client_name;

select client_name, job_status, to_char(job_start_time,'DD-MON-YY HH24:MI') "START_TIME", to_char((job_start_time + job_duration),'DD-MON-YY HH24:MI') "END_TIME", job_duration
from DBA_AUTOTASK_JOB_HISTORY
where rownum<5
order by client_name, job_start_time;

select window_name, to_char(window_next_time,'DD-MON-YY HH24:MI') "NEXT_TIME",
  autotask_status "STATUS", optimizer_stats "OPT_STATS", segment_advisor "SEG_ADVSR", 
  sql_tune_advisor "SQL_TUNE", health_monitor "HLTH_MON"
from DBA_AUTOTASK_WINDOW_CLIENTS
order by 2;


-- ##################
-- # ENABLE/DISABLE #
-- ##################

-- enable
BEGIN
  DBMS_AUTO_TASK_ADMIN.ENABLE(
    client_name => 'auto optimizer stats collection', 
    operation => NULL, 
    window_name => NULL);
END;
/

-- disable
BEGIN
  DBMS_AUTO_TASK_ADMIN.DISABLE(
    client_name => 'auto optimizer stats collection', 
    operation => NULL, 
    window_name => NULL);
END;
/

-- check modification monitoring (must be typical or all)
show parameter STATISTICS_LEVEL
