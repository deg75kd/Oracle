-- ###################
-- # TRIGGER QUERIES #
-- ###################

-- find system triggers
SELECT a.obj#, a.sys_evts, b.name
FROM trigger$ a,obj$ b, 
WHERE a.sys_evts > 0 AND a.obj#=b.obj#
AND a.obj
AND baseobject = 0;

-- details of trigger
-- may be several rows if item/schema duplicated
set lines 150 pages 200
col "TRIGGER" format a40
col description format a65
col status format a12
col "OBJ_STATUS" format a12
SELECT dt.owner||'.'||dt.trigger_name "TRIGGER", dt.status, do.status "OBJ_STATUS", dt.description
FROM dba_triggers dt join dba_objects do on dt.trigger_name=do.object_name
WHERE do.object_type='TRIGGER' and dt.trigger_name='&what_trigger';

-- with trigger body
set lines 150 pages 200
col "TRIGGER" format a40
col description format a65
col status format a12
set long 100000
SELECT dt.owner||'.'||dt.trigger_name "TRIGGER", do.status, dt.description, dt.trigger_body
FROM dba_triggers dt join dba_objects do on dt.trigger_name=do.object_name
WHERE do.object_type='TRIGGER' and dt.trigger_name='&what_trigger';

TRIGGER_TYPE
•BEFORE STATEMENT
•BEFORE EACH ROW
•AFTER STATEMENT
•AFTER EACH ROW
•INSTEAD OF
•COMPOUND

TRIGGERING_EVENT
DML
DDL
database event

BASE_OBJECT_TYPE
•TABLE
•VIEW
•SCHEMA
•DATABASE



set lines 150 pages 200
col "TRIGGER" format a40
col TRIGGERING_EVENT format a20
col status format a12
SELECT dt.owner||'.'||dt.trigger_name "TRIGGER", dt.TRIGGER_TYPE, dt.TRIGGERING_EVENT, do.status, dt.BASE_OBJECT_TYPE
FROM dba_triggers dt join dba_objects do on dt.trigger_name=do.object_name
WHERE do.object_type='TRIGGER' --and dt.TRIGGERING_EVENT='DDL'
ORDER BY dt.owner, dt.trigger_name;

-- #################
-- # ALTER TRIGGER #
-- #################

-- enable/disable trigger
ALTER TRIGGER &trig_name DISABLE;
ALTER TRIGGER &trig_name ENABLE;

-- drop trigger
DROP TRIGGER <trigger_name>;

-- recompile a trigger
alter trigger LOGFILEHISTORY_AWESITE_BI compile;
alter trigger LOGFILEHISTORY_AWESITE_BI compile debug;


-- ##################
-- # CREATE TRIGGER #
-- ##################

/* Simple DML Triggers */
-- instead trigger
create or replace
TRIGGER instead_trg INSTEAD OF UPDATE...


/* Non-DML Triggers */
-- logon trigger (after)
create or replace trigger logon_actionafter
  after logon on database
declare
begin
  dqi.vpd_pkg.set_integration_id;
end;
/

-- logon trigger for specific users
CREATE OR REPLACE TRIGGER prevent_ny_users 
	AFTER LOGON 
	ON database when (user='BSARP') 
DECLARE 
	app_user VARCHAR2(30); 
	app_region useradmin.region%TYPE; 
BEGIN 
	SELECT osuser INTO app_user FROM v$session WHERE audsid = USERENV('sessionid'); 
 
	SELECT region INTO app_region 
	FROM bsarp.useradmin 
	WHERE userid = app_user; 
 
	IF ( app_region = 'NY' ) THEN 
		RAISE_APPLICATION_ERROR(-20001,'The system is not currently available for this region');
	END IF; 
 END; 
 / 

-- drop trigger (before)
create or replace
TRIGGER aw_drop_trg BEFORE DROP ON DATABASE
BEGIN
  aw_drop_proc(ora_dict_obj_type, ora_dict_obj_name, ora_dict_obj_owner);
END;
/


-- #####################
-- # SCHEMA v DATABASE #
-- #####################

A SCHEMA trigger is created on a schema and fires whenever the user who owns it is the current user and initiates the triggering event.

-- If this is created in the HR schema, when a user connected as HR tries to drop a database object, the database fires the trigger before dropping the object.
CREATE OR REPLACE TRIGGER drop_trigger
  BEFORE DROP ON hr.SCHEMA
  BEGIN
    RAISE_APPLICATION_ERROR (
      num => -20000,
      msg => 'Cannot drop object');
  END;
