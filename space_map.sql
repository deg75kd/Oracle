var tablespace varchar2(30)

exec :tablespace := '&tablespace'


set termout off
spool 1.lst
select file_id
      ||chr(9)||block_id
      ||CHR(9)||end_block
      ||CHR(9)||blocks   
      ||CHR(9)||owner
      ||CHR(9)||segment_name
      ||CHR(9)||partition_name
      ||CHR(9)||segment_type
from  (select file_id
             ,min(block_id) block_id
             ,max(end_block) end_block
             ,sum(blocks) blocks
             ,owner
             ,segment_name
             ,partition_name
             ,segment_type
       from   (select file_id
                     ,block_id
                     ,block_id + blocks - 1 end_block
                     ,blocks   
                     ,owner
                     ,segment_name
                     ,partition_name
                     ,segment_type
                     ,row_number() over (order by file_id, block_id)
                    - row_number() over (partition by file_id, segment_name, partition_name
                                         order by     file_id, block_id
                                        ) grp
               from   dba_extents
               where  tablespace_name = :tablespace
               and segment_type <> 'TEMPORARY'
               )
       group by file_id, owner, segment_name,partition_name,segment_type,grp
       union all
       select file_id
             ,block_id
             ,block_id + blocks - 1 
             ,blocks 
             ,'free'          
             ,'free'          
             ,null            
             ,null            
       from   dba_free_space
       where  tablespace_name = :tablespace
       order by file_id, block_id
      )
/
spool off
host 1.lst
