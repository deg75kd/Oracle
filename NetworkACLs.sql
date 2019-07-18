-- ################
-- # GENERAL INFO #
-- ################

https://docs.oracle.com/cd/E11882_01/network.112/e36292/authorization.htm#sthref961

To configure fine-grained access control to external network services, you create an access control list (ACL)
This feature enhances security for network connections because it restricts the external network hosts that a 
	database user can connect to using the PL/SQL network utility packages UTL_TCP, UTL_SMTP, UTL_MAIL, UTL_HTTP, 
	and UTL_INADDR, the DBMS_LDAP PL/SQL package
You should create one access control list dedicated to a group of common users
Do not create too many access control lists
To create the access control list by using the DBMS_NETWORK_ACL_ADMIN package, follow these steps:
	• Step 1: Create the Access Control List and Its Privilege Definitions
	• Step 2: Assign the Access Control List to One or More Network Hosts



-- ###########
-- # QUERIES #
-- ###########

DBA_NETWORK_ACLS
DBA_NETWORK_ACL_PRIVILEGES
DBA_WALLET_ACLS

-- ACLs
set lines 150 pages 200
break on acl on host
col acl format a40
col host format a20
col principal format a20
col privilege format a20
SELECT a.acl, a.host, a.lower_port, a.upper_port, b.principal, b.privilege,
	b.is_grant --, b.start_date, b.end_date
FROM   dba_network_acls a JOIN dba_network_acl_privileges b ON a.acl = b.acl
ORDER BY a.acl, a.host, a.lower_port, a.upper_port, b.principal;

-- check dependencies
col owner format a30
col name format a30
col referenced_name format a30
select owner, name, type, referenced_name
from DBA_DEPENDENCIES
where referenced_name in ('UTL_TCP','UTL_SMTP','UTL_MAIL','UTL_HTTP','UTL_INADDR','DBMS_LDAP')
order by 1,2,3,4;


-- ########
-- # APIs #
-- ########

/*
A database user needs the connect privilege to an external network host computer if he or she is connecting using 
	the UTL_TCP, UTL_SMTP, UTL_MAIL, UTL_HTTP, the DBMS_LDAP package, and the HttpUriType type.
To resolve the host name that was given a host IP address, or the IP address that was given a host name, with the 
	UTL_INADDR package, grant the database user the resolve privilege instead
*/

BEGIN
	DBMS_NETWORK_ACL_ADMIN.create_acl (
		acl          => '/sys/acls/bpa_mail.xml',
		description  => '/sys/acls/bpa_mail.xml',
		principal    => 'GGTEST',
		is_grant     => true,
		privilege    => 'connect',
		start_date   => NULL,
		end_date     => NULL);
	COMMIT;
END;
/

BEGIN
	DBMS_NETWORK_ACL_ADMIN.assign_acl (
		acl         => '/sys/acls/bpa_mail.xml',
		host        => 'smtp.conseco.com',
		lower_port  => NULL,
		upper_port  => NULL);
	COMMIT;
END;
/

BEGIN
	DBMS_NETWORK_ACL_ADMIN.add_privilege (
		acl       => '/sys/acls/bpa_mail.xml',
		principal => 'GGTEST',
		is_grant  => true,
		privilege => 'connect',
		start_date   => NULL,
		end_date     => NULL);
	COMMIT;
END;
/

-- Grant ACL permission (MOS 1209644.1)
SET SERVEROUTPUT ON
BEGIN
  --Only uncomment the following line if ACL "network_services.xml" has already been created
  --DBMS_NETWORK_ACL_ADMIN.DROP_ACL('network_services.xml');
  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL
  (
    ACL         => '<name_of_XML_file>',
    DESCRIPTION => '<name_for_ACL>',
    PRINCIPAL   => '<user_or_role>',
    IS_GRANT    => true,
    PRIVILEGE   => 'connect'
  );

  DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE
  (
    ACL       => '<name_of_XML_file>',
    PRINCIPAL => '<user_or_role>',
    IS_GRANT  => true,
    PRIVILEGE => 'resolve'
  );

  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL
  (
    ACL  => '<name_of_XML_file>',
    HOST => '<host_name>'
  );
  COMMIT;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Error while granting the ACL: '|| SQLERRM);
