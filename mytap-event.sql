-- EVENTS
-- ======
-- >= 5.5

/************************************************************************************/

DELIMITER //


-- Is the scheduler process running

DROP FUNCTION IF EXISTS _scheduler //
CREATE FUNCTION _scheduler()
RETURNS VARCHAR(3)
BEGIN
  DECLARE ret VARCHAR(3);
    
  SELECT @@GLOBAL.event_scheduler INTO ret;

  RETURN ret;
END //

DROP FUNCTION IF EXISTS scheduler_is //
CREATE FUNCTION scheduler_is(want VARCHAR(3), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = 'Event scheduler process should be correctly set';
  END IF;

  RETURN eq(_scheduler(), want, description);
END //


DROP FUNCTION IF EXISTS _has_event //
CREATE FUNCTION _has_event(sname VARCHAR(64), ename VARCHAR(64))
RETURNS BOOLEAN
BEGIN
  DECLARE ret BOOLEAN;

  SELECT 1 INTO ret
  FROM `information_schema`.`events`
  WHERE `event_schema` = sname
  AND `event_name` = ename;

  RETURN COALESCE(ret, 0);
END //

DROP FUNCTION IF EXISTS has_event //
CREATE FUNCTION has_event(sname VARCHAR(64), ename VARCHAR(64), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should exist');
  END IF;

  IF NOT _has_schema(sname) THEN
    RETURN CONCAT(ok(FALSE, description), '\n',
      diag(CONCAT('    Schema ', quote_ident(sname), ' does not exist')));
    END IF;

    RETURN ok(_has_event(sname, ename), description);
END //


DROP FUNCTION IF EXISTS hasnt_event //
CREATE FUNCTION hasnt_event(sname VARCHAR(64), ename VARCHAR(64), description TEXT )
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should not exist');
  END IF;

  IF NOT _has_schema(sname) THEN
    RETURN CONCAT(ok(FALSE, description), '\n',
      diag(CONCAT('    Schema ', quote_ident(sname), ' does not exist')));
    END IF;

  RETURN ok(NOT _has_event(sname, ename), description);
END //


/****************************************************************************/
-- EVENT TYPE
-- { ONE TIME | RECURRING }

DROP FUNCTION IF EXISTS _event_type //
CREATE FUNCTION _event_type(sname VARCHAR(64), ename VARCHAR(64))
RETURNS VARCHAR(9)
BEGIN
  DECLARE ret VARCHAR(9);

  SELECT `event_type` INTO ret
  FROM `information_schema`.`events`
  WHERE `event_schema` = sname
  AND `event_name` = ename;

  RETURN ret;
END //

DROP FUNCTION IF EXISTS event_type_is //
CREATE FUNCTION event_type_is(sname VARCHAR(64), ename VARCHAR(64), etype VARCHAR(9), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should have Event Type ', qv(etype));
  END IF;

  IF NOT _has_schema(sname) THEN
    RETURN CONCAT(ok(FALSE, description), '\n',
      diag(CONCAT('    Schema ', quote_ident(sname), ' does not exist')));
  END IF;

  RETURN eq(_event_type(sname, ename), etype, description);
END //


/****************************************************************************/
-- INTERVAL_VALUE for recurring events
-- VARCHAR(256) ALLOWS NULL
-- stores a number as a string!

DROP FUNCTION IF EXISTS _event_interval_value //
CREATE FUNCTION _event_interval_value(sname VARCHAR(64), ename VARCHAR(64))
RETURNS VARCHAR(256)
BEGIN
  DECLARE ret VARCHAR(256);

  SELECT `interval_value` INTO ret
  FROM `information_schema`.`events`
  WHERE `event_schema` = sname
  AND `event_name` = ename;

  RETURN ret;
END //

DROP FUNCTION IF EXISTS event_interval_value_is //
CREATE FUNCTION event_interval_value_is(sname VARCHAR(64), ename VARCHAR(64), ivalue VARCHAR(256), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should have Interval Value ', qv(ivalue));
  END IF;

  IF NOT _has_event(sname,ename) THEN
    RETURN CONCAT(ok(FALSE, description), '\n',
      diag(CONCAT('    Event ', quote_ident(sname), '.', quote_ident(ename),
        ' does not exist')));
  END IF;

  RETURN eq(_event_interval_value(sname, ename), ivalue, description);
END //

/****************************************************************************/
-- INTERVAL_FIELD for recurring events
-- VARCHAR(18) ALLOWS NULL
-- HOUR, DAY, WEEK etc 

DROP FUNCTION IF EXISTS _event_interval_field //
CREATE FUNCTION _event_interval_field(sname VARCHAR(64), ename VARCHAR(64))
RETURNS VARCHAR(18)
BEGIN
  DECLARE ret VARCHAR(18);

  SELECT `interval_field` INTO ret
  FROM `information_schema`.`events`
  WHERE `event_schema` = sname
  AND `event_name` = ename;

  RETURN ret;
END //

DROP FUNCTION IF EXISTS event_interval_field_is //
CREATE FUNCTION event_interval_field_is(sname VARCHAR(64), ename VARCHAR(64), ifield VARCHAR(18), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should have Interval Field ', qv(ifield));
  END IF;

  IF NOT _has_event(sname,ename) THEN
    RETURN CONCAT(ok(FALSE, description), '\n', 
      diag(CONCAT('    Event ', quote_ident(sname), '.', quote_ident(ename),
        ' does not exist')));
    END IF;

    RETURN eq(_event_interval_field(sname, ename), ifield, description);
END //


/****************************************************************************/
-- STATUS
-- { ENABLED | DISABLED | SLAVESIDE DISABLED }

DROP FUNCTION IF EXISTS _event_status //
CREATE FUNCTION _event_status(sname VARCHAR(64), ename VARCHAR(64))
RETURNS VARCHAR(18)
BEGIN
  DECLARE ret VARCHAR(18);

  SELECT `status` INTO ret
  FROM `information_schema`.`events`
  WHERE `event_schema` = sname
  AND `event_name` = ename;

  RETURN ret;
END //

DROP FUNCTION IF EXISTS event_status_is //
CREATE FUNCTION event_status_is(sname VARCHAR(64), ename VARCHAR(64), stat VARCHAR(18), description TEXT)
RETURNS TEXT
BEGIN
  IF description = '' THEN
    SET description = CONCAT('Event ', quote_ident(sname), '.', quote_ident(ename),
      ' should have Status ', qv(stat));
  END IF;

  IF NOT _has_event(sname,ename) THEN
    RETURN CONCAT(ok(FALSE, description), '\n',
      diag(CONCAT('    Event ', quote_ident(sname), '.', quote_ident(ename),
        ' does not exist')));
    END IF;

    RETURN eq(_event_status(sname, ename), stat, description);
END //


/****************************************************************************/

-- Check that the proper events are defined

DROP FUNCTION IF EXISTS _missing_events //
CREATE FUNCTION _missing_events(sname VARCHAR(64))
RETURNS TEXT
BEGIN
  DECLARE ret TEXT;

  SELECT GROUP_CONCAT(qi(`ident`)) INTO ret 
  FROM 
    (
      SELECT `ident`
      FROM `idents1`
      WHERE `ident` NOT IN
        (
          SELECT `event_name`
          FROM `information_schema`.`events`
          WHERE `event_schema` = sname
        )
     ) msng;

  RETURN COALESCE(ret, '');
END //

DROP FUNCTION IF EXISTS _extra_events //
CREATE FUNCTION _extra_events(sname VARCHAR(64))
RETURNS TEXT
BEGIN
  DECLARE ret TEXT;

  SELECT GROUP_CONCAT(qi(`ident`)) INTO ret
  FROM 
    (
      SELECT `event_name` AS `ident`
      FROM `information_schema`.`events`
      WHERE `event_schema` = sname
      AND `event_name` NOT IN 
        (
          SELECT `ident`
          FROM `idents2`
        )
    ) xtra;

  RETURN COALESCE(ret, '');
END //


DROP FUNCTION IF EXISTS events_are //
CREATE FUNCTION events_are(sname VARCHAR(64), want TEXT, description TEXT) 
RETURNS TEXT
BEGIN
  DECLARE sep       CHAR(1) DEFAULT ','; 
  DECLARE seplength INTEGER DEFAULT CHAR_LENGTH(sep);
  DECLARE missing   TEXT; 
  DECLARE extras    TEXT;

  IF description = '' THEN
    SET description = CONCAT('Schema ', quote_ident(sname), ' should have the correct Events');
  END IF;

  IF NOT _has_schema(sname) THEN
    RETURN CONCAT( ok(FALSE, description), '\n',
      diag( CONCAT('    Schema ', quote_ident(sname), ' does not exist' )));
  END IF;

  SET want = _fixCSL(want);

  IF want IS NULL THEN
    RETURN CONCAT(ok(FALSE,description),'\n',
      diag(CONCAT('Invalid character in comma separated list of expected schemas\n',
                  'Identifier must not contain NUL Byte or extended characters (> U+10000)')));
  END IF;

  DROP TEMPORARY TABLE IF EXISTS idents1;
  CREATE TEMPORARY TABLE tap.idents1 (ident VARCHAR(64) PRIMARY KEY)
    ENGINE MEMORY CHARSET utf8 COLLATE utf8_general_ci;
  DROP TEMPORARY TABLE IF EXISTS idents2;
  CREATE TEMPORARY TABLE tap.idents2 (ident VARCHAR(64) PRIMARY KEY)
    ENGINE MEMORY CHARSET utf8 COLLATE utf8_general_ci;

  WHILE want != '' > 0 DO
    SET @val = TRIM(SUBSTRING_INDEX(want, sep, 1));
    SET @val = uqi(@val);
    IF  @val <> '' THEN 
      INSERT IGNORE INTO idents1 VALUE(@val);
      INSERT IGNORE INTO idents2 VALUE(@val); 
    END IF;
    SET want = SUBSTRING(want, CHAR_LENGTH(@val) + seplength + 1);
  END WHILE;

  SET missing = _missing_events(sname);
  SET extras  = _extra_events(sname);

  RETURN _are('events', extras, missing, description);
END //


DELIMITER ;