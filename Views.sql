###########
# CHANGES #
###########

-- recompile a view
alter view CTRL_RISK_DETAILS_TMP_VW compile;

-- drop a view
DROP VIEW &what_view;

-- see compilation errors
set serveroutput on
show errors view &what_view;

###########
# QUERIES #
###########

-- get definition of a view
col text format a119
set long 50000
select text from dba_VIEWS where view_name=upper('&what_view') and owner=upper('&what_owner');

-- as the owner
col text format a119
set long 50000
select text from user_VIEWS where view_name=upper('&what_view');

-- get definitions for all of a user's views
col view_name format a30
col text format a88
set long 50000
select view_name, text from dba_VIEWS where owner=upper('&what_owner') order by 1;

-- as the user
col view_name format a30
col text format a88
set long 50000
select view_name, text from user_VIEWS order by 1;

-- get status of a user's views
col view_name format a30
select uv.view_name, uo.status, uo.last_ddl_time
from dba_VIEWS uv join dba_objects uo on uv.view_name=uo.object_name
where uo.object_type='VIEW' and uv.owner=upper('&what_owner')
order by 1;

-- as the user
col view_name format a30
select uv.view_name, uo.status, uo.last_ddl_time
from user_VIEWS uv join user_objects uo on uv.view_name=uo.object_name
where uo.object_type='VIEW'
order by 1;

-- get definition of invalid views
-- as the user
col view_name format a30
col text format a88
set long 50000
select uv.view_name, uv.text
from user_VIEWS uv join user_objects uo on uv.view_name=uo.object_name
where uo.object_type='VIEW' and uo.status!='VALID'
order by 1;

-- is a view read-only
col owner format a30
col view_name format a30
select OWNER, VIEW_NAME, READ_ONLY
from DBA_VIEWS
where OWNER='EDW_PERST' and VIEW_NAME in ('S1_CLNT_PTY_VW','VW_S1_AGT','VW_S1_PTY')
order by 1,2;



-- ######################
-- # MATERIALIZED VIEWS #
-- ######################

-- get status of a user's mviews
col mview_name format a30
select uv.mview_name, uo.status, uo.last_ddl_time
from dba_MVIEWS uv join dba_objects uo on uv.mview_name=uo.object_name
where uo.object_type='MATERIALIZED VIEW' and uv.owner=upper('&what_owner')
order by 1;

-- get list of invalid mviews
col view_name format a30
col text format a88
set long 50000
select uv.owner, uv.mview_name, uv.query
from user_MVIEWS uv join user_objects uo on uv.mview_name=uo.object_name
where uo.object_type='MATERIALIZED VIEW' and uo.status!='VALID'
order by 1;

-- get definition of invalid mviews (as the user)
col view_name format a30
col text format a88
set long 50000
select uv.mview_name, uv.text
from user_MVIEWS uv join user_objects uo on uv.mview_name=uo.object_name
where uo.object_type='MATERIALIZED VIEW' and uo.status!='VALID'
order by 1;

-- create simple mview
create materialized view test_mv
as select lx.OWNER, lx.TABLE_NAME, aix.RECORD_COUNT "AIX", lx.RECORD_COUNT "LINUX", lx.RECORD_COUNT-aix.RECORD_COUNT "DIFFERENCE"
	from ggtest.row_count_linux lx full outer join ggtest.row_count_aix aix
	on aix.OWNER=lx.OWNER and aix.TABLE_NAME=lx.TABLE_NAME;
	
-- refresh mview
EXECUTE DBMS_MVIEW.REFRESH(LIST=>'CAIRO.BENCHMARK_RATES_VIEW',PARALLELISM=>4);