-- #################
-- # Index Queries #
-- #################

-- find status of indexes on a partitioned table
col "POS" format 990
col partition_name format a30
select partition_position "POS", partition_name, status
from dba_ind_partitions 
where index_name='&ind_name' order by partition_position;

-- find subpartitions
col "POS" format 990
col partition_name format a30
col subpartition_name format a30
break on partition_name
select partition_name, subpartition_position "POS", subpartition_name, status
from dba_ind_subpartitions 
where index_name='&ind_name' order by 1,2;

-- find the columns that are indexed
col "TABLE" format a40
col column_name format a25
col index_type format a15
col "UNIQUE" format a10
col descend format a4
select ic.table_owner||'.'||ic.table_name "TABLE", ic.column_name, di.index_type, di.uniqueness "UNIQUE", di.status, ic.descend 
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
where ic.index_name='&idx_name' order by 1;

-- get index stats
ANALYZE INDEX &index_name VALIDATE STRUCTURE;  
SELECT BLOCKS, BR_BLKS, LF_BLKS, btree_space, used_space, pct_used FROM index_stats;  

-- find the indexes of a tablespace and their number of leaf blocks
set lines 120
set pages 100
col "Index" format a30
col "Used (M)" format a15
col "Free (M)" format a15
SELECT	i.index_name AS "Index",
	i.leaf_blocks
FROM	dba_indexes i, dba_tablespaces ts
WHERE	i.tablespace_name=ts.tablespace_name AND ts.tablespace_name='&ts_name'
ORDER BY i.index_name;

-- find details of a user's indexes
set lines 150
set pages 1000
col "Index" format a30
SELECT	i.index_name AS "Index", ts.tablespace_name,
	i.leaf_blocks, i.last_analyzed
FROM	dba_indexes i, dba_tablespaces ts
WHERE	i.tablespace_name=ts.tablespace_name AND i.owner='&what_owner'
ORDER BY i.index_name;

-- find the clustering factor of an index
SELECT INDEX_NAME, CLUSTERING_FACTOR 
FROM DBA_INDEXES WHERE INDEX_NAME like '%&idx_name%';

-- find the indexes on a table
set long 30
col "INDEX" format a40
col index_type format a12
col column_name format a25
col column_expression format a60
break on "INDEX" on index_type on status skip 0
select di.owner||'.'||di.index_name "INDEX", di.index_type, di.status, ic.column_name, ie.column_expression
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
  left outer join dba_ind_expressions ie 
    on ic.index_name=ie.index_name and ic.column_position=ie.column_position
where di.table_name='&what_table' AND di.table_owner='&what_owner'
order by "INDEX", column_name;

-- find the table for a given index
set long 30
col "TABLE" format a40
col index_type format a15
col column_name format a30
break on "TABLE" on index_type on status skip 0
select di.table_owner||'.'||di.table_name "TABLE", di.index_type, di.status, do. created "IND CREATE", do.last_ddl_time
from dba_indexes di join dba_objects do on di.index_name=do.object_name
where di.index_name='&what_index' and do.object_type like '%INDEX%'
order by "TABLE";

-- details of all bitmap indexes
set lines 150 pages 200
set long 30
col "BITMAP INDEX" format a35
col index_type format a15
col column_name format a50
break on "INDEX" on index_type on status skip 0
select di.owner||'.'||di.index_name "BITMAP INDEX", di.status, di.table_name||'.'||ic.column_name column_name, di.tablespace_name
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
  left outer join dba_ind_expressions ie 
    on ic.index_name=ie.index_name and ic.column_position=ie.column_position
where di.index_type='BITMAP' and di.tablespace_name not in ('SYSTEM','SYSAUX')
order by "BITMAP INDEX", column_name;

-- details of indexes without stats
col table_name format a46
col index_type format a22
select di.owner||'.'||di.table_name "TABLE_NAME", di.index_name, di.index_type, di.status
from dba_indexes di join dba_objects do on di.index_name=do.object_name
where di.last_analyzed is null and di.index_name not like 'SYS_%' and di.owner in ('ACTD00','INSURER_INTEGRATION')
  and do.object_type like '%INDEX%' and di.index_type not like '%LOB%'
order by 1,2;

select di.index_name, di.table_name, di.index_type, di.status, do.created "IND CREATE", do.last_ddl_time
from dba_indexes di join dba_objects do on di.index_name=do.object_name
where di.index_name='&what_index' and do.object_type like '%INDEX%' and di.owner='&what_owned'
order by di.index_name;

