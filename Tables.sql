##################
# Object Queries #
##################

-- find a table's dependencies
col "OBJECT" format a30
col "REF_OBJ" format a30
select owner||'.'||name "OBJECT", type, referenced_owner||'.'||referenced_name "REF_OBJ",
  referenced_type "REFTYPE", dependency_type
from DBA_DEPENDENCIES where type='TABLE' and name='&what_name';

-- find objects dependent on a table
col "OBJECT" format a40
col "REF_OBJ" format a40
select owner||'.'||name "OBJECT", type, referenced_owner||'.'||referenced_name "REF_OBJ",
  referenced_type "REFTYPE", dependency_type
from DBA_DEPENDENCIES where referenced_name='&what_name' and referenced_owner='&what_owner'
order by type, object;

-- find indexes on a table
set long 30
col "INDEX" format a30
col index_type format a15
col column_name format a30
break on "INDEX" on index_type on status skip 0
select di.owner||'.'||di.index_name "INDEX", di.index_type, di.status, ic.column_name, ie.column_expression
from dba_indexes di join dba_ind_columns ic
    on di.index_name=ic.index_name
  left outer join dba_ind_expressions ie 
    on ic.index_name=ie.index_name and ic.column_position=ie.column_position
where di.table_name='&what_table' order by "INDEX", column_name;


######################
# Tablespace Queries #
######################

