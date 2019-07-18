-- prep work before creating an external table
CREATE DIRECTORY external_dir AS 'D:\external';
GRANT READ ON DIRECTORY external_dir TO table_owner;
GRANT WRITE ON DIRECTORY external_dir TO table_owner;

-- create an external table
CREATE TABLE tablename
	(column1	NUMBER(4),
	 ...
	)
ORGANIZATION EXTERNAL
(
	TYPE ORACLE_LOADER
	DEFAULT DIRECTORY external_dir
	ACCESS PARAMETERS
	(
	  records delimited by newline
	  badfile external_dir:'ext%a_%p.bad'
	  logfile external_dir:'ext%a_%p.log'
	  fields terminated by ','
	  missing field values are null
	  (  column1,...
	  )
	)
	LOCATION ('external.dat')
)
REJECT LIMIT UNLIMITED;



-- example
-- put log file on local disk, not snapdisk
create table LISTENER_UXP33 ( 
	TIMESTAMP        date, 
	CONNECT_DATA     varchar2(2048), 
	PROTOCOL_INFO    varchar2(64), 
	EVENT            varchar2(64), 
	SID              varchar2(64), 
	RETURN_CODE      number(5) 
  ) 
  organization external ( 
	type   ORACLE_LOADER 
	default directory DPUMP_EXP
	access parameters ( 
	   records delimited by NEWLINE 
	   badfile DPUMP_EXP:'listener_uxp33.bad'
	   nodiscardfile
	   logfile DPUMP_EXP:'listener_uxp33.log'
	   fields terminated by '*' LDRTRIM 
	   reject rows with all null fields 
	   ( 
		"TIMESTAMP" char date_format DATE mask "DD-MON-YYYY HH24:MI:SS ", 
		"CONNECT_DATA", 
		"PROTOCOL_INFO", 
		"EVENT", 
		"SID", 
		"RETURN_CODE" 
	   ) 
	) 
	location ('listener_uxp33.log') 
  ) 
reject limit unlimited;

create table edmat_tab_privs ( 
	GRANTEE		VARCHAR2(128),
	OWNER		VARCHAR2(128),
	TABLE_NAME	VARCHAR2(128),
	PRIVILEGE	VARCHAR2(40)
) 
  organization external ( 
	type   ORACLE_LOADER 
	default directory external_dir
	access parameters ( 
	   records delimited by NEWLINE 
	   badfile external_dir:'edmat_tab_privs.bad'
	   nodiscardfile
	   logfile external_dir:'edmat_tab_privs.log'
	   fields terminated by ','
	   reject rows with all null fields 
	   ( 
		"GRANTEE", 
		"OWNER", 
		"TABLE_NAME", 
		"PRIVILEGE"	   ) 
	) 
	location ('edmat_tab_privs.csv') 
  ) 
reject limit unlimited;


-- *** fixing newline issue ***

-- external table includes newline as part of last column
select rtrim(GRANTED_ROLE)||'*' from edmat_roles_ext where rownum<11;
RTRIM(GRANTED_ROLE)||'*'
---------------------------------------------------------------------------------------------------------------------------------
*ONNECT
*BA
*ONNECT

-- use REGEXP_REPLACE to remove it
select REGEXP_REPLACE(GRANTED_ROLE,'(^[[:space:]]*|[[:space:]]*$)')||'*' from edmat_roles_ext where rownum<11;
REGEXP_REPLACE(GRANTED_ROLE,'(^[[:SPACE:]]*|[[:SPACE:]]*$)')||'*'
------------------------------------------------------------------------------------------------------------------------------------------------------
CONNECT*
DBA*
CONNECT*

-- create internal table to get table clean
create table edmap_roles as
select rtrim(grantee) grantee, REGEXP_REPLACE(GRANTED_ROLE,'(^[[:space:]]*|[[:space:]]*$)') granted_role
from edmap_roles_ext;


-- ##########
-- # TKPROF # -- Using an external table as a way to view trace files
-- ##########

/* SYSDBA */
-- Create new directories
CREATE DIRECTORY bin_dir AS 'D:\DBA\TKProf';
CREATE DIRECTORY trace_dir AS 'D:\oradata\DEVA\dw3\General\Admin\diag\rdbms\dw3deva\dw3deva\trace';

-- Grant privs
GRANT READ, WRITE ON DIRECTORY trace_dir TO dw3;
GRANT EXECUTE ON DIRECTORY bin_dir TO dw3;
GRANT READ, WRITE ON DIRECTORY bin_dir TO dw3;

-- allow DW3 to enable tracing
grant alter session to dw3;

-- Server Access Change
-- Allow users to modify D:\oradata\DEVA\dw3\General\Admin\diag\rdbms\dw3deva\dw3deva\trace

/* DW3 */
-- this can be any end user with above privs
CREATE TABLE tkprof_xt 
  (line NUMBER
  ,text VARCHAR2(4000)
  )
ORGANIZATION EXTERNAL
  (TYPE ORACLE_LOADER
   DEFAULT DIRECTORY trace_dir
   ACCESS PARAMETERS
     (RECORDS DELIMITED BY NEWLINE
      PREPROCESSOR bin_dir: 'TKProf_dw3deva.bat'
      LOGFILE bin_dir: 'TKProf_dw3deva.log'
      FIELDS TERMINATED BY WHITESPACE
        (line RecNum
        ,text POSITION(1:4000)
        )
     )
   LOCATION ('')
  )
REJECT LIMIT UNLIMITED;

-- start tracing
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';

SELECT COUNT(*) FROM user_tables;

-- end tracing
ALTER SESSION SET EVENTS '10046 trace name context off';

-- find trace file
SELECT 'ALTER TABLE tkprof_xt LOCATION ('''||REGEXP_SUBSTR(value, '[^\]+$')||''');' run_me
FROM   v$diag_info WHERE  name = 'Default Trace File';

-- view contents
SELECT * FROM tkprof_xt ORDER BY line;

/* TKProf_dw3deva.bat */
/*
@echo off
cd D:\oradata\DEVA\dw3\General\Admin\diag\rdbms\dw3deva\dw3deva\trace
D:\Oracle\Product\11.2.0\dbhome_11203\BIN\tkprof %1 %1.txt
type %1.txt
*/



