-- #####################
-- # ENABLING AUDITING #
-- #####################

-- parameter AUDIT_TRAIL = { none | os | db | db,extended | xml | xml,extended }
-- requires restart
ALTER SYSTEM SET audit_trail=db SCOPE=SPFILE;


-- ##################
-- # START AUDITING #
-- ##################

-- as dba
-- audit sql statements
AUDIT ALL BY &usrname BY ACCESS;
AUDIT SELECT TABLE, UPDATE TABLE, INSERT TABLE, DELETE TABLE BY &usrname BY ACCESS;
AUDIT EXECUTE PROCEDURE BY &usrname BY ACCESS;

-- log only once per session
AUDIT EXECUTE PROCEDURE BY &usrname BY SESSION;

-- log only failed attempts
AUDIT EXECUTE PROCEDURE BY &usrname BY SESSION WHENEVER NOT SUCCESSFUL;

-- audit use of sys privs
AUDIT CREATE TABLE BY &usrname BY ACCESS;
AUDIT ALL PRIVILEGES BY &usrname BY ACCESS;

-- audit the use of specific objects
AUDIT ALTER ON &tbl_owner.&tbl_name BY ACCESS;


-- ###############
-- # AUDIT TRAIL #
-- ###############

-- views
SYS.AUD$			-- stores all audit info; should be archived regularly
DBA_AUDIT_EXISTS
DBA_AUDIT_OBJECT
DBA_AUDIT_POLICIES
DBA_AUDIT_POLICY_COLUMNS
DBA_AUDIT_SESSION
DBA_AUDIT_STATEMENT
DBA_AUDIT_TRAIL			-- standard auditing only
DBA_FGA_AUDIT_TRAIL		-- fine-grained auditing only
DBA_COMMON_AUDIT_TRAIL		-- both standard & fine-grained auditing
DBA_OBJ_AUDIT_OPTS
DBA_PRIV_AUDIT_OPTS
DBA_REPAUDIT_ATTRIBUTE
DBA_REPAUDIT_COLUMN
DBA_STMT_AUDIT_OPTS

-- basic info
COLUMN username FORMAT A10
COLUMN owner    FORMAT A10
COLUMN obj_name FORMAT A10
COLUMN extended_timestamp FORMAT A35
SELECT username, extended_timestamp, owner, obj_name, action_name
FROM   dba_audit_trail WHERE  owner = '&aud_obj_owner'
ORDER BY timestamp;

-- reading info in XML audit trail
COLUMN db_user       FORMAT A10
COLUMN object_schema FORMAT A10
COLUMN object_name   FORMAT A10
COLUMN extended_timestamp FORMAT A35
SELECT db_user, extended_timestamp, object_schema, object_name, action
FROM   v$xml_audit_trail WHERE  object_schema = '&aud_obj_owner'
ORDER BY extended_timestamp;


-- ####################
-- # AUDIT MANAGEMENT #
-- ####################

-- clean (delete records from) audit trail
DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
   audit_trail_type         IN PLS_INTEGER,
   use_last_arch_timestamp  IN BOOLEAN DEFAULT TRUE,
   container                IN PLS_INTEGER DEFAULT CONTAINER_CURRENT,
   database_id              IN NUMBER DEFAULT NULL,
   container_guid           IN VARCHAR2 DEFAULT NULL);

/*
audit_trail_type	AUDIT_TRAIL_ALL - all types
					AUDIT_TRAIL_AUD_STD - records in SYS.AUD$
					AUDIT_TRAIL_OS - OS audit trail
*/


/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ clean up @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */

-- idwd - lxoradwsd02
sho parameter audit
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
audit_file_dest                      string      /database/cidwd_admn01/admin/a
                                                 udit/
audit_sys_operations                 boolean     TRUE
audit_syslog_level                   string
audit_trail                          string      DB
unified_audit_sga_queue_size         integer     1048576

select count(*) from aud$;
51

alter session set container=idwd;
select count(*) from aud$;
25,909,203

set lines 150 pages 200
col "Table" format a50
col tablespace_name format a20
col "GB" format 999,999,999
SELECT	t.owner||'.'||t.table_name AS "Table", t.tablespace_name, s.segment_type, round(s.bytes/1024/1024/1024,0) "GB"
FROM	dba_segments s, dba_tables t
WHERE	s.segment_type like 'TABLE%' AND s.segment_name=t.table_name AND t.table_name='AUD$'
ORDER BY t.owner, t.table_name, s.segment_type;
Table                                              TABLESPACE_NAME      SEGMENT_TYPE                 GB
-------------------------------------------------- -------------------- ------------------ ------------
SYS.AUD$                                           SYSTEM               TABLE                         4

col file_id format 990
col file_name format a75
col "MB" format 9,999,990
col "MaxMB" format 9,999,990
break on report;
compute sum label "TOTAL" of "MB" "MaxMB" on REPORT;
select file_id, file_name, (bytes/1024/1024) "MB", 
(decode(maxbytes,0,bytes,maxbytes)/1024/1024) "MaxMB", autoextensible
from dba_data_files
where tablespace_name=upper('SYSTEM') 
order by file_name;
FILE_ID FILE_NAME                                                                           MB      MaxMB AUT
------- --------------------------------------------------------------------------- ---------- ---------- ---
     18 /database/idwd01/oradata/system01.dbf                                            5,150     32,768 YES

truncate table sys.aud$;
select count(*) from aud$;
0

Table                                              TABLESPACE_NAME      SEGMENT_TYPE                 GB
-------------------------------------------------- -------------------- ------------------ ------------
SYS.AUD$                                           SYSTEM               TABLE                         0

ALTER SYSTEM SET audit_trail = 'NONE' SCOPE=both;
ORA-02095: specified initialization parameter cannot be modified

ALTER SYSTEM SET audit_trail = 'NONE' SCOPE=spfile;


-- #########################
-- # FINE-GRAINED AUDITING #
-- #########################

-- create FGA policy
BEGIN
  DBMS_FGA.add_policy(
    object_schema   => 'AUDIT_TEST',
    object_name     => 'EMP',
    policy_name     => 'SALARY_CHK_AUDIT',
    audit_condition => 'SAL > 50000',
    audit_column    => 'SAL');
END;
/

-- using procedure in FGA policy
BEGIN
  DBMS_FGA.add_policy(
    object_schema   => 'AUDIT_TEST',
    object_name     => 'EMP',
    policy_name     => 'SALARY_CHK_AUDIT',
    audit_condition => 'SAL > 50000',
    audit_column    => 'SAL',
    handler_schema  => 'AUDIT_TEST',
    handler_module  => 'FIRE_CLERK',
    enable          => TRUE);
END;
/


-- ##############
-- # REFERENCES #
-- ##############

http://www.oracle-base.com/articles/10g/Auditing_10gR2.php