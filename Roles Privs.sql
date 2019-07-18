-- ################
-- # User Queries #
-- ################

-- see all granted roles
select * from user_role_privs;

/******************** ALL PRIVS ********************/

-- find obj privs for user/role (grantee)
-- or use tiered query at bottom
set lines 150 pages 50
col "PRIVILGE" format a80
select privilege||' on '||owner||'.'||table_name "PRIVILEGE"
from dba_tab_privs
where grantee in
  (select username from dba_users where username='&&what_user'
    UNION
   select granted_role from dba_role_privs where grantee='&&what_user'
    UNION
   select role from dba_roles where role='&&what_user')
UNION
select privilege
from dba_sys_privs where grantee in
  (select username from dba_users where username='&&what_user'
    UNION
   select granted_role from dba_role_privs where grantee='&&what_user'
    UNION
   select role from dba_roles where role='&&what_user');
   
-- 12c
set lines 150 pages 50
col "PRIVILEGE" format a60
select privilege||' on '||owner||'.'||table_name "PRIVILEGE", common
from dba_tab_privs
where grantee in
  (select username from dba_users where username='&&what_user'
    UNION
   select granted_role from dba_role_privs where grantee='&&what_user'
    UNION
   select role from dba_roles where role='&&what_user')
UNION
select privilege, common
from dba_sys_privs where grantee in
  (select username from dba_users where username='&&what_user'
    UNION
   select granted_role from dba_role_privs where grantee='&&what_user'
    UNION
   select role from dba_roles where role='&&what_user');


/******************** OBJECT PRIVS ********************/

-- 12c
set lines 150 pages 50
col "PRIVILEGE" format a60
select privilege||' on '||owner||'.'||table_name "PRIVILEGE", common
from dba_tab_privs
where lower(grantee)='&what_user';

-- find users with an obj priv
undefine what_table
undefine what_priv
col privilege format a50
col "VIA" format a25
with privs (grantee
           ,granted_role
           )
as (select rp1.grantee
          ,rp1.granted_role
    from   dba_role_privs rp1
    join   dba_users u
      on   rp1.grantee = u.username
    union all
    select privs.grantee
          ,rp2.granted_role
    from   dba_role_privs rp2
    join   privs
      on   privs.granted_role = rp2.grantee
   )
select distinct p.grantee
      ,rtp.privilege||' ON '||rtp.owner||'.'||rtp.table_name privilege, rtp.role||' role' "VIA"
  from   privs p  join   role_tab_privs rtp
    on   p.granted_role=rtp.role
  where rtp.privilege=upper('&&what_priv') and rtp.table_name=upper('&&what_table')
UNION
select tp.grantee, tp.privilege||' ON '||tp.owner||'.'||tp.table_name, tp.grantor
  from dba_tab_privs tp join dba_users ur on tp.grantee=ur.username
  where tp.table_name=upper('&&what_table') and tp.privilege=upper('&&what_priv')
ORDER BY grantee, privilege, via;

-- find the privs granted on all a user's objects
col "GRANTED TO" format a40
select tp.table_name, tp.privilege, 
  NVL2(rp.grantee, rp.grantee||' from '||tp.grantee, tp.grantee) "GRANTED TO"
from dba_tab_privs tp left outer join dba_role_privs rp
  on tp.grantee=rp.granted_role
where tp.owner='&what_owner'
order by tp.table_name, tp.grantee, tp.privilege;

-- find the privs granted on all a user's objects
col "GRANTED TO" format a40
select tp.table_name, tp.privilege, 
  NVL2(rp.grantee, rp.grantee||' from '||tp.grantee, tp.grantee) "GRANTED TO"
from dba_tab_privs tp left outer join dba_role_privs rp
  on tp.grantee=rp.granted_role
where tp.owner='&what_owner' and tp.table_name='&what_table'
order by tp.table_name, tp.grantee, tp.privilege;

-- find breakdown of tables that RO user can select
-- this won't count tables if other users have privs on them
select NVL2(privilege,'YES','NO') "ACCESS", count(*)
from
  (select dt.table_name, tp.grantee, tp.privilege
   from dba_tables dt left outer join dba_tab_privs tp
     on dt.table_name=tp.table_name
   where dt.owner='&what_owner')
where (grantee='&what_ro' or grantee is null)
  and (privilege='SELECT' or privilege is null)
group by NVL2(privilege,'YES','NO');

