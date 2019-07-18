set lines 1000
set pages 0
set long 500000
set trimspool on
set echo off
set verify off
set define on

ACCEPT user_name PROMPT 'Enter view owner: ';
ACCEPT view_name PROMPT 'Enter view name: ';

column last_ddl new_val last_ddl

select to_char(last_ddl_time,'ddmonyy') last_ddl 
from dba_objects where object_name='&view_name' and owner='&user_name';

spool D:\oradata\ACTAPX\ObjectHistory\&user_name..&view_name._&last_ddl..sql

select text from dba_views where view_name='&view_name' and owner='&user_name';

spool off