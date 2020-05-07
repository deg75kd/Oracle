-- find active roles
select * from session_roles;

-- is a name a user or a role?
undefine what_name
select 'USER' "WHAT" from dba_users where username=upper('&&what_name')
UNION
select 'ROLE' "WHAT" from dba_roles where role=upper('&what_name');

-- ###########
-- # OBJECTS #
-- ###########

-- find the size of a user's objects
set pagesize 1000
break on report;
compute sum label "TOTAL" of "MB" on report;
col tablespace_name format a30
col segment_name format a30
col "MB" format 999,990
SELECT segment_name, tablespace_name, Sum(bytes)/1024/1024 AS "MB"
FROM dba_segments WHERE owner = '&MYSCHEMANAME'
GROUP BY tablespace_name, segment_name
order BY tablespace_name, segment_name;


-- find the size of a user's tables
set pagesize 100
break on report;
compute sum label "TOTAL" of "MB" on report;
col tablespace_name format a30
col segment_name format a30
col "MB" format 999,990
select tablespace_name, sum(bytes)/1024/1024/1024 gb
from dba_segments
where segment_name in 
  (select object_name from dba_objects where object_type = 'TABLE')
and owner='&MYSCHEMANAME'
group by tablespace_name;



col tablespace_name format a30
set pagesize 100
set numformat 999,999,990
break on report;
compute sum label "TOTAL" of total_size_mb on report;
SELECT segment_name, tablespace_name, Sum(bytes)/1024/1024 AS total_size_mb
FROM dba_segments WHERE owner = '&MYSCHEMANAME'
GROUP BY tablespace_name;


-- find all of a user's objects
col object_name format a30
select object_type, object_name, status
from dba_objects where owner='&whatowner'
order by object_type, object_name, status;

-- find object sizes by user
break on report;
compute sum label "TOTAL" of "MB" on report;
col "MB" format 999,990
SELECT owner, Sum(bytes)/1024/1024 AS "MB"
FROM dba_segments
GROUP BY owner order BY owner;


-- ##########
-- # QUOTAS #
-- ##########

-- find a user's quota
select tablespace_name, (bytes/1024/1024) as MB, (max_bytes/1024/1024) as "MAX MB"
from dba_ts_quotas where username=upper('&u_name');

-- change a user's quota
ALTER USER &u_name QUOTA &quota_size ON &ts_name;

-- give a user unlimited quota
ALTER USER &u_name QUOTA UNLIMITED ON &ts_name;

-- find quotas for a given TS
select username, (max_bytes/1024/1024) as "MAX MB"
from dba_ts_quotas where tablespace_name='&ts_name';

-- find a user's default tablespace & temp space
select username, default_tablespace, temporary_tablespace
from dba_users where username like '%&what_usr%'
order by 1;


-- #################
-- # ROLES / PRIVS #
-- #################
-- see Roles Privs.sql


-- ###################
-- # ACCOUNT QUERIES #
-- ###################

-- details of an account
-- CTIME - date user created
-- PTIME - date password last changed
-- EXPTIME - 
-- LTIME - date user last locked (not nulled when unlocked)
-- LCOUNT - failed logins
select NAME, CTIME, PTIME, EXPTIME, LTIME, LCOUNT
from USER$
where NAME='&what_user';

-- ###################
-- # ACCOUNT CHANGES #
-- ###################

-- create new user
CREATE USER &user_name IDENTIFIED BY &pass_word
DEFAULT TABLESPACE &def_ts
TEMPORARY TABLESPACE &temp_ts
QUOTA 1k ON &quota_ts
PROFILE &what_profile
ACCOUNT [LOCK | UNLOCK]

-- create externally authenticated user
CREATE USER &user_name IDENTIFIED EXTERNALLY;

-- find a user's password hash
SELECT spare4, password FROM user$ WHERE name='&what_user';
SELECT password FROM user$ WHERE name='&what_user';

-- change a user's password (case-sensitive)
ALTER USER &what_user IDENTIFIED BY &pass_word;
-- change a user's password (non case-sensitive)
ALTER USER &what_user IDENTIFIED BY VALUES '&pwdhash';
-- create temporary password for user (forced to change on 1st logon)
ALTER USER &what_user IDENTIFIED BY &pass_word PASSWORD EXPIRE;
-- change a user to be externally authenticated
ALTER USER &what_user IDENTIFIED EXTERNALLY;

-- connect using password with @ in it
sqlplus 'XXX_user/"x@yyyzzz"@//host:port/service'

