-- create DB link
CREATE DATABASE LINK DW2MS7.DEV.INT.ACTURIS.COM
CONNECT TO MS7 IDENTIFIED BY MS7
USING 'ADMNDEVB.DEV.INT.ACTURIS.COM';

-- drop DB link
DROP DATABASE LINK DW2MS7.DEV.INT.ACTURIS.COM;

-- close link
ALTER SESSION CLOSE DATABASE LINK &what_link;

-- get DDL to recreate link
set long 10000000
select dbms_metadata.get_ddl('DB_LINK','&what_dblink','&what_owner') from dual;

-- create public link that connects as current user
create public database link dsgd_dbl
using '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS= (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = dsgd_pkg.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SID = dsgd)))';

create public database link dsgp_dbl
using '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS= (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = dsgp_pkg.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SID = dsgp)))';

create database link dsgd_dbl
connect to system identified by &what_pwd
using '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS= (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = dsgd_pkg.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SID = dsgd)))';

-- find objects dependent on a DB link
col "OBJECT" format a40
col "REF_OBJ" format a40
select owner||'.'||name "OBJECT", type, referenced_owner||'.'||referenced_name "REF_OBJ",
  referenced_type "REFTYPE", dependency_type
from DBA_DEPENDENCIES 
where referenced_link_name='&what_name'
order by 1,2,3;

/* using BY VALUES in the CONNECT string
Starting with version 11.2.0.4 and also in 12c it is no longer possible to supply the obfuscated password using a BY VALUES clause for creating a database link, 
this is only allowed from a datapump import 
(internally, Data Pump replaces the ":1" mentioned in bug 18461318 with the correct obfuscated database link password when it runs the DDL on the target system), 
there's now an explicit check in the code that deliberately prevents this, so it's not a bug. 
The solution is to use valid syntax only, the BY VALUES clause, despite its widespread use has always been for internal use only, 
this has now been enforced.
*/

-- shared DB link
CREATE SHARED DATABASE LINK CPSMRTSP_DBLINK
CONNECT TO C3SMARTS IDENTIFIED BY &pwd
AUTHENTICATED BY C3SMARTS IDENTIFIED BY &pwd
USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = cpsmrtsp_pkg.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SERVICE_NAME = cpsmrtsp)))';

-- link where password starts with a number
CREATE DATABASE LINK CPSMRTSP_DBLINK
CONNECT TO C3SMARTS IDENTIFIED BY "4assword"
USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (COMMUNITY = tcp.world) (PROTOCOL = TCP)(HOST = cpsmrtsp_pkg.conseco.com)(PORT = 1521))) (CONNECT_DATA = (SERVICE_NAME = cpsmrtsp)))';


/*--- update password in DB link ---*/
ALTER DATABASE LINK private_link 
  CONNECT TO hr IDENTIFIED BY hr_new_password;

ALTER PUBLIC DATABASE LINK public_link
  CONNECT TO scott IDENTIFIED BY scott_new_password;

ALTER SHARED PUBLIC DATABASE LINK shared_pub_link
  CONNECT TO scott IDENTIFIED BY scott_new_password
  AUTHENTICATED BY hr IDENTIFIED BY hr_new_password;

ALTER SHARED DATABASE LINK shared_pub_link
  CONNECT TO scott IDENTIFIED BY scott_new_password;
  
/*--- get password from a DB link ---*/
set serveroutput on
select passwordx from sys.link$ where name='AWD10SIT_DBL';
declare
	db_link_password varchar2(100);
begin
	db_link_password := '0569E4FEC087F258B789A747AB1A17C34F0A17A15770662B44';
	dbms_output.put_line ('Plain password: ' || utl_raw.cast_to_varchar2 ( dbms_crypto.decrypt ( substr (db_link_password, 19) , dbms_crypto.DES_CBC_PKCS5 , substr (db_link_password, 3, 16) ) ) );
end;
/

-- for several
set lines 150 pages 200
set serveroutput on
begin
	FOR i IN
		(select name, passwordx as hash from sys.link$ where name in ('CAMRARUNTIME','LMS','LMSRUNTIME'))
	LOOP
		dbms_output.put_line (i.name || ' password: ' || utl_raw.cast_to_varchar2 ( dbms_crypto.decrypt ( substr (i.hash, 19) , dbms_crypto.DES_CBC_PKCS5 , substr (i.hash, 3, 16) ) ) );
	END LOOP;
end;
/

-- errors
ORA-28817: PL/SQL function returned an error.
ORA-06512: at "SYS.DBMS_CRYPTO_FFI", line 67
ORA-06512: at "SYS.DBMS_CRYPTO", line 44
ORA-06512: at line 5
-- Doc ID 956603.1 says use below, but still getting error on idevt (SB)
-- RAWTOHEX 
-- UTL_I18N.RAW_TO_CHAR
-- UTL_ENCODE.BASE64_ENCODE

begin
	FOR i IN
		(select name, passwordx as hash from sys.link$ where name in ('TRADELINK','BPARPTT'))
	LOOP
		dbms_output.put_line (i.name || ' password: ' || UTL_ENCODE.BASE64_ENCODE ( dbms_crypto.decrypt ( substr (i.hash, 19) , dbms_crypto.DES_CBC_PKCS5 , substr (i.hash, 3, 16) ) ) );
	END LOOP;
end;
/

(select name, passwordx as hash from sys.link$ where passwordx is not null)


-- ######################
-- # heterogenous links #
-- ######################

-- create link
CREATE PUBLIC DATABASE LINK MAID
CONNECT TO ORACLEMAID IDENTIFIED BY '&what_pwd'
USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=lxorainfd01.conseco.ad)(PORT=1521))(CONNECT_DATA=(SID=dsgdtomaidprod))(HS=OK))';

-- /app/oracle/product/gateway/12c/1/hs/admin/initdsgdtomaidprod.ora
HS_FDS_CONNECT_INFO = DSGDTOMAIDPROD
HS_FDS_TRACE_LEVEL = OFF
HS_FDS_SHAREABLE_NAME = /usr/lib64/libodbc.so
HS_FDS_TRACE_FILE_NAME = /app/oracle/product/gateway/12c/1/hs/admin/dsgdtomaidprod.trc
set ODBCINI=/etc/odbc.ini
set LIBPATH=/usr/lib64

-- /etc/odbc.ini
[DSGDTOMAIDPROD]
Driver=ODBC Driver 13 for SQL Server
Description=MSSQL Server
Trace=No
AutoTranslate=No
Server=NTS8R2P05
Database=MAID
LogonID=OracleMaid
Password=Nj6faszw
Port=1433

-- /app/oracle/tns_admin/listener.ora
SID_LIST_LISTENER =
  (SID_LIST =
      (SID_DESC=
         (SID_NAME=dsgptomaidprd)
         (ORACLE_HOME=/app/oracle/product/gateway/12c/1)
         (PROGRAM=dg4odbc)
         (ENVS=LIBPATH=/usr/lib64:/app/oracle/product/gateway/12c/1)
      )


-- ##########
-- # Errors #
-- ##########

-- ORA-00922
see able if password starts with a number


-- ORA-02085: database link DSGD_DBL connects to DSGD
alter system set global_names=FALSE scope=both;

