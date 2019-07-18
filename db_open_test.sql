SET SERVEROUTPUT ON
DECLARE
	v_Open		VARCHAR2(20);
BEGIN
	select open_mode into v_Open from v$database;
	if v_Open='MOUNTED' then
		DBMS_OUTPUT.PUT_LINE('Database is mounted');
		execute immediate 'alter database open';
	elsif v_Open='READ WRITE' then
		DBMS_OUTPUT.PUT_LINE('Database is open');
	end if;
END;
/

