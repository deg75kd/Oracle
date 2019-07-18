-- #####################
-- # ENABLING AUDITING #
-- #####################

-- parameter AUDIT_TRAIL = { none | os | db | db,extended | xml | xml,extended }
-- requires restart
ALTER SYSTEM SET audit_trail=db SCOPE=SPFILE;


-- ##################
-- # START AUDITING #
-- ##################

-- as dba
-- audit sql statements
AUDIT ALL BY &usrname BY ACCESS;
AUDIT SELECT TABLE, UPDATE TABLE, INSERT TABLE, DELETE TABLE BY &usrname BY ACCESS;
AUDIT EXECUTE PROCEDURE BY &usrname BY ACCESS;

-- log only once per session
AUDIT EXECUTE PROCEDURE BY &usrname BY SESSION;

-- log only failed attempts
AUDIT EXECUTE PROCEDURE BY &usrname BY SESSION WHENEVER NOT SUCCESSFUL;

-- audit use of sys privs
AUDIT CREATE TABLE BY &usrname BY ACCESS;
AUDIT ALL PRIVILEGES BY &usrname BY ACCESS;

-- audit the use of specific objects
AUDIT ALTER ON &tbl_owner.&tbl_name BY ACCESS;


-- ###############
-- # AUDIT TRAIL #
-- ###############

-- views
SYS.AUD$			-- stores all audit info; should be archived regularly
DBA_AUDIT_EXISTS
DBA_AUDIT_OBJECT
DBA_AUDIT_POLICIES
DBA_AUDIT_POLICY_COLUMNS
DBA_AUDIT_SESSION
DBA_AUDIT_STATEMENT
DBA_AUDIT_TRAIL			-- standard auditing only
DBA_FGA_AUDIT_TRAIL		-- fine-grained auditing only
DBA_COMMON_AUDIT_TRAIL		-- both standard & fine-grained auditing
DBA_OBJ_AUDIT_OPTS
DBA_PRIV_AUDIT_OPTS
DBA_REPAUDIT_ATTRIBUTE
DBA_REPAUDIT_COLUMN
DBA_STMT_AUDIT_OPTS

-- basic info
COLUMN username FORMAT A10
COLUMN owner    FORMAT A10
COLUMN obj_name FORMAT A10
COLUMN extended_timestamp FORMAT A35
SELECT username, extended_timestamp, owner, obj_name, action_name
FROM   dba_audit_trail WHERE  owner = '&aud_obj_owner'
ORDER BY timestamp;

-- reading info in XML audit trail
COLUMN db_user       FORMAT A10
COLUMN object_schema FORMAT A10
COLUMN object_name   FORMAT A10
COLUMN extended_timestamp FORMAT A35
SELECT db_user, extended_timestamp, object_schema, object_name, action
FROM   v$xml_audit_trail WHERE  object_schema = '&aud_obj_owner'
ORDER BY extended_timestamp;


-- #########################
-- # FINE-GRAINED AUDITING #
-- #########################

-- create FGA policy
BEGIN
  DBMS_FGA.add_policy(
    object_schema   => 'AUDIT_TEST',
    object_name     => 'EMP',
    policy_name     => 'SALARY_CHK_AUDIT',
    audit_condition => 'SAL > 50000',
    audit_column    => 'SAL');
END;
/

-- using procedure in FGA policy
BEGIN
  DBMS_FGA.add_policy(
    object_schema   => 'AUDIT_TEST',
    object_name     => 'EMP',
    policy_name     => 'SALARY_CHK_AUDIT',
    audit_condition => 'SAL > 50000',
    audit_column    => 'SAL',
    handler_schema  => 'AUDIT_TEST',
    handler_module  => 'FIRE_CLERK',
    enable          => TRUE);
END;
/


-- ##############
-- # REFERENCES #
-- ##############

http://www.oracle-base.com/articles/10g/Auditing_10gR2.php