-- find users who have insert/update on a table w/o select (SQL92_SECURITY parameter)
select iu.GRANTEE, iu.OWNER, iu.TABLE_NAME
from DBA_TAB_PRIVS iu
where iu.PRIVILEGE in ('UPDATE','INSERT')
MINUS
select dtp.GRANTEE, dtp.OWNER, dtp.TABLE_NAME
from DBA_TAB_PRIVS dtp
where dtp.PRIVILEGE='SELECT'
order by GRANTEE, OWNER, TABLE_NAME;


select *
from
  (select dt.table_name, tp.grantee, tp.privilege
   from dba_tables dt left outer join dba_tab_privs tp
     on dt.table_name=tp.table_name
   where dt.owner='&what_owner')
where grantee='&what_ro' and privilege='SELECT'
group by NVL2(privilege,'YES','NO');

-- list of all user's directly granted object privs
select grantee, owner, table_name, privilege
from dba_tab_privs
where grantee not in ('TNSUSER','SQLTUNE','ADM_PARALLEL_EXECUTE_TASK','ANONYMOUS','APEX_040200','APEX_ADMINISTRATOR_ROLE',
'APEX_PUBLIC_USER','APPQOSSYS','AQ_ADMINISTRATOR_ROLE','AQ_USER_ROLE','CDB_DBA','COGZMJ','CTXAPP','CTXSYS','DATAPUMP_EXP_FULL_DATABASE',
'DATAPUMP_IMP_FULL_DATABASE','DBA','DBSNMP','DIP','DVSYS','DV_ACCTMGR','DV_ADMIN','DV_AUDIT_CLEANUP','DV_DATAPUMP_NETWORK_LINK','DV_MONITOR',
'DV_OWNER','DV_SECANALYST','DV_STREAMS_ADMIN','EXECUTE_CATALOG_ROLE','EXP_FULL_DATABASE','FLOWS_FILES','GDS_CATALOG_SELECT','GGS','GSMADMIN_INTERNAL',
'GSMADMIN_ROLE','GSMCATUSER','GSMUSER_ROLE','GSM_POOLADMIN_ROLE','HS_ADMIN_EXECUTE_ROLE','HS_ADMIN_SELECT_ROLE','IMP_FULL_DATABASE',
'LOGSTDBY_ADMINISTRATOR','MDSYS','OEM_MONITOR','OLAP_DBA','OLAP_USER','OLAP_XS_ADMIN','OPTIMIZER_PROCESSING_RATE','ORACLE_OCM','ORDADMIN',
'ORDPLUGINS','ORDSYS','OUTLN','PDB_DBA','RECOVERY_CATALOG_OWNER','SELECT_CATALOG_ROLE','SPATIAL_CSW_ADMIN','SPATIAL_CSW_ADMIN_USR',
'SPATIAL_WFS_ADMIN','SPATIAL_WFS_ADMIN_USR','SQLGUARD','SYS','SYSBACKUP','SYSDG','SYSKM','SYSTEM','UIMMONITOR','WMSYS','WM_ADMIN_ROLE','XDB',
'XDBADMIN','XS_CACHE_ADMIN','XS_SESSION_ADMIN','WFS_USR_ROLE','AUDIT_ADMIN','AUDIT_VIEWER','CAPTURE_ADMIN','CSW_USR_ROLE','DBFS_ROLE')
and table_name not like '/%' and table_name not like 'BIN$%'
order by grantee, owner, table_name, privilege;

-- users, system privs, and roles in table format (by BC)
set lines 150 pages 200
SQL> col username format a30
SQL> col granted_role format a30

with privs (grantee
           ,granted_role
           ,lvl
           )
as (select rp1.grantee
          ,rp1.granted_role
          ,1
    from   dba_role_privs rp1
    join   dba_users u
      on   rp1.grantee = u.username
    union all
    select privs.grantee
          ,rp2.granted_role
          ,privs.lvl+1
    from   dba_role_privs rp2
    join   privs
      on   privs.granted_role = rp2.grantee
   )
select distinct u.username
      ,p.granted_role
      ,coalesce(up.privilege,rp.privilege) privilege
from   dba_users u
join   (select grantee
              ,granted_role
        from   privs
        union all
        select username
              ,'<user>'
        from   dba_users
       ) p
  on   u.username = p.grantee
left join   dba_sys_privs up
  on   u.username = up.grantee
and   p.granted_role ='<user>'
left join dba_sys_privs rp
       on p.granted_role = rp.grantee
where u.username not in ('SYS','SYSTEM','RMANBACK','BHATIAS','DBSNMP','DEJESUSK','POTAPCHUKY','OUTLN','ORACLE_OCM','XDB','XS$NULL')
and   u.account_status = 'OPEN';