END;
/

-- Configure ACL for Oracle wallet (MOS 1209644.1)
SET SERVEROUTPUT ON;
BEGIN
  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL
  (
    ACL         => '<name_of_the_XML_file>',
    DESCRIPTION => '<description_for_ACL>',
    PRINCIPAL   => '<user_or_role>',
    IS_GRANT    => TRUE|FALSE,
    PRIVILEGE   => '<privilege_name>',
    START_DATE  => NULL,
    END_DATE    => NULL
  );
  COMMIT;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Error occurred while creating ACL: '|| SQLERRM);
END;
/

BEGIN
  DBMS_NETWORK_ACL_ADMIN.ASSIGN_WALLET_ACL
  (
    ACL         => '<name_of_the_XML_file>',
    WALLET_PATH => 'file:<full_path>'
  );
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Error occurred while assigning ACL to wallet: '|| SQLERRM);
END;
/

-- recommended method for 12c
-- CREATE_ACL, ADD_PRIVILEGE and ASSIGN_ACL are deprecated
-- The 'smtp' privilege allows a user to send mail using the UTL_SMTP or UTL_MAIL package.
-- The 'connect' privilege allows a user to connect to a network service at a host through the UTL_HTTP, UTL_MAIL or UTL_SMTP package.
SET SERVEROUTPUT ON
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE
  (
    HOST       => '<host_name>',
    LOWER_PORT => NULL,
    UPPER_PORT => NULL,
    ACE        => XS$ACE_TYPE(
                               PRIVILEGE_LIST => xs$name_list('smtp'),
                               PRINCIPAL_NAME => '<user_or_role>',
                               PRINCIPAL_TYPE => xs_acl.ptype_db
                             )
  ); 
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Error while granting ACL :'|| SQLERRM);
END;
/


-- #################
-- # Recreate ACLs #
-- #################

-- -----------------------------------------------------------------------------------
-- File Name    : https://oracle-base.com/dba/script_creation/network_acls_ddl.sql
-- Author       : Tim Hall
-- Description  : Displays DDL for all network ACLs.
-- Requirements : Access to the DBA views.
-- Call Syntax  : @network_acls_ddl
-- Last Modified: 14-DEV-2016
-- -----------------------------------------------------------------------------------

