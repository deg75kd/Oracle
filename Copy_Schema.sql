/* Create new account based on existing one */

SET LINES 500
SET PAGES 0
SET ECHO OFF
SET DEFINE ON
SET VERIFY OFF
SET FEEDBACK OFF
SET TRIMSPOOL ON

DEFINE what_user=&1

column filename new_val filename
select 'Copy_Schema_&what_user._'||name filename from v$database; 

SPOOL &filename..sql

PROMPT spool &filename..log

-- get create statement based on existing user
select 'CREATE USER '||du.username||' IDENTIFIED BY VALUES '''||us.password||
  ''' DEFAULT TABLESPACE '||du.default_tablespace||
  ' TEMPORARY TABLESPACE '||du.temporary_tablespace||
  ' PROFILE '||du.profile||';'
from dba_users du join user$ us on du.username=us.name
where du.username=upper('&what_user');

-- get grant role statement
select 'GRANT '||granted_role||' TO '||grantee||';'
from dba_role_privs where grantee=upper('&what_user');

-- get default role statement
select 'ALTER USER '||grantee||' DEFAULT ROLE '||granted_role||';'
from dba_role_privs where grantee=upper('&what_user') and default_role='YES';

-- get quota statement
select 'ALTER USER '||username||' QUOTA '||
  case	when max_bytes = -1 then 'UNLIMITED'
	else to_char(max_bytes)
  end
  ||' ON '||tablespace_name||';'
from dba_ts_quotas where username=upper('&what_user');

-- get sys priv statement
select 'GRANT '||privilege||' TO '||grantee||';'
from dba_sys_privs where grantee=upper('&what_user');

-- get obj priv statement
select 'GRANT '||privilege||' ON '||owner||'.'||table_name||' TO '||grantee||';'
from dba_tab_privs where grantee=upper('&what_user');

PROMPT spool off
SPOOL OFF