/

A DATABASE trigger is created on the database and fires whenever any database user initiates the triggering event.


-- ##########
-- # Test 1 #
-- ##########
-- http://psoug.org/reference/ddl_trigger.html

-- idevt (12c SB)
sqlplus / as sysdba
alter session set container=idevt;

CREATE TABLE ddl_log (
 operation   VARCHAR2(30),
 obj_owner   VARCHAR2(30),
 object_name VARCHAR2(30),
 sql_text    VARCHAR2(64),
 attempt_by  VARCHAR2(30),
 attempt_dt  DATE); 

-- ON SCHEMA
ORA-30510: system triggers cannot be defined on the schema of SYS user
-- changed to ON DATABASE

CREATE OR REPLACE TRIGGER ddl_trigger
BEFORE CREATE OR ALTER OR DROP
 ON DATABASE
DECLARE
  oper ddl_log.operation%TYPE;
 sql_text ora_name_list_t;
  i        PLS_INTEGER; 
BEGIN
   SELECT ora_sysevent
   INTO oper
   FROM DUAL;

   i := sql_txt(sql_text);

   IF oper IN ('CREATE', 'DROP') THEN
     INSERT INTO ddl_log
     SELECT ora_sysevent, ora_dict_obj_owner, 
    ora_dict_obj_name, sql_text(1), USER, SYSDATE
     FROM DUAL;
   ELSIF oper = 'ALTER' THEN
     INSERT INTO ddl_log
     SELECT ora_sysevent, ora_dict_obj_owner, 
    ora_dict_obj_name, sql_text(1), USER, SYSDATE
     FROM sys.gv_$sqltext
     WHERE UPPER(sql_text) LIKE 'ALTER%'
     AND UPPER(sql_text) LIKE '%NEW_TABLE%';
   END IF;
END ddl_trigger;
/

set lines 150 pages 200
col operation format a15
col obj_owner format a10
col object_name format a15
col sql_text format a40
col attempt_by format a10
SELECT * FROM ddl_log;

alter system flush shared_pool;
alter system flush shared_pool;

CREATE TABLE new_table (
 charcol VARCHAR(20));

SELECT * FROM ddl_log;
OPERATION       OBJ_OWNER  OBJECT_NAME     SQL_TEXT                                 ATTEMPT_BY ATTEMPT_DT
--------------- ---------- --------------- ---------------------------------------- ---------- ----------
CREATE          SYS        NEW_TABLE       CREATE TABLE new_table (                 SYS        01/11/2018
                                            charcol VARCHAR(20))

ALTER TABLE new_table
 ADD (numbcol NUMBER(10));

SELECT * FROM ddl_log;
OPERATION       OBJ_OWNER  OBJECT_NAME     SQL_TEXT                                 ATTEMPT_BY ATTEMPT_DT
--------------- ---------- --------------- ---------------------------------------- ---------- ----------
CREATE          SYS        NEW_TABLE       CREATE TABLE new_table (                 SYS        01/11/2018
                                            charcol VARCHAR(20))

ALTER           SYS        NEW_TABLE       ALTER TABLE new_table                    SYS        01/11/2018
                                            ADD (numbcol NUMBER(10))

ALTER USER ggtest identified by This1Works;

conn ggtest/This1Works@idevt
ALTER TABLE USERS_LINUX
 ADD (numbcol NUMBER(10));

conn / as sysdba
alter session set container=idevt;

SELECT * FROM ddl_log;
OPERATION       OBJ_OWNER  OBJECT_NAME     SQL_TEXT                                 ATTEMPT_BY ATTEMPT_DT
--------------- ---------- --------------- ---------------------------------------- ---------- ----------
CREATE          SYS        NEW_TABLE       CREATE TABLE new_table (                 SYS        01/11/2018
                                            charcol VARCHAR(20))

ALTER           SYS        NEW_TABLE       ALTER TABLE new_table                    SYS        01/11/2018
                                            ADD (numbcol NUMBER(10))

grant select, insert on ddl_log to ggtest;

conn ggtest/This1Works@idevt

CREATE TABLE new_table (
 charcol VARCHAR(20));
 
select * from sys.ddl_log;
OPERATION       OBJ_OWNER  OBJECT_NAME     SQL_TEXT                                 ATTEMPT_BY ATTEMPT_DT
--------------- ---------- --------------- ---------------------------------------- ---------- ----------
CREATE          SYS        NEW_TABLE       CREATE TABLE new_table (                 SYS        01/11/2018
                                            charcol VARCHAR(20))

