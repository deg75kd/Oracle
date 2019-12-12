
alter system set db_recovery_file_dest_size=40g scope=both;
alter system set db_recovery_file_dest='D:\oradata\PRODS\wm\Oracle\flash_recovery' scope=both;

-- turn on/off flashback
alter database flashback on;
alter database flashback off;

-- create restore point
-- DB can be mounted or open
-- if flashback not enabled, DB must be mounted
CREATE RESTORE POINT post_refresh_wmprods;

-- restore flashback DB
flashback database to RESTORE POINT post_refresh_wmprods;


-- ###############
-- # RECYCLE BIN #
-- ###############

-- check if it's on
show parameter recycle

-- disable recycle bin
ALTER SESSION SET recyclebin = OFF;
ALTER SYSTEM SET recyclebin = OFF SCOPE = BOTH;

-- enable recycle bin
ALTER SESSION SET recyclebin = ON;
ALTER SYSTEM SET recyclebin = ON SCOPE = BOTH;


-- see what's in recycle bin
-- indexes are restored with recycle bin names - run this to get system name
col "ORIGINAL_NAME" format a50
SELECT object_name, owner||'.'||original_name "ORIGINAL_NAME", createtime
FROM dba_recyclebin ORDER BY 2;
-- only your objects
SELECT object_name, original_name, createtime FROM recyclebin;

-- query a table in recycle bin
SELECT * FROM "BIN$yrMKlZaVMhfgNAgAIMenRA==$0";


-- restore table from recycle bin
FLASHBACK TABLE int_admin_emp TO BEFORE DROP;
-- restore table and rename it
FLASHBACK TABLE int_admin_emp TO BEFORE DROP 
   RENAME TO int2_admin_emp;
-- restore table using recycle bin name
FLASHBACK TABLE "BIN$yrMKlZaVMhfgNAgAIMenRA==$0" TO BEFORE DROP;


-- purge table from recycle bin
PURGE TABLE int_admin_emp;
-- purge table using recycle bin name
PURGE TABLE "BIN$jsleilx392mk2=293$0";

-- purge all tablespace objects
PURGE TABLESPACE example;
-- purge tablespace objects for one user
PURGE TABLESPACE example USER oe;

-- purge your stuff
PURGE RECYCLEBIN;
-- purge everything
PURGE DBA_RECYCLEBIN;


-- ################################
-- # Flashback Data Archive (FDA) #
-- ################################

-- https://oracle-base.com/articles/12c/flashback-data-archive-fda-enhancements-12cr1
-- https://docs.oracle.com/database/121/ADFNS/adfns_flashback.htm#ADFNS643

/*--- Queries ---*/
-- find FDAs
SET LINESIZE 150 PAGES 200
COLUMN owner_name FORMAT A20
COLUMN flashback_archive_name FORMAT A22
COLUMN create_time FORMAT A20
COLUMN last_purge_time FORMAT A20
SELECT owner_name,
       flashback_archive_name,
       flashback_archive#,
       retention_in_days,
       --TO_CHAR(create_time, 'DD-MON-YYYY HH24:MI:SS') AS create_time,
       --TO_CHAR(last_purge_time, 'DD-MON-YYYY HH24:MI:SS') AS last_purge_time,
       status
FROM   dba_flashback_archive
ORDER BY owner_name, flashback_archive_name;

-- Querying DBA_FLASHBACK_ARCHIVE View Gives ORA-08181 (Doc ID 1153794.1)
select OWNERNAME owner_name, 
	FANAME flashback_archive_name, 
	FA# flashback_archive#, 
	RETENTION retention_in_days, 
	--scn_to_timestamp(CREATESCN), 
	--scn_to_timestamp(PURGESCN), 
	decode(bitand(flags, 1), 1, 'DEFAULT', NULL) status
from SYS_FBA_FA
order by owner_name;

-- find FDA tablespaces
COLUMN flashback_archive_name FORMAT A22
COLUMN tablespace_name FORMAT A20
COLUMN quota_in_mb FORMAT A11
SELECT flashback_archive_name,
       flashback_archive#,
       tablespace_name,
       quota_in_mb
FROM   dba_flashback_archive_ts
ORDER BY flashback_archive_name;

