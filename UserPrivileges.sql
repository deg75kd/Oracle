set lines 150 pages 200
col USERNAME format a30
col GRANTED_ROLE format a30
col PRIVILEGE format a50
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
where u.username='&what_user'
and   u.account_status = 'OPEN'
order by 1,2,3;
