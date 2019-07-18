set lines 1000
set pages 0
set long 50000
set trimspool on
set echo off
set verify off
set define on
set feedback off

ACCEPT user_name PROMPT 'Enter object owner: ';
ACCEPT obj_name PROMPT 'Enter object name: ';

column last_ddl new_val last_ddl

select to_char(last_ddl_time,'ddmonyy') last_ddl 
from dba_objects where object_name='&obj_name' and owner='&user_name';

spool D:\oradata\ACTAPX\ObjectHistory\&user_name..&obj_name._&last_ddl..sql

select text from dba_source where name='&obj_name' and owner='&user_name';

spool off