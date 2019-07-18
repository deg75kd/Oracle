-- ##################
-- # cihubd         #
-- # lxora12cinfs02 #
-- # 5/18           #
-- ##################

-- sysdba
sho parameter os_authent_prefix
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
os_authent_prefix                    string      ops$

alter session set container=ihubd;
select username from dba_users where username like 'OPS$%';
no rows selected

CREATE USER ops$oracle IDENTIFIED EXTERNALLY;


-- oracle
cihubd
sqlplus /
ORA-01017: invalid username/password; logon denied

ihubd
sqlplus /
ORA-01034: ORACLE not available
ORA-27101: shared memory realm does not exist


-- sysdba
alter session set container=ihubd;
drop USER ops$oracle;

alter session set container=cdb$root;
sho parameter common
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
common_user_prefix                   string

alter system set os_authent_prefix='' scope=spfile;
shutdown immediate
startup

create user oracle identified externally container=all;
grant set container to oracle container=all;
grant create session to oracle container=all;


-- oracle
ihubd
sqlplus /
ORA-01034: ORACLE not available
ORA-27101: shared memory realm does not exist

cihubd
sqlplus /
alter session set container=ihubd;
alter session set container=cdb$root;


-- osauthe_test.sh
#!/usr/bin/bash
unset LIBPATH
export two_task=ihubd
export ORACLE_SID=ihubd
export ORACLE_HOME=/app/oracle/product/db/12c/1
export ORAENV_ASK=NO
export PATH=/usr/local/bin:$PATH
. /usr/local/bin/oraenv
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
export LIBPATH=$ORACLE_HOME/lib
echo "================================"
echo "Your Oracle Environment Settings:"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "ORACLE_SID            = ${ORACLE_SID}"
echo "ORACLE_HOME           = ${ORACLE_HOME}"
echo "TNS_ADMIN             = ${TNS_ADMIN}"
echo "LD_LIBRARY_PATH       = ${LD_LIBRARY_PATH}"
echo ""

`$ORACLE_HOME/bin/sqlplus -s / <<EOF
SET HEAD OFF FEEDBACK OFF
SELECT SYS_CONTEXT ('USERENV', 'DB_NAME') FROM DUAL;
alter session set container=cdb$root;
SELECT SYS_CONTEXT ('USERENV', 'DB_NAME') FROM DUAL;
EOF`


-- ########################
-- # export/import test 1 #
-- ########################

-- prodd (uxs33) as oracle
CREATE TABLE table1 (
   tabid	NUMBER(10,0),
   tabname	VARCHAR2(10),
	CONSTRAINT table1_pk01 PRIMARY KEY (tabid) 
	using index (CREATE INDEX table1_pk_ix ON table1 (tabid))
);
insert into table1 values (1,'employee');
insert into table1 values (2,'department');
commit;

create view view1 as
select * from table1 where tabid=1;

set lines 150 pages 200
col object_name format a30
select owner, object_name, object_type from dba_objects where owner like '%ORACLE' order by 1,2,3;
OWNER                          OBJECT_NAME                    OBJECT_TYPE
------------------------------ ------------------------------ -------------------
OPS$ORACLE                     ORA_DSGD_DBL                   DATABASE LINK
OPS$ORACLE                     ORA_DSGP_DBL                   DATABASE LINK
OPS$ORACLE                     TABLE1                         TABLE
OPS$ORACLE                     TABLE1_PK_IX                   INDEX
OPS$ORACLE                     VIEW1                          VIEW

CNO_MIGRATE=/oragg/prodd/dmpdir
oragg -> /backup_uxs33/ggate/12.2/dirdat
mkdir prodd
cd prodd
mkdir dmpdir
cd dmpdir

/*
expdp \"/ as sysdba\" DIRECTORY=CNO_MIGRATE DUMPFILE=ORACLE_SCHEMA.dmp LOGFILE=ORACLE_SCHEMA_exp.log CONTENT=ALL SCHEMAS=OPS\$ORACLE
*/

-- lxora12cinfs02 - cihubd
SQL> sho parameter common
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
common_user_prefix                   string

SQL> sho parameter os_authent_prefix
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
os_authent_prefix                    string

col username format a30
select username, AUTHENTICATION_TYPE, COMMON from dba_users where AUTHENTICATION_TYPE='EXTERNAL' order by 1;
USERNAME                       AUTHENTI COM
------------------------------ -------- ---
ORACLE                         EXTERNAL YES

drop user oracle;

CNO_MIGRATE=/oragg/ihubd/dmpdir