-- find tables w/FDA enabled
COLUMN owner_name FORMAT A20
COLUMN table_name FORMAT A30
COLUMN flashback_archive_name FORMAT A22
COLUMN archive_table_name FORMAT A20
SELECT owner_name,
       table_name,
       flashback_archive_name,
       archive_table_name,
       status
FROM   dba_flashback_archive_tables
ORDER BY owner_name, table_name;

-- see sizes of tables and FDA archives
col owner format a20
col segment_name format a30
col segment_type format a20
col "MB" format 9,999,999,990
select s.owner, s.segment_name, s.segment_type, s.tablespace_name, (s.bytes/1024/1024) "MB"
from dba_segments s, dba_flashback_archive_ts ts,
  (SELECT owner_name, table_name, archive_table_name FROM dba_flashback_archive_tables) tbl
where s.tablespace_name=ts.tablespace_name
and s.owner=tbl.owner_name 
and (s.segment_name=tbl.table_name OR s.segment_name=tbl.archive_table_name)
order by s.tablespace_name, s.owner, s.segment_name, s.segment_type;


/*--- Privileges ---*/
-- grant necessary privs to user TEST
GRANT FLASHBACK ARCHIVE ON fda_1year TO test;		--> autoddl
GRANT FLASHBACK ARCHIVE ADMINISTER TO test;			--> dba
GRANT EXECUTE ON DBMS_FLASHBACK_ARCHIVE TO test;	--> app devs, app account ??
GRANT CREATE ANY CONTEXT TO test;					--> ???


/*--- FDA Changes ---*/
-- create TS and FDA w/ 1 year retention
CREATE TABLESPACE fda_ts DATAFILE SIZE 1M AUTOEXTEND ON NEXT 1M;
ALTER USER test QUOTA UNLIMITED ON fda_ts;
CREATE FLASHBACK ARCHIVE DEFAULT fda_1year 
  TABLESPACE fda_ts
  QUOTA 10G 			-- default quota is unlimited; get ORA-55621 if allocating more than user's quota on TS
  RETENTION 1 YEAR;
  
-- alter archive
ALTER FLASHBACK ARCHIVE fla1 SET DEFAULT;
ALTER FLASHBACK ARCHIVE fla1 ADD TABLESPACE tbs3 QUOTA 5G;
ALTER FLASHBACK ARCHIVE fla1 MODIFY RETENTION 2 YEAR;
ALTER FLASHBACK ARCHIVE fla1 REMOVE TABLESPACE tbs2;
ALTER FLASHBACK ARCHIVE fla1 PURGE BEFORE TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' DAY);

-- drop archive
DROP FLASHBACK ARCHIVE fla1;

-- alter amount of context to capture (ALL, TYPICAL or NONE)
EXEC DBMS_FLASHBACK_ARCHIVE.set_context_level('ALL');


/*--- Table Changes ---*/
-- create table associated with FDA
CREATE TABLE tab1 (
  id           NUMBER,
  description  VARCHAR2(50),
  CONSTRAINT tab_1_pk PRIMARY KEY (id)
) FLASHBACK ARCHIVE fda_1year;

-- alter existing table to use FDA
ALTER TABLE tab1 FLASHBACK ARCHIVE fda_1year;

-- drop table (remove from FDA first)
ALTER TABLE test.tab1 NO FLASHBACK ARCHIVE;
DROP TABLE test.tab1 PURGE;


/*--- Table Queries ---*/
-- query FDA tables
COLUMN versions_startscn FORMAT 99999999999999999
COLUMN versions_starttime FORMAT A24
COLUMN versions_endscn FORMAT 99999999999999999
COLUMN versions_endtime FORMAT A24
COLUMN versions_xid FORMAT A16
COLUMN versions_operation FORMAT A1
COLUMN session_user FORMAT A20
COLUMN client_identifier FORMAT A20
COLUMN my_attribute FORMAT A20
SELECT LTCG_CDF_FDA_ID,			-- column from table
       versions_startscn,
       --versions_starttime, 
       versions_endscn,
       --versions_endtime,
       versions_xid,
       versions_operation,
       DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'USERENV','SESSION_USER') AS session_user,
       DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'USERENV','CLIENT_IDENTIFIER') AS client_identifier,
       DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'test_context','my_attribute') AS my_attribute
FROM   ENT_STAGING.S1_FDO_LTCG_CDF_FDA 
       VERSIONS BETWEEN TIMESTAMP SYSTIMESTAMP-(1/24/60) AND SYSTIMESTAMP
