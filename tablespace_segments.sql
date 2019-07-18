set serveroutput on
DECLARE
  CURSOR c1 IS
    select file_id, block_id, blocks, bytes, segment_name, segment_type
    from dba_extents where tablespace_name = 'DQI_TABLES_X4M'
    order by file_id, block_id;
  v_fileid	NUMBER;
  v_blockid	NUMBER;
  v_blocks	NUMBER;
  v_bytes	NUMBER;
  v_segname	VARCHAR2(81);
  v_segtype	VARCHAR2(18);
  v_oldfileid	NUMBER;
  v_startblock	NUMBER;
  v_endblock	NUMBER;
  v_ttlblocks	NUMBER;
  v_ttlbytes	NUMBER;
  v_oldsegname	VARCHAR2(81);
  v_oldsegtype	VARCHAR2(18);
  v_first	CHAR(1) := 'Y';
BEGIN
  -- print header
  DBMS_OUTPUT.PUT_LINE('FILE  FIRST      LAST    MB     SEGMENT NAME                    SEGMENT TYPE');
  DBMS_OUTPUT.PUT_LINE('---- ------ --------- -----     ------------------------------- ------------------');
  OPEN c1;
  LOOP
    -- get first record
    FETCH c1 INTO v_fileid, v_blockid, v_blocks, v_bytes, v_segname, v_segtype;
    -- end loop if no new record (will cause problem with last record?)
    EXIT WHEN c1%NOTFOUND;
    -- is this first record
    IF v_first = 'Y' THEN
      -- set old variables
      v_oldfileid := v_fileid;
      v_startblock := v_blockid;
      v_ttlblocks := v_blocks;
      v_ttlbytes := v_bytes;
      v_oldsegname := v_segname;
      v_oldsegtype := v_segtype;
      v_first := 'N';
    -- not first record
    -- is there a break in blocks or change in segment
    ELSIF (v_blockid != v_startblock + v_ttlblocks) OR (v_segname != v_oldsegname) OR (v_segtype != v_oldsegtype) THEN
      -- set end block
      v_endblock := v_startblock+v_ttlblocks-1;
      -- convert bytes
      v_ttlbytes := trunc(v_ttlbytes/1024/1024,2);
      -- print details of segment
      DBMS_OUTPUT.PUT_LINE(v_oldfileid||'      	'||v_startblock||'       '||v_endblock||'	'||v_ttlbytes||'	'||v_oldsegname||'			'||v_oldsegtype);
      -- reset variables
      v_oldfileid := v_fileid;
      v_startblock := v_blockid;
      v_ttlblocks := v_blocks;
      v_ttlbytes := v_bytes;
      v_oldsegname := v_segname;
      v_oldsegtype := v_segtype;
    -- not first record but continuation of previous record
    ELSE
      -- update totals
      v_ttlblocks := v_blocks + v_ttlblocks;
      v_ttlbytes := v_bytes + v_ttlbytes;
    END IF;
  END LOOP;
  CLOSE c1;
  -- set end block
  v_endblock := v_startblock+v_ttlblocks-1;
  -- convert bytes
  v_ttlbytes := trunc(v_ttlbytes/1024/1024,2);
  -- print details of last segment
  DBMS_OUTPUT.PUT_LINE(v_oldfileid||'      	'||v_startblock||'       '||v_endblock||'	'||v_ttlbytes||'	'||v_oldsegname||'			'||v_oldsegtype);
END;
/