-- for object privs
with privs (grantee
           ,granted_role
           ,lvl
           )
as (select rp1.grantee
          ,rp1.granted_role
          ,1
    from   dba_role_privs rp1
    join   dba_users u
      on   rp1.grantee = u.username
    union all
    select privs.grantee
          ,rp2.granted_role
          ,privs.lvl+1
    from   dba_role_privs rp2
    join   privs
      on   privs.granted_role = rp2.grantee
   )
select distinct u.username
      ,p.granted_role
--      ,coalesce(up.privilege,rp.privilege) privilege
      ,CASE
	      WHEN up.privilege IS NOT NULL THEN up.privilege||' on '||up.owner||'.'||up.table_name
		  WHEN rp.privilege IS NOT NULL THEN rp.privilege||' on '||rp.owner||'.'||rp.table_name
		  ELSE NULL
	   END privilege
from   dba_users u
join   (select grantee
              ,granted_role
        from   privs
        union all
        select username
              ,'<user>'
        from   dba_users
       ) p
  on   u.username = p.grantee
left join   dba_tab_privs up
  on   u.username = up.grantee
and   p.granted_role ='<user>'
left join dba_tab_privs rp
       on p.granted_role = rp.grantee
where u.username not in ('SYS','SYSTEM','RMANBACK','BHATIAS','DBSNMP','DEJESUSK','POTAPCHUKY','OUTLN','ORACLE_OCM','XDB','XS$NULL')
and   u.account_status = 'OPEN';

-- privs via cascading views
undefine what_owner
undefine what_table
WITH cascade_views (owner
                   ,name
                   ) AS (SELECT owner
                               ,name
                         FROM   dba_dependencies
                         WHERE  referenced_owner = '&&what_owner'
                         AND    referenced_name  = '&&what_table'
                         AND    referenced_type  = 'TABLE'
                         AND    type             = 'VIEW'
                        UNION ALL
                         SELECT d.owner
                               ,d.name
                         FROM   dba_dependencies d
                         JOIN   cascade_views cv
                           ON   d.referenced_owner = cv.owner
                          AND   d.referenced_name  = cv.name
                          AND   d.referenced_type  = 'VIEW'
                          AND   type               = 'VIEW'
                         )
SELECT tp.grantee
      ,'VIEW' object_type
      ,cv.owner
      ,cv.name
FROM   dba_tab_privs tp
JOIN   cascade_views cv
  ON   tp.owner      = cv.owner
AND   tp.table_name = cv.name
WHERE  privilege   = 'SELECT'
UNION ALL
SELECT grantee
      ,'TABLE'
      ,owner
      ,table_name
FROM   dba_tab_privs
WHERE  table_name  = '&&what_table'
AND    owner       = '&&what_owner'
AND    privilege   = 'SELECT';



/******************** SYSTEM PRIVS ********************/

-- find users with a sys priv
col privilege format a35
col "GRANTED TO" format a40
break on privilege
select sp.privilege,
  NVL2(rp.grantee, rp.grantee||' from '||sp.grantee, sp.grantee) "GRANTED TO",
  sp.admin_option
from dba_sys_privs sp left outer join dba_role_privs rp
  on sp.grantee=rp.granted_role
where sp.privilege like '%&what_priv%'
order by sp.privilege, "GRANTED TO";

-- find all of a user's privs according to how they got them
-- (for roles see below query)
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, username granted_role
    from dba_users
    where username = '&enter_username'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  /* THE ROLES TO OBJ PRIVILEGE RELATIONS */ 
  union
    select grantee,
      privilege||' on '||owner||'.'||table_name
    from dba_tab_privs
    --where owner not like '%SYS%' and owner!='OUTLN'
  )
start with grantee is null
connect by grantee = prior granted_role;

-- see just SYS privs
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, username granted_role
    from dba_users
    where username = '&enter_username'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  )
start with grantee is null
connect by grantee = prior granted_role;



/******************** ROLES ***************************/

-- is a name a user or a role?
undefine what_name
select 'USER' "WHAT" from dba_users where username=upper('&&what_name')
UNION
select 'ROLE' "WHAT" from dba_roles where role=upper('&what_name');

-- find user & roles with a given role
col "STATUS" format a17
select rp.granted_role "ROLE", rp.grantee||' '||NVL2(us.username,'(user)','(role)') "GRANTEE",
  us.account_status "STATUS", rp.admin_option, rp.default_role
from dba_role_privs rp left outer join dba_users us on rp.grantee=us.username
where rp.granted_role like '%&whatrole%' order by rp.granted_role, grantee;

