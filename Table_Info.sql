SET VERIFY OFF
SET SERVEROUTPUT ON
--ACCEPT table_name PROMPT 'Enter Table Name: '
DECLARE
  psInput           VARCHAR2(32000);
  psTablename       VARCHAR2(32000);
  psSchema          VARCHAR2(32000);
  sAllPrefix        VARCHAR2(32000);
  sTablespace       VARCHAR2(30);
  sOwner            VARCHAR2(30);
  sTable            VARCHAR2(30);
  sErrorTable       VARCHAR2(30);
  nRowCount         NUMBER(10);
  nNumRows          NUMBER(10);
  nTableMB          NUMBER(15,2);
  nIndexMB          NUMBER(15,2);
  nLobMB            NUMBER(15,2);
  nLobIndexMB       NUMBER(15,2);
  dAnalysed         DATE;
  sInsRepDependents VARCHAR2(32000);
  sDW3Dependents    VARCHAR2(32000);
  sOtherDependents  VARCHAR2(32000);
--------------------------------------------------------------------------------
  TYPE rColumnList_t IS RECORD (column_name    VARCHAR2(32000)
                               ,data_type      all_tab_columns.data_type%TYPE
                               ,data_scale     all_tab_columns.data_scale%TYPE
                               ,data_precision all_tab_columns.data_precision%TYPE
                               ,char_used      all_tab_columns.char_used%TYPE
                               ,char_length    all_tab_columns.char_length%TYPE
                               ,nullable       VARCHAR2(32000)
                               ,histogram      VARCHAR2(32000)
                               ,selectivity    NUMBER(6,2)
                               ,default_value  VARCHAR2(32000)
                               );
  TYPE tColumnList_t IS TABLE OF rColumnList_t
  INDEX BY PLS_INTEGER;
--------------------------------------------------------------------------------
  TYPE rIndexList_t IS RECORD(index_name  VARCHAR2(32000)
                             ,index_type  VARCHAR2(32000)
                             ,uniqueness  VARCHAR2(32000)
                             ,cols        VARCHAR2(32000)
                             ,index_owner all_indexes.owner%TYPE
                             );
  TYPE tIndexList_t IS TABLE OF rIndexList_t
  INDEX BY PLS_INTEGER;
--------------------------------------------------------------------------------
  TYPE rForeignKeyList_t IS RECORD(constraint_name  all_constraints.constraint_name%TYPE
                                  ,referenced_table VARCHAR2(32000)
                                  ,cols             VARCHAR2(32000)
                                  );
  TYPE tForeignKeyList_t IS TABLE OF rForeignKeyList_t
  INDEX BY PLS_INTEGER;
--------------------------------------------------------------------------------
  TYPE rConstraintList_t IS RECORD (constraint_name  all_constraints.constraint_name%TYPE
                                   ,owner            all_constraints.owner%TYPE
                                   ,search_condition all_constraints.search_condition%TYPE
                                   );
  TYPE tConstraintList_t IS TABLE OF rConstraintList_t
  INDEX BY PLS_INTEGER;
--------------------------------------------------------------------------------
  tColumnList tColumnList_t;
  tIndexList  tIndexList_t;
  tForeignKeyList tForeignKeyList_t;
  tConstraintList tConstraintList_t;
