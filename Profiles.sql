-- ############
-- # PROFILES #
-- ############

/*------------------ QUERIES ------------------*/

-- find existing profiles
select distinct profile from DBA_PROFILES;

-- find a limit for a profile
select profile, resource_name, limit from DBA_PROFILES 
where resource_name like '%&what_resource%' order by 1,2;

-- find all limits for a profile
select resource_name, limit from DBA_PROFILES 
where profile = '&what_profile' order by 1,2;

-- find limits for all profiles
break on profile
col profile format a15
col limit format a15
select profile, resource_name, limit from DBA_PROFILES order by 1,2;

-- find a user's profile
set lines 120 pages 200
break on profile
col profile format a15
col limit format a15
select u.profile, p.resource_name, p.limit 
from DBA_PROFILES p join dba_users u on u.profile=p.profile
where u.username='&what_user' order by 1,2;

-- find profiles for all users
set lines 120 pages 200
col profile format a15
select username, profile from dba_users order by 1,2;

-- see the password verify function
set lines 250
set pages 0
select s.text 
from dba_source s, dba_profiles p
where s.name=p.limit and s.owner='SYS' and p.resource_name='PASSWORD_VERIFY_FUNCTION'
and p.profile='&what_profile';

/* --- profile resources ---
COMPOSITE_LIMIT
CONNECT_TIME
CPU_PER_CALL
CPU_PER_SESSION
FAILED_LOGIN_ATTEMPTS
IDLE_TIME
LOGICAL_READS_PER_CALL
LOGICAL_READS_PER_SESSION
PASSWORD_GRACE_TIME
PASSWORD_LIFE_TIME
PASSWORD_LOCK_TIME
PASSWORD_REUSE_MAX
PASSWORD_REUSE_TIME
PASSWORD_VERIFY_FUNCTION
PRIVATE_SGA
SESSIONS_PER_USER
*/


/*------------------ CHANGES ------------------*/

-- create new profile
create profile dba_profile limit
  sessions_per_user unlimited
  password_life_time 7
  password_grace_time 1;

-- drop profile
drop profile dba_profile;

-- edit a profile
alter profile default limit password_grace_time unlimited;

-- assign a user a profile
ALTER USER &what_user PROFILE &what_profile;


/*------------------ USER PROFILES ------------------*/

-- create user and set profile
CREATE USER &what_user IDENTIFIED BY &what_password
DEFAULT TABLESPACE &what_ts
TEMPORARY TABLESPACE &what_temp
PROFILE &what_profile;

-- assign a user a profile
ALTER USER &what_user PROFILE &what_profile;


/*------------------ QUESTIONS ------------------*/

-- Does changing the password function force users to change their password? (11g)
-- NO
SQL> create user profile_test1 identified by profile_test1 profile conseco_profile;

User created.

SQL> alter user profile_test1 profile cno_profile;

User altered.

SQL> conn profile_test1
Enter password:
Connected.