-- get size of index
col segment_name format a40
col "KB" format 9,999,990
select seg.segment_name, seg.segment_type, (seg.bytes/1024) "KB"
from dba_segments seg join dba_indexes ind on seg.segment_name=ind.index_name
where seg.segment_type like '%INDEX%' and ind.index_name='&what_index';

-- get details of all extents of an index
SELECT	f.block_id, --starting block # of extent
	(f.bytes/1024/1024) AS "Ext (MB)", --size of extent in bytes
	f.blocks --size of extent in blocks
FROM	dba_extents f join dba_indexes i
ON	f.tablespace_name = i.tablespace_name
WHERE	i.index_name='&what_index' and f.owner='&what_owner'
	and f.segment_type='INDEX';


SELECT	d.file_name, 
FROM	dba_extents f join dba_indexes i
  ON	f.tablespace_name = i.tablespace_name
 JOIN	dba_data_files d ON f.file_id=d.file_id
WHERE	i.index_name='&what_index' and f.owner='&what_owner'
	and f.segment_type='INDEX';


SELECT	d.file_name, 
FROM	dba_segments s join dba_indexes i
  ON	s.tablespace_name = i.tablespace_name
 JOIN	dba_data_files d ON f.file_id=d.file_id
WHERE	i.index_name='&what_index' and f.owner='&what_owner'
	and f.segment_type='INDEX';
	
-- find unusable indexes
select owner, index_name, index_type, table_owner, table_name
from dba_indexes
where STATUS='UNUSABLE'
order by owner, index_name;


-- ###################
-- # Create an Index #
-- ###################

-- create a table index
CREATE [UNIQUE | BITMAP] INDEX
[schema.]index
ON [schema.]table
( column | column_expression [ASC | DESC] )
[index properties]
[UNUSABLE];

[index properties] :=
	[ONLINE]
	[TABLESPACE {ts_name | DEFAULT}]
	[SORT | NOSORT]
	[REVERSE]
	[VISIBLE | INVISIBLE]
	[physical_attributes] :=
		[PCTFREE x]
		[PCTUSED x]
		[INITRANS x]
		[storage_clause]
	[PARALLEL x | NOPARALLEL]

-- create a basic index
CREATE INDEX MONTHLY_SPENDING_PK
   ON orders (customer_id);

-- create a function-based index
CREATE INDEX upper_ix ON employees (UPPER(last_name)); 

-- create a bitmap index
CREATE BITMAP INDEX MONTHLY_SPENDING_STORE_IX
   ON MONTHLY_SPENDING (STORE);

-- create a bitmap index on partitioned table
CREATE BITMAP INDEX MONTHLY_SPENDING_STORE_IX
   ON MONTHLY_SPENDING (STORE) LOCAL;
   
-- get DDL to recreate index
set long 10000000
select DBMS_METADATA.GET_DDL('INDEX','&what_index','&what_owner') from dual;


-- ##################
-- # Alter an Index #
-- ##################

-- allow DDL to wait for locks
-- waits so many seconds, up to 1m
ALTER SESSION SET ddl_lock_timeout=&secs;

-- recompile index
ALTER INDEX &myindex COMPILE;

-- rename
ALTER INDEX upper_ix RENAME TO upper_name_ix;

-- rebuild
-- also used to move index
ALTER INDEX &myindex REBUILD;
-- rebuild without locking table
ALTER INDEX &myindex REBUILD ONLINE;

-- command to generate commands to rebuild partitioned indexes
select 'alter index '||index_name||' rebuild partition '||partition_name||';'
from USER_IND_PARTITIONS where status!='VALID' order by 1;

-- rename
ALTER INDEX &what_index RENAME TO &new_name;

-- drop an index
DROP INDEX owner.index;

-- drop a PK index (must drop constraint first)
set long 40
col owner format a20
col constraint_name format a30
col column_name format a30
select dc.owner, dc.constraint_name, col.column_name, dc.constraint_type, dc.status
from dba_constraints dc join dba_cons_columns col
  on dc.constraint_name = col.constraint_name
where dc.table_name='&tbl_name' and dc.constraint_type='P'
order by dc.constraint_type desc, dc.constraint_name asc;

alter table &what_owner..&what_table drop constraint &what_constraint;
drop INDEX &what_owner..&what_index;


-- ###############
-- # Index Stats #
-- ###############

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