SET SERVEROUTPUT ON
DECLARE
  l_last_acl       dba_network_acls.acl%TYPE                 := '~';
  l_last_principal dba_network_acl_privileges.principal%TYPE := '~';
  l_last_host      dba_network_acls.host%TYPE                := '~';

  FUNCTION get_timestamp (p_timestamp IN TIMESTAMP WITH TIME ZONE)
    RETURN VARCHAR2
  AS
    l_return  VARCHAR2(32767);
  BEGIN
    IF p_timestamp IS NULL THEN
      RETURN 'NULL';
    END IF;
    RETURN 'TO_TIMESTAMP_TZ(''' || TO_CHAR(p_timestamp, 'DD-MON-YYYY HH24:MI:SS.FF TZH:TZM') || ''',''DD-MON-YYYY HH24:MI:SS.FF TZH:TZM'')';
  END;
BEGIN
  FOR i IN (SELECT a.acl,
                   a.host,
                   a.lower_port,
                   a.upper_port,
                   b.principal,
                   b.privilege,
                   b.is_grant,
                   b.start_date,
                   b.end_date
            FROM   dba_network_acls a
                   JOIN dba_network_acl_privileges b ON a.acl = b.acl
            ORDER BY a.acl, a.host, a.lower_port, a.upper_port)
  LOOP
    IF l_last_acl <> i.acl THEN
      -- First time we've seen this ACL, so create a new one.
      l_last_host := '~';

      DBMS_OUTPUT.put_line('-- -------------------------------------------------');
      DBMS_OUTPUT.put_line('-- ' || i.acl);
      DBMS_OUTPUT.put_line('-- -------------------------------------------------');
      DBMS_OUTPUT.put_line('BEGIN');
      DBMS_OUTPUT.put_line('  DBMS_NETWORK_ACL_ADMIN.create_acl (');
      DBMS_OUTPUT.put_line('    acl          => ''' || i.acl || ''',');
      DBMS_OUTPUT.put_line('    description  => ''' || i.acl || ''',');
      DBMS_OUTPUT.put_line('    principal    => ''' || i.principal || ''',');
      DBMS_OUTPUT.put_line('    is_grant     => ' || i.is_grant || ',');
      DBMS_OUTPUT.put_line('    privilege    => ''' || i.privilege || ''',');
      DBMS_OUTPUT.put_line('    start_date   => ' || get_timestamp(i.start_date) || ',');
      DBMS_OUTPUT.put_line('    end_date     => ' || get_timestamp(i.end_date) || ');');
      DBMS_OUTPUT.put_line('  COMMIT;');
      DBMS_OUTPUT.put_line('END;');
      DBMS_OUTPUT.put_line('/');
      DBMS_OUTPUT.put_line(' ');
      l_last_acl := i.acl;
      l_last_principal := i.principal;
    END IF;

    IF l_last_principal <> i.principal THEN
      -- Add another principal to an existing ACL.
      DBMS_OUTPUT.put_line('BEGIN');
      DBMS_OUTPUT.put_line('  DBMS_NETWORK_ACL_ADMIN.add_privilege (');
      DBMS_OUTPUT.put_line('    acl       => ''' || i.acl || ''',');
      DBMS_OUTPUT.put_line('    principal => ''' || i.principal || ''',');
      DBMS_OUTPUT.put_line('    is_grant  => ' || i.is_grant || ',');
      DBMS_OUTPUT.put_line('    privilege => ''' || i.privilege || ''',');
      DBMS_OUTPUT.put_line('    start_date   => ' || get_timestamp(i.start_date) || ',');
      DBMS_OUTPUT.put_line('    end_date     => ' || get_timestamp(i.start_date) || ');');
      DBMS_OUTPUT.put_line('  COMMIT;');
      DBMS_OUTPUT.put_line('END;');
      DBMS_OUTPUT.put_line('/');
      DBMS_OUTPUT.put_line(' ');
      l_last_principal := i.principal;
    END IF;

    IF l_last_host <> i.host||':'||i.lower_port||':'||i.upper_port THEN
      DBMS_OUTPUT.put_line('BEGIN');
      DBMS_OUTPUT.put_line('  DBMS_NETWORK_ACL_ADMIN.assign_acl (');
      DBMS_OUTPUT.put_line('    acl         => ''' || i.acl || ''',');
      DBMS_OUTPUT.put_line('    host        => ''' || i.host || ''',');
      DBMS_OUTPUT.put_line('    lower_port  => ' || NVL(TO_CHAR(i.lower_port),'NULL') || ',');
      DBMS_OUTPUT.put_line('    upper_port  => ' || NVL(TO_CHAR(i.upper_port),'NULL') || ');');
      DBMS_OUTPUT.put_line('  COMMIT;');
      DBMS_OUTPUT.put_line('END;');
      DBMS_OUTPUT.put_line('/');
      DBMS_OUTPUT.put_line(' ');
      l_last_host := i.host||':'||i.lower_port||':'||i.upper_port;
    END IF;
  END LOOP;
END;
/


-- ##########
-- # Errors #
-- ##########

Error:		ORA-24247: network access denied by access control list (ACL)
Symptoms:	Errors using UTL_TCP, UTL_HTTP, UTL_SMTP or UTL_MAIL
Cause:		Upgrade to 11gR1
			From 11g Oracle using ACLs via new DBMS_NETWORK_ACL_ADMIN package
Solution:	Use ACL
Reference:	MOS Doc ID 1209644.1

Error:		ORA-24247: network access denied by access control list (ACL)
Symptoms:	Using UTL_HTTP package
			Only happens with connections through listener, not via directo connection
			Resolution from Doc ID 1209644.1 did not resolve problem
Cause:		Envrionment variable HTTP_PROXY is set
Solution:	Unset HTTP_PROXY variable and restart listener and database
Reference:	MOS Doc ID 1430315.1