-- find all roles for a users
select granted_role "ROLE", grantee, admin_option, default_role
from dba_role_privs where grantee like '%&whatuser%' 
order by granted_role, grantee;

-- find all privs granted to a role
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, granted_role
    from dba_role_privs
    where granted_role = '&enter_rolename'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  /* THE ROLES TO OBJ PRIVILEGE RELATIONS */ 
  union
    select grantee,
      privilege||' on '||owner||'.'||table_name
    from dba_tab_privs
    --where owner not like '%SYS%' and owner!='OUTLN'
  )
start with grantee is null
connect by grantee = prior granted_role;

-- only sys privs
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, granted_role
    from dba_role_privs
    where granted_role = '&enter_rolename'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  )
start with grantee is null
connect by grantee = prior granted_role;

-- find roles with a sys priv
col privilege format a35
col "GRANTED TO" format a40
break on privilege
select sp.privilege,
  NVL2(rp.grantee, rp.grantee||' from '||sp.grantee, sp.grantee) "GRANTED TO",
  sp.admin_option
from dba_sys_privs sp left outer join dba_role_privs rp
  on sp.grantee=rp.granted_role
where sp.privilege like '%&what_priv%'
order by sp.privilege, "GRANTED TO";


-- ###########
-- # As User #
-- ###########

-- find a user's roles and system privs according to how they got them
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, username granted_role
    from user_users
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select username, granted_role
    from user_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select username, privilege
    from user_sys_privs
  /* THE ROLES TO OBJ PRIVILEGE RELATIONS */ 
  union
    select grantee,
      privilege||' on '||owner||'.'||table_name
    from user_tab_privs
    where owner not like '%SYS%' and owner!='OUTLN'
  )
start with grantee is null
connect by grantee = prior granted_role;


-- ################
-- # Role Queries #
-- ################

-- find sys privs for a role
select sp.grantee, sp.privilege, sp.admin_option
from dba_sys_privs sp, dba_roles r
where sp.grantee=r.role and sp.grantee='&what_role'
order by sp.grantee, sp.privilege;

-- find users with given role
select grantee, admin_option, default_role
from DBA_ROLE_PRIVS
where granted_role='&what_role' 
order by 1;


-- ###############
-- # Proxy Users #
-- ###############

-- see proxy users
col proxy format a30
col client format a30
select proxy,client FROM proxy_users order by 1,2;
-- see more details
col proxy format a30
col client format a30
select * FROM proxy_users order by 1,2;

-- grant proxy privilege
ALTER USER &end_user GRANT CONNECT THROUGH &proxy_user;
-- all options
ALTER USER &end_user 
GRANT CONNECT THROUGH &proxy_user
[WITH [NO ROLES | ROLE [role_name | ALL EXCEPT role_name]]]
[AUTHENTICATION REQUIRED];

-- get commands to recreate privs
select 'ALTER USER '||client||' GRANT CONNECT THROUGH '||proxy||
	case FLAGS
		when 'PROXY MAY ACTIVATE ALL CLIENT ROLES' then ' '
		when 'NO CLIENT ROLES MAY BE ACTIVATED' then ' WITH NO ROLES'
		else ' !!! this one is complicated !!!'
	end ||
	case AUTHENTICATION
		when 'NO' then ';'
		else ' AUTHENTICATION REQUIRED;'
	end
FROM proxy_users order by 1;


-- ####################
-- # Role/Priv Grants #
-- ####################
-- user can be replaced by a role

-- grant a role to a user
GRANT &r_name TO &u_name;
-- allow user to pass it on
GRANT &r_name TO &u_name WITH ADMIN OPTION;

-- grant a sys priv to a user
GRANT &sys_priv TO &u_name;
-- allow user to pass it on
GRANT &sys_priv TO &u_name WITH ADMIN OPTION;

-- grant an obj priv to a user
GRANT &obj_priv TO &u_name;
-- allow user to pass it on
GRANT &obj_priv TO &u_name WITH GRANT OPTION;

-- spool all grants in DB
select 'grant '||sp.privilege||' to '||rp.grantee||';'
from dba_sys_privs sp, dba_role_privs rp
where rp.granted_role=sp.grantee and
rp.grantee not in 
  ('POTAPCHUKY','TSMSYS','SYSTEM','ORACLE_OCM','JACKSONR','DEJESUSK','BHATIAS','SYS','WMSYS','DBA','DBSNMP')
order by rp.grantee, sp.privilege;


-- #####################
-- # Role/Priv Revokes #
-- #####################
-- user can be replaced by a role

-- revoke a role from a user
REVOKE &r_name FROM &u_name;