--------------------------------------------------------------------------------
  FUNCTION Check_DB_User(psTableType IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2
  IS
    sUser   VARCHAR2(32000);
    sPrefix VARCHAR2(32000);
  BEGIN
    SELECT SYS_CONTEXT('userenv','session_user')
    INTO   sUser
    FROM   dual;

    BEGIN
      EXECUTE IMMEDIATE 'SELECT ''X'' FROM dba_tables WHERE 1=0';
      sPrefix := 'DBA';
    EXCEPTION
      WHEN OTHERS THEN
        sPrefix := 'ALL';
    END;
    RETURN sPrefix;
  END Check_DB_User;
--------------------------------------------------------------------------------
  FUNCTION Find_Value(psOwner VARCHAR2, psCName VARCHAR2)
    RETURN VARCHAR2
  IS
    lCondition LONG;
  BEGIN
    EXECUTE IMMEDIATE '
    SELECT search_condition
    FROM   '||sAllPrefix||'_constraints
    WHERE  owner = :sOwner
    AND    constraint_name = :sCName'
    INTO   lCondition
    USING  psOwner
          ,psCName;

    RETURN lCondition;
  END Find_Value;
--------------------------------------------------------------------------------
  FUNCTION Find_Expression(psOwner VARCHAR2, psIName VARCHAR2, pnColPos NUMBER)
    RETURN VARCHAR2
  IS
     lExpression LONG;
  BEGIN
    EXECUTE IMMEDIATE '
    SELECT column_expression column_expression
    FROM   '||sAllPrefix||'_ind_expressions
    WHERE  index_owner  = :sOwner
    AND    index_name   = :sIName
    AND    column_position = :nColPos'
    INTO   lExpression
    USING  psOwner
          ,psIName
          ,pnColPos;

    RETURN lExpression;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END Find_Expression;
--------------------------------------------------------------------------------
  FUNCTION print_columns(psOwner VARCHAR2,psIName VARCHAR2)
  RETURN VARCHAR2
  IS
    sCols VARCHAR2(32000) := NULL;
  BEGIN
    FOR rCol IN (SELECT column_name
                       ,column_position
                 FROM   all_ind_columns
                 WHERE  index_owner = psOwner
                 AND    index_name  = psIName
                 ORDER BY column_position
                )
    LOOP
      IF Find_Expression(psOwner,psIName,rCol.column_position) IS NOT NULL THEN
        sCols := sCols||Find_Expression(psOwner,psIName,rCol.column_position)||', ';
      ELSE
        sCols := sCols||rCol.column_name||', ';
      END IF;
    END LOOP;

    RETURN SUBSTR(sCols,1,LENGTH(sCols)-2);

  END print_columns;
--------------------------------------------------------------------------------
BEGIN
  psInput     := UPPER('&1');
  CASE
    WHEN INSTR(psInput,'.',1,1) <> 0 THEN
      psSchema    := REGEXP_SUBSTR(psInput,'^[[:alnum:]_]+');
      psTablename := REGEXP_REPLACE(psInput,'^[[:alnum:]_]+[.]{1}','');
    ELSE
      psTablename := psInput;
  END CASE;
  sAllPrefix       := Check_DB_User;

  BEGIN
    EXECUTE IMMEDIATE
    'SELECT owner t_owner
           ,owner t_schema
           ,num_rows
           ,table_name
           ,last_analyzed
     FROM   '||sAllPrefix||'_tables
     WHERE  table_name = :sTableName
     AND    CASE
              WHEN :sSchema IS NULL THEN
                owner
              ELSE
                :sSchema
              END = owner'
   INTO   sOwner
         ,psSchema
         ,nNumRows
         ,sTable
         ,dAnalysed
   USING  psTableName
         ,psSchema
         ,psSchema;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbms_output.new_line;
      RAISE_APPLICATION_ERROR(-20120,'Table Not Found');
    WHEN TOO_MANY_ROWS THEN
      dbms_output.new_line;
      RAISE_APPLICATION_ERROR(-20121,'More Than One Table, Include Schema');
  END;

  BEGIN
    CASE
      WHEN sAllPrefix = 'DBA' THEN
        EXECUTE IMMEDIATE
        'SELECT ROUND(SUM(t_s.bytes)/1024/1024,2) table_mb
               ,ROUND(SUM(ind.bytes)/1024/1024,2) index_mb
               ,ROUND(SUM(lob.bytes)/1024/1024,2) lob_mb
               ,ROUND(SUM(lob_ind.bytes)/1024/1024,2) lob_index_mb
               ,t_s.tablespace_name
         FROM   dba_segments t_s
         LEFT JOIN (SELECT SUM(s.bytes) bytes
                          ,i.table_name
                          ,i.owner
                    FROM   dba_segments s
                    JOIN   dba_indexes i
                      ON   s.segment_name = i.index_name
                     AND   s.owner        = i.owner
                    GROUP BY i.table_name
                            ,i.owner
                   ) ind
                ON t_s.segment_name = ind.table_name
               AND t_s.owner = ind.owner
         LEFT JOIN (SELECT l.table_name
                          ,l.owner
                          ,SUM(s.bytes) bytes
                    FROM   dba_lobs l
                    JOIN   dba_segments s
                      ON   l.segment_name = s.segment_name
                     AND   l.owner        = s.owner
                    GROUP BY l.table_name
                            ,l.owner
                   ) lob
                ON t_s.segment_name = lob.table_name
               AND t_s.owner = lob.owner
         LEFT JOIN (SELECT l.table_name
                          ,l.owner
                          ,SUM(s.bytes) bytes
                    FROM   dba_lobs l
                    JOIN   dba_segments s
                      ON   l.index_name = s.segment_name
                     AND   l.owner      = s.owner
                    GROUP BY l.table_name
                            ,l.owner
                   ) lob_ind
                ON t_s.segment_name = lob_ind.table_name
               AND t_s.owner = lob_ind.owner
         WHERE  t_s.segment_name = :sTableName
         AND    t_s.owner = :sSchema
         GROUP BY t_s.tablespace_name'
        INTO   nTableMB
              ,nIndexMB
              ,nLobMB
              ,nLobIndexMB
              ,sTableSpace
        USING  psTableName
              ,psSchema;
      ELSE
        EXECUTE IMMEDIATE
        'SELECT ROUND(SUM(t_s.bytes)/1024/1024,2) table_mb
               ,ROUND(SUM(ind.bytes)/1024/1024,2) index_mb
               ,ROUND(SUM(lob.bytes)/1024/1024,2) lob_mb
               ,ROUND(SUM(lob_ind.bytes)/1024/1024,2) lob_index_mb
               ,t_s.tablespace_name
         FROM   user_segments t_s
         LEFT JOIN (SELECT SUM(s.bytes) bytes
                          ,i.table_name
                    FROM   user_segments s
                    JOIN   user_indexes i
                      ON   s.segment_name = i.index_name
                    GROUP BY i.table_name
                   ) ind
                ON t_s.segment_name = ind.table_name
         LEFT JOIN (SELECT l.table_name
                          ,SUM(s.bytes) bytes
                    FROM   user_lobs l
                    JOIN   user_segments s
                      ON   l.segment_name = s.segment_name
                    GROUP BY l.table_name
                   ) lob
                ON t_s.segment_name = lob.table_name
         LEFT JOIN (SELECT l.table_name
                          ,SUM(s.bytes) bytes
                    FROM   user_lobs l
                    JOIN   user_segments s
                      ON   l.index_name = s.segment_name
                    GROUP BY l.table_name
                   ) lob_ind
                ON t_s.segment_name = lob_ind.table_name
         WHERE  t_s.segment_name = :sTableName
         GROUP BY t_s.tablespace_name'
        INTO   nTableMB
              ,nIndexMB
              ,nLobMB
              ,nLobIndexMB
              ,sTableSpace
        USING  psTableName;
    END CASE;

  EXCEPTION
    WHEN OTHERS THEN
      sTablespace := 'N/A';
      nTableMB := 0;
  END;

  BEGIN
    EXECUTE IMMEDIATE
    'SELECT LISTAGG(name,'', '') WITHIN GROUP (ORDER BY name)
     FROM   '||sAllPrefix||'_dependencies
     WHERE  referenced_name = :sTableName
     AND    owner = ''INSREPD00''
     AND    referenced_owner = :sSchema
     AND    rownum<=10'
    INTO   sInsrepDependents
    USING  psTableName
          ,psSchema;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      sInsrepDependents := 'None';
  END;

  BEGIN
    EXECUTE IMMEDIATE
    'SELECT LISTAGG(name,'', '') WITHIN GROUP (ORDER BY name)
     FROM   '||sAllPrefix||'_dependencies
     WHERE  referenced_name = :TableName
     AND    owner = ''DW3''
     AND    referenced_owner = :sSchema
     AND    rownum<=100'
    INTO   sDW3Dependents
    USING  psTableName
          ,psSchema;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      sDW3Dependents := 'None';
  END;



  BEGIN
    EXECUTE IMMEDIATE
    'SELECT LISTAGG(owner||''.''||name,'', '') WITHIN GROUP (ORDER BY name)
     FROM   '||sAllPrefix||'_dependencies
     WHERE  referenced_name = :sTableName
     AND    owner NOT IN (''DW3'',''INSREPD00'')
     AND    referenced_owner = :sSchema
     AND    rownum<=100'
    INTO   sOtherDependents
    USING  psTableName
          ,psSchema;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      sOtherDependents := 'None';
  END;


  BEGIN
    EXECUTE IMMEDIATE
    'SELECT table_name
     FROM   '||sAllPrefix||'_tab_comments
     WHERE  comments = ''DML Error Logging table for "'||psTableName||'"''
     AND    owner = :sSchema'
    INTO sErrorTable
    USING psSchema;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      sErrorTable := 'N/A';
  END;

  dbms_output.new_line;
  dbms_output.new_line;
  dbms_output.new_line;
  dbms_output.put_line('Table Name       : '||sTable);
  dbms_output.put_line('Owner            : '||sOwner);
  dbms_output.put_line('Tablespace       : '||sTablespace);
  dbms_output.put_line('Error Table      : '||sErrorTable);
  dbms_output.put_line('Rows (stats)     : '||TRIM(TO_CHAR(nNumRows,'999,999,999,999')));
  dbms_output.put_line('Size (MB)');
  dbms_output.put_line('  Table          : '||LPAD(TRIM(TO_CHAR(nTableMB   ,'999,999,999.99')),10));
  dbms_output.put_line('  Indexes        : '||LPAD(TRIM(TO_CHAR(nIndexMB   ,'999,999,999.99')),10));
  dbms_output.put_line('  Lob            : '||LPAD(TRIM(TO_CHAR(nLobMB     ,'999,999,999.99')),10));
  dbms_output.put_line('  Lob Index      : '||LPAD(TRIM(TO_CHAR(nLobIndexMB,'999,999,999.99')),10));
  dbms_output.put_line('Last Analysed    : '||TO_CHAR(dAnalysed,'dd/mm/yyyy hh24:mi:ss'));
  dbms_output.put_line('DW3 Dependents   : '||sDW3Dependents);
  dbms_output.new_line;
  dbms_output.put_line('OTHER Dependents : '||sOtherDependents);
  dbms_output.new_line;
  dbms_output.put_line('INSREP Dependents: '||sInsRepDependents);
  dbms_output.new_line;
  dbms_output.put_line('Columns');
  dbms_output.put_line('  Name                           Type                     Nul His Card % Default');
  dbms_output.put_line('  ------------------------------ ------------------------ --- --- ------ -----------------------------');
  EXECUTE IMMEDIATE
  'SELECT column_name
         ,data_type
         ,data_scale
         ,data_precision
         ,char_used
         ,char_length
         ,DECODE(nullable,''Y'',''Yes'',''No'') nullable
         ,CASE WHEN num_buckets > 1 THEN ''Yes'' ELSE ''No'' END histogram
         ,ROUND(CASE WHEN NVL(:nNumRows1,0) = 0.00 THEN 0
                     WHEN NVL(num_distinct,0) = 0.00 THEN 0
                     ELSE ((:nNumRows2/num_distinct)/:nNumRows3)*100
                END
               ,2) selectivity
         ,data_default
  FROM    '||sAllPrefix||'_tab_columns
  WHERE   table_name = :sTableName
  AND     owner = :sSchema
  ORDER BY 1'
  BULK COLLECT INTO tColumnList
  USING nNumRows
       ,nNumRows
       ,nNumRows
       ,psTableName
       ,psSchema;

  FOR i IN 1..tColumnList.COUNT
  LOOP
    dbms_output.put('  '||RPAD(tColumnList(i).column_name,31));
    IF tColumnList(i).data_type = 'VARCHAR2' THEN
      IF tColumnList(i).char_used = 'C' THEN
        dbms_output.put(RPAD('VARCHAR2('||tColumnList(i).char_length||' CHAR)',25));
      ELSE
        dbms_output.put(RPAD('VARCHAR2('||tColumnList(i).char_length||')',25));
      END IF;
    ELSIF tColumnList(i).data_type = 'NUMBER' AND tColumnList(i).data_precision IS NOT NULL THEN
      dbms_output.put(RPAD('NUMBER('||TO_CHAR(tColumnList(i).data_precision)||','||TO_CHAR(tColumnList(i).data_scale)||')',25));
   ELSIF tColumnList(i).data_type = 'NUMBER' THEN
      dbms_output.put(RPAD('NUMBER',25));
    ELSE
      dbms_output.put(RPAD(tColumnList(i).data_type,25));
    END IF;
    dbms_output.put(RPAD(tColumnList(i).nullable,4)||RPAD(tColumnList(i).histogram,3)||RPAD(TO_CHAR(tColumnList(i).selectivity,'999.99'),7));
    dbms_output.put(SUBSTR(REPLACE(REPLACE(tColumnList(i).default_value,CHR(10),''),CHR(13),''),1,30));
    dbms_output.new_line;
  END LOOP;
  dbms_output.new_line;
  dbms_output.put_line('Indexes (Including PK)');
  dbms_output.put_line('  Name                           Type                  Columns');
  dbms_output.put_line('  ------------------------------ --------------------- ------------------------------------------------------------ ');
  EXECUTE IMMEDIATE
  'SELECT index_name
         ,REPLACE(index_type,''NORMAL'',''B-TREE'') index_type
         ,DECODE(uniqueness,''UNIQUE'',''UNIQUE '',NULL) uniqueness
         ,LISTAGG(column_name,'', '') WITHIN GROUP (ORDER BY column_position) cols
        ,index_owner
   FROM   (SELECT ai.index_name
                 ,ai.index_type
                 ,ai.owner index_owner
                 ,aic.column_name column_name
                 ,aic.column_position
                 ,ai.uniqueness
           FROM   '||sAllPrefix||'_indexes ai
           JOIN   '||sAllPrefix||'_ind_columns aic
             ON   ai.index_name = aic.index_name
            AND   ai.owner      = aic.index_owner
           WHERE  ai.table_name = :sTableName
           AND    ai.owner = :sSchema
          )
   GROUP BY index_name
           ,index_type
           ,index_owner
           ,uniqueness
   ORDER BY INSTR(index_name,''_PK'') desc
           ,index_name'
  BULK COLLECT INTO tIndexList
  USING psTableName
       ,psSchema;

  FOR i IN 1..tIndexList.COUNT
  LOOP
    dbms_output.put('  '||RPAD(tIndexList(i).index_name,31));
    dbms_output.put(RPAD(tIndexList(i).uniqueness||tIndexList(i).index_type,22));
    IF tIndexList(i).index_type LIKE 'FUNCTION%' THEN
      dbms_output.put(print_columns(tIndexList(i).index_owner,tIndexList(i).index_name));
    ELSE
      dbms_output.put(tIndexList(i).cols);
    END IF;
    dbms_output.new_line;
  END LOOP;
  dbms_output.new_line;
  dbms_output.put_line('Foreign Keys');
  dbms_output.put_line('  Name                           Table                          Columns');
  dbms_output.put_line('  ------------------------------ ------------------------------ ----------------------------------------------------');
  EXECUTE IMMEDIATE
  'SELECT  ac.constraint_name
          ,rc.table_name referenced_table
          ,LISTAGG(acc.column_name,'', '') WITHIN GROUP (ORDER BY acc.position) cols
   FROM    '||sAllPrefix||'_constraints ac
   JOIN    '||sAllPrefix||'_cons_columns acc
     ON    ac.constraint_name = acc.constraint_name
    AND    ac.owner           = acc.owner
   LEFT JOIN    '||sAllPrefix||'_constraints rc
          ON    ac.r_constraint_name  = rc.constraint_name
         AND    ac.r_owner            = rc.owner
   WHERE   ac.table_name = :sTableName
   AND     ac.constraint_type = ''R''
   AND     ac.owner = :sSchema
   GROUP BY ac.constraint_name
           ,rc.table_name
   ORDER BY constraint_name'
  BULK COLLECT INTO tForeignKeyList
  USING psTableName
       ,psSchema;

  FOR i IN 1..tForeignKeyList.COUNT
  LOOP
    dbms_output.put('  '||RPAD(tForeignKeyList(i).constraint_name,31));
    dbms_output.put(RPAD(tForeignKeyList(i).referenced_table,31));
    dbms_output.put(tForeignKeyList(i).cols);
    dbms_output.new_line;
  END LOOP;
  dbms_output.new_line;
  dbms_output.put_line('Check Constraints');
  dbms_output.put_line('  Name                           Condition');
  dbms_output.put_line('  ------------------------------ -----------------------------------------------------------------------------------');
  EXECUTE IMMEDIATE
  'SELECT  ac.constraint_name
          ,ac.owner
          ,ac.search_condition
   FROM    '||sAllPrefix||'_constraints ac
   WHERE   ac.table_name = :sTableName
   AND     ac.constraint_type = ''C''
   AND     ac.owner = :sSchema
   ORDER BY constraint_name'
  BULK COLLECT INTO tConstraintList
  USING psTableName
       ,psSchema;
  FOR i IN 1..tConstraintList.COUNT
  LOOP
    dbms_output.put('  '||RPAD(tConstraintList(i).constraint_name,31));
    dbms_output.put(RPAD(Find_Value(tConstraintList(i).owner,tConstraintList(i).constraint_name),70));
    dbms_output.new_line;
  END LOOP;
  dbms_output.new_line;
END;
/
undefine 1
