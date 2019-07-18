###################
# INVALID OBJECTS #
###################

-- find a user's invalid objects
select object_name, object_type, status from user_objects where status != 'VALID';

-- find all invalid objects
set lines 120 pagesize 100
col owner format a20
col object_name format a25
select owner, object_name, object_type from dba_objects 
where status != 'VALID' order by owner, object_name;

-- recompile a view
alter view CTRL_RISK_DETAILS_TMP_VW compile;

alter materialized view CTRL_RISK_DETAILS_TMP_VW compile;

-- recompile an index
alter index I_PROXY_ROLE_DATA$_1 compile;

-- rebuild an index
alter index I_PROXY_ROLE_DATA$_1 rebuild;

-- recompile a PL/SQL package
alter package PARALLEL_JOBS_PKG compile;

-- recompile a package body
alter package PARALLEL_JOBS_PKG compile body;

-- recompile a trigger
alter trigger PARALLEL_JOBS_PKG compile;


-- recompile a user's invalid objects
set pagesize 0
set linesize 500
set head off
spool recomp_all.out
select 'alter package '||object_name||' compile package;'
from user_objects where object_type like 'PACKAGE%' and status != 'VALID';
select 'alter function '||object_name||' compile;'
from user_objects where object_type='FUNCTION' and status != 'VALID';
select 'alter procedure '||object_name||' compile;'
from user_objects where object_type='PROCEDURE' and status != 'VALID';
select 'alter view '||object_name||' compile;'
from user_objects where object_type='VIEW' and status != 'VALID';
spool off

@recomp_all.out


-- recompile all invalid objects
set pagesize 0
set linesize 500
set head off
spool recomp_all.out
select 'alter package '||owner||'.'||object_name||' compile package;'
from dba_objects where object_type like 'PACKAGE%' and status != 'VALID';
select 'alter function '||owner||'.'||object_name||' compile;'
from dba_objects where object_type='FUNCTION' and status != 'VALID';
select 'alter procedure '||owner||'.'||object_name||' compile;'
from dba_objects where object_type='PROCEDURE' and status != 'VALID';
select 'alter view '||owner||'.'||object_name||' compile;'
from dba_objects where object_type='VIEW' and status != 'VALID';
spool off
@recomp_all.out

-- OR -- 

set pagesize 0
set linesize 500
set head off
spool recomp_all.out
select distinct 'exec DBMS_UTILITY.COMPILE_SCHEMA('''||owner||''');'
from dba_objects where status != 'VALID';
spool off

@recomp_all.out


-- #############
-- # ORA-08102 #
-- #############

-- verify table is not corrupt
analyze table &tblname validate structure;

-- find offensive object
select owner, object_name, object_type from dba_objects where object_id=818188;

-- get DDL to recreate object
set long 10000000
select dbms_metadata.get_ddl('INDEX','USRUSER_IX04','ACTD00') from dual;

-- drop the object (may be different if not an index)
drop index USRUSER_IX04;

-- use DDL to recreate it

