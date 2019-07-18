-- ############
-- # DATABASE #
-- ############

col "Obj Count" format 999,990
col "Ext Count" format 999,990
col Blocks format 99,999,990
col "GB" format 9,999,990
select count(*) "Obj Count", sum(extents) AS "Ext Count",
   sum((bytes/1024/1024/1024)) AS "GB", sum(blocks) AS "Blocks"
from dba_segments;

clear breaks;
clear computes;
break on report;
compute sum label "TOTAL" of "Obj Count", "Ext Count", "GB", Blocks on report;
select segment_type, count(*) "Obj Count", sum(extents) AS "Ext Count",
   sum((bytes/1024/1024/1024)) AS "GB", sum(blocks) AS "Blocks"
from dba_segments
group by segment_type order by segment_type;


-- ##########
-- # TABLES #
-- ##########

-- find size of table, its LOBs and indexes
undefine what_table
col segment_name format a40
col "KB" format 9,999,990
select seg.segment_name, (seg.bytes/1024) "KB"
from dba_segments seg join dba_tables tab on seg.segment_name=tab.table_name
where seg.segment_type like '%TABLE%' and tab.table_name='&&what_table'
union all
select seg.segment_name, (seg.bytes/1024) "KB"
from dba_segments seg join dba_lobs lob on seg.segment_name=lob.segment_name
where lob.table_name='&&what_table'
union all
select seg.segment_name, (seg.bytes/1024) "KB"
from dba_segments seg join dba_indexes ind on seg.segment_name=ind.index_name
where seg.segment_type like '%INDEX%' and ind.table_name='&&what_table';

-- size of table partitions with LOB size included
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

-- gather stats on a table to get most up-to-date info
exec DBMS_STATS.GATHER_TABLE_STATS ('schema','table',NULL,100);


-- ###############
-- # TABLESPACES #
-- ###############

-- find block size of a tablespace
select block_size from dba_tablespaces where tablespace_name='&ts_name';

-- every TS summarized by obj count, bytes, blocks and extents
clear breaks;
clear computes;
col "Tablespace" format a40
col "Obj Count" format 999,990
col "Ext Count" format 999,990
col Blocks format 99,999,990
break on report;
compute sum label "TOTAL" of "Obj Count", "Ext Count", "MB", Blocks on report;
select tablespace_name AS "Tablespace", count(*) "Obj Count", sum(extents) AS "Ext Count",
   sum((bytes/1024/1024)) AS "MB", sum(blocks) AS "Blocks" from dba_segments
group by tablespace_name;

-- find list of blocks & their segments
-- not very practical for files/TS with lots of objects
col "OBJECT" format a40
col "KB" format 9,999,990
select file_id, block_id first, block_id+blocks-1 last, (bytes/1024) "KB", owner||'.'||segment_name "OBJECT", segment_type
  from dba_extents where file_id=&file_num
union all
select file_id, block_id, block_id+blocks-1, (bytes/1024) "KB", '---free---', NULL
  from dba_free_space where file_id=&&file_num
order by file_id, first;

-- TS info summarized by file/segment with size & segment type
undefine what_ts
break on file_id skip 1;
compute sum label "KB Free" of "KB" on file_id;
col object format a45
select file_id, (sum(bytes)/1024) "KB", OBJECT, segment_type
from (
  select file_id, bytes, owner||'.'||segment_name "OBJECT", segment_type
    from dba_extents where tablespace_name='&&what_ts'
  union all
  select file_id, bytes, '---free---', NULL
    from dba_free_space where tablespace_name='&&what_ts')
group by file_id, OBJECT, segment_type
order by file_id, OBJECT, segment_type;

-- file info summarized by segment with size & segment type
break on file_id;
compute sum label "KB Free" of "KB" on file_id;
col object format a45
select file_id, (sum(bytes)/1024) "KB", OBJECT, segment_type
from (
  select file_id, bytes, owner||'.'||segment_name "OBJECT", segment_type
    from dba_extents where file_id=&what_file
  union all
  select file_id, bytes, '---free---', NULL
    from dba_free_space where file_id=&what_file)
