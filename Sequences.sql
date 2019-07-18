-- ###################
-- # Using sequences #
-- ###################

-- use sequence in insert statement
insert into audit_gkpr.daily_update
	(daily_id, weekday, month, monthday, year, currtime)
values (
	audit_gkpr.daily_update_seq.nextval,
	to_char(sysdate,'Day'),
	to_char(sysdate,'Month'),
	to_char(sysdate,'DD'),
	to_char(sysdate,'YYYY'),
	to_char(sysdate,'HH:MI:SS AM')
);

-- increment sequence
SELECT webstats.AWETrans_archive_run_seq.NEXTVAL FROM dual;
SELECT &what_owner..&what_seq..NEXTVAL FROM dual;

-- view current number
SELECT webstats.AWETrans_archive_run_seq.CURRVAL FROM dual;
SELECT &what_owner..&what_seq..CURRVAL FROM dual;

-- use sequence in pl/sql block
SELECT webstats.AWETrans_archive_run_seq.NEXTVAL INTO vRunSeqNo FROM dual;


-- #####################
-- # Create a Sequence #
-- #####################

CREATE SEQUENCE apex_ts_history_seq
START WITH 1 INCREMENT BY 1
NOMAXVALUE NOCYCLE;

CREATE SEQUENCE  "CORE_EXT"."AUDIT_LOG_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 67746 NOCACHE  NOORDER  NOCYCLE;

-- change increment value
ALTER SEQUENCE &what_sequence INCREMENT BY &what_increment;


/* WEBSTATS QUERIES */
-- If increment is positive, the sequence needs to be advanced

-- AWETRANS
select awe.AWE "AWETRANS", us.last_number "SEQ", (awe.AWE - us.last_number) "INCREMENT"
from user_sequences us, (select max(awetransseqno) as AWE from awetrans) awe
where us.sequence_name='AWETRANSSEQ';

-- ACWSTRANS
select acws.ACWS "ACWSTRANS", us.last_number "SEQ", (acws.ACWS - us.last_number) "INCREMENT"
from user_sequences us, (select max(acwstransseqno) as ACWS from acwstrans) acws
where us.sequence_name='ACWSTRANSSEQ';

-- AWETRANS ARCHIVE RUN
select run.RUN "ARCHIVE_RUN", us.last_number "SEQ", (run.RUN - us.last_number) "INCREMENT"
from user_sequences us, (select max(runseqno) as RUN from awetrans_archive_run) run
where us.sequence_name='AWETRANS_ARCHIVE_RUN_SEQ';

-- AWETRANS ARCHIVE INCIDENT
select INCID.incid "ARCHIVE_INCIDENT", us.last_number "SEQ", (INCID.incid - us.last_number) "INCREMENT"
from user_sequences us, (select max(incidentseqno) as INCID from awetrans_archive_incident) incid
where us.sequence_name='AWETRANS_ARCHIVE_INCIDENT_SEQ';


/*--- REBUILD SEQUENCES ---*/
set long 10000000
set echo off
set lines 1000 pages 0
set trimspool on
COL "DDL"  FORMAT A1000
column filename new_val filename
spool /oragg/datapump/idwp/rebuild_sequences.sql
select 'DROP SEQUENCE '||SEQUENCE_OWNER||'.'||SEQUENCE_NAME||';' from dba_sequences where sequence_owner='ARDB_GKPR';
select DBMS_METADATA.GET_DDL('SEQUENCE',SEQUENCE_NAME,SEQUENCE_OWNER)||';' "DDL" from dba_sequences where sequence_owner='ARDB_GKPR';
spool off