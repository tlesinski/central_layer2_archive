create or replace FUNCTION FN_EXPR_CALC
(
  p_partition_high_value       IN VARCHAR2,
  p_prev_partition_high_value  IN VARCHAR2,
  p_subpartition_high_value    IN VARCHAR2,
  p_cutoff_expression          IN VARCHAR2,
  p_mode                       IN VARCHAR2 DEFAULT 'FLAG'
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
  l_result VARCHAR2(4000);
BEGIN
  IF p_mode = 'FLAG' THEN
    IF p_partition_high_value IS NULL OR p_cutoff_expression IS NULL THEN
      RETURN 'N';
    END IF;
  
    /* Replace placeholder with actual partition high value */
    l_expression := REPLACE(p_cutoff_expression, '<partition_high_value>', p_partition_high_value);
    l_expression := REPLACE(l_expression, '<prev_partition_high_value>', p_prev_partition_high_value);
    l_expression := REPLACE(l_expression, '<subpartition_high_value>', p_subpartition_high_value);
  
    /* Evaluate expression as boolean condition, return 1 or 0 */
    EXECUTE IMMEDIATE 'SELECT CASE WHEN ' || l_expression || ' THEN ''Y'' ELSE ''N'' END FROM dual'
      INTO l_result;
  
    RETURN l_result;
  ELSE
    IF p_partition_high_value IS NULL OR p_cutoff_expression IS NULL THEN
      RETURN NULL;
    END IF;
  
    /* Replace placeholder with actual partition high value */
    l_expression := REPLACE(p_cutoff_expression, '<partition_high_value>', p_partition_high_value);
  
    /* Evaluate expression as boolean condition, return 1 or 0 */
    EXECUTE IMMEDIATE 'SELECT ' || l_expression || ' FROM dual'
      INTO l_result;
  
    RETURN l_result;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLERRM;
END FN_EXPR_CALC;
/