-- find a user's invalid packages and bodies
select object_name, object_type, status from user_objects
where status != 'VALID' and object_type like '%PACKAGE%';

-- find all invalid packages in DB
select owner, object_name, object_type, status from dba_objects
where status != 'VALID' and object_type like '%PACKAGE%'
order by owner, object_type, object_name;

-- drop an entire package
DROP PACKAGE dqi.DQI_Partition_Pkg;
-- drop just the package body
DROP PACKAGE BODY dqi.DQI_Partition_Pkg;

-- recompile a PL/SQL package
alter package PARALLEL_JOBS_PKG compile;

-- recompile a package body
alter package PARALLEL_JOBS_PKG compile body;

-- get the errors from the compile
show errors package body edt_client

-- recompile all of a user's packages and bodies
set pagesize 1000
set linesize 120
set head off
spool recomp_all.out
--select 'alter package '||owner||'.'||object_name||' compile;'
--from dba_objects where object_type='PACKAGE' and owner='DW2';
--select 'alter package '||owner||'.'||object_name||' compile body;'
--from dba_objects where object_type='PACKAGE BODY' and owner='DW2';
select 'alter function '||owner||'.'||object_name||' compile;'
from dba_objects where object_type='FUNCTION' and owner='DW2';
select 'alter procedure '||owner||'.'||object_name||' compile;'
from dba_objects where object_type='PROCEDURE' and owner='DW2';
spool off

@recomp_all.out


