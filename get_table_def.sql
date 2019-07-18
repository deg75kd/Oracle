set lines 250
set pages 0
set long 50000
set trimspool on
set echo off
set verify off
set define on

ACCEPT user_name PROMPT 'Enter table owner: ';
ACCEPT what_table PROMPT 'Enter table name: ';

column last_ddl new_val last_ddl

select to_char(last_ddl_time,'ddmonyy') last_ddl 
from dba_objects where object_name='&what_table' and owner='&user_name';

spool D:\oradata\ACTAPX\ObjectHistory\&user_name..&what_table._&last_ddl..sql

select DBMS_METADATA.GET_DDL('TABLE','&what_table','&user_name') from DUAL;

spool off