/*
scp oracle@uxs33.conseco.com:/oragg/prodd/dmpdir/*.dmp /oragg/ihubd/dmpdir
impdp \"system@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=LXORA12CINFS02.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ihubd)))\" DIRECTORY=CNO_MIGRATE DUMPFILE=ORACLE_SCHEMA.dmp LOGFILE=ORACLE_SCHEMA_imp.log REMAP_SCHEMA=OPS\$ORACLE:ORACLE
*/

sqlplus / as sysdba
alter session set container=ihubd;
set lines 150 pages 200
col owner format a30
col object_name format a30
select owner, object_name, object_type from dba_objects where owner like '%ORACLE' order by 1,2,3;
OWNER                          OBJECT_NAME                    OBJECT_TYPE
------------------------------ ------------------------------ -----------------------
ORACLE                         ORA_DSGD_DBL                   DATABASE LINK
ORACLE                         ORA_DSGP_DBL                   DATABASE LINK
ORACLE                         TABLE1                         TABLE
ORACLE                         TABLE1_PK_IX                   INDEX
ORACLE                         VIEW1                          VIEW

col username format a30
select username, AUTHENTICATION_TYPE, COMMON from dba_users where AUTHENTICATION_TYPE='EXTERNAL' order by 1;

USERNAME                       AUTHENTI COM
------------------------------ -------- ---
ORACLE                         EXTERNAL NO

-- as oracle
ORA-01017: invalid username/password; logon denied


-- ########################
-- # export/import test 2 #
-- ########################

-- lxora12cinfs02 - cihubd
SQL> sho parameter common
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
common_user_prefix                   string

SQL> sho parameter os_authent_prefix
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
os_authent_prefix                    string

set lines 150 pages
col username format a30
select username, AUTHENTICATION_TYPE, COMMON from dba_users where AUTHENTICATION_TYPE='EXTERNAL' order by 1;
no rows selected

create user oracle identified externally container=all;
grant set container to oracle container=all;
grant create session to oracle container=all;

-- as oracle
sqlplus /
SQL> show con_name
CON_NAME
------------------------------
CDB$ROOT

alter session set container=ihubd;
SQL> show con_name
CON_NAME
------------------------------
IHUBD

/*
impdp \"system@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=LXORA12CINFS02.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ihubd)))\" DIRECTORY=CNO_MIGRATE DUMPFILE=ORACLE_SCHEMA.dmp LOGFILE=ORACLE_SCHEMA_imp.log REMAP_SCHEMA=OPS\$ORACLE:ORACLE TABLE_EXISTS_ACTION=REPLACE
*/
ORA-31684: Object type USER:"ORACLE" already exists
. . imported "ORACLE"."TABLE1"                           5.492 KB       2 rows
Job "SYSTEM"."SYS_IMPORT_FULL_01" completed with 1 error(s) at Mon May 22 16:04:41 2017 elapsed 0 00:00:03

sqlplus /
alter session set container=ihubd;
select * from table1;
     TABID TABNAME
---------- ----------
         1 employee
         2 department

select * from view1;
     TABID TABNAME
---------- ----------
         1 employee

-- as sysdba
sqlplus / as sysdba
alter session set container=ihubd;
set lines 150 pages 200
col owner format a30
col object_name format a30
select owner, object_name, object_type from dba_objects where owner like '%ORACLE' order by 1,2,3;
OWNER                          OBJECT_NAME                    OBJECT_TYPE
------------------------------ ------------------------------ -----------------------
ORACLE                         ORA_DSGD_DBL                   DATABASE LINK
ORACLE                         ORA_DSGP_DBL                   DATABASE LINK
ORACLE                         TABLE1                         TABLE
ORACLE                         TABLE1_PK_IX                   INDEX
ORACLE                         VIEW1                          VIEW

col username format a30
select username, AUTHENTICATION_TYPE, COMMON from dba_users where AUTHENTICATION_TYPE='EXTERNAL' order by 1;
USERNAME                       AUTHENTI COM
------------------------------ -------- ---
ORACLE                         EXTERNAL YES

col granted_role format a30
select granted_role, admin_option, common from dba_role_privs where grantee='ORACLE' order by 1;
GRANTED_ROLE                   ADM COM
------------------------------ --- ---
DBA                            NO  NO


-- prodd
select granted_role, admin_option from dba_role_privs where grantee='OPS$ORACLE' order by 1;
GRANTED_ROLE                   ADM
------------------------------ ---
DBA                            NO


-- ########################
-- # export/import test 3 #
-- ########################

-- lxora12cinfs02 - cihubd
drop user oracle cascade;
drop user ggtest cascade;