ORDER BY versions_startscn;


/*-- blcdwsd implementation - LXORADWSD01 --*/
OWNER_NAME           FLASHBACK_ARCHIVE_NAME FLASHBACK_ARCHIVE# RETENTION_IN_DAYS STATUS
-------------------- ---------------------- ------------------ ----------------- -------
CNOLM7               LTCG_7YR_FBDA                           1              2555

FLASHBACK_ARCHIVE_NAME FLASHBACK_ARCHIVE# TABLESPACE_NAME      QUOTA_IN_MB
---------------------- ------------------ -------------------- -----------
LTCG_7YR_FBDA                           1 ENT_STAGING_DATA

OWNER_NAME           TABLE_NAME                     FLASHBACK_ARCHIVE_NAME ARCHIVE_TABLE_NAME   STATUS
-------------------- ------------------------------ ---------------------- -------------------- -------------
ENT_STAGING          S1_FDO_LTCG_CDF_CNTRL_FDA      LTCG_7YR_FBDA          SYS_FBA_HIST_288529  ENABLED
ENT_STAGING          S1_FDO_LTCG_CDF_FDA            LTCG_7YR_FBDA          SYS_FBA_HIST_296176  ENABLED
ENT_STAGING          S1_FQO_LTCG_CDF_QTR_CNTRL_FDA  LTCG_7YR_FBDA          SYS_FBA_HIST_288541  ENABLED
ENT_STAGING          S1_FQO_LTCG_CDF_QTR_FDA        LTCG_7YR_FBDA          SYS_FBA_HIST_296195  ENABLED
ENT_STAGING          S1_TEST_FLSH                   LTCG_7YR_FBDA          SYS_FBA_HIST_301178  ENABLED

SEGMENT_NAME                                     KB
---------------------------------------- ----------
S1_FQO_LTCG_CDF_QTR_FDA                      53,248
S1_FQO_LTCG_CDF_QTR_FDA_PK                    2,048
S1_FQO_LTCG_CDF_QTR_FDA_U1                   10,240

OWNER                SEGMENT_NAME                   SEGMENT_TYPE         TABLESPACE_NAME                  MB
-------------------- ------------------------------ -------------------- -------------------- --------------
ENT_STAGING          S1_FDO_LTCG_CDF_CNTRL_FDA      TABLE                ENT_STAGING_DATA                  1
ENT_STAGING          S1_FDO_LTCG_CDF_FDA            TABLE                ENT_STAGING_DATA                  1
ENT_STAGING          S1_FQO_LTCG_CDF_QTR_CNTRL_FDA  TABLE                ENT_STAGING_DATA                  1
ENT_STAGING          S1_FQO_LTCG_CDF_QTR_FDA        TABLE                ENT_STAGING_DATA                 52
ENT_STAGING          S1_TEST_FLSH                   TABLE                ENT_STAGING_DATA                  1
ENT_STAGING          SYS_FBA_HIST_288529            TABLE PARTITION      ENT_STAGING_DATA                  1
ENT_STAGING          SYS_FBA_HIST_288541            TABLE PARTITION      ENT_STAGING_DATA                  1
ENT_STAGING          SYS_FBA_HIST_296176            TABLE PARTITION      ENT_STAGING_DATA                  1
ENT_STAGING          SYS_FBA_HIST_296195            TABLE PARTITION      ENT_STAGING_DATA                 59
ENT_STAGING          SYS_FBA_HIST_296195            TABLE PARTITION      ENT_STAGING_DATA                  1
ENT_STAGING          SYS_FBA_HIST_296195            TABLE PARTITION      ENT_STAGING_DATA                 59


/*--- Doug Johnson - DDL being promoted ---*/
/*--- LXORA12CINFS02 testing ---*/
-- sysdba
set lines 150 pages 200
alter user autoddl identified by This1Works;
alter user sqltune identified by This1Works;

alter session set container=testdbs;
USERNAME                       GRANTED_ROLE                   PRIVILEGE
------------------------------ ------------------------------ --------------------------------------------------
AUTODDL                        <user>                         UNLIMITED TABLESPACE
AUTODDL                        AUTODDL_ADMIN_ROLE             ALTER ANY CLUSTER
... (none of the required privs)