group by file_id, OBJECT, segment_type
order by file_id, OBJECT, segment_type;

break on file_id
col "OBJECT" format a40
col "MB" format 9,999,990
select file_id, (sum(bytes)/1024/1024) "MB", segment_type from (
  select file_id, bytes, segment_type
    from dba_extents where tablespace_name='&what_ts'
  union all
  select file_id, bytes, '---free---'
    from dba_free_space where tablespace_name='&what_ts')
group by file_id, segment_type
order by file_id, segment_type;


-- see just the free space in a tablespace
col "KB" format 99,999,990
break on file_id;
compute sum label "KB Free" of "KB" on file_id;
select file_id, block_id first, block_id+blocks-1 last, (bytes/1024) "KB"
  from dba_free_space where tablespace_name = '&tbs_name'
order by file_id, first;

-- see free space in a datafile
col "KB" format 99,999,990
break on file_id;
compute sum label "KB Free" of "KB" on file_id;
select file_id, block_id first, block_id+blocks-1 last, (bytes/1024) "KB"
  from dba_free_space where file_id=&file_num
order by file_id, first;


-- get segment breakdown of a tablespace (not good for large TS)
SET SERVEROUTPUT ON;
DECLARE
  CURSOR c1 IS
    select file_id, block_id, blocks, bytes, segment_name, segment_type
    from dba_extents where tablespace_name = 'GGS'
    order by file_id, block_id;
  v_fileid	NUMBER;
  v_blockid	NUMBER;
  v_blocks	NUMBER;
  v_bytes	NUMBER;
  v_segname	VARCHAR2(81);
  v_segtype	VARCHAR2(18);
  v_oldfileid	NUMBER;
  v_startblock	NUMBER;
  v_endblock	NUMBER;
  v_ttlblocks	NUMBER;
  v_ttlbytes	NUMBER;
  v_oldsegname	VARCHAR2(81);
  v_oldsegtype	VARCHAR2(18);
  v_first	CHAR(1) := 'Y';
BEGIN
  -- print header
  DBMS_OUTPUT.PUT_LINE('FILE  FIRST      LAST    MB     SEGMENT NAME                    SEGMENT TYPE');
  DBMS_OUTPUT.PUT_LINE('---- ------ --------- -----     ------------------------------- ------------------');
  OPEN c1;
  LOOP
    -- get first record
    FETCH c1 INTO v_fileid, v_blockid, v_blocks, v_bytes, v_segname, v_segtype;
    -- end loop if no new record (will cause problem with last record?)
    EXIT WHEN c1%NOTFOUND;
    -- is this first record
    IF v_first = 'Y' THEN
      -- set old variables
      v_oldfileid := v_fileid;
      v_startblock := v_blockid;
      v_ttlblocks := v_blocks;
      v_ttlbytes := v_bytes;
      v_oldsegname := v_segname;
      v_oldsegtype := v_segtype;
      v_first := 'N';
    -- not first record
    -- is there a break in blocks or change in segment
    ELSIF (v_blockid != v_startblock + v_ttlblocks) OR (v_segname != v_oldsegname) OR (v_segtype != v_oldsegtype) THEN
      -- set end block
      v_endblock := v_startblock+v_ttlblocks-1;
      -- convert bytes
      v_ttlbytes := trunc(v_ttlbytes/1024/1024,2);
      -- print details of segment
      DBMS_OUTPUT.PUT_LINE(v_oldfileid||'      	'||v_startblock||'       '||v_endblock||'	'||v_ttlbytes||'	'||v_oldsegname||'			'||v_oldsegtype);
      -- reset variables
      v_oldfileid := v_fileid;
      v_startblock := v_blockid;
      v_ttlblocks := v_blocks;
      v_ttlbytes := v_bytes;
      v_oldsegname := v_segname;
      v_oldsegtype := v_segtype;
    -- not first record but continuation of previous record
    ELSE
      -- update totals
      v_ttlblocks := v_blocks + v_ttlblocks;
      v_ttlbytes := v_bytes + v_ttlbytes;
    END IF;
  END LOOP;
  CLOSE c1;
  -- set end block
  v_endblock := v_startblock+v_ttlblocks-1;
  -- convert bytes
  v_ttlbytes := trunc(v_ttlbytes/1024/1024,2);
  -- print details of last segment
  DBMS_OUTPUT.PUT_LINE(v_oldfileid||'      	'||v_startblock||'       '||v_endblock||'	'||v_ttlbytes||'	'||v_oldsegname||'			'||v_oldsegtype);