set lines 150 pages
col username format a30
select username, AUTHENTICATION_TYPE, COMMON from dba_users where AUTHENTICATION_TYPE='EXTERNAL' order by 1;
no rows selected

create user oracle identified externally container=all;
grant set container to oracle container=all;
grant create session to oracle container=all;

-- uxs33 - prodd
SQL> select table_name from dba_tables where owner='GGTEST';
TABLE_NAME
------------------------------
INDEX_COUNT_AIX
INDEX_COUNT_LINUX
OBJECT_COUNT_AIX
OBJECT_COUNT_LINUX
ROW_COUNT_AIX
ROW_COUNT_LINUX
TABLE1

grant select on ggtest.ROW_COUNT_AIX to ops$oracle;
grant select on ggtest.ROW_COUNT_LINUX to ops$oracle;
grant select, insert, update, delete on ggtest.TABLE1 to ops$oracle;

rm /oragg/prodd/dmpdir/ORACLE_SCHEMA.dmp
/*
expdp \"/ as sysdba\" DIRECTORY=CNO_MIGRATE DUMPFILE=ORACLE_SCHEMA.dmp LOGFILE=ORACLE_SCHEMA_exp.log CONTENT=ALL SCHEMAS=OPS\$ORACLE,GGTEST
*/

-- lxora12cinfs02
/*
rm /oragg/ihubd/dmpdir/*
scp oracle@uxs33.conseco.com:/oragg/prodd/dmpdir/*.dmp /oragg/ihubd/dmpdir 
impdp \"system@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=LXORA12CINFS02.conseco.ad)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ihubd)))\" DIRECTORY=CNO_MIGRATE DUMPFILE=ORACLE_SCHEMA.dmp LOGFILE=ORACLE_SCHEMA_imp.log REMAP_SCHEMA=OPS\$ORACLE:ORACLE TABLE_EXISTS_ACTION=REPLACE
*/
ORA-31684: Object type USER:"ORACLE" already exists
. . imported "GGTEST"."INDEX_COUNT_AIX"                  382.9 KB    4785 rows
. . imported "GGTEST"."OBJECT_COUNT_AIX"                 1.291 MB   24506 rows
. . imported "GGTEST"."OBJECT_COUNT_LINUX"               1.451 MB   24500 rows
. . imported "GGTEST"."ROW_COUNT_AIX"                    626.8 KB   12388 rows
. . imported "GGTEST"."ROW_COUNT_LINUX"                  711.5 KB   12395 rows
. . imported "GGTEST"."TABLE1"                           5.492 KB       2 rows
. . imported "ORACLE"."TABLE1"                           5.492 KB       2 rows
. . imported "GGTEST"."INDEX_COUNT_LINUX"                    0 KB       0 rows
Processing object type SCHEMA_EXPORT/TABLE/GRANT/OWNER_GRANT/OBJECT_GRANT
Job "SYSTEM"."SYS_IMPORT_FULL_01" completed with 1 error(s) at Mon May 22 22:11:13 2017 elapsed 0 00:00:09

sqlplus /
alter session set container=ihubd;
select * from table1;
     TABID TABNAME
---------- ----------
         1 employee
         2 department

select * from view1;
     TABID TABNAME
---------- ----------
         1 employee

select * from "GGTEST"."INDEX_COUNT_AIX" where rownum=1;
select * from "GGTEST"."OBJECT_COUNT_AIX" where rownum=1;
select * from "GGTEST"."OBJECT_COUNT_LINUX" where rownum=1;
select * from "GGTEST"."ROW_COUNT_AIX" where rownum=1;
select * from "GGTEST"."ROW_COUNT_LINUX" where rownum=1;
select * from "GGTEST"."TABLE1" where rownum=1;
select * from "GGTEST"."INDEX_COUNT_LINUX" where rownum=1;


-- ########################
-- # trigger test 1       #
-- ########################

-- lxora12cinfs02 - ihubd - sysdba
revoke select, insert, update, delete on ggtest.TABLE1 from oracle;
create role ggtest_role;
grant select, insert, update, delete on ggtest.TABLE1 to ggtest_role;
grant ggtest_role to oracle;

-- cihubd - sysdba
grant select_catalog_role to oracle container=all;

-- ihubd - oracle
SQL> sho con_name
CON_NAME
------------------------------
CDB$ROOT

alter session set container=ihubd;
SQL> sho con_name
CON_NAME
------------------------------
IHUBD

