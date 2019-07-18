###################
# SERVICE TRACING #
###################

-- find the service name for a module
select service_name, module from v$session where module='AddSearch';

-- enable SQL tracing for a given combination of Service Name, MODULE and ACTION
DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE(
   service_name    IN VARCHAR2,
   module_name     IN VARCHAR2 DEFAULT ANY_MODULE,
   action_name     IN VARCHAR2 DEFAULT ANY_ACTION,
   waits           IN BOOLEAN DEFAULT TRUE,
   binds           IN BOOLEAN DEFAULT FALSE,
   instance_name   IN VARCHAR2 DEFAULT NULL, 
   plan_stat       IN VARCHAR2 DEFAULT NULL);

EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE( -
  service_name	=> 'SYS$USERS', -
  module_name	=> 'ClientFee', -
  action_name	=> 'AcceptClientFee', -
  waits		=> TRUE, -
  binds		=> TRUE, -
  instance_name	=> NULL, -
  plan_stat	=> NULL);
EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE('ACTSDE','AddSearch', -
            DBMS_MONITOR.ALL_ACTIONS,TRUE,TRUE,NULL);
EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE('SYS$USERS','AddSearch', -
            DBMS_MONITOR.ALL_ACTIONS,TRUE,TRUE,NULL);



EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE('SDEAPP3','AddSearch', -
            DBMS_MONITOR.ALL_ACTIONS,TRUE,TRUE,NULL);

-- enable tracing for the whole DB
DBMS_MONITOR.DATABASE_TRACE_ENABLE(
   waits          IN BOOLEAN DEFAULT TRUE,
   binds          IN BOOLEAN DEFAULT FALSE,
   instance_name  IN VARCHAR2 DEFAULT NULL);
EXEC DBMS_MONITOR.DATABASE_TRACE_ENABLE(TRUE, FALSE, NULL);


-- disable tracing
DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE(
   service_name    IN  VARCHAR2,
   module_name     IN  VARCHAR2,
   action_name     IN  VARCHAR2 DEFAULT ALL_ACTIONS,
   instance_name   IN  VARCHAR2 DEFAULT NULL);

EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE('ACTSDE','AddSearch');
EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE('actsde.dev.int.acturis.com','AddSearch');
EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE('SYS$USERS','AddSearch');
EXECUTE DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE('SYS$USERS','ClientFee','AcceptClientFee');

EXEC DBMS_MONITOR.DATABASE_TRACE_DISABLE(NULL);

-- see what's being traced
select * from DBA_ENABLED_TRACES;


###################
# SESSION TRACING #
###################

-- Oracle trace event classes
--	Class 1 - dump something
--	Class 2 - trap on error
--	Class 3 - change execution path
--	Class 4 - trace something

-- trace levels
--	1	same as a regular trace.
--	4	also dump bind variables
--	8	also dump wait information
--	12	dump both bind and wait information

-- session tracing
ALTER SESSION SET TRACEFILE_IDENTIFIER=’traceid’;
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';
ALTER SESSION SET SQL_TRACE=TRUE;
EXEC DBMS_SESSION.SET_SQL_TRACE (TRUE);

-- disable it
ALTER SESSION SET EVENTS '10046 trace name context off';
ALTER SESSION SET EVENTS '10298 trace name context off';

-- check set events
set serveroutput on
declare
	event_level number;
begin
	for i in 10000..10999 loop
		sys.dbms_system.read_ev(i,event_level);
		if (event_level > 0) then
			dbms_output.put_line('Event '||to_char(i)||' set at level '||to_char(event_level));
		end if;
	end loop;
end;
/


-- *** session tracing as sysdba ***
-- Identify the OSPID of the applciation session which is going to run the insert. 
connect / as sysdba 
select s.sid, p.pid, p.spid OSPID, s.USERNAME from v$session s, v$process p where s.paddr = p.addr and s.sid = &sessionsid; 

oradebug setospid <OSPID of application session> 
oradebug tracefile_name >>>>>>>>>>>>>>> This will show us the trace file name, 
oradebug unlimit 

oradebug event 10046 trace name context forever,level 12; 
oradebug dump errorstack 3; 
oradebug tracefile_name 

<<<<<<<<<<<<<<<<<<<< Reproduce the problem by running application job >>>>>>>>>>>>>>>>>>>>>>>>>> 

oradebug event 10046 trace name context off; 


##################
# SYSTEM TRACING #
##################



#################
# USING TRCSESS #
#################

/* Tracing information is present in multiple trace files and you 
   must use the trcsess tool to collect it into a single file     */

