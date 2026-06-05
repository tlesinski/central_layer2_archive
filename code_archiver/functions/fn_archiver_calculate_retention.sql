CREATE OR REPLACE FUNCTION FN_ARCHIVER_CALCULATE_RETENTION
(
  p_retention_rule IN VARCHAR2
)
RETURN SYS.ODCIDATELIST PIPELINED 
AS
  l_cursor       SYS_REFCURSOR;
  l_first_date   DATE;
  l_second_date  DATE;
BEGIN
  BEGIN
    OPEN l_cursor FOR p_retention_rule;
  EXCEPTION
    WHEN OTHERS THEN
      PIPE ROW (NULL);
      RETURN;
  END;
    
  FETCH l_cursor INTO l_first_date;
  
  IF l_cursor%NOTFOUND THEN
    PIPE ROW (NULL);
  ELSE
    FETCH l_cursor INTO l_second_date;
    
    IF l_cursor%FOUND THEN
      PIPE ROW (NULL);
    ELSE
      PIPE ROW (l_first_date);
    END IF;
  END IF;
   
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