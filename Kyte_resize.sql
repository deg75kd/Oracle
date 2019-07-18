/************************ KYTE RESIZE *********************************************************/

-- find possible savings by resizing datafiles (takes awhile)
-- added minimum value but not quite precise
set verify off
column file_name format a60 word_wrapped
column smallest format 9,999,990 heading "Smallest|Poss."
column currsize format 9,999,990 heading "Current|Size"
column savings  format 9,999,990 heading "Poss.|Savings"
break on report
compute sum of savings on report
column value new_val blksize
select value from v$parameter where name = 'db_block_size';
select c.tablespace_name,
       sum(greatest(ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024), ((c.min_extents*c.initial_extent+a.bytes-a.user_bytes)/1024/1024) )) smallest,
       sum(ceil( a.blocks*&&blksize/1024/1024)) currsize,
       sum(ceil( a.blocks*&&blksize/1024/1024) - greatest(ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024), ((c.min_extents*c.initial_extent+a.bytes-a.user_bytes)/1024/1024) )) savings
from dba_data_files a, dba_tablespaces c,
     ( select file_id, max(block_id+blocks-1) hwm
         from dba_extents
        group by file_id ) b
where a.file_id = b.file_id(+) and a.tablespace_name=c.tablespace_name
  group by c.tablespace_name order by c.tablespace_name;


-- actual resizing
set lines 200 pages 0
set head off
spool tbs_shrink.out;

select 'alter database datafile '''||a.file_name||''' resize ' ||greatest(ceil( (nvl(b.hwm,1)*&&blksize)), (c.min_extents*c.initial_extent)+(a.bytes - a.user_bytes))|| ';'
from dba_data_files a, dba_tablespaces c,
     ( select file_id, max(block_id+blocks-1) hwm
         from dba_extents 
        group by file_id ) b
where a.file_id = b.file_id(+) and a.tablespace_name=c.tablespace_name
  and a.tablespace_name='DQI_TABLES_X4M'
  and ceil( a.blocks*&&blksize/1024/1024) -
      ceil( (nvl(b.hwm,1)*&&blksize)/1024/1024 ) > 0;

spool off;
@tbs_shrink.out
