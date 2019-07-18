set head on
set lines 120
set pages 100
col "Used (M)" format a15
col "Used %" format a15
col "Size (M)" format a15

SELECT 	d.status "Status",
	d.tablespace_name "Name",
	d.contents "Type",
	d.extent_management "Ext Man",
	TO_CHAR(NVL(a.bytes / 1024 / 1024, 0),'99,999,990.900') "Size (M)", 
	TO_CHAR(NVL(a.bytes - NVL(f.bytes, 0), 0)/1024/1024,'99,999,999.900') "Used (M)",
	TO_CHAR(NVL((a.bytes - NVL(f.bytes, 0)) / a.bytes * 100, 0), '990.00') "Used %"
FROM	sys.dba_tablespaces d,
		(select 
		   tablespace_name,
		   sum(bytes) bytes
		 from dba_data_files
		 group by tablespace_name) a,
		(select
		   tablespace_name,
		   sum(bytes) bytes
		 from dba_free_space
		 group by tablespace_name) f
WHERE 	d.tablespace_name = a.tablespace_name(+)
AND 	d.tablespace_name = f.tablespace_name(+)
	AND NOT 
	(d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY')
UNION ALL
SELECT 	d.status "Status",
	d.tablespace_name "Name",
	d.contents "Type",
	d.extent_management "Ext Man", 
	TO_CHAR(NVL(a.bytes / 1024 / 1024, 0),'99,999,990.900') "Size (M)",
	TO_CHAR(NVL(t.bytes, 0)/1024/1024,'99,999,999.900') "Used (M)",
	TO_CHAR(NVL(t.bytes / a.bytes * 100, 0), '990.00') "Used %"
FROM 	sys.dba_tablespaces d,
		(select
		   tablespace_name,
		   sum(bytes) bytes
		 from dba_temp_files
		 group by tablespace_name) a,
		(select 
		   tablespace_name,
		   sum(bytes_cached) bytes
		 from v$temp_extent_pool
		 group by tablespace_name) t
WHERE 	d.tablespace_name = a.tablespace_name(+)
AND 	d.tablespace_name = t.tablespace_name(+)
AND	d.extent_management like 'LOCAL'
AND 	d.contents like 'TEMPORARY'
ORDER BY "Name";