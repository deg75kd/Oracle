-- create a directory
CREATE OR REPLACE DIRECTORY MS8_exp AS 'D:\DBA\KEVIN\ADMN';

-- remove a directory
DROP DIRECTORY ms8_exp;

-- grant privs on directory
grant read, write on directory INSREP_EREP3_EXTRACTS to insrepd00;