END;
/


-- ###############
-- # ALL OBJECTS #
-- ###############

/*** these reflect the actual space used ***/
/*** whereas dba_data_files reflects the high water mark ***/

-- find objects in a tablespaces and their sizes
clear breaks;
clear computes;
break on owner skip 1 on report;
compute sum label "TOTAL" of MB on owner;
compute sum label "GRAND TOTAL" of MB on report;
col owner format a25
col segment_name format a30
col MB format 999,990
select owner, segment_name, segment_type, (bytes/1024/1024) as MB from dba_segments
where tablespace_name='&ts_name' order by owner, segment_name;

-- find TS objects grouped by type
clear breaks;
clear computes;
break on owner skip 1 on report;
compute sum label "TOTAL" of MB on report;
col owner format a25
col segment_name format a30
col MB format 999,990
select owner, segment_type, (sum(bytes)/1024/1024) as MB from dba_extents
where tablespace_name='&ts_name' group by owner, segment_type
order by owner, segment_type;

-- find the object sizes of a file#
clear breaks;
clear computes;
break on owner skip 1 on report;
compute sum label "TOTAL" of MB on report;
col owner format a25
col segment_name format a30
col MB format 999,990
select owner, segment_type, (sum(bytes)/1024/1024) as MB from dba_extents
where file_id=&fileid group by owner, segment_type
order by owner, segment_type;

-- get the size of all LOBs in the included schemas
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs 
	where owner in ('ACTQUEUE','TNARCHIVE','ACTLOG','WMDOC','TNREPO');
	vOwner	dba_lobs.owner%TYPE;
	vTable	dba_lobs.table_name%TYPE;
	vCol	dba_lobs.column_name%TYPE;
	vSum	NUMBER := 9999;
	vCurrent	NUMBER;
BEGIN
	OPEN c1;
	LOOP
		FETCH c1 INTO vOwner, vTable, vCol;
		EXIT WHEN c1%NOTFOUND;
		execute immediate 'select sum(DBMS_LOB.GETLENGTH('||vCol||')) from '||vOwner||'.'||vTable||'' INTO vCurrent;
		IF vCurrent>0 THEN
			vSum := vSum + vCurrent;
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('vSum is '||vSum);
END;
/

-- get a list of LOBs in a tablespace
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs 
	where owner in ('ACTQUEUE','TNARCHIVE','ACTLOG','WMDOC','TNREPO')
	and tablespace_name='WM_REPOSITORY_X4M';
	vOwner	dba_lobs.owner%TYPE;
	vTable	dba_lobs.table_name%TYPE;
	vCol	dba_lobs.column_name%TYPE;
	vSum	NUMBER := 0;
	vCurrent	NUMBER;
BEGIN
	OPEN c1;
	LOOP
		FETCH c1 INTO vOwner, vTable, vCol;
		EXIT WHEN c1%NOTFOUND;
		execute immediate 'select sum(DBMS_LOB.GETLENGTH('||vCol||')) from '||vOwner||'.'||vTable||'' INTO vCurrent;
		IF vCurrent>0 THEN
			vSum := vSum + vCurrent;
			DBMS_OUTPUT.PUT_LINE(vCurrent||'  '||vOwner||'.'||vTable);
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('Total MB '||vSum);
END;
/

