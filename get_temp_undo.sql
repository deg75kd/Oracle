-- ######################################
-- # Temp_Redo_Usage.sql				#
-- # Creates a job to track the usage	#
-- #   of temp & redo space				#
-- #									#
-- # Prereq: Create UTL_DIR				#
-- ######################################

-- procedure to record date
CREATE OR REPLACE PROCEDURE TEMP_UNDO_USAGE_PRC AS
	fileHandler UTL_FILE.FILE_TYPE;
	vDate		VARCHAR2(12);
	vUndo		PLS_INTEGER;
	vTemp		PLS_INTEGER;
BEGIN
	-- get date, undo, and redo values
	SELECT to_char(sysdate,'MON-DD HH24:MI') INTO vDate FROM dual;
	SELECT ROUND(sum(ue.bytes)/1024/1024,0) INTO vUndo
		from dba_undo_extents ue where ue.status='ACTIVE';
	SELECT ROUND(SUM( u.blocks * blk.block_size)/1024/1024,0) INTO vTemp
		FROM v$sort_usage u,
			(SELECT block_size
			 FROM dba_tablespaces
			 WHERE contents = 'TEMPORARY') blk;
		
	-- write values to file
	fileHandler := UTL_FILE.FOPEN('UTL_DIR', 'temp_redo_usage.log', 'A');
	UTL_FILE.PUTF(fileHandler, vDate||'\n');
	UTL_FILE.PUTF(fileHandler, 'Undo: '||vUndo||' MB\n');
	UTL_FILE.PUTF(fileHandler, 'Temp: '||vTemp||' MB\n');
	UTL_FILE.PUTF(fileHandler, '\n');
	UTL_FILE.FCLOSE(fileHandler);
EXCEPTION
	WHEN utl_file.invalid_path THEN
		raise_application_error(-20000, 'ERROR: Invalid PATH FOR file.');
END;
/

-- create program using stored procedure
BEGIN
  DBMS_SCHEDULER.create_program (
    program_name        => 'get_temp_undo_prog',
    program_type        => 'STORED_PROCEDURE',
    program_action      => 'TEMP_UNDO_USAGE_PRC',
    number_of_arguments => 0,
    enabled             => TRUE,
    comments            => 'Program to output temp and undo usage');
END;
/

-- Create the schedule.
BEGIN
  DBMS_SCHEDULER.create_schedule (
    schedule_name   => 'get_temp_undo_sched',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MINUTELY;INTERVAL=10',
    end_date        => NULL,
    comments        => 'Repeats every 10 minutes');
END;
/

-- Create job
BEGIN
  DBMS_SCHEDULER.create_job (
    job_name      => 'get_temp_undo_job',
    program_name  => 'get_temp_undo_prog',
    schedule_name => 'get_temp_undo_sched',
    enabled       => TRUE);
END;
/
