CREATE OR REPLACE FUNCTION FN_CUTOFF_CALC
(
  p_partition_high_value IN VARCHAR2,
  p_cutoff_expression IN VARCHAR2
)
RETURN VARCHAR2
IS
  /*
    Evaluates a cutoff expression with placeholder replacement.
    
    Parameters:
      p_partition_high_value - Value to substitute for <partition_high_value>
      p_cutoff_expression    - Expression containing <partition_high_value> placeholder
                              Example: '<partition_high_value> - 90 < dat.eod'
    
    Returns:
      '1'           - Partition is in scope for archiving (condition is TRUE)
      '0'           - Partition is out of scope (condition is FALSE)
      'ERROR: ...'  - Evaluation failed; contains error message for diagnostics
  */
  l_expression VARCHAR2(4000);
  l_result NUMBER;
BEGIN
  IF p_partition_high_value IS NULL OR p_cutoff_expression IS NULL THEN
    RETURN 'ERROR: NULL parameter - partition_high_value or cutoff_expression';
  END IF;

  /* Replace placeholder with actual partition high value */
  l_expression := REPLACE(p_cutoff_expression, '<partition_high_value>', p_partition_high_value);

  /* Evaluate expression as boolean condition, return 1 or 0 */
  EXECUTE IMMEDIATE 'SELECT CASE WHEN ' || l_expression || ' THEN 1 ELSE 0 END FROM dual'
    INTO l_result;

  RETURN TO_CHAR(l_result);
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLERRM;
END FN_CUTOFF_CALC;
/