-- find the tables of a tablespace and their sizes (doesn't show partitioned tables)
set lines 120
set pages 100
col owner format a30
col "Table" format a30
col "Used (M)" format a15
col "Free (M)" format a15
SELECT	t.owner, t.table_name AS "Table",
	TO_CHAR(NVL(t.blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Used (M)", --used blocks in table
	TO_CHAR(NVL(t.empty_blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Free (M)" --blocks never used in table
FROM	dba_tables t, dba_tablespaces ts
WHERE	t.tablespace_name=ts.tablespace_name AND ts.tablespace_name='&ts_name'
ORDER BY t.owner, t.table_name;

-- find the tablespace a table belongs to
select tablespace_name from dba_tables where table_name='&tbl_name';

col "Used (M)" format a15
col "Free (M)" format a15
SELECT	TO_CHAR(NVL(t.blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Used (M)", --used blocks
	TO_CHAR(NVL(t.empty_blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Free (M)" --blocks never used
FROM	dba_tables t, dba_tablespaces ts
WHERE	t.tablespace_name=ts.tablespace_name AND ts.tablespace_name='&ts_name'

################
# Size Queries #
################


set lines 150
set pages 200
col "Table" format a50
col "GB" format 999,999,999
SELECT	t.owner||'.'||t.table_name AS "Table", s.segment_type, sum(round(s.bytes/1024/1024/1024,0)) "GB"
FROM	dba_segments s, dba_tables t
WHERE	s.segment_type like 'TABLE%' AND s.segment_name=t.table_name
	--AND s.bytes>=21474836480
	AND t.table_name like '%&what_table%'
GROUP BY t.owner, t.table_name, s.segment_type
ORDER BY t.owner, t.table_name, s.segment_type;

-- find size in bytes of a column
-- useful for numbers since they're variable sizes
SELECT vsize(total_bytes), vsize(used_bytes), vsize(free_bytes) from apex_table_owner.apex_ts_history;

-- find details about the segments of a table
-- Used & Unused only up-to-date if table has been analyzed
set lines 120
set pages 100
col "Table" format a15
col "Rows" format 999,999,999
col "Used (M)" format a15
col "Unused (M)" format a15
col "Seg (M)" format a15
SELECT	t.table_name AS "Table",
	t.num_rows AS "Rows", --rows in table
	TO_CHAR(NVL(t.blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Used (M)", --used blocks in table
	TO_CHAR(NVL(t.empty_blocks*ts.block_size/1024/1024,0), '99,999,990.900') AS "Unused (M)", --blocks never used in table
	TO_CHAR(NVL(s.bytes/1024/1024,0), '99,999,990.900') AS "Seg (M)",
	s.extents AS "Extents"
FROM	dba_segments s, dba_tables t, dba_tablespaces ts
--WHERE	t.tablespace_name=ts.tablespace_name
WHERE	s.tablespace_name=ts.tablespace_name
	AND s.segment_type like 'TABLE%' AND s.segment_name=t.table_name
	AND s.segment_name='&tbl_name';

-- find same info in blocks
-- Used & Unused only up-to-date if table has been analyzed
col "Used (BLK)" format a15
col "Unused (BLK)" format a15
col "Seg (BLK)" format a15
SELECT	t.table_name AS "Table",
	t.num_rows AS "Rows", --rows in table
	TO_CHAR(NVL(t.blocks,0), '9,999,999,990') AS "Used (BLK)", --used blocks in table
	TO_CHAR(NVL(t.empty_blocks,0), '9,999,999,990') AS "Unused (BLK)", --blocks never used in table
	TO_CHAR(NVL(s.blocks,0), '9,999,999,990') AS "Seg (BLK)",
	s.extents AS "Extents"
FROM	dba_segments s, dba_tables t
WHERE	s.segment_type like 'TABLE%' AND s.segment_name=t.table_name
	AND s.segment_name='&tbl_name';

-- if that comes up blank, try this (very basic)
select sum(bytes)/1024/1024 "MB" from dba_segments where segment_name='APEX_TS_HISTORY';
-- or
SELECT	TO_CHAR(NVL(sum(s.bytes)/1024/1024,0), '99,999,990.900') AS "MB"
FROM	dba_segments s
WHERE	s.segment_type like 'TABLE%' AND s.segment_name='&tbl_name';

-- get details about the free extents of a table
SELECT	f.block_id, --starting block # of extent
	(f.bytes/1024/1024) AS "Free Ext (MB)", --size of extent in bytes
	f.blocks, --size of extent in blocks
	owner
FROM	dba_free_space f join dba_tables t
ON	f.tablespace_name = t.tablespace_name
WHERE	t.table_name='&tbl_name' order by f.block_id;

-- get details of all extents of a table
break on report;
compute sum label "TOTAL" of "Ext (MB)" BLOCKS on REPORT;
SELECT	f.block_id, --starting block # of extent
	(f.bytes/1024/1024) AS "Ext (MB)", --size of extent in bytes
	f.blocks --size of extent in blocks
FROM	dba_extents f join dba_tables t
ON	f.tablespace_name = t.tablespace_name
WHERE	t.table_name='&tbl_name' and f.owner='&tbl_owner'
	and f.segment_type='TABLE'
ORDER BY f.block_id;

-- see how many blocks are used
SELECT blocks, empty_blocks, IOT_TYPE FROM dba_tables WHERE table_name = '&tbl_name'; 

-- find out how many rows are chained
ANALYZE TABLE &tbl_name COMPUTE STATISTICS;
SELECT table_name, num_rows, chain_cnt, blocks from dba_tables WHERE table_name = '&&tbl_name'; 

/* dump the block contents of a table */
-- find file & block #s
select header_file, header_block from dba_segments where segment_name = '&tbl_name';
-- dump block to user dump folder
alter system dump datafile 3 block 108639;

-- dump a file using a rowid
declare
  p_rowid rowid;
  dump_file varchar2(4000);
begin

  execute immediate '
    alter system dump datafile ' ||
      dbms_rowid.rowid_relative_fno(p_rowid) || '
    block ' ||
      dbms_rowid.rowid_block_number(p_rowid);

  select 
    u_dump.value || '/' || instance.value || '_ora_' || sys.v_$process.spid || '.trc'
  into 
    dump_file
  from 
               sys.v_$parameter u_dump 
    cross join sys.v_$parameter instance
    cross join sys.v_$process 
          join sys.v_$session 
            on sys.v_$process.addr = sys.v_$session.paddr
  where 
   u_dump.name   = 'user_dump_dest' and 
   instance.name = 'instance_name' and
   sys.v_$session.audsid=sys_context('userenv','sessionid');

  dbms_output.put_line('  dumped block to: ');
  dbms_output.put_line('  ' ||  dump_file);
end;
/

-- get space usage of data blocks under high water mark
set define on
set serveroutput on
DECLARE
  unformat_blk number; 
  unformat_byt number; 
  f0_25_blk number; 
  f0_25_byt number; 
  f25_50_blk number; 
  f25_50_byt number; 
  f50_75_blk number; 
  f50_75_byt number; 
  f75_100_blk number; 
  f75_100_byt number; 
  full_blk number; 
  full_byt number; 
begin 
  dbms_space.space_usage('ACTD00','INSACC','TABLE', unformat_blk, unformat_byt, f0_25_blk, 
  f0_25_byt, f25_50_blk, f25_50_byt, f50_75_blk, f50_75_byt, f75_100_blk, f75_100_byt, full_blk, 
  full_byt); 

    dbms_output.put_line('Unformatted Blk: '|| unformat_blk); 
    dbms_output.put_line('Unformatted Byt: '||unformat_byt/1024/1024); 
    dbms_output.put_line('Blocks 75-100:   '||f75_100_blk); 
    dbms_output.put_line('Bytes 75-100:    '||f75_100_byt); 
    dbms_output.put_line('Blocks 50-75:    '||f50_75_blk); 
    dbms_output.put_line('Bytes 50-75:     '||f50_75_byt); 
    dbms_output.put_line('Blocks 25-50:    '||f25_50_blk); 
    dbms_output.put_line('Bytes 25-50:     '||f25_50_byt); 
    dbms_output.put_line('Blocks 0-25:     '||f0_25_blk); 
    dbms_output.put_line('Bytes 0-25:      '||f0_25_byt); 
    dbms_output.put_line('Full Blocks:     '||full_blk); 
    dbms_output.put_line('Full Bytes:      '||full_byt); 
end; 
/ 

-- find objects in a data file
col owner format a30
col segment_name format a30
select de.owner, de.segment_name, de.segment_type, sum(de.blocks) "BLOCKS"
from dba_extents de, dba_data_files df
where de.file_id=df.file_id
and df.file_name='/database/Ecustsvcp/custsvcp01/oradata/entsvcpldb_data05.dbf'
group by de.owner, de.segment_name, de.segment_type
order by de.owner, de.segment_name, de.segment_type;


####################
# Table Partitions #
####################

-- find partitioned tables
select owner, table_name, partitioning_type, partition_count
from dba_part_tables
where owner not in ('SYS','SYSTEM')
order by 1,2;

-- details of table partitions
col "TABLE" format a40
col "POS" format 90
col partition_name format a25
set long 40
break on "TABLE"
select table_owner||'.'||table_name "TABLE", partition_position "POS", partition_name, high_value 
from dba_tab_partitions where table_name='&tbl_name' order by "POS";

-- as non-dba
-- details of table partitions
col "TABLE" format a40
col "POS" format 90
col partition_name format a25
set long 40
break on "TABLE"
select table_name "TABLE", partition_position "POS", partition_name, high_value 
from user_tab_partitions where table_name='&tbl_name' order by "POS";

-- find the column(s) the table is partitioned on
select * from DBA_PART_KEY_COLUMNS where owner='&what_owner' and name='&what_table'

-- partition count
select count(*) from &tbl_name partition (&part_name);

-- count for all paritions (takes about 5 minutes)
-- run as owner
set serveroutput on
declare
  v_table_name	constant varchar2(30) := 'AUDIT_HIST_PART';
  cursor c1 is
    select partition_name from user_tab_partitions where table_name='AUDIT_HIST_PART'
	order by partition_position;
  v_partition_name user_tab_partitions.partition_name%TYPE;
  v_partition_count PLS_INTEGER;
begin
  open c1;
  loop
    fetch c1 into v_partition_name;
	exit when c1%notfound;
    execute immediate 'select count(*) from ' || v_table_name || ' partition ('|| v_partition_name || ')' into v_partition_count;
    dbms_output.put_line (v_partition_name||' -> '||v_partition_count);
  end loop;
  close c1;
end;
/

-- sizes of partitions with a LOB
WITH tab_part AS
	(SELECT	tp.partition_position, tp.table_name, s.partition_name, s.bytes
	 FROM	dba_segments s, dba_tab_partitions tp
	 WHERE	s.segment_name=tp.table_name AND s.partition_name=tp.partition_name AND s.segment_name='BIZDOCCONTENT'),
lob_part AS
	(SELECT	lp.partition_position, lp.table_name, lp.partition_name, lp.lob_partition_name, s.bytes
	 FROM	dba_segments s, dba_lob_partitions lp
	 WHERE	s.partition_name=lp.lob_partition_name AND lp.table_name='BIZDOCCONTENT')
SELECT	tab_part.partition_position "POS", tab_part.table_name, tab_part.partition_name, lob_part.lob_partition_name,
		TO_CHAR(NVL((tab_part.bytes+lob_part.bytes)/1024/1024,0), '99,999,990.900') AS "Used (M)" --used blocks in table
FROM lob_part join tab_part ON tab_part.partition_name=lob_part.partition_name
ORDER BY tab_part.partition_position;


-- add a partition
ALTER TABLE &tbl_name ADD PARTITION &part_name
   VALUES LESS THAN (TO_DATE('&split_date','DD-MON-YYYY'));
ALTER TABLE &tbl_name ADD PARTITION &part_name
   VALUES LESS THAN (MAXVALUE);

-- split a partition
ALTER TABLE webstats.awetrans SPLIT PARTITION AWETRANS_30032014
   AT (TO_DATE('20140330 000000','YYYYMMDD HH24MISS'))
   INTO (PARTITION AWETRANS_29032014, PARTITION AWETRANS_30032014);

-- merge 2 partitions
ALTER TABLE sales 
   MERGE PARTITIONS sales_q4_2000, sales_q4_2000b
   INTO PARTITION sales_q4_2000;

-- drop a partition
ALTER TABLE print_media_part DROP PARTITION p3;

-- rename a part
ALTER TABLE sales RENAME PARTITION sales_q4_2003 TO sales_currentq;

-- trunc a part
ALTER TABLE print_media_demo
   TRUNCATE PARTITION p1 DROP STORAGE;





ALTER TABLE &what_table
EXCHANGE PARTITION &what_part WITH TABLE &xchg_table INCLUDING INDEXES UPDATE INDEXES;

-- get space usage of data blocks under high water mark
DECLARE
  unformat_blk number; 
  unformat_byt number; 
  f0_25_blk number; 
  f0_25_byt number; 
  f25_50_blk number; 
  f25_50_byt number; 
  f50_75_blk number; 
  f50_75_byt number; 
  f75_100_blk number; 
  f75_100_byt number; 
  full_blk number; 
  full_byt number; 
  CURSOR c1 IS
    select partition_position, partition_name
    from dba_tab_partitions where table_name='AWETRANS'
    order by partition_position;
  v_partpos	NUMBER;
  v_partname  VARCHAR2(30);
begin 
  dbms_output.put_line('PARTITION_NAME	  unformat f75_100 f50_75 f25_50 f0_25  full');
  dbms_output.put_line('----------------- -------- ------- ------ ------ ----- -----');
  OPEN c1;
  LOOP
    FETCH c1 INTO v_partpos, v_partname;
    EXIT WHEN c1%NOTFOUND;
    dbms_space.space_usage('WEBSTATS','AWETRANS','TABLE PARTITION', unformat_blk, unformat_byt, f0_25_blk, 
      f0_25_byt, f25_50_blk, f25_50_byt, f50_75_blk, f50_75_byt, f75_100_blk, f75_100_byt, full_blk, 
      full_byt, v_partname); 
    dbms_output.put_line(v_partname||'	 '||unformat_blk||'	 '||f75_100_blk||'	'||f50_75_blk||'      '||f25_50_blk||'     '||f0_25_blk||' '||full_blk);
  END LOOP;
  CLOSE c1;
end; 
/


######################
# Constraint Queries #
######################

-- find constraints on a user's table
set long 40
col constraint_name format a25
col column_name format a30
select dc.constraint_name, col.column_name, dc.constraint_type, dc.status, dc.invalid
from user_constraints dc join user_cons_columns col
  on dc.constraint_name = col.constraint_name
where dc.table_name='&tbl_name'
order by dc.constraint_type desc, dc.constraint_name asc;

-- as dba
set long 40
col owner format a20
col constraint_name format a30
col column_name format a30
select dc.owner, dc.constraint_name, col.column_name, dc.constraint_type, dc.status
from dba_constraints dc join dba_cons_columns col
  on dc.constraint_name = col.constraint_name
where dc.table_name='&tbl_name' and dc.owner='&what_owner'
order by dc.constraint_type desc, dc.constraint_name asc;

-- get details of check constraints
set long 40
col owner format a20
col constraint_name format a20
select dc.owner, dc.constraint_name, dc.constraint_type, dc.search_condition, dc.status
from dba_constraints dc
where dc.constraint_type='C' and dc.table_name='&tbl_name'
order by dc.constraint_name;

-- Constraint Types
C (check constraint on a table)
P (primary key)
U (unique key)
R (referential integrity)
V (with check option, on a view)
O (with read only, on a view)

-- find owner, table, & column for FK constraint
set lines 120 pages 200
col owner format a25
col "TABLE" format a50
col column_name format a30
select constraint_name, owner||'.'||table_name "TABLE", column_name 
from dba_cons_columns where constraint_name=
 (select r_constraint_name from dba_constraints 
  where constraint_name='&fk_constr');

-- find details of PK or unique constraints
col column_name format a30
select i.index_name, i.column_name, i.column_position, c.status
from dba_constraints c join dba_ind_columns i
  on c.index_name=i.index_name
where c.constraint_name='&whatconstraint';

-- find constraints using this one as a FK
set lines 150 pages 200
col owner format a25
col "TABLE" format a50
col column_name format a30
select constraint_name, owner||'.'||table_name "TABLE", column_name 
from dba_cons_columns where constraint_name in
 (select constraint_name from dba_constraints 
  where r_constraint_name='&fk_constr');


-- find all of a user's constraints
set long 40
col constraint_name format a25
col column_name format a30
select dc.table_name, dc.constraint_name, col.column_name, dc.constraint_type, dc.status, dc.invalid
from user_constraints dc join user_cons_columns col
  on dc.constraint_name = col.constraint_name
order by dc.table_name, dc.constraint_name asc;

-- find all pk and unique constraints for a user
set long 40
col constraint_name format a30
col column_name format a30
select dc.table_name, dc.constraint_name, col.column_name, dc.constraint_type, dc.status, dc.invalid
from dba_constraints dc join dba_cons_columns col
  on dc.constraint_name = col.constraint_name
where col.owner='&what_owner' and dc.constraint_type in ('P','U') and dc.table_name not like 'BIN$%'
order by dc.table_name, dc.constraint_name asc;

-- find tables w/o PK or unique key for a user
select owner, table_name from dba_tables where (owner, table_name) not in
(select owner, table_name from dba_constraints where constraint_type in ('P','U'))
and owner not in ('GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS')
order by 1,2;

select owner, table_name from dba_constraints where constraint_type in ('P','U') and owner='&what_owner'


select AUTHCODESEQNO from ACTD00.POLMAIN where AUTHCODESEQNO not in (select AUTHCODESEQNO from ACTD00.AUTHCODE);


-- ##################
-- # Create a Table #
-- ##################

-- specify TS, PK, FK, and check constraints
CREATE TABLE dept_20 (
	employee_id     NUMBER(4)	CONSTRAINT dept_20_pk PRIMARY KEY, -- inline PK constraint
	last_name       VARCHAR2(10), 
	job_id          VARCHAR2(9)	CONSTRAINT check_job_id CHECK (job_id > 0), -- inline check constraint
	manager_id      NUMBER(4)	CONSTRAINT fk_mgr REFERENCES employees ON DELETE CASCADE, -- inline FK constraint
	department_id, 
CONSTRAINT fk_deptno FOREIGN  KEY (department_id) REFERENCES  departments(department_id) -- out-of-line FK constraint
)
TABLESPACE APEX_1247004037875322;

-- create table & PK index
-- this doesn't seem to work for FK indexes
CREATE TABLE table1 (
   col1		NUMBER(10,0)	constraint col1_nn01 not null,
   col2		NUMBER(10,0)	constraint col2_nn02 not null, 
   col3		NUMBER(10,0)	constraint col3_nn03 not null,
   col4		NUMBER(1,0)	constraint col4_nn04 not null,
   CONSTRAINT table1_pk01 PRIMARY KEY (col1) 
      using index (CREATE INDEX table1_pk_ix ON table1 (col1) tablespace apex_users)
)
tablespace apex_users;

-- add FK afterwards
ALTER TABLE table_counts
ADD CONSTRAINT table_counts_fk 
FOREIGN KEY (table_id) 
REFERENCES table_names (table_id) ON DELETE SET NULL;

-- use a subquery
create table active_undo 
tablespace users
as
(select s.sid, s.username, s.osuser, 
  (t.used_ublk*(select block_size from sys.dba_tablespaces where contents='UNDO')/1024/1024) "USED MB", 
  sq.sql_fulltext
from sys.v_$transaction t, sys.v_$session s, sys.dba_rollback_segs r, sys.v_$sql sq
where t.ses_addr=s.saddr and t.xidusn=r.segment_id and s.sql_id=sq.sql_id);

CREATE TABLE table_name
(	column datatype inline_contraint,
	column datatype inline_ref_contraint,
	out_of_line_constraint,
	out_of_line_ref_constraint
)
physical_properties
LOB (LOB_item) STORE AS (TABLESPACE lob_tbs_name)
table_partitioning_clauses
AS subquery;

physical_properties =
	TABLESPACE tbs_name PCTFREE x PCTUSED y INITRANS z
or	ORGANIZATION {HEAP | INDEX | EXTERNAL}

-- table with partitions (subquery optional)
CREATE TABLE audit_hist_part
(	USERNAME		VARCHAR2(30),
	USERHOST		VARCHAR2(128),
	TMSTAMP			DATE
)
TABLESPACE APEX_USERS
PARTITION BY RANGE (TMSTAMP)
(	PARTITION partition_name range_values table_partition_desc,
	PARTITION partition_name range_values table_partition_desc,
	PARTITION partition_name range_values table_partition_desc
);

-- partition example
CREATE TABLE audit_hist_part
(	USERNAME		VARCHAR2(30),
	USERHOST		VARCHAR2(128),
	TMSTAMP			DATE
)
TABLESPACE APEX_USERS
PARTITION BY RANGE (TMSTAMP)
(	PARTITION VALUES LESS THAN (to_date('20131001000000','YYYYMMDDHH24MISS')),
	PARTITION VALUES LESS THAN (to_date('20131101000000','YYYYMMDDHH24MISS')),
	PARTITION VALUES LESS THAN (to_date('20131201000000','YYYYMMDDHH24MISS')),
	PARTITION VALUES LESS THAN (MAXVALUE)
);


/* creating tables with LOB */

-- Best performance for LOBs can be achieved by specifying storage for LOBs in a 
-- tablespace different from the one used for the table that contains the LOB
CREATE TABLE ContainsLOB_tab 
(	n	NUMBER, 
	c 	CLOB
) 
TABLESPACE APEX_USERS
lob (c) STORE AS BASICFILE segname 
	(TABLESPACE lobtbs1 CHUNK 4096 
	 PCTVERSION 5 
	 NOCACHE LOGGING 
	 STORAGE (MAXEXTENTS 5) 
); 

-- use securefile
CREATE TABLE ContainsLOB_tab1 (n NUMBER, c CLOB)
      lob (c) STORE AS SECUREFILE sfsegname (TABLESPACE lobtbs1
                       RETENTION AUTO
                       CACHE LOGGING
                       STORAGE (MAXEXTENTS 5)
                     );

-- create a temp table
CREATE GLOBAL TEMPORARY TABLE dept_20 (
	employee_id     NUMBER(4)
)
ON COMMIT DELETE ROWS;


-- estimate size of new table
DBMS_SPACE.CREATE_TABLE_COST (
   tablespace_name    IN VARCHAR2,
   avg_row_size       IN NUMBER,
   row_count          IN NUMBER,
   pct_free           IN NUMBER,
   used_bytes         OUT NUMBER,
   alloc_bytes        OUT NUMBER);

DBMS_SPACE.CREATE_TABLE_COST (
   tablespace_name    IN VARCHAR2,
   colinfos           IN CREATE_TABLE_COST_COLUMNS,
   row_count          IN NUMBER,
   pct_free           IN NUMBER,
   used_bytes         OUT NUMBER,
   alloc_bytes        OUT NUMBER);

-- colinfos	description of the columns
-- used_bytes	spaced used by user data
-- alloc_bytes	size of object taking into account the extent characteristics

-- using first procedure
set serveroutput on
DECLARE
 ub NUMBER;
 ab NUMBER;
BEGIN
  DBMS_SPACE.CREATE_TABLE_COST('DW2_TABLES_X4M_EXT',400,12218209,10,ub,ab);

  DBMS_OUTPUT.PUT_LINE('Used MB: ' ||ub/1024/1024);
  DBMS_OUTPUT.PUT_LINE('Alloc MB: ' ||ab/1024/1024);
END;
/

-- using second procedure
set serveroutput on
DECLARE 
 ub NUMBER; 
 ab NUMBER; 
 cl sys.create_table_cost_columns; 
BEGIN 
  cl := sys.create_table_cost_columns
	( 
	  sys.create_table_cost_colinfo('NUMBER',10), 
	  sys.create_table_cost_colinfo('NUMBER',10), 
	  sys.create_table_cost_colinfo('NUMBER',10), 
	  sys.create_table_cost_colinfo('NUMBER',38), 
          sys.create_table_cost_colinfo('DATE',NULL),
          sys.create_table_cost_colinfo('DATE',NULL),
	  sys.create_table_cost_colinfo('NUMBER',38),
          sys.create_table_cost_colinfo('DATE',NULL),
          sys.create_table_cost_colinfo('DATE',NULL)
	); 
 
  DBMS_SPACE.CREATE_TABLE_COST('ACT_TABLES_X4M',cl,9358217,10,ub,ab); 
 
  DBMS_OUTPUT.PUT_LINE('Used MB: ' ||to_char(ub/1024/1024));
  DBMS_OUTPUT.PUT_LINE('Alloc MB: ' ||to_char(ab/1024/1024));
END; 
/ 


Used Bytes: 335,872	= 0.32 MB
Alloc Bytes: 393,216	= 0.375 MB

APEX_TS_HISTORY_ID	1
TABLESPACE_NAME		25
TOTAL_BYTES		5
USED_BYTES		6
FREE_BYTES		6
TMSTAMP			7
DB_NAME			8


-- ##################
-- # Change a Table #
-- ##################

-- allow DDL to wait for locks
-- waits so many seconds, up to 1m
ALTER SESSION SET ddl_lock_timeout=&secs;

-- add a column (separate multiple columns with commas)
ALTER TABLE &tbl_name ADD (&col_name &data_type);

-- rename a column
ALTER TABLE customers
   RENAME COLUMN credit_limit TO credit_amount;

-- modify a column
ALTER TABLE emp
   MODIFY (empno NUMBER(5));

-- drop columns
ALTER TABLE contacts_table DROP (FIRST_NAME, LAST_NAME, COUNTRY_CODE, HOME_PHONE);
ALTER TABLE &what_table DROP (&what_column);
-- with constraints
ALTER TABLE t1 DROP (pk) CASCADE CONSTRAINTS;

-- add a default value
ALTER TABLE &what_table
  MODIFY (&what_column DEFAULT &what_default); 

-- rename table
ALTER TABLE &what_table RENAME TO &new_name;

-- make a table not compressed
ALTER TABLE &what_table MOVE NOCOMPRESS NOLOGGING PARALLEL 4;


/************ constraint changes ************/
-- add PK
ALTER TABLE &what_table
ADD CONSTRAINT &what_constraint
PRIMARY KEY (&what_column);

ALTER TABLE table_counts
ADD CONSTRAINT table_counts_pk
PRIMARY KEY (table_counts_id)
using index (CREATE INDEX table_counts_pk_ix ON table_counts (table_counts_id) tablespace apex_users);

-- exception table created with D:\oracle\product\11.2.0\dbhome_11203\RDBMS\ADMIN\utlexcpt.sql
ALTER TABLE audit_hist_part
ADD CONSTRAINT audit_hist_part_pk
PRIMARY KEY (USERNAME, USERHOST, TMSTAMP, ACTION)
EXCEPTIONS INTO sys.exceptions;

-- drop PK
ALTER TABLE &what_table
DROP PRIMARY KEY 
[CASCADE]					-- if you want all other integrity constraints that depend on the dropped integrity constraint to be dropped as well
[KEEP INDEX | DROP INDEX]
[ONLINE];					-- DML operations on the table will be allowed while dropping the constraint

-- add unique
ALTER TABLE &what_table
ADD CONSTRAINT &what_constraint
UNIQUE (&what_column);

-- drop unique
ALTER TABLE &what_table
DROP UNIQUE (col1, col2,..)
[CASCADE]					-- if you want all other integrity constraints that depend on the dropped integrity constraint to be dropped as well
[KEEP INDEX | DROP INDEX]
[ONLINE];					-- DML operations on the table will be allowed while dropping the constraint

-- add FK
ALTER TABLE &what_table
ADD CONSTRAINT &what_constraint
FOREIGN KEY (&what_column)
REFERENCES &ref_table (&ref_column)
-- ON DELETE [CASCADE | SET NULL]

-- add check
ALTER TABLE &what_table
ADD CONSTRAINT &what_constraint
CHECK (&what_condition);

-- drop other constraints
ALTER TABLE &what_table
DROP CONSTRAINT &what_constraint
[CASCADE]
[ONLINE];				-- DML operations on the table will be allowed while dropping the constraint

/*** add an index ***/
-- create a basic index
CREATE INDEX MONTHLY_SPENDING_PK
   ON orders (customer_id);

-- create a function-based index
CREATE INDEX upper_ix ON employees (UPPER(last_name)); 

-- create a bitmap index
CREATE BITMAP INDEX MONTHLY_SPENDING_STORE_IX
   ON MONTHLY_SPENDING (STORE);


-- change state of constraints
ALTER TABLE employees
   ENABLE NOVALIDATE PRIMARY KEY
   ENABLE NOVALIDATE CONSTRAINT emp_last_name_nn;
-- disable a PK and any FK that references it
ALTER TABLE locations
   MODIFY PRIMARY KEY DISABLE CASCADE;
   
ALTER TABLE INF_DQMREP.PR_RESOURCE DISABLE CONSTRAINT FK_PR_RESOURCE_PR_;

spool disable_constraints_ms7.out
-- disable PK/FK
select 'ALTER TABLE '||owner||'.'||table_name||' MODIFY PRIMARY KEY DISABLE CASCADE;'
from dba_constraints where owner='MS7' and constraint_type='P' order by table_name;
select 'ALTER TABLE '||owner||'.'||table_name||' DISABLE CONSTRAINT '||constraint_name||';'
from dba_constraints where owner='MS7' and constraint_type not in ('P','R') order by constraint_name;
spool off

spool enable_constraints_ms7.out
-- enable PK
select 'ALTER TABLE '||owner||'.'||table_name||' ENABLE CONSTRAINT '||constraint_name||';'
from dba_constraints where owner='MS7' and constraint_type='P' order by constraint_name;
-- enable all else
select 'ALTER TABLE '||owner||'.'||table_name||' ENABLE CONSTRAINT '||constraint_name||';'
from dba_constraints where owner='MS7' and constraint_type!='P' order by constraint_name;
spool off


-- rename a constraint
ALTER TABLE customers RENAME CONSTRAINT cust_fname_nn
   TO cust_firstname_nn;

-- drop a constraint
ALTER TABLE departments
    DROP CONSTRAINT pk_dept CASCADE;

-- mark column as unused then drop it
ALTER TABLE contacts_table SET UNUSED (col1);
ALTER TABLE DROP UNUSED COLUMNS;


/************ Various changes ************/

-- lock a table
LOCK TABLE &what_table IN &what_mode MODE;
-- ROW SHARE
-- ROW EXCLUSIVE
-- SHARE UPDATE
-- SHARE 
-- SHARE ROW EXCLUSIVE
-- EXCLUSIVE 

-- gather stats on a table
-- first entry is owner
-- second entry is table
EXEC DBMS_STATS.GATHER_TABLE_STATS ('&schma_name','&tbl_name',NULL,100);

-- free up usused space
ALTER TABLE employees DEALLOCATE UNUSED;

-- move a table
ALTER TABLE &what_table MOVE
[TABLESPACE &what_tablespace]
[PARALLEL x | NOPARALLEL];

ALTER TABLE SYSMAN_MDS.MDS_ATTRIBUTES MOVE
PARALLEL 2;

-- move a partitioned table
ALTER TABLE &what_table MOVE
PARTITION &what_partition
UPDATE INDEXES
[PARALLEL x | NOPARALLEL];

-- get command for all partitions
set lines 200 pages 0
spool move_tab_parts.out
select 'ALTER TABLE '||table_owner||'.'||table_name||' MOVE PARTITION "'||partition_name||'" UPDATE INDEXES;'
from dba_tab_partitions where table_name='&tbl_name' order by partition_position;
spool off
@move_tab_parts.out


ALTER INDEX &what_index
REBUILD PARTITION &what_partition;


spool move_ind_parts.out
select distinct 'ALTER INDEX '||owner||'.'||segment_name||' REBUILD PARTITION "'||partition_name||'";'
from dba_extents where file_id=6 and partition_name is not null and segment_type='INDEX PARTITION'
order by owner, segment_name, partition_name;




################
# Drop a Table #
################

DROP TABLE testK CASCADE CONSTRAINTS;


###################
# External Tables #
###################

-- find external tables
select * from dba_external_tables;

-- find all internal tables
select tb.owner, tb.table_name, tb.status
from DBA_TABLES tb
where (tb.owner, tb.table_name) not in 
	(select owner, table_name from dba_external_tables);
	
-- required privs
GRANT READ ON DIRECTORY test_dir TO apex_table_owner;
GRANT WRITE ON DIRECTORY test_dir TO apex_table_owner;

-- create external table
CREATE TABLE ext_wmusage
	(ts_name	VARCHAR2(25),
	 megabytes	NUMBER,
	 sampledate	VARCHAR2(12),
	 db_name	VARCHAR2(6)
	)
ORGANIZATION EXTERNAL
(
	TYPE ORACLE_LOADER
	DEFAULT DIRECTORY test_dir
	ACCESS PARAMETERS
	(
	  records delimited by newline
	  badfile test_dir:'WM_TablespaceGrowth_Usage.bad'
	  logfile test_dir:'WM_TablespaceGrowth_Usage.log'
	  fields terminated by whitespace
	  missing field values are null
	  (ts_name, megabytes, sampledate, db_name)
	)
	LOCATION ('WM_TablespaceGrowth_Usage.txt')
)
REJECT LIMIT UNLIMITED;

-- query just like normal table
select ts_name, megabytes*1024*1024, to_date(sampledate,'DD/MM/YYYY'), db_name
from ext_tsusage;

-- populate normal table from external
INSERT INTO apex_ts_history
	(apex_ts_history_id, tablespace_name, total_bytes, tmstamp, db_name)
select apex_ts_history_seq.nextval, inner_view.*
from	(select ts_name, megabytes*1024*1024, to_date(sampledate,'DD/MM/YYYY'), db_name
	 from ext_tsusage) inner_view;


##########################
# INDEX-ORGANIZED TABLES #
##########################

-- create a normal IOT
CREATE TABLE album_sales_details_iot
	(album_id	NUMBER, 
	 country_id	NUMBER, 
	 total_sales 	NUMBER, 
	 description 	VARCHAR2(1000), 
   CONSTRAINT album_sales_det_pk PRIMARY KEY(album_id, country_id)) 
ORGANIZATION INDEX;

-- create IOT with overflow
-- all cols up to & including total_sales are created in IOT structure
-- all cols after total_sales are created in overflow area
CREATE TABLE album_sales_details_iot2
	(album_id 	NUMBER, 
	country_id 	NUMBER, 
	total_sales 	NUMBER, 
	description 	VARCHAR2(1000), 
   CONSTRAINT album_sales_det_pk2 PRIMARY KEY(album_id, country_id))
ORGANIZATION INDEX INCLUDING total_sales OVERFLOW TABLESPACE bowie2;

(NOTE:	If the PK columns are not listed first, Oracle re-orders them before applying the INCLUDING
	clause. This means only the PKs will be stored in the IOT; the others in the overflow.)



select last_analyzed from dba_tab_statistics where table_name='POLPART';


SELECT table_name FROM dba_indexes WHERE index_name = '&what_index';
SELECT iot_name FROM dba_tables WHERE table_name = '&what_table';


ALTER TABLE my_iot MOVE TABLESPACE ts_i01;
ALTER TABLE my_iot MOVE OVERFLOW TABLESPACE ts_i01;


ALTER TABLE my_iot MOVE 

	
ALTER TABLE admin_docindex MOVE;
ALTER TABLE admin_docindex MOVE ONLINE;
ALTER TABLE admin_docindex MOVE TABLESPACE admin_tbs2 
    OVERFLOW TABLESPACE admin_tbs3;

ALTER TABLE admin_docindex MOVE "part_name" [mapping table] update indexes (index_name (ind_part_name))

alter table SYSMAN.EM_METRIC_VALUES move partition "2013-01-23 00:00" update indexes (sysman.EM_METRIC_VALUES_PK (partition "2013-01-23 00:00"));


################
# QUEUE TABLES #
################

-- drop
exec dbms_aqadm.drop_queue_table (queue_table=>'SYSMAN.AQ$_MGMT_HOST_PING_QTABLE_G',force=>TRUE);

-- rename




-- get table definition
set long 50000
set lines 120 pages 0
select DBMS_METADATA.GET_DDL('TABLE','&what_table','&what_schema') from DUAL;

select DBMS_METADATA.GET_DDL('TABLE','&what_table') from DUAL;

spool trunc_tables_ms7.out
select 'truncate table ms7.'||table_name||';' from dba_tables where owner='MS7' order by table_name;
spool off

-- ###########
-- # TESTING #
-- ###########

-- create sequence
CREATE SEQUENCE sys.LOGON_AUDIT_LOG_seq
START WITH 1 INCREMENT BY 1
NOMAXVALUE NOCYCLE;

-- add random data
INSERT INTO sys.LOGON_AUDIT_LOG
	SELECT	'DUMMY'||sys.LOGON_AUDIT_LOG_seq.nextval,
			dbms_random.string('U',trunc(dbms_random.value(3,30))),
			TRUNC(dbms_random.value(1,999)),
			TRUNC(dbms_random.value(1,9999)),
			sysdate,
			dbms_random.string('U',trunc(dbms_random.value(8,64))),
			dbms_random.string('U',trunc(dbms_random.value(8,64)))
	FROM  dual
CONNECT BY level <= &num_rows;

ORA-01653: unable to extend table SYS.LOGON_AUDIT_LOG by 8 in tablespace
LOGON_AUDIT_DATA