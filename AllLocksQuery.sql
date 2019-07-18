set linesize 120 pagesize 200 trimspool on
column username format a10
column osuser format a10
column sid format 99999
column object format a35
column type format a35

select s.username, s.sid, s.serial#,
       s.osuser, k.ctime, o.object_name object, k.kaddr,
case l.locked_mode when 1 then 'No Lock'
                   when 2 then 'Row Share'
                   when 3 then 'Row Exclusive'
                   when 4 then 'Shared Table'
                   when 5 then 'Shared Row Exclusive'
                   when 6 then 'Exclusive'
end locked_mode,
case
when k.type = 'AE' then 'Application Edition'
when k.type = 'BL' then 'Buffer Cache Management (PCM lock)'
when k.type = 'CF' then 'Controlfile Transaction'
when k.type = 'CI' then 'Cross Instance Call'
when k.type = 'CU' then 'Bind Enqueue'
when k.type = 'DF' then 'Data File'
when k.type = 'DL' then 'Direct Loader'
when k.type = 'DM' then 'Database Mount'
when k.type = 'DR' then 'Distributed Recovery'
when k.type = 'DX' then 'Distributed Transaction'
when k.type = 'FS' then 'File Set'
when k.type = 'IN' then 'Instance Number'
when k.type = 'IR' then 'Instance Recovery'
when k.type = 'IS' then 'Instance State'
when k.type = 'IV' then 'Library Cache Invalidation'
when k.type = 'JQ' then 'Job Queue'
when k.type = 'KK' then 'Redo Log Kick'
when k.type like 'L%' then 'Library Cache Lock'
when k.type = 'MM' then 'Mount Definition'
when k.type = 'MR' then 'Media Recovery'
when k.type like 'N%' then 'Library Cache Pin'
when k.type = 'PF' then 'Password File'
when k.type = 'PI' then 'Parallel Slaves'
when k.type = 'PR' then 'Process Startup'
when k.type = 'PS' then 'Parallel slave Synchronization'
when k.type like 'Q%' then 'Row Cache Lock'
when k.type = 'RT' then 'Redo Thread'
when k.type = 'SC' then 'System Commit number'
when k.type = 'SM' then 'SMON synchronization'
when k.type = 'SN' then 'Sequence Number'
when k.type = 'SQ' then 'Sequence Enqueue'
when k.type = 'SR' then 'Synchronous Replication'
when k.type = 'SS' then 'Sort Segment'
when k.type = 'ST' then 'Space Management Transaction'
when k.type = 'SV' then 'Sequence Number Value'
when k.type = 'TA' then 'Transaction Recovery'
when k.type = 'TM' then 'DML Enqueue'
when k.type = 'TS' then 'Table Space (or Temporary Segment)'
when k.type = 'TT' then 'Temporary Table'
when k.type = 'TX' then 'Transaction'
when k.type = 'UL' then 'User-defined Locks'
when k.type = 'UN' then 'User Name'
when k.type = 'US' then 'Undo segment Serialization'
when k.type = 'WL' then 'Writing redo Log'
when k.type = 'XA' then 'Instance Attribute Lock'
when k.type = 'XI' then 'Instance Registration Lock'
 end type
from v$session s, sys.v_$_lock c, sys.v_$locked_object l, dba_objects o, sys.v_$lock k
where o.object_id = l.object_id
and l.session_id = s.sid
and k.sid = s.sid
and s.saddr = c.saddr
and k.kaddr = c.kaddr
and k.lmode = l.locked_mode
and k.lmode = c.lmode
and k.request = c.request
order by object;