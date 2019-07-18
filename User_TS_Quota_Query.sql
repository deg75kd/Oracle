set lines 120 pages 200
col TABLESPACE_NAME format a25
col USERNAME format a20
col "MB" format 999,999,990
col "MAX MB" format 999,999,990
col "BLCKS" format 999,999,990
col max_blocks format 999,999,990
break on report;
compute sum label "TOTAL" of "MB", "MAx MB", "BLCKS", max_blocks on report;
with ttlbytes as (
     select tablespace_name, sum(bytes) ttl_bytes, sum(blocks) ttl_blocks
     from dba_data_files
     group by tablespace_name
  ),
  userquotas as(
     select
     TABLESPACE_NAME,
     USERNAME,
     BYTES,
     max_bytes,
     blocks,
     MAX_BLOCKS
     from dba_ts_quotas
     where username = upper('&&usrname')
)
select
s.tablespace_name,
nvl(q.username, upper('&&usrname')) username,
(nvl(q.bytes,0)/1024/1024) "MB",
case when q.MAX_BYTES = -1 then (s.ttl_bytes/1024/1024) else (nvl(q.max_bytes,0)/1024/1024) end "MAX MB",
nvl(q.BLOCKS,0) "BLCKS",
case when q.MAX_BLOCKS = -1 then s.ttl_blocks else nvl(q.max_blocks,0) end max_blocks
from userquotas q full outer join ttlbytes s
        on (q.tablespace_name = s.tablespace_name)
order by q.username, s.tablespace_name;