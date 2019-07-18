-- find location for alert files
sho parameter background_dump_dest;

-- find location for log or Oracle errors
sho parameter user_dump_dest;

-- query alert log
col "TIME" format a20
col MESSAGE_TEXT format a95
select to_char(ORIGINATING_TIMESTAMP,'DD-MON-RR HH24.MI.SS') "TIME", MESSAGE_TEXT
from x$dbgalertext
where ORIGINATING_TIMESTAMP >= (systimestamp - 12/24)
order by ORIGINATING_TIMESTAMP;

-- write to the alert log
-- http://www.dbapundits.com/blog/query-script/dbms_system-ksdwrt%E2%80%93write-messages-to-oracle-alert-log/
exec dbms_system.ksdwrt(2, 'ORA-00060: Testing monitoring tool');

-- write to alert and trace files
exec dbms_system.ksdwrt(3, 'This message goes to the alert log and trace file in the udump location');

-- write to trace file only
exec dbms_system.ksdwrt(1, 'This message goes to trace file in the udump location');