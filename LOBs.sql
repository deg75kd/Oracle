-- ##############
-- # CONVERSION #
-- ##############

-- convert CLOB to VARCHAR2
dbms_lob.substr( clob_column, for_how_many_bytes, from_which_byte );

-- with sqlplus max size is 4000
select dbms_lob.substr( x, 4000, 1 ) from T;

-- with pl/sql max size is 32k
declare
   my_var long;
begin
   for x in ( select X from t ) 
   loop
       my_var := dbms_lob.substr( x.X, 32000, 1 );
       ....


-- ###########
-- # QUERIES #
-- ###########

-- size of all LOB segments
set lines 150 pages 200
break on report;
compute sum label "TOTAL" of "GB" on report;
col column_name format a30
select a.owner, a.table_name, a.column_name, a.index_name, round(b.bytes/1024/1024/1024,2) GB
from dba_lobs a, dba_segments b
where a.segment_name=b.segment_name and a.owner not in
('GGS','ANONYMOUS','APEX_030200','APEX_040200','APPQOSSYS','AUDSYS','AUTODDL','CTXSYS','DB_BACKUP','DBAQUEST','DBSNMP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_FILES','GSMADMIN_INTERNAL','INSIGHT','LBACSYS','MDSYS','OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','OUTLN','RMAN','SI_INFORMTN_SCHEMA','SYS','SYSTEM','WMSYS','XDB','XS$NULL','DIP','ORACLE_OCM','ORDPLUGINS','OPS$ORACLE','UIMMONITOR','AUTODML','ORA_QUALYS_DB','APEX_PUBLIC_USER','GSMCATUSER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYSBACKUP','SYSDG','SYSKM','SYSMAN','MGMT_USER','MGMT_VIEW','OWB$CLIENT','OWBSYS','TRCANLZR','GSMUSER','MDDATA','PDBADMIN','OWBSYS_AUDIT','TSMSYS','GGTEST')
order by 1,2,3;


-- get length in bytes of LOB
select sum(DBMS_LOB.GETLENGTH('SQL_FULLTEXT')) from ACTD00.SQL_HISTORY;

-- get the total size of all LOBs in the included schemas
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs 
	where owner in ('FISERV_GTWY');
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

-- get a list of all LOBs in the included schemas and their sizes
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs
	where owner in ('BLC_EAPP_GTWY','FISERV_GTWY','GTWY_APP_USER','AGT_PROV','LIFERAY')
	order by owner, table_name;
	--and tablespace_name='WM_REPOSITORY_X4M';
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
			vCurrent := vCurrent/1024/1024;
			DBMS_OUTPUT.PUT_LINE(vOwner||'.'||vTable||' '||vCurrent||'MB');
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('Total MB '||vSum);
END;
/

-- get a list of LOBs in a tablespace
set serveroutput on
DECLARE
	CURSOR c1 IS
	select owner, table_name, column_name from dba_lobs 
	where owner in ('ACTQUEUE','TNARCHIVE','ACTLOG','WMDOC','TNREPO')
	and tablespace_name='WM_REPOSITORY_X128M';
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
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('Total MB '||vSum);
END;
/

-- partitioned LOBs in a tablespace
set serveroutput on
DECLARE
	CURSOR c1 IS
	select table_owner, table_name, partition_name, column_name from dba_lob_partitions
	where table_owner in ('ACTQUEUE','TNARCHIVE','ACTLOG','WMDOC','TNREPO')
	and tablespace_name='WM_REPOSITORY_X128M';
	vOwner	dba_lob_partitions.owner%TYPE;
	vTable	dba_lob_partitions.table_name%TYPE;
	vPart	dba_lob_partitions.partition_name%TYPE;
	vCol	dba_lob_partitions.column_name%TYPE;
	vTotalSum	NUMBER := 0;
	vPartSun	NUMBER := 0;
	vCurrent	NUMBER;
BEGIN
	OPEN c1;
	LOOP
		FETCH c1 INTO vOwner, vTable, vPart, vCol;
		EXIT WHEN c1%NOTFOUND;
		execute immediate 'select sum(DBMS_LOB.GETLENGTH('||vCol||')) from '||vOwner||'.'||vTable||'' INTO vCurrent;
		IF vCurrent>0 THEN
			vSum := vSum + vCurrent;
		END IF;
	END LOOP;
	CLOSE c1;
	vSum := vSum/1024/1024;
	DBMS_OUTPUT.PUT_LINE('Total MB '||vSum);
END;
/

-- get a list of LOBs
col column_name format a40
select owner, table_name, column_name, tablespace_name
from dba_lobs
where owner ='&what_owner'
--not in ('SYS','SYSTEM','OUTLN')
order by owner, table_name, column_name;

-- get details & sizes (if stats current)
select a.owner, a.table_name, a.column_name, a.segment_name, a.index_name, b.bytes/1024/1024 MB
from dba_lobs a, dba_segments b
where a.segment_name=b.segment_name and a.table_name in
  ('APP_EMP_DTL_FORM','APP_PAYLD')
order by 1,2,3;

--
select table_owner, table_name, tablespace_name
from dba_lob_partitions
where table_owner ='&what_owner'
-- not in ('SYS','SYSTEM','OUTLN')
order by table_owner, table_name, tablespace_name;

-- size of partitions with a LOB column
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



##############
# CORRUPTION #
##############

-- look for data corruption in LOB
drop table bad_rows;
create table bad_rows (row_id ROWID
                      ,oracle_error_code number);

undefine lob_column
undefine table_owner
undefine table_with_lob

set concat off
set serveroutput on
declare
  n number;
  error_code number;
  bad_rows number := 0;
  ora600 EXCEPTION;
  PRAGMA EXCEPTION_INIT(ora600, -600);
begin
   for cursor_lob in (select rowid rid, &&lob_column from &&table_owner.&table_with_lob) loop
   begin
     n:=dbms_lob.instr(cursor_lob.&&lob_column,hextoraw('889911')) ;
   exception
    when ora600 then
     bad_rows := bad_rows + 1;
     insert into bad_rows values(cursor_lob.rid,600);
     commit;
    when others then
     error_code:=SQLCODE;
     bad_rows := bad_rows + 1;
     insert into bad_rows values(cursor_lob.rid,error_code);
     commit;  
   end;
  end loop;
  dbms_output.put_line('Total Rows identified with errors in LOB column:'||bad_rows);
end;
/

select * from bad_rows;





-- looking for largest CLOBs in a table
set serveroutput on
DECLARE
	CURSOR c1 IS
		select owner, table_name, column_name from dba_lobs
		where table_name='APP_PAYLD' and owner='BLC_EAPP_GTWY';
	CURSOR c2 IS
		select APP_PAYLD_ID from BLC_EAPP_GTWY.APP_PAYLD;
	vOwner	dba_lobs.owner%TYPE;
	vTable	dba_lobs.table_name%TYPE;
	vCol	dba_lobs.column_name%TYPE;
	vID		NUMBER;
	vSum	NUMBER := 0;
	vCurrent	NUMBER;
BEGIN
	OPEN c2;
	OPEN c1;
	LOOP
		FETCH c1 INTO vOwner, vTable, vCol;
		EXIT WHEN c1%NOTFOUND;
		LOOP
			FETCH c2 INTO vID;
			EXIT WHEN c2%NOTFOUND;
				execute immediate 'select DBMS_LOB.GETLENGTH('||vCol||') from '||vOwner||'.'||vTable||' where APP_PAYLD_ID='||vID INTO vCurrent;
				IF vCurrent>4194304 THEN
					vCurrent := round(vCurrent/1024/1024,0);
					DBMS_OUTPUT.PUT_LINE(vID||' '||vCurrent||' MB');
				END IF;
			END LOOP;	
	END LOOP;
	CLOSE c1;
	CLOSE c2;
END;
/


select APP_EMP_DTL_FORM_ID, dbms_lob.getlength('FORM') 
from BLC_EAPP_GTWY.APP_EMP_DTL_FORM
where ;


select a.owner, a.table_name, a.column_name, a.segment_name, a.index_name, b.bytes/1024/1024 MB
from dba_lobs a, dba_segments b
where a.segment_name=b.segment_name and a.table_name='APP_EMP_DTL_FORM' and a.owner='BLC_EAPP_GTWY'
order by 1,2,3;