ALTER           SYS        NEW_TABLE       ALTER TABLE new_table                    SYS        01/11/2018
                                            ADD (numbcol NUMBER(10))

CREATE          GGTEST     NEW_TABLE       CREATE TABLE new_table (                 GGTEST     01/11/2018
                                            charcol VARCHAR(20))


-- ##########
-- # Test 2 #
-- ##########

conn ggtest/This1Works@idevt
alter table QUOTA_AIX nologging;
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE1','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE2','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE3','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE4','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE5','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE6','USERS','1');
INSERT /*+ APPEND */ INTO QUOTA_AIX VALUES ('NO_ONE7','USERS','1');
commit;

alter table QUOTA_AIX move;

select status from all_indexes where index_name='QUOTA_AIX_PK_IX';
STATUS
--------
UNUSABLE

conn / as sysdba
alter session set container=idevt;

CREATE OR REPLACE TRIGGER rebuild_index_trg
	AFTER ALTER ON DATABASE
	WHEN (ora_dict_obj_type='TABLE')
DECLARE
	vObjType		VARCHAR2(30);
	vTblOwner		VARCHAR2(128);
	vTblName		VARCHAR2(128);
	vIndOwner		VARCHAR2(128);
	vIndName		VARCHAR2(128);
	vSQL			VARCHAR2(500);
	vStatus			VARCHAR2(30);
	vTable			PLS_INTEGER;
BEGIN
	SELECT ora_dict_obj_type INTO vObjType FROM dual;
	SELECT ora_dict_obj_owner INTO vTblOwner FROM DUAL;
	SELECT ora_dict_obj_name INTO vTblName FROM DUAL;
	
	INSERT INTO ddl_log
		SELECT ora_sysevent, ora_dict_obj_owner, ora_dict_obj_name, 'ALTER '||vTblOwner||'.'||vTblName, USER, SYSDATE
		FROM dual;

	IF vObjType='TABLE' THEN
		SELECT ai.status INTO vStatus
		FROM all_constraints ac, all_indexes ai
		WHERE ac.owner=ai.table_owner AND ac.table_name=ai.table_name
		AND ac.owner=vTblOwner AND ac.table_name=vTblName 
		AND ac.constraint_type='P';
		
		INSERT INTO ddl_log
		SELECT ora_sysevent, ora_dict_obj_owner, ora_dict_obj_name, 'PK is '||vStatus, USER, SYSDATE
		FROM dual;
		
		FOR i IN
			(SELECT 'ALTER INDEX '||ac.index_owner||'.'||ac.index_name||' REBUILD PARALLEL 64 nologging' cmd
			 FROM all_constraints ac, all_indexes ai
			 WHERE ac.owner=ai.table_owner AND ac.table_name=ai.table_name
			 AND ac.owner=vTblOwner AND ac.table_name=vTblName 
			 AND ac.constraint_type='P' AND ai.status='UNUSABLE')
		LOOP
			execute immediate i.cmd;
		END LOOP;
	ELSE
		INSERT INTO ddl_log
			SELECT ora_sysevent, ora_dict_obj_owner, ora_dict_obj_name, 'ALTER '||vObjType, USER, SYSDATE
			FROM dual;
	END IF;
	
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RAISE_APPLICATION_ERROR(-20998, 'No data found');
END rebuild_index_trg;
/

select status from all_indexes where index_name='QUOTA_AIX_PK_IX';
STATUS
--------
VALID

conn ggtest/This1Works@idevt

select status from all_indexes where index_name='QUOTA_AIX_PK_IX';
ALTER INDEX GGTEST.QUOTA_AIX_PK_IX REBUILD PARALLEL 64 nologging;
alter table QUOTA_AIX move;

SELECT ac.index_owner, ac.index_name
FROM all_constraints ac, all_indexes ai
WHERE ac.owner=ai.table_owner AND ac.table_name=ai.table_name
AND ac.owner='GGTEST' AND ac.table_name='QUOTA_AIX' 
AND ac.constraint_type='P' AND ai.status='UNUSABLE';
		
conn / as sysdba
alter session set container=idevt;
alter session set nls_date_format='HH24:MI:SS';

col operation format a15
col obj_owner format a10
col object_name format a15
col sql_text format a40
col attempt_by format a10
SELECT * FROM ddl_log order by attempt_dt;
TRUNCATE TABLE ddl_log;