GRANT FLASHBACK ARCHIVE ADMINISTER TO AUTODDL container=all;			--> dba
ORA-65040: operation not allowed from within a pluggable database

alter session set container=cdb$root;
Grant succeeded.


-- sqlplus autoddl@testdbs
CREATE FLASHBACK ARCHIVE BRDGR_7YR_FDA 
    TABLESPACE USERS
    RETENTION 7 YEAR
    OPTIMIZE DATA; 
ORA-55612: No privilege to manage Flashback Archive
(after grant given)
Flashback archive created.

-- sysdba
--GRANT FLASHBACK ARCHIVE ON BRDGR_7YR_FDA TO autoddl;		--> autoddl

-- autoddl
CREATE TABLE SQLTUNE.tab1 (
  id           NUMBER,
  description  VARCHAR2(50),
  CONSTRAINT tab_1_pk PRIMARY KEY (id)
) 
TABLESPACE USERS
FLASHBACK ARCHIVE BRDGR_7YR_FDA;
Table created.

OWNER_NAME           FLASHBACK_ARCHIVE_NAME FLASHBACK_ARCHIVE# RETENTION_IN_DAYS STATUS
-------------------- ---------------------- ------------------ ----------------- -------
AUTODDL              BRDGR_7YR_FDA                           1              2555

FLASHBACK_ARCHIVE_NAME FLASHBACK_ARCHIVE# TABLESPACE_NAME      QUOTA_IN_MB
---------------------- ------------------ -------------------- -----------
BRDGR_7YR_FDA                           1 USERS

OWNER_NAME           TABLE_NAME                     FLASHBACK_ARCHIVE_NAME ARCHIVE_TABLE_NAME   STATUS
-------------------- ------------------------------ ---------------------- -------------------- -------------
SQLTUNE              TAB1                           BRDGR_7YR_FDA          SYS_FBA_HIST_73389   ENABLED


-- sqlplus SQLTUNE@testdbs
INSERT INTO tab1 VALUES (1, 'ONE');
COMMIT;
select * from tab1;

UPDATE tab1
SET    description = 'TWO'
WHERE  id = 1;
COMMIT;
select * from tab1;

UPDATE tab1
SET    description = 'THREE'
WHERE  id = 1;
COMMIT;
select * from tab1;

SET LINESIZE 150 pages200
COLUMN versions_startscn FORMAT 99999999999999999
COLUMN versions_starttime FORMAT A24
COLUMN versions_endscn FORMAT 99999999999999999
COLUMN versions_endtime FORMAT A24
COLUMN versions_xid FORMAT A16
COLUMN versions_operation FORMAT A1
COLUMN description FORMAT A11
COLUMN session_user FORMAT A20
COLUMN client_identifier FORMAT A20
COLUMN my_attribute FORMAT A20
SELECT versions_startscn,
       versions_endscn,
       versions_xid,
       versions_operation,
       description
       --DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'USERENV','SESSION_USER') AS session_user,
       --DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'USERENV','CLIENT_IDENTIFIER') AS client_identifier,
       --DBMS_FLASHBACK_ARCHIVE.get_sys_context(versions_xid, 'test_context','my_attribute') AS my_attribute
FROM   tab1 
       VERSIONS BETWEEN TIMESTAMP SYSTIMESTAMP-(1/24/60) AND SYSTIMESTAMP
WHERE  id = 1
ORDER BY versions_startscn;
ORA-00904: "DBMS_FLASHBACK_ARCHIVE"."GET_SYS_CONTEXT": invalid identifier
(after below grant)
 VERSIONS_STARTSCN    VERSIONS_ENDSCN VERSIONS_XID     V DESCRIPTION SESSION_USER         CLIENT_IDENTIFIER    MY_ATTRIBUTE
------------------ ------------------ ---------------- - ----------- -------------------- -------------------- --------------------
    10987117793923                    10000B0025000000 U THREE

(without the grant)
 VERSIONS_STARTSCN    VERSIONS_ENDSCN VERSIONS_XID     V DESCRIPTION
------------------ ------------------ ---------------- - -----------
    10987117793923                    10000B0025000000 U THREE

-- sysdba
GRANT EXECUTE ON DBMS_FLASHBACK_ARCHIVE TO sqltune;	--> app devs, app account ??





GRANT CREATE ANY CONTEXT TO test;					--> ???
