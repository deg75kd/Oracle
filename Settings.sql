-- change default tablespace
ALTER DATABASE DEFAULT TABLESPACE &ts_name;

-- change default temp tablespace
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE &temp_name;

-- change global name
ALTER DATABASE RENAME GLOBAL_NAME TO &new_global_name.&new_domain;

-- change date/time settings for session
ALTER SESSION SET NLS_DATE_FORMAT="DD-MON-YY HH24:MI";


-- #######################
-- # Oracle Installation #
-- #######################

-- find patch sets / version
col comments format a40
select to_char(action_time,'DD-MON-YY') "ACTION_TIME", action, version, bundle_series, comments
from registry$history order by 1;
 
-- find installed components (JVM, XML, Oracle Text, Multimedia=ORDIM)
set lines 120 pages 200
col comp_name format a40
col status format a15
select comp_name,status,version from dba_registry order by 1;

col parameter format a40
col value format a12
select * from v$option order by parameter;

-- common installed components
col parameter format a40
col value format a12
select * from v$option 
where parameter in ('Java','Oracle Database Vault','Oracle Label Security','OLAP','Spatial')
order by parameter;

-- Oracle JVM
select * from all_registry_banners;

-- Oracle APEX
SELECT username FROM dba_users WHERE username LIKE 'FLOWS_%' or username like 'APEX%';


-- find DB host
select host_name from v$instance;