drop table bad_rows;
create table bad_rows (row_id ROWID
                      ,oracle_error_code number);

undefine lob_column
undefine table_owner
undefine table_with_lob

set concat off
set serveroutput on
declare
  n number;
  error_code number;
  bad_rows number := 0;
  ora600 EXCEPTION;
  PRAGMA EXCEPTION_INIT(ora600, -600);
begin
   for cursor_lob in (select rowid rid, &&lob_column from &&table_owner.&table_with_lob) loop
   begin
     n:=dbms_lob.instr(cursor_lob.&&lob_column,hextoraw('889911')) ;
   exception
    when ora600 then
     bad_rows := bad_rows + 1;
     insert into bad_rows values(cursor_lob.rid,600);
     commit;
    when others then
     error_code:=SQLCODE;
     bad_rows := bad_rows + 1;
     insert into bad_rows values(cursor_lob.rid,error_code);
     commit;  
   end;
  end loop;
  dbms_output.put_line('Total Rows identified with errors in LOB column:'||bad_rows);
end;
/

select * from bad_rows;