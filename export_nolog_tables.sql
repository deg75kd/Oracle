set lines 150 pages 200
set serveroutput on
declare
  h1          number;        -- Data Pump job handle
  i           number;        -- Loop index
  v_job_state varchar2(30);  -- To keep track of job state
  v_sts       ku$_Status;    -- Status object returned by get_status
  v_js        ku$_JobStatus; -- Job status from get_status
  v_le        ku$_LogEntry;  -- For WIP and error messages
begin
   -- Declare a new Data Pump job and get a handle for this job:
   h1 := dbms_datapump.open('EXPORT','TABLE');
   
   -- Specify or add a dump file of the dump file set, and a log file:
   dbms_datapump.add_file(h1,'expdp_nolog_meta.dmp','NOLOGMETA',NULL,DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE,1);
   dbms_datapump.add_file(h1,'expdp_nolog_meta.log','NOLOGMETA',NULL,DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
   
   -- Specify table owners:
   dbms_datapump.metadata_filter(h1,'SCHEMA_LIST','''GGTEST'''); 
   
   -- Specify which items to process:
   dbms_datapump.metadata_filter(h1,'NAME_LIST','''ROW_COUNT_LINUX'',''OBJECT_COUNT_AIX'',''ROW_COUNT_AIX'',''OBJECT_COUNT_LINUX''','TABLE');
   
   -- Specify which rows to retrieve:
   dbms_datapump.data_filter(h1,'INCLUDE_ROWS',0,NULL,NULL); 
   
   -- Specify a Data Pump specific parameter
   dbms_datapump.set_parameter(h1,'METRICS',1);
   
   -- Start or resume the job
   dbms_datapump.start_job(h1); 
   
   -- Display that the job was submitted:
   dbms_output.put_line('PLSQL: Data Pump job submitted successfully.');
   dbms_output.put_line('PLSQL: -------------------------------------');

   -- Monitor job and display status:
   v_job_state := 'UNDEFINED';
   while (v_job_state != 'COMPLETED') and (v_job_state != 'STOPPED') loop
     dbms_datapump.get_status(h1,
         dbms_datapump.ku$_status_job_error +
         dbms_datapump.ku$_status_job_status +
         dbms_datapump.ku$_status_wip,-1,v_job_state,v_sts);
     v_js := v_sts.job_status;
 
     -- Display Work in Progress and error messages:
     if (bitand(v_sts.mask,dbms_datapump.ku$_status_wip) != 0)
       then
         v_le := v_sts.wip;
       else
         if (bitand(v_sts.mask,dbms_datapump.ku$_status_job_error) != 0)
           then
             v_le := v_sts.error;
           else
             v_le := null;
         end if;
     end if;
     if v_le is not null
       then
         i := v_le.FIRST;
         while i is not null loop
           dbms_output.put_line(v_le(i).LogText);
           i := v_le.NEXT(i);
         end loop;
     end if;
   end loop;
 
   -- Display that the job finished:
   dbms_output.put_line('PLSQL: -------------------------------------');
   dbms_output.put_line('PLSQL: Job has completed');
   dbms_output.put_line('PLSQL: Final job state = ' || v_job_state);
 
   -- Detach from the handle:
   dbms_datapump.detach(h1);
end;
/