-- revoke a sys priv from a user
REVOKE &sys_priv FROM &u_name;

-- revoke an obj priv from a user
-- also revokes from everyone they've given it to
REVOKE &obj_priv FROM &u_name;


-- #####################
-- # Role/Priv Changes #
-- #####################

-- see active role
select * from session_roles;

-- set your role
SET ROLE &r_name;
-- enable all your roles
SET ROLE ALL;

-- change a user's default role
ALTER USER &u_name DEFAULT ROLE &r_name;

-- make a user have no default role
ALTER USER &u_name DEFAULT ROLE NONE;

-- make all of a user's roles default
ALTER USER &u_name DEFAULT ROLE ALL;
-- eliminate some
ALTER USER &u_name DEFAULT ROLE ALL EXCEPT &r_name;

-- create a role
CREATE ROLE &r_name;

-- drop a role
DROP ROLE &r_name;

-- drop a user
DROP USER &u_name;
-- and all their objects
DROP USER &u_name CASCADE;



-- #############
-- # Processes #
-- #############

-- build object grant command for role (grantee)
set heading off
spool d:\dba\kevin\insurer_grants.sql
select 'GRANT '||privilege||' on '||owner||'.'||table_name||' to CDC_DWDW3_PUB;'
from dba_tab_privs
where grantee='CDC_DWDW3_PUB';
spool off


-- build system grant command for role (grantee)
select 'GRANT '||privilege||' to CDC_DWDW3_PUB;' from dba_sys_privs 
where grantee='CDC_DWDW3_PUB' and admin_option='NO';
select 'GRANT '||privilege||' to CDC_DWDW3_PUB WITH ADMIN OPTION;' from dba_sys_privs 
where grantee='CDC_DWDW3_PUB' and admin_option='YES';


select privilege, owner, table_name, grantor
from dba_tab_privs
where grantee='INSURER';


-- ##############
-- # JAVA PRIVS #
-- ##############

-- java roles: JAVAUSERPRIV, JAVASYSPRIV, JAVADEBUGPRIV

-- see all privs for user/role
col type_name format a30
col name format a25
col action format a25
select kind, type_name, name, action, enabled
from DBA_JAVA_POLICY
where grantee='JAVAUSERPRIV' order by kind, type_name;


select kind, grantee, name, action, enabled
from DBA_JAVA_POLICY
where type_name='java.io.FilePermission' order by grantee, action;


PROCEDURE grant_permission (grantee VARCHAR2, permission_type VARCHAR2, permission_name VARCHAR2, permission_action VARCHAR2)
PROCEDURE revoke_permission (permission_schema VARCHAR2, permission_type VARCHAR2, permission_name VARCHAR2, permission_action VARCHAR2) 


-- ##################
-- # Tiered Queries #
-- ##################

-- find roles and users that have a sys priv
select
  lpad(' ', 2*level) || c "Privilege, Roles and Users"
from
  (
  /* THE PRIVILEGES */
    select 
      null   p, 
      name   c
    from 
      system_privilege_map
    where
      name like upper('%&enter_privliege%')
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      granted_role  p,
      grantee       c
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      privilege     p,
      grantee       c
    from
      dba_sys_privs
  )
start with p is null
connect by p = prior c;

-- find a user's roles and privs according to how they got them
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, username granted_role
    from dba_users
    where username = '&enter_username'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  /* THE ROLES TO OBJ PRIVILEGE RELATIONS */ 
  union
    select grantee,
      privilege||' on '||owner||'.'||table_name
    from dba_tab_privs
    --where owner not like '%SYS%' and owner!='OUTLN'
  )
start with grantee is null
connect by grantee = prior granted_role;

-- same w/o obj privs; use if user has lots of obj privs
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role
    from 
      dba_users
    where
      username = '&enter_username'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee,
      granted_role
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege
    from
      dba_sys_privs
  )
start with grantee is null
connect by grantee = prior granted_role;

-- find a user's roles and system privs w/o SELECT
select
  lpad(' ', 2*level) || granted_role "User, its roles and privileges"
from
  (
  /* THE USERS */
    select null grantee, username granted_role
    from dba_users
    where username = '&enter_username'
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select grantee, granted_role
    from dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select grantee, privilege
    from dba_sys_privs
  /* THE ROLES TO OBJ PRIVILEGE RELATIONS */ 
  union
    select grantee,
      privilege||' on '||owner||'.'||table_name
    from dba_tab_privs
    where privilege!='SELECT'
  )
start with grantee is null
connect by grantee = prior granted_role;
