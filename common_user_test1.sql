-- ####################
-- # Common User Test #
-- # lxora12cinfs02   #
-- # cawdm            #
-- # 14 Mar 17        #
-- ####################

set lines 200 pages 200
show con_name
CON_NAME
------------------------------
CDB$ROOT

show parameter common_user_prefix
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
common_user_prefix                   string      C##

select username, COMMON from dba_users where username like 'C##%' order by 1;
USERNAME                                                                                                                         COM
-------------------------------------------------------------------------------------------------------------------------------- ---
C##GGS                                                                                                                           YES

select username, COMMON from dba_users where COMMON='YES' order by 1;
60 rows selected.

alter system set common_user_prefix='' scope=spfile;
shutdown immediate
startup

show parameter common_user_prefix
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
common_user_prefix                   string

create user commontest
identified by Oracle1;
grant connect to commontest container=all;
grant select on v_$database to commontest container=all;
grant select on dba_users to commontest;

-- *** COMMONTEST USER *** ---
conn commontest/Oracle1

show con_name
CON_NAME
------------------------------
CDB$ROOT

select con_id, name, open_mode from v$database order by con_id;
    CON_ID NAME      OPEN_MODE
---------- --------- --------------------
         0 CAWDM     READ WRITE

select username, COMMON from dba_users where username like 'C##%' order by 1;
USERNAME                                                                                                                         COM
-------------------------------------------------------------------------------------------------------------------------------- ---
C##GGS                                                                                                                           YES

-- change to PDB
alter session set container=awdm;

show con_name
CON_NAME
------------------------------
AWDM

select con_id, name, open_mode from v$database order by con_id;
    CON_ID NAME      OPEN_MODE
---------- --------- --------------------
         0 CAWDM     READ WRITE

select username, COMMON from dba_users where username like 'C##%' order by 1;
ERROR at line 1:
ORA-00942: table or view does not exist


-- *** COMMON PROFILE TEST *** ---

conn sys as sysdba
show con_name
CON_NAME
------------------------------
CDB$ROOT

col profile format a25
select distinct profile, common from dba_profiles order by 1;
PROFILE                   COM
------------------------- ---
APP_PROFILE               YES
C##APP_PROFILE            YES
C##CNO_PROFILE            YES
CNO_PROFILE               YES
DEFAULT                   NO
ORA_STIG_PROFILE          NO

CREATE PROFILE TEST_PROFILE
    LIMIT
    SESSIONS_PER_USER          	UNLIMITED
    CPU_PER_SESSION            	UNLIMITED
    CPU_PER_CALL               	UNLIMITED
    CONNECT_TIME               	UNLIMITED
    IDLE_TIME                  		UNLIMITED
    LOGICAL_READS_PER_SESSION  UNLIMITED
    COMPOSITE_LIMIT            	UNLIMITED
    PRIVATE_SGA                	UNLIMITED
    FAILED_LOGIN_ATTEMPTS      	UNLIMITED
    PASSWORD_LIFE_TIME         	UNLIMITED
    PASSWORD_REUSE_TIME        	UNLIMITED
    PASSWORD_REUSE_MAX         	UNLIMITED
    PASSWORD_LOCK_TIME         	UNLIMITED
    PASSWORD_GRACE_TIME        	UNLIMITED
    PASSWORD_VERIFY_FUNCTION   VERIFY_FUNCTION_CNO
/

select distinct profile, common from dba_profiles order by 1;
PROFILE                   COM
------------------------- ---
APP_PROFILE               YES
C##APP_PROFILE            YES
C##CNO_PROFILE            YES
CNO_PROFILE               YES
DEFAULT                   NO
ORA_STIG_PROFILE          NO
TEST_PROFILE              YES

-- change to PDB
alter session set container=awdm;
select distinct profile, common from dba_profiles order by 1;
PROFILE                   COM
------------------------- ---
APP_PROFILE               YES
C##APP_PROFILE            YES
C##CNO_PROFILE            YES
CNO_PROFILE               YES
DEFAULT                   NO
ORA_STIG_PROFILE          NO
TEST_PROFILE              YES