-- lock a user's account
ALTER USER &what_user ACCOUNT LOCK;
-- unlock/open a user's account
alter user &what_user account unlock;
-- force a user to change password
alter user &what_user PASSWORD EXPIRE;

-- drop a user
DROP USER &user_name CASCADE;

-- if ORA-28014: cannot drop administrative users
alter session set "_oracle_script"=true;
drop user gigi1 cascade;
alter session set "_oracle_script"=false;

-- give a user a role
grant &what_role to &what_user;

-- make a user's role the default
ALTER USER &user_name DEFAULT ROLE &role_name;
ALTER USER &user_name DEFAULT ROLE ALL EXCEPT &role_name;
ALTER USER &user_name DEFAULT ROLE NONE;

-- change a user's default tablespace
ALTER USER &user_name DEFAULT TABLESPACE &what_ts;
ALTER USER &user_name TEMPORARY TABLESPACE &what_ts;


/* Create new account based on existing one */

-- get create statement based on existing user
undefine what_user;
select 'CREATE USER '||du.username||' IDENTIFIED '||
  case when us.password='EXTERNAL' then 'EXTERNALLY'
    else 'BY VALUES '''||us.password||''''
  end ||
  ' DEFAULT TABLESPACE '||du.default_tablespace||
  ' TEMPORARY TABLESPACE '||du.temporary_tablespace||
  ' PROFILE '||du.profile||';'
from dba_users du join user$ us on du.username=us.name
where du.username='&&what_user';

-- get quota statement
select 'ALTER USER '||username||' QUOTA '||
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end
  ||' ON '||tablespace_name||';'
from dba_ts_quotas where username='&&what_user';

set lines 150 pages 200
set long 10000000
COL "DDL"  FORMAT A1000
select DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT','&what_user') "DDL" from dual;
select DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT','&what_user') "DDL" from dual;
select DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT','&what_user') "DDL" from dual;

-- get grant role statement
select 'GRANT '||granted_role||' TO '||grantee||';'
from dba_role_privs where grantee='&&what_user';

-- get default role statement
select 'ALTER USER '||grantee||' DEFAULT ROLE '||granted_role||';'
from dba_role_privs where grantee='&&what_user' and default_role='YES';

-- get sys priv statement
select 'GRANT '||privilege||' TO '||grantee||
  decode(admin_option,'YES',' WITH ADMIN OPTION;',';')
from dba_sys_privs where grantee='&what_user'
order by 1;

-- get obj priv statement
select 'GRANT '||privilege||' ON '||owner||'.'||table_name||' TO '||grantee||';'
from dba_tab_privs where grantee='&what_user'
order by 1;


-- ############
-- # PROFILES #
-- ############

-- find existing profiles
select distinct profile from DBA_PROFILES;

-- create new profile
create profile dba_profile limit
  sessions_per_user unlimited
  password_life_time 7
  password_grace_time 1;

-- drop profile
drop profile dba_profile;

-- edit a profile
alter profile default limit password_grace_time unlimited;

-- find a limit for a profile
select profile, resource_name, limit from DBA_PROFILES 
where resource_name='PASSWORD_LIFE_TIME' order by 1;

-- find a user's profile
select profile from dba_users where username='&what_user';

-- assign a user a profile
ALTER USER &what_user PROFILE &what_profile;


-- ################
-- # SCHEMA STATS #
-- ################

-- procedure to gather schema stats
DBMS_STATS.GATHER_SCHEMA_STATS ( 
   ownname          VARCHAR2, 
   estimate_percent NUMBER   DEFAULT to_estimate_percent_type 
                                                (get_param('ESTIMATE_PERCENT')), 
   block_sample     BOOLEAN  DEFAULT FALSE, 
   method_opt       VARCHAR2 DEFAULT get_param('METHOD_OPT'),
   degree           NUMBER   DEFAULT to_degree_type(get_param('DEGREE')), 
   granularity      VARCHAR2 DEFAULT GET_PARAM('GRANULARITY'), 
   cascade          BOOLEAN  DEFAULT to_cascade_type(get_param('CASCADE')), 
   stattab          VARCHAR2 DEFAULT NULL, 
   statid           VARCHAR2 DEFAULT NULL, 
   options          VARCHAR2 DEFAULT 'GATHER', 
   statown          VARCHAR2 DEFAULT NULL, 
   no_invalidate    BOOLEAN  DEFAULT to_no_invalidate_type (
                                     get_param('NO_INVALIDATE')),
  force             BOOLEAN DEFAULT FALSE);

exec DBMS_STATS.CREATE_STAT_TABLE ('MS7', 'ADMIN_STATS_11G');
exec DBMS_STATS.CREATE_STAT_TABLE ('MS8STATS', 'ADMIN_STATS_11G');

set serveroutput on
exec DBMS_STATS.GATHER_SCHEMA_STATS ( -
   ownname          => 'MS7', -
   estimate_percent => 100, -
   degree           => 2, -
   cascade          => FALSE, -
   stattab          => 'ADMIN_STATS_11G', -
   statown          => 'MS7', -
  force             => TRUE);


set serveroutput on
exec DBMS_STATS.GATHER_SCHEMA_STATS ( -
   ownname          => 'MS7', -
   estimate_percent => 100, -
   degree           => 2, -
   cascade          => TRUE, -
   stattab          => 'ADMIN_STATS_11G', -
  force             => FALSE);



set lines 1000 pages 0
spool gather_table_stats.out
select 'execute DBMS_STATS.GATHER_TABLE_STATS (ownname=>'''||owner||''',tabname=>'''||table_name||''',estimate_percent=>100,stattab=>''ADMIN_STATS_11G'',statown=>'''||owner||''');'
from dba_tables where owner in ('MS8STATS');
spool off
@gather_table_stats.out



execute DBMS_STATS.GATHER_TABLE_STATS (ownname=>'MS7',tabname=>'DSSMDJRNOBJS',estimate_percent=>100,stattab=>'ADMIN_STATS_11G',statown=>'MS7');


-- ##################
-- # SCHEMA DETAILS #
-- ##################

/*--- see Copy_Schema.sql script ---*/

-- get create statement based on existing user
undefine what_user
select du.default_tablespace, du.temporary_tablespace, du.profile
from dba_users du where du.username='&&what_user';

-- roles
select 'ROLE', granted_role, default_role
from dba_role_privs where grantee='&&what_user';

-- quota
select tablespace_name,
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end "QUOTA"
from dba_ts_quotas where username='&&what_user';

-- get sys priv statement
col "SYS PRIVS" format a40
select privilege "SYS PRIVS" from dba_sys_privs 
where grantee='&what_user' order by 1;

-- obj privs
col "OBJ PRIVS" format a80
select privilege||' ON '||owner||'.'||table_name "OBJ PRIVS"
from dba_tab_privs where grantee='&what_user' order by 1;


select 'GRANT '||privilege||' ON '||owner||'.'||table_name||' TO &what_user;' "OBJ PRIVS"
from dba_tab_privs where grantee='&what_user' order by 1;



select du.default_tablespace, du.temporary_tablespace, du.profile
from dba_users du left outer join dba_ts_quotas dq on 
where du.username='&&what_user';

select tablespace_name,
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end "QUOTA"
from  where username='&&what_user';






undefine what_user;

select usr.username, prf.profile, prf.resource_name, prf.limit
from DBA_PROFILES prf, DBA_USERS usr
where prf.profile=usr.profile
and resource_name in ('PASSWORD_LIFE_TIME','PASSWORD_VERIFY_FUNCTION','FAILED_LOGIN_ATTEMPTS','PASSWORD_REUSE_MAX','IDLE_TIME')
and rownum<11
order by 1;

SELECT username, profile,
  max( decode( resource_name, 'PASSWORD_LIFE_TIME', limit, null ) ) "PASSWORD_LIFE_TIME",
  max( decode( resource_name, 'PASSWORD_VERIFY_FUNCTION', limit, null ) ) "PASSWORD_VERIFY_FUNCTION",
  max( decode( resource_name, 'FAILED_LOGIN_ATTEMPTS', limit, null ) ) "FAILED_LOGIN_ATTEMPTS",
  max( decode( resource_name, 'PASSWORD_REUSE_MAX', limit, null ) ) "PASSWORD_REUSE_MAX",
  max( decode( resource_name, 'IDLE_TIME', limit, null ) ) "IDLE_TIME"
FROM
  (select usr.username, prf.profile, prf.resource_name, prf.limit
	from DBA_PROFILES prf, DBA_USERS usr
	where prf.profile=usr.profile
	and resource_name in ('PASSWORD_LIFE_TIME','PASSWORD_VERIFY_FUNCTION','FAILED_LOGIN_ATTEMPTS','PASSWORD_REUSE_MAX','IDLE_TIME'))
GROUP BY username, profile order by username, profile;