set lines 150 pages 200
col username format a30
col granted_role format a30
select * from user_role_privs;
USERNAME                       GRANTED_ROLE                   ADM DEL DEF OS_ COM
------------------------------ ------------------------------ --- --- --- --- ---
ORACLE                         DBA                            NO  NO  YES NO  NO
ORACLE                         GGTEST_ROLE                    NO  NO  YES NO  NO
ORACLE                         SELECT_CATALOG_ROLE            NO  NO  YES NO  YES

select * from ggtest.TABLE1;
     TABID TABNAME
---------- ----------
         1 employee
         2 department


-- cihubd - sysdba

create or replace trigger logon_osuser_switch
	after logon on database
begin
	EXECUTE IMMEDIATE 'alter session set container=ihubd';
end;
/


-- oracle
SQL> sho con_name
CON_NAME
------------------------------
IHUBD

set lines 150 pages 200
col username format a30
col granted_role format a30
select * from user_role_privs;
no rows selected

select * from ggtest.TABLE1;
ERROR at line 1:
ORA-00942: table or view does not exist



--create or replace trigger logon_osuser_switch
--	after logon on database
--declare
--	curr_user		VARCHAR2(256);
--	auth_meth		VARCHAR2(256);
--	pdb_name		VARCHAR2(30);
--begin
--	SELECT SYS_CONTEXT ('USERENV', 'CURRENT_USER') INTO curr_user FROM DUAL;
--	SELECT SYS_CONTEXT ('USERENV', 'AUTHENTICATION_METHOD') INTO auth_meth FROM DUAL;
--	select name into pdb_name from v$pdbs where name!='PDB$SEED';
--	DBMS_OUTPUT.put_line('Connecting to PDB '||pdb_name);
--	
--	IF (auth_meth='OS' AND curr_user!='SYS') THEN
--		EXECUTE IMMEDIATE 'alter session set container='||pdb_name;
--	END IF;
--end;
--/


SYS.V_$CONTAINERS
SYS.DBA_PDBS



/* *** This will NOT work if we switch to multiple PDB setup *** */

-- ##################
-- # script testing #
-- ##################

*** manually recreate users ***
col "STMT" format a2500
select 'CREATE USER '||substr(us.username,length(pf.value)+1)||' IDENTIFIED EXTERNALLY CONTAINER=ALL'||
	' DEFAULT TABLESPACE '||us.default_tablespace||
	' TEMPORARY TABLESPACE '||us.temporary_tablespace||
	' PROFILE '||us.profile||';'
	"STMT"
from dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where us.AUTHENTICATION_TYPE='EXTERNAL';

grant set container to oracle container=all;

substr(us.username,length(pf.value)+1)

-- get quota statement
select 'ALTER USER '||substr(us.username,length(pf.value)+1)||' QUOTA '||
  case	when tq.max_bytes = -1 then 'UNLIMITED'
	else to_char(tq.max_bytes)
  end
  ||' ON '||tq.tablespace_name||';'
from dba_ts_quotas tq, dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where tq.username=us.username and us.AUTHENTICATION_TYPE='EXTERNAL';

-- get grant role statement
select 'GRANT '||rp.granted_role||' TO '||substr(us.username,length(pf.value)+1)||';'
from dba_role_privs rp, dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where rp.grantee=us.username and us.AUTHENTICATION_TYPE='EXTERNAL';

-- get default role statement
select 'ALTER USER '||substr(us.username,length(pf.value)+1)||' DEFAULT ROLE '||rp.granted_role||';'
from dba_role_privs rp, dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where rp.grantee=us.username and us.AUTHENTICATION_TYPE='EXTERNAL'
and rp.default_role='YES';

-- get sys priv statement
select 'GRANT '||sp.privilege||' TO '||substr(us.username,length(pf.value)+1)||
  decode(sp.admin_option,'YES',' WITH ADMIN OPTION;',';')
from dba_sys_privs sp, dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where sp.grantee=us.username and us.AUTHENTICATION_TYPE='EXTERNAL';

-- get obj priv statement
select 'GRANT '||tp.privilege||' ON '||tp.owner||'.'||tp.table_name||' TO '||substr(us.username,length(pf.value)+1)||';'
from dba_tab_privs tp, dba_users us,
(select value from v$spparameter where name='os_authent_prefix') pf
where tp.grantee=us.username and us.AUTHENTICATION_TYPE='EXTERNAL';


-- ########################
-- # trigger test 2       #
-- ########################

-- lxora12cinfs02 - cidevt - sysdba
create user oracle identified externally container=all;
grant set container to oracle container=all;
grant create session to oracle container=all;
grant select_catalog_role to oracle container=all;

