############
# COMMANDS #
############

-- create synonym
CREATE SYNONYM &syn_name FOR &obj_name;

-- replace existing
CREATE OR REPLACE SYNONYM &syn_name FOR &obj_name;

-- create public synonym
CREATE PUBLIC SYNONYM &syn_name FOR &obj_name;


###########
# QUERIES #
###########

col OWNER format a25
col SYNONYM_NAME format a25
col TABLE_OWNER format a25
col TABLE_NAME format a25
select OWNER, SYNONYM_NAME, TABLE_OWNER, TABLE_NAME
from dba_synonyms where synonym_name='&what_synonym';


####################
# INVALID SYNONYMS #
####################

-- post bus stop invalid object check
select owner, object_name, object_type
from dba_objects
where owner not in ('SYS','SYSTEM')
and status != 'VALID';

-- just for synonyms
col object_name format a30
select owner, object_name, object_type
from dba_objects
where owner not in ('SYS','SYSTEM')
and status != 'VALID' and object_type='SYNONYM'
order by owner, object_name;


-- replace all invalid synonyms
set lines 200 pages 0
set head off
spool replace_syns.out
select 'CREATE OR REPLACE SYNONYM '||sy.owner||'.'||sy.synonym_name||' FOR '||sy.table_owner||'.'||sy.table_name||';'
from dba_objects ob, dba_synonyms sy
where ob.status != 'VALID' and ob.object_type='SYNONYM' 
  and ob.object_name=sy.synonym_name and ob.owner=sy.owner
order by sy.owner, sy.synonym_name;
spool off
@replace_syns.out


-- replace a user's invalid synonyms
set lines 200 pages 0
set head off
spool replace_syns.out
select 'CREATE OR REPLACE SYNONYM '||sy.synonym_name||' FOR '||sy.table_owner||'.'||sy.table_name||';'
from user_objects ob, user_synonyms sy
where ob.status != 'VALID' and ob.object_type='SYNONYM' and ob.object_name=sy.synonym_name
order by sy.synonym_name;
spool off
@replace_syns.out


-- find synonyms that are invalid due to nonexistant tables
select sy.owner, sy.synonym_name, sy.table_owner, sy.table_name
from dba_objects ob, dba_synonyms sy
where ob.status != 'VALID' and ob.object_type='SYNONYM' 
  and ob.object_name=sy.synonym_name and ob.owner=sy.owner
  and not exists
    (select 'x' from dba_tables tb
     where tb.owner=sy.table_owner and tb.table_name=sy.table_name);

-- test that tables don't exist
set lines 200 pages 0
set head off
spool test_syns.out
select distinct 'SELECT * FROM '||sy.table_owner||'.'||sy.table_name||' WHERE ROWNUM=1;'
from dba_objects ob, dba_synonyms sy
where ob.status != 'VALID' and ob.object_type='SYNONYM' 
  and ob.object_name=sy.synonym_name and ob.owner=sy.owner
  and not exists
    (select 'x' from dba_tables tb
     where tb.owner=sy.table_owner and tb.table_name=sy.table_name);
spool off
@test_syns.out


-- drop synonyms that are invalid due to nonexistant tables
set lines 200 pages 0
set head off
spool drop_syns.out
select 'DROP SYNONYM '||sy.owner||'.'||sy.synonym_name||';'
from dba_objects ob, dba_synonyms sy
where ob.status != 'VALID' and ob.object_type='SYNONYM' 
  and ob.object_name=sy.synonym_name and ob.owner=sy.owner
  and not exists
    (select 'x' from dba_tables tb
     where tb.owner=sy.table_owner and tb.table_name=sy.table_name)
order by sy.owner, sy.synonym_name;
spool off
@drop_syns.out



 select * from DBA_DEPENDENCIES where owner='PUBLIC' and name='SF_ACCOUNT';