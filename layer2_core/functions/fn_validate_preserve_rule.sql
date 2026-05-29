CREATE OR REPLACE FUNCTION FN_VALIDATE_PRESERVE_RULE
(
  p_preserve_rule IN VARCHAR2
)
RETURN SYS.ODCIDATELIST PIPELINED
AS
  l_cursor SYS_REFCURSOR;
  l_date   DATE;
BEGIN
  IF p_preserve_rule IS NULL THEN
    RETURN;
  END IF;

  OPEN l_cursor FOR p_preserve_rule;

  LOOP
    FETCH l_cursor INTO l_date;
    EXIT WHEN l_cursor%NOTFOUND;
    PIPE ROW (l_date);
  END LOOP;

  CLOSE l_cursor;
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    IF l_cursor%ISOPEN THEN
      CLOSE l_cursor;
    END IF;

    PIPE ROW (NULL);
    RETURN;
END;
/