--
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs 
	where owner in ('ACTQUEUE','TNARCHIVE','ACTLOG','WMDOC','TNREPO')
	and tablespace_name='WM_REPOSITORY_X4M';
	vOwner	dba_lobs.owner%TYPE;
	vTable	dba_lobs.table_name%TYPE;
	vCol	dba_lobs.column_name%TYPE;
	vSum	NUMBER := 0;
	vCurrent	NUMBER;
BEGIN
	OPEN c1;
	LOOP
		FETCH c1 INTO vOwner, vTable, vCol;
		EXIT WHEN c1%NOTFOUND;
		execute immediate 'select sum(DBMS_LOB.GETLENGTH('||vCol||')) from '||vOwner||'.'||vTable||'' INTO vCurrent;
		IF vCurrent>0 THEN
			vSum := vSum + vCurrent;
			DBMS_OUTPUT.PUT_LINE(vCurrent||'  '||vOwner||'.'||vTable);
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('Total MB '||vSum);
END;
/


-- ################
-- # USER OBJECTS #
-- ################

-- find the names, types and status of a user's objects
break on object_type;
col object_name format a30
select object_type, object_id, object_name, status
from dba_objects where owner='&username' order by object_type, object_name;

-- find a user's objects when logged in as that user
set pagesize 100
col object_name format a40
select object_name, object_id, object_type
from user_objects order by object_type, object_name;

-- find the sizes of a user's objects
clear breaks;
clear computes;
set pagesize 300;
set numformat 999,999,990
col segment_name format a30;
break on segment_type on report;
compute sum label TOTAL of "MB", blocks on report;
select segment_type, segment_name, (sum(bytes)/1024/1024) AS "MB", sum(blocks) "BLOCKS" from dba_segments
where owner='&username' 
group by segment_type, segment_name
order by segment_type, segment_name;

-- same with segment count instead of names
clear breaks;
clear computes;
break on report;
compute sum label TOTAL of "SEGS", "MB", "BLKS" on report;
select segment_type, count(*) "SEGS", (sum(bytes)/1024/1024) AS "MB", sum(blocks) "BLKS" from dba_segments
where owner='&username' group by segment_type order by segment_type;

-- find the sizes of a user's objects when logged in as that user
clear breaks;
clear computes;
set pagesize 100;
set numformat 999,999,990
col segment_name format a25;
col segment_type format a25;
break on report;
compute sum label "TOTAL" of "MB" on report;
select segment_name, segment_type, (bytes/1024/1024) AS "MB"
from user_segments order by segment_name;


-- ######################
-- # SEGMENTS / EXTENTS #
-- ######################

col "MB" format 999,999,990
col extents format 999,999,990
col max_extents format 999,999,990
col segment_name format a25
col partition_name format a20
select segment_name, partition_name, (bytes/1024/1024) AS "MB", extents, max_extents
from dba_segments where segment_name='&segname';

col file_name format a40
select distinct df.file_id, df.file_name, (df.bytes/1024/1024) AS "MB", (df.maxbytes/1024/1024) AS "MaxMB", df.autoextensible
from dba_data_files df join dba_extents ext on df.file_id=ext.file_id
where ext.segment_name='SYS_LOB0000010937C00008$$' and ext.partition_name='SYS_LOB_P743';


-- #################
-- # LOGDB QUERIES #
-- #################

-- sizes of TS objects from last night
set lines 120 pages 200
break on "LOG DATE"
col segment_name format a40
select round(log_date) "LOG DATE", segment_name, (bytes/1024/1024) "MB"
from actstats.segment_HISTORY where database='DW' and tablespace_name='CDC_ADMIN_X1M' 
  and round(log_date) > (sysdate-1) order by 1,2;