-- merge the trace output
trcsess  [output=output_file_name]
         [session=session_id]		-- sid.serial#, eg. 21.2371
         [clientid=client_id]
         [service=service_name]		-- v$session.service_name
         [action=action_name]		-- v$session.action ?
         [module=module_name]		-- v$session.module
         [trace_files]			-- null uses all files in directory; leave space between multiple files

trcsess  output=actsde_18nov11.log session=2067.19809 actsde_ora_21260.trc actsde_ora_12008.trc

trcsess  output=D:\oradata\DEVB\acturis\oracle\Acturis9\Admin\udump\POLICY.trc service=actrh5.dev.int.acturis.com module=POLICY
         
         
-- Format the Trace Files 
tkprof IIInbound_22jun11.trc IIInbound_1206.trc
tkprof Policy_22jun11.trc Policy_1206.trc
tkprof actsde_ora_9896.trc actsde_22nov11.trc


##################
# PLUSTRACE ROLE #
##################

-- enable tracing if getting:
-- SP2-0618: Cannot find the Session Identifier.  Check PLUSTRACE role is enabled
-- check if plustrace role exists
select role from dba_roles where role like '%PLUS%';
-- check who has plustrace role
select grantee, admin_option, default_role from dba_role_privs where granted_role='PLUSTRACE';

-- create plustrace role
@D:\Oracle\Product\10.2.0\db_2\sqlplus\admin\plustrce.sql
@D:\Oracle\Product\11.2.0\dbhome_11203\sqlplus\admin\plustrce.sql
grant plustrace to actadmin;

-- create plan_table in schema (required to use the role)
@D:\Oracle\Product\11.2.0\dbhome_11203\RDBMS\ADMIN\utlxplan.sql


###################
# TRACING PACKAGE #
###################

-- Needs to be run as SYS user
-- only picks up existing sessions, not new ones
CREATE OR REPLACE PROCEDURE Session_Tracing
(ViModule   IN    VARCHAR2    DEFAULT NULL,
 ViEvent    IN    NUMBER            DEFAULT 0,
 ViLevel    IN    NUMBER            DEFAULT 0)
IS
  CURSOR CSessions_Module IS
    SELECT sid, serial#, module, osuser, username
    FROM v$session
    WHERE module = ViModule;

  CURSOR CSessions_All IS
    SELECT sid, serial#, module, osuser, username
    FROM v$session;

  vSetEvent   VARCHAR2(100);
BEGIN
  IF ViModule IS NULL THEN
    FOR vRec in CSessions_All LOOP
      dbms_system.set_ev(vRec.sid, vRec.serial#, ViEvent,ViLevel,'');
      --DBMS_OUTPUT.PUT_LINE('Sid: ' || vRec.sid || ' Module: ' || vRec.module || ' OSUser: '|| vRec.osuser || ' Username: '|| vRec.username);
    END LOOP; 

  ELSE
    FOR vRec in CSessions_Module LOOP
      dbms_system.set_ev(vRec.sid, vRec.serial#, ViEvent,ViLevel,'');
      --DBMS_OUTPUT.PUT_LINE('Sid: ' || vRec.sid || ' Module: ' || vRec.module || ' OSUser: '|| vRec.osuser || ' Username: '|| vRec.username);
    END LOOP;
  END IF;
END;
/

-- Example code to run procedure
SET SERVEROUT ON

EXEC Session_Tracing('ClientFee',10046,0)


EXEC Session_Tracing('ClientFee',10046,12)


-- set module for session
DBMS_APPLICATION_INFO.SET_MODULE ( 
   module_name IN VARCHAR2, 
   action_name IN VARCHAR2);

exec DBMS_APPLICATION_INFO.SET_MODULE ('ClientFee',NULL);

-- see who's using module
col module format a30
SELECT sid, serial#, module, osuser, username
FROM v$session WHERE module = '&what_module';


###############
# TRACE FILES #
###############

-- PARSING IN CURSOR
len	length of the cursor
dep	recursive depth of cursor
uid	user id
oct	command type
tim	time parse began (centiseconds)
ad	SQL address of cursor
sqlid	SQL ID

-- PARSE (numbers can be reused)
C	cpu time
e	elapsed time
p	# of blocks read
cr	# of consistent mode blocks read
cu	# of current mode blocks read
mis	# of library cache misses
r	# of rows
og	optimizer goal (1=all_rows, 2=first_rows, 3=rule, 4=choose)

-- EXEC / FETCH
same variables as above

-- WAIT
nam	wait event
ela	elapsed time (microseconds)
p#	specific to each event


-- write to alert and trace files
exec dbms_system.ksdwrt(3, 'This message goes to the alert log and trace file in the udump location');

-- write to trace file only
exec dbms_system.ksdwrt(1, 'This message goes to trace file in the udump location');