alter session set container=idevt;
drop role ggtest_role;
create role ggtest_role;
grant select, insert, update, delete on ggtest.TABLE1 to ggtest_role;
grant ggtest_role to oracle;

-- oracle
sqlplus /
SQL> sho user
USER is "ORACLE"

SQL> sho con_name
CON_NAME
------------------------------
CDB$ROOT

alter session set container=idevt;
SQL> sho con_name
CON_NAME
------------------------------
IDEVT

set lines 150 pages 200
col username format a30
col granted_role format a30
select * from user_role_privs;
USERNAME                       GRANTED_ROLE                   ADM DEL DEF OS_ COM
------------------------------ ------------------------------ --- --- --- --- ---
ORACLE                         GGTEST_ROLE                    NO  NO  YES NO  NO
ORACLE                         SELECT_CATALOG_ROLE            NO  NO  YES NO  YES

select * from ggtest.TABLE1;
     TABID TABNAME
---------- ----------
         1 employee
         2 department

-- cidevt - sysdba
create or replace trigger logon_osuser_switch
	after logon on database
begin
	EXECUTE IMMEDIATE 'alter session set container=idevt';
end;
/

-- oracle
sqlplus /
SQL> sho user
USER is "SYS"

SQL> sho con_name
CON_NAME
------------------------------
IDEVT

set lines 150 pages 200
col username format a30
col granted_role format a30
select * from user_role_privs;
ORA-01918: user '' does not exist


select * from ggtest.TABLE1;
ORA-00942: table or view does not exist

set role all;
select * from user_role_privs;
ORA-01918: user '' does not exist

-- cidevt - sysdba
create or replace trigger logon_osuser_switch
	after logon on database
begin
	EXECUTE IMMEDIATE 'alter session set container=idevt';
	EXECUTE IMMEDIATE 'set role all';
end;
/

-- oracle
sqlplus /
ORA-06565: cannot execute SET ROLE from within stored procedure

-- sysdba
drop trigger logon_osuser_switch;
create or replace trigger ORACLE.LOGTRG 
	after logon on database 
begin 
	if sys_context('userenv','session_user')='ORACLE' 
	then 
		execute immediate 'alter session set container=IDEVT'; 
	end if; 
end;
/

-- oracle
sqlplus /
SQL> sho user
USER is "ORACLE"

SQL> sho con_name
CON_NAME
------------------------------
IDEVT

set lines 150 pages 200
col username format a30
col granted_role format a30
select * from user_role_privs;
USERNAME                       GRANTED_ROLE                   ADM DEL DEF OS_ COM
------------------------------ ------------------------------ --- --- --- --- ---
ORACLE                         GGTEST_ROLE                    NO  NO  YES NO  NO
ORACLE                         SELECT_CATALOG_ROLE            NO  NO  YES NO  YES

select * from ggtest.TABLE1;
ORA-00942: table or view does not exist

col role format a30
select * from session_roles;
ROLE
------------------------------
SELECT_CATALOG_ROLE
HS_ADMIN_SELECT_ROLE

set role all;
select * from session_roles;
ROLE
------------------------------
SELECT_CATALOG_ROLE
HS_ADMIN_SELECT_ROLE
GGTEST_ROLE

select * from ggtest.TABLE1;
     TABID TABNAME
---------- ----------
         1 employee
         2 department

-- sysdba
create or replace trigger ORACLE.LOGTRG 
	after logon on database 
begin 
	if sys_context('userenv','session_user')='ORACLE' 
	then 
		execute immediate 'alter session set container=IDEVT'; 
		execute immediate 'set role all';
	end if; 
end;
/

-- oracle
sqlplus /
ORA-06565: cannot execute SET ROLE from within stored procedure



--create or replace trigger logon_osuser_switch
--	after logon on database
--declare
--	curr_user		VARCHAR2(256);
--	auth_meth		VARCHAR2(256);
--	pdb_name		VARCHAR2(30);
--begin
--	SELECT SYS_CONTEXT ('USERENV', 'CURRENT_USER') INTO curr_user FROM DUAL;
--	SELECT SYS_CONTEXT ('USERENV', 'AUTHENTICATION_METHOD') INTO auth_meth FROM DUAL;
--	select name into pdb_name from v$pdbs where name!='PDB$SEED';
--	DBMS_OUTPUT.put_line('Connecting to PDB '||pdb_name);
--	
--	IF (auth_meth='OS' AND curr_user!='SYS') THEN
--		EXECUTE IMMEDIATE 'alter session set container='||pdb_name;
--	END IF;
--end;
--/
