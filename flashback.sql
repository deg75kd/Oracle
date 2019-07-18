
alter system set db_recovery_file_dest_size=40g scope=both;
alter system set db_recovery_file_dest='D:\oradata\PRODS\wm\Oracle\flash_recovery' scope=both;

-- turn on/off flashback
alter database flashback on;
alter database flashback off;

-- create restore point
-- DB can be mounted or open
-- if flashback not enabled, DB must be mounted
CREATE RESTORE POINT post_refresh_wmprods;

-- restore flashback DB
flashback database to RESTORE POINT post_refresh_wmprods;


-- ###############
-- # RECYCLE BIN #
-- ###############

-- check if it's on
show parameter recycle

-- disable recycle bin
ALTER SESSION SET recyclebin = OFF;
ALTER SYSTEM SET recyclebin = OFF SCOPE = BOTH;

-- enable recycle bin
ALTER SESSION SET recyclebin = ON;
ALTER SYSTEM SET recyclebin = ON SCOPE = BOTH;


-- see what's in recycle bin
-- indexes are restored with recycle bin names - run this to get system name
col "ORIGINAL_NAME" format a50
SELECT object_name, owner||'.'||original_name "ORIGINAL_NAME", createtime
FROM dba_recyclebin ORDER BY 2;
-- only your objects
SELECT object_name, original_name, createtime FROM recyclebin;

-- query a table in recycle bin
SELECT * FROM "BIN$yrMKlZaVMhfgNAgAIMenRA==$0";


-- restore table from recycle bin
FLASHBACK TABLE int_admin_emp TO BEFORE DROP;
-- restore table and rename it
FLASHBACK TABLE int_admin_emp TO BEFORE DROP 
   RENAME TO int2_admin_emp;
-- restore table using recycle bin name
FLASHBACK TABLE "BIN$yrMKlZaVMhfgNAgAIMenRA==$0" TO BEFORE DROP;


-- purge table from recycle bin
PURGE TABLE int_admin_emp;
-- purge table using recycle bin name
PURGE TABLE "BIN$jsleilx392mk2=293$0";

-- purge all tablespace objects
PURGE TABLESPACE example;
-- purge tablespace objects for one user
PURGE TABLESPACE example USER oe;

-- purge your stuff
PURGE RECYCLEBIN;
-- purge everything
PURGE DBA_RECYCLEBIN;
