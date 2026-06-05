
  CREATE TABLE "PARTMGR"."ARCHIVER_REPORT" 
   (	"RPT_NAME" VARCHAR2(128 BYTE), 
	"RPT_COMM" VARCHAR2(4000 BYTE), 
	"RPT_HTML_STYLE" CLOB
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PARTMGR" 
 LOB ("RPT_HTML_STYLE") STORE AS SECUREFILE (
  TABLESPACE "PARTMGR" ENABLE STORAGE IN ROW CHUNK 8192
  NOCACHE LOGGING  NOCOMPRESS  KEEP_DUPLICATES 
  STORAGE(INITIAL 106496 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)) ;
  
    CREATE TABLE "PARTMGR"."ARCHIVER_REPORT_SQL" 
   (	"SQL_NAME" VARCHAR2(128 BYTE), 
	"SQL_CODE" CLOB
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PARTMGR" 
 LOB ("SQL_CODE") STORE AS SECUREFILE (
  TABLESPACE "PARTMGR" ENABLE STORAGE IN ROW CHUNK 8192
  NOCACHE LOGGING  NOCOMPRESS  KEEP_DUPLICATES 
  STORAGE(INITIAL 106496 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)) ;

REM INSERTING into ARCHIVER_REPORT
SET DEFINE OFF;
Insert into ARCHIVER_REPORT (RPT_NAME,RPT_COMM,RPT_HTML_STYLE) values ('SUMMARY_REPORT','Summary report',TO_CLOB(q'[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Archiver report</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            border: 1px solid black;
            padding: 10px;
            text-align: center;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>
    <hea]')
|| TO_CLOB(q'[der>
        <h1>Archiver report</h1>
    </header>
    <main>
        <p>Summary of archiver process for last week</p>

        Recently added partitions
        <SQL>SQL_ADD_PARTITIONS</SQL>
        </br>
        Quality checks
        <SQL>SQL_QUALITY_CHECK</SQL>
        </br>

        Archived data
        <SQL>SQL_ARCHIVE</SQL>
        </br>
        Data truncated
        <SQL>SQL_TRUNCATED</SQL>
        </br>
        Data for truncate
        <SQL>SQL_FOR_TRUNCATE</SQL>
        </br>
    <]')
|| TO_CLOB(q'[/main>
    <footer>
        <p>&copy; 2025 Archiver Webpage</p>
    </footer>
</body>
</html>
]'));

REM INSERTING into ARCHIVER_REPORT_SQL
SET DEFINE OFF;
Insert into ARCHIVER_REPORT_SQL (SQL_NAME,SQL_CODE) values ('SQL_ADD_PARTITIONS','select ''LAST ADDED PARTITIONS'' data_type, source_database_name,source_schema_name,source_table_name,min_value,max_value data_scope
 from (
 select source_database_name, source_schema_name, source_table_name, min(partition_high_value) min_value, max(partition_high_value) max_value
 from PARTMGR.ARCHIVER_PARTITIONS
 where updated_at >= trunc(sysdate)
 group by source_database_name, source_schema_name, source_table_name)');
Insert into ARCHIVER_REPORT_SQL (SQL_NAME,SQL_CODE) values ('SQL_QUALITY_CHECK',' select ''LAST QUALITY CHECKED'' data_type, source_database_name,source_schema_name,source_table_name,min_value,max_value data_scope
 from (
 select source_database_name, source_schema_name, source_table_name, min(partition_high_value) min_value, max(partition_high_value) max_value
 from PARTMGR.ARCHIVER_PARTITIONS
 where target_count_at >= trunc(sysdate) 
 group by source_database_name, source_schema_name, source_table_name)');
Insert into ARCHIVER_REPORT_SQL (SQL_NAME,SQL_CODE) values ('SQL_ARCHIVE','select ''ARCHIVED'' data_type,source_database_name,source_schema_name,source_table_name,min_value,max_value data_scope
 from (
 select source_database_name, source_schema_name, source_table_name, min(partition_high_value) min_value, max(partition_high_value) max_value
 from PARTMGR.ARCHIVER_PARTITIONS
 where archive_status=''Y''
 group by source_database_name, source_schema_name, source_table_name)');
Insert into ARCHIVER_REPORT_SQL (SQL_NAME,SQL_CODE) values ('SQL_TRUNCATED',' select ''TRUNCATED'' data_type,source_database_name,source_schema_name,source_table_name,min_value,max_value from (
 select source_database_name, source_schema_name, source_table_name, min(partition_high_value) min_value, max(partition_high_value) max_value
 from PARTMGR.ARCHIVER_PARTITIONS
 where archive_status=''Y'' and truncate_status=''Y''
 group by source_database_name, source_schema_name, source_table_name)
');
Insert into ARCHIVER_REPORT_SQL (SQL_NAME,SQL_CODE) values ('SQL_FOR_TRUNCATE',TO_CLOB(q'[ select 'FOR TRUNCATE' data_type,source_database_name,source_schema_name,source_table_name,min_value,max_value 
  from (
  select source_database_name, source_schema_name, source_table_name, min(partition_high_value) min_value, max(partition_high_value) max_value
  from (SELECT 
      P.source_database_name, P.source_schema_name, P.source_table_name, t.partition_type,
      P.target_schema_name, P.target_table_name, 
      P.partition_name, P.partition_high_value, 
      P.subpartition_name, P.s]')
|| TO_CLOB(q'[ubpartition_high_value, 
      P.archive_status, P.archive_at, 
      P.truncate_status, P.truncate_at,
      P.target_count, P.source_count,
      T.source_retention_query, T.table_tablespace, T.index_tablespace 
    FROM archiver_partitions P, archiver_tables T
   WHERE T.source_database_name = 'PLENP'
     AND T.source_schema_name   = nvl(null, t.source_schema_name)
     AND T.source_table_name    = nvl(null,  t.source_table_name)
     and T.source_database_name = p.source_database_name
     ]')
|| TO_CLOB(q'[AND T.source_schema_name   = P.source_schema_name
     AND T.source_table_name    = p.source_table_name
     AND P.archive_status = 'Y'
     AND p.truncate_status = 'N'
     AND nvl(P.source_count,-1) = nvl(P.target_count,-2)
     AND pkg_archiver_util.fn_calc_condition(T.source_truncate_query, P.partition_high_value, P.subpartition_high_value) = 1
   ORDER BY P.source_database_name, P.source_schema_name, P.source_table_name)
   group by source_database_name, source_schema_name, source_table_nam]')
|| TO_CLOB(q'[e
   )]'));
  
  FUNCTION fn_transform_sql
  (
    p_log_id      IN NUMBER,
    in_sql        IN VARCHAR2,
    in_trnsf_type IN VARCHAR2
  )
  RETURN CLOB
  IS
    l_cur            pls_integer;
    l_col_cnt        PLS_INTEGER;
    l_desc_tab       dbms_sql.desc_tab2;
    l_clob           CLOB;
    l_sql            CLOB;
    l_hdr            CLOB;
    l_row_limit      NUMBER := 100;
    l_eol            VARCHAR2(2);
    l_full_file      CLOB;
    l_rows_dumped    NUMBER;
    l_time           NUMBER;
    l_proc_name      VARCHAR2(128) := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.fn_transform_sql';
  BEGIN
    pkg_tl_logging.prc_log
    (
      p_log_id  => p_log_id,
      p_log_msg => 'Starting procedure ' || l_proc_name || ' with parameters: ' || CHR(10) ||
                   '  in_sql:        ' || in_sql        || CHR(10) ||
                   '  in_trnsf_type: ' || in_trnsf_type 
    );

    -- Parse and execute query
    l_cur := dbms_sql.open_cursor;
    dbms_sql.parse(l_cur, in_sql, dbms_sql.native);

    dbms_sql.describe_columns2(l_cur, l_col_cnt, l_desc_tab);   

    dbms_sql.close_cursor(l_cur);

    IF in_trnsf_type = 'HTML' THEN
      l_sql := 'select ''<tr>''||''';
      l_hdr := 'select ''<tr>''||''';

      FOR i IN 1..l_col_cnt
      loop
        l_sql := l_sql||'<td>''||'||l_desc_tab(i).col_name||'||''</td>';
        l_hdr := l_hdr||'<th>'||l_desc_tab(i).col_name||'</th>';
      END LOOP;

      l_sql := l_sql||'''||''</tr>'' from ('||in_sql||')';
      l_hdr := l_hdr||'''||''</tr>'' from dual';
    ELSE  
      l_sql := 'select ';
      l_hdr := 'select ''';

      FOR i IN 1..l_col_cnt
      loop
        l_sql := l_sql||' '||l_desc_tab(i).col_name||'||'' - ''||';
        l_hdr := l_hdr||' '||l_desc_tab(i).col_name||' : ';
      END LOOP;

      l_sql := rtrim(l_sql, '-|')||' from ('||in_sql||')';
      l_hdr := rtrim(l_hdr, ': ')||''' from dual';
    END IF;

    l_sql := l_hdr||chr(10)||'union all'||chr(10)||l_sql;

    --dbms_output.put_line(l_sql);
    pkg_tl_logging.prc_log
    (
      p_log_id  => p_log_id,
      p_log_msg => 'Parsed query: ' || chr(10) ||
                   '  l_sql = ' || l_sql 
    );

    l_eol := chr(13) || chr(10);
--             CASE
--               WHEN dbms_utility.port_string LIKE 'IBMPC%' THEN 
--                 CHR(13) || CHR(10)
--               ELSE 
--                 chr(10)
--             END; 

    -- Open file
    l_clob := 
      to_clob('DECLARE
      CURSOR l_cur
      IS  ') || l_sql || to_clob(';
      TYPE t_var_tab IS TABLE OF VARCHAR2(32767);
      l_var_tab   t_var_tab;
      l_var_rec   VARCHAR2(32767);
      l_file      CLOB;
      l_lines     PLS_INTEGER   := 0;
      l_eollen    PLS_INTEGER;
      c_maxline   CONSTANT PLS_INTEGER := 30000;
      l_eol       VARCHAR2(2);
      l_time      DATE;
      l_ext_time  NUMBER;
    BEGIN
      l_eol    := :l_eol;
      l_eollen := LENGTHB(l_eol);
      l_lines  := 0;

      dbms_lob.createtemporary(l_file, TRUE);

      l_time := SYSDATE; --checking extract generation time

      OPEN l_cur;

      LOOP
        FETCH l_cur BULK COLLECT INTO l_var_tab LIMIT 1000;

        FOR i IN 1 .. l_var_tab.COUNT 
        LOOP
          IF ( LENGTHB(l_var_rec) + l_eollen + LENGTHB(l_var_tab(i)) <= c_maxline ) THEN
            l_var_rec := l_var_rec || l_eol || l_var_tab(i);
          ELSE
            IF ( l_var_rec IS NOT NULL ) THEN
              dbms_lob.writeappend( l_file, LENGTH(l_var_rec) + l_eollen, l_var_rec || l_eol );
            END IF;

            l_var_rec := l_var_tab(i);
          END IF;

          l_lines := l_lines + 1;

          EXIT WHEN l_lines > ' || to_clob(l_row_limit) || ';
        END LOOP;

        EXIT WHEN l_cur%NOTFOUND;
      END LOOP;

      CLOSE l_cur;

      l_ext_time := (SYSDATE - l_time)*24*60*60; 
       --checking extract generation time

      IF ( LENGTH(l_var_rec) > 0 ) THEN
        dbms_lob.writeappend( l_file, LENGTH(l_var_rec) + l_eollen, 
                              l_var_rec || l_eol );
      END IF;

      IF ( DBMS_LOB.GETLENGTH(l_file) != 0 ) THEN
        :l_file := l_file;
        :l_rows_dumped := l_lines;
      ELSE
        :l_file := l_file;
        :l_rows_dumped := 0;
      END IF;

      :l_time := l_ext_time;

      dbms_lob.freetemporary(l_file);
    END;');

    --dbms_output.put_line(l_clob);

    EXECUTE IMMEDIATE l_clob
      USING l_eol, out l_full_file, out l_rows_dumped, out l_time;

    RETURN l_full_file;
  END fn_transform_sql;

  FUNCTION fn_report_html
  (
    p_log_id    IN NUMBER,
    in_rpt_name IN VARCHAR2,
    in_parm1    IN VARCHAR2 DEFAULT NULL,
    in_parm2    IN VARCHAR2 DEFAULT NULL,
    in_parm3    IN VARCHAR2 DEFAULT NULL
  )
  RETURN CLOB
  IS
    l_rpt            CLOB;
    l_sql            CLOB;
    l_tag_id         CLOB;
    l_tag_parm1      CLOB;
    l_tag_parm2      CLOB;
    l_tag_parm3      CLOB;
    l_proc_name      VARCHAR2(128) := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.fn_report_html';
  BEGIN
    pkg_tl_logging.prc_log
    (
      p_log_id  => p_log_id,
      p_log_msg => 'Starting procedure ' || l_proc_name || ' with parameters: ' || CHR(10) ||
                    ' in_rpt_name = ' || in_rpt_name || chr(10)||
                    ' in_parm1 = ' || in_parm1 || chr(10)||
                    ' in_parm2 = ' || in_parm2 || chr(10)||
                    ' in_parm3 = ' || in_parm3
    );

    FOR i IN (SELECT rpt_name, rpt_comm, rpt_html_style
                FROM archiver_report
               WHERE rpt_name = in_rpt_name)
    loop
      pkg_tl_logging.prc_log
      (
        p_log_id  => p_log_id,
        p_log_msg => 'Starting procedure ' || l_proc_name || ' with parameters: ' || CHR(10) ||
                     '  rpt_name = ' || i.rpt_name || chr(10) ||
                     '  rpt_comm = ' || i.rpt_comm
      );

      l_rpt := REPLACE(i.rpt_html_style, '<RPT>RPT_HEADER</RPT>', i.rpt_comm);

      --checnage parameters for report
      l_rpt := REPLACE(l_rpt, '<PARM1>', in_parm1);
      l_rpt := REPLACE(l_rpt, '<PARM2>', in_parm2);
      l_rpt := REPLACE(l_rpt, '<PARM3>', in_parm3);

      pkg_tl_logging.prc_log
      (
        p_log_id  => p_log_id,
        p_log_msg =>         'Report: ' || chr(10) ||
        l_rpt
      );

      FOR j IN (SELECT
                    A.single_line,
                    LEVEL lvl,
                    REGEXP_SUBSTR(A.single_line, '(<SQL>([^<]+)\</SQL>)', 1, LEVEL, 'i', 2) tag_name,
                    cnt
                  FROM
                  (
                    SELECT A.single_line, regexp_count(A.single_line, '<SQL>([^<]+)</SQL>' ) cnt
                      FROM (SELECT l_rpt single_line FROM dual) A
                  ) A
                  CONNECT BY LEVEL <= A.cnt)
      loop
        --find param
        l_tag_id    := regexp_substr(j.tag_name, '[^:]+', 1, 1);
        l_tag_parm1 := regexp_substr(j.tag_name, '[^:]+', 1, 2);
        l_tag_parm2 := regexp_substr(j.tag_name, '[^:]+', 1, 3);
        l_tag_parm3 := regexp_substr(j.tag_name, '[^:]+', 1, 4);

        pkg_tl_logging.prc_log
        (
          p_log_id  => p_log_id,
          p_log_msg => 'Tag id: ' || l_tag_id || chr(10) ||
          'param1: ' || l_tag_parm1 || chr(10) ||
          'param2: ' || l_tag_parm2 || chr(10) ||
          'param3: ' || l_tag_parm3
        );

        --find sql
        SELECT sql_code 
          INTO l_sql 
          FROM archiver_report_sql 
         WHERE sql_name = to_char(l_tag_id);

        l_sql := REPLACE(
                   REPLACE(
                     REPLACE(l_sql,
                              '<PARM1>', l_tag_parm1),
                          '<PARM2>', l_tag_parm2),
                        '<PARM3>', l_tag_parm3);

        pkg_tl_logging.prc_log
        (
          p_log_id  => p_log_id,
          p_log_msg =>         'Report: ' || chr(10) ||
          l_rpt
        );

        l_sql := fn_transform_sql(p_log_id, l_sql, 'HTML');
        l_rpt := REPLACE(l_rpt, '<SQL>'||j.tag_name||'</SQL>', to_clob('<table>')||l_sql||to_clob('</table>'));
      END LOOP;
    END LOOP;

    RETURN l_rpt;
  END fn_report_html;
  

CREATE TABLE “SHARED_CODE”.”EMAIL_SETUP”
( “ATTR_NAME” VARCHAR2(128 BYTE),
“ATTR_TYPE” VARCHAR2(128 BYTE),
“ATTR_VALUE” VARCHAR2(4000 BYTE),
CONSTRAINT “EMAIL_SETUP_CHK1” CHECK (attr_type IN (‘CONSTANT’, ‘SQL’)) ENABLE
) ;

create or replace PACKAGE “PKG_MAIL”
authid current_user
IS

— Package : PKG_MAIL —
— Developer : Tomasz Lesinski —
— Date : 2022-03-21 —
— Purpose : Mail package —
— Prerequisite : PKG_TL_LOGGING —

— Change History —
— —
— Version Date Programmer Description —

— 1.0 2022-03-21 Tomasz, Lesinski Initial version —
— 2.0 2022-10-12 Tomasz, Lesinski Create simple templates —
— 2.1 2022-01-24 Tomasz, Lesinski Add file compression as zip —
— 2.2 2024-06-20 Tomasz, Lesinski Switch to smtp.prod.stockex.local —
— 2.3 2024-07-18 Pawel Nowak Take SMTP from EMAIL_SETUP table —

———————– Customizable Section ———————–
— Customize the SMTP host, port and your domain name below.
g_smtp_from_port PLS_INTEGER := 25;
g_smtp_to_port PLS_INTEGER := 25;

— Customize the signature that will appear in the email’s MIME header.
— Useful for versioning.
g_mailer_id CONSTANT VARCHAR2 (256) := ‘Mailer by Oracle UTL_SMTP’;
——————— End Customizable Section ———————

— A unique string that demarcates boundaries of parts in a multi-part email
— The string should not appear inside the body of any part of the email.
— Customize this if needed or generate this randomly dynamically.
g_boundary CONSTANT VARCHAR2 (256) := ‘—–7D81B75CCC90D2974F7A1CBD’;
g_first_boundary CONSTANT VARCHAR2 (256) := ‘–‘ || g_boundary || utl_tcp.crlf;
g_last_boundary CONSTANT VARCHAR2 (256) := ‘–‘ || g_boundary || ‘–‘ || utl_tcp.crlf;

— A MIME type that denotes multi-part email (MIME) messages.
g_multipart_mime_type CONSTANT VARCHAR2 (256) := ‘multipart/mixed; boundary=”‘ || g_boundary || ‘”‘;
g_max_base64_line_width CONSTANT PLS_INTEGER := 76 / 4 * 3;

–Procedure prc_mail
— A simple email API for sending email in plain text in a single call.
— The format of an email address is one of these:
— someone@some-domain
— “Someone at some domain”
— Someone at some domain
— The recipients is a list of email addresses separated by
— either a “,” or a “;”

— Parameters:
— p_sender sender mail
— p_recipients mail recipients
— p_subject mail subject
— p_message mail message

—

PROCEDURE prc_mail
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
);

–Procedure prc_mail_file
— A simple email API for sending email in plain text in a single call.
— The format of an email address is one of these:
— someone@some-domain
— “Someone at some domain”
— Someone at some domain
— The recipients is a list of email addresses separated by
— either a “,” or a “;”
— a single file can be attached to email

— Parameters:
— p_sender sender mail
— p_recipients mail recipients
— p_subject mail subject
— p_message mail message
— p_file_name file name attachment
— p_file_content file content attachment

—

PROCEDURE prc_mail_file
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
, p_file_name IN VARCHAR2
, p_file_content IN CLOB
);

–Procedure prc_mail_file
— A simple email API for sending email in plain text in a single call.
— The format of an email address is one of these:
— someone@some-domain
— “Someone at some domain”
— Someone at some domain
— The recipients is a list of email addresses separated by
— either a “,” or a “;”
— a single file can be attached to email

— Parameters:
— p_sender sender mail
— p_recipients mail recipients
— p_subject mail subject
— p_message mail message
— p_file_name file name attachment
— p_file_content file content attachment

—

PROCEDURE prc_mail_file_blob
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
, p_file_name IN VARCHAR2
, p_file_content IN BLOB
);

–Function fn_begin_mail
— Extended email API to send email in HTML or plain text with no size limit.
— First, begin the email by begin_mail(). Then, call write_text() repeatedly
— to send email in ASCII piece-by-piece. Or, call write_mb_text() to send
— email in non-ASCII or multi-byte character set. End the email with
— end_mail().

— Parameters:
— p_sender sender mail
— p_recipients mail recipients
— p_subject mail subject
— p_mime_type mime type
— p_priority mail priority

— Return:
— smtp connection

FUNCTION fn_begin_mail
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_priority IN PLS_INTEGER DEFAULT NULL
)
RETURN utl_smtp.connection;

–Procedure prc_write_text
— Write email body in ASCII

— Parameters:
— p_conn smtp connection
— p_message mail message

—

PROCEDURE prc_write_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN VARCHAR2
);

–Procedure prc_write_mb_text
— Write email body in non-ASCII (including multi-byte). The email body
— will be sent in the database character set.

— Parameters:
— p_conn smtp connection
— p_message mail message

—

PROCEDURE prc_write_mb_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN VARCHAR2
);

–Procedure prc_write_raw
— Write email body in binary

— Parameters:
— p_conn smtp connection
— p_message mail message

—

PROCEDURE prc_write_raw
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN RAW
);

–Procedure prc_attach_text
— APIs to send email with attachments. Attachments are sent by sending
— emails in “multipart/mixed” MIME format. Specify that MIME format when
— beginning an email with begin_mail().
— Send a single text attachment.

— Parameters:
— p_conn smtp connection
— p_data mail message
— p_mime_type mime type
— p_inline
— p_filename file name
— p_last

—

PROCEDURE prc_attach_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
);

–Procedure prc_attach_clob
— Send a single CLOB text attachment (can be very large).

— Parameters:
— p_conn smtp connection
— p_data mail message
— p_mime_type mime type
— p_inline
— p_filename file name
— p_last

—

PROCEDURE prc_attach_clob
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN CLOB
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
);

–Procedure prc_attach_base64
— Send a binary attachment. The attachment will be encoded in Base-64
— encoding format.

— Parameters:
— p_conn smtp connection
— p_data mail message
— p_mime_type mime type
— p_inline
— p_filename file name
— p_last

—

PROCEDURE prc_attach_base64
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN RAW
, p_mime_type IN VARCHAR2 DEFAULT ‘application/octet’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
);

–Procedure prc_begin_attachment
— Send an attachment with no size limit. First, begin the attachment
— with begin_attachment(). Then, call write_text repeatedly to send
— the attachment piece-by-piece. If the attachment is text-based but
— in non-ASCII or multi-byte character set, use write_mb_text()instead.
— To send binary attachment, the binary content should first be
— encoded in Base-64 encoding format using the demo package for 8i,
— or the native one in 9i. End the attachment with end_attachment.

— Parameters:
— p_conn smtp connection
— p_mime_type mime type
— p_inline
— p_filename file name
— p_transfer_enc transfer encryption

—

PROCEDURE prc_begin_attachment
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_transfer_enc IN VARCHAR2 DEFAULT NULL
);

–Procedure prc_end_attachment
— End the attachment.

— Parameters:
— p_conn smtp connection
— p_last

—

PROCEDURE prc_end_attachment
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_last IN BOOLEAN DEFAULT FALSE
);

–Procedure prc_end_mail
— End the email.

— Parameters:
— p_conn smtp connection

—

PROCEDURE prc_end_mail
(
p_conn IN OUT NOCOPY utl_smtp.connection
);

–Function fn_begin_session
— Extended email API to send multiple emails in a session for better
— performance. First, begin an email session with begin_session.
— Then, begin each email with a session by calling begin_mail_in_session
— instead of begin_mail. End the email with end_mail_in_session instead
— of end_mail. End the email session by end_session.

— Parameters:
—

— Returns:
— smtp connection

FUNCTION fn_begin_session
RETURN utl_smtp.connection;

–Procedure prc_begin_mail_in_session
— Begin an email in a session.

— Parameters:
— p_conn smtp connection
— p_sender mail sender
— p_recipients mail recipients
— p_subject subject
— p_mime_type mime type
— p_priority priority

—
—

PROCEDURE prc_begin_mail_in_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_priority IN PLS_INTEGER DEFAULT NULL
);

–Procedure prc_begin_mail_in_session
— End an email in a session.

— Parameters:
— p_conn smtp connection

—
—

PROCEDURE prc_end_mail_in_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
);

–Procedure prc_begin_mail_in_session
— End an email session.

— Parameters:
— p_conn smtp connection

—
—

PROCEDURE prc_end_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
);

–Function fn_get_attribute
— return attribute value

— Parameters:
— p_attr_name defined in email_setup

— Return:
— value of attribute

FUNCTION fn_get_attribute
(
p_attr_name IN VARCHAR2
)
RETURN VARCHAR2;
END pkg_mail;

create or replace PACKAGE BODY “PKG_MAIL”
IS

— Package : PKG_MAIL —
— Developer : Tomasz Lesinski —
— Date : 2022-03-21 —
— Purpose : Mail package —
— Prerequisite : PKG_TL_LOGGING —

— Change History —
— —
— Version Date Programmer Description —

— 1.0 2022-03-21 Tomasz, Lesinski Initial version —
— 2.0 2022-10-12 Tomasz, Lesinski Create simple templates —
— 2.1 2022-01-24 Tomasz, Lesinski Add file compression as zip —
— 2.2 2024-06-20 Tomasz, Lesinski Switch to smtp.prod.stockex.local —
— 2.3 2024-07-18 Pawel Nowak Take SMTP from EMAIL_SETUP table —

FUNCTION fn_get_address
(
p_addr_list IN OUT VARCHAR2
)
RETURN VARCHAR2;

–Function fn_get_attribute
— return attribute value

— Parameters:
— p_attr_name defined in email_setup

— Return:
— value of attribute

FUNCTION fn_get_attribute
(
p_attr_name IN VARCHAR2
)
RETURN VARCHAR2
IS
l_return VARCHAR2(4000);
BEGIN
FOR i IN
(
SELECT attr_name, attr_type, attr_value
FROM email_setup
WHERE attr_name = p_attr_name
)
LOOP
IF i.attr_type = ‘CONSTANT’ THEN
l_return := i.attr_value;
ELSIF i.attr_type = ‘SQL’ THEN
–calculate sql
EXECUTE IMMEDIATE i.attr_value INTO l_return;
END IF;
END LOOP;

IF l_return IS NULL THEN
  raise_application_error(-20001, 'Return value is NULL for p_attr_name: ' || p_attr_name);
END IF;

RETURN l_return;

END;

PROCEDURE prc_mail_file
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
, p_file_name IN VARCHAR2
, p_file_content IN CLOB
)
IS
l_conn utl_smtp.connection;
l_clob_temp CLOB;
l_const_buffer_size CONSTANT PLS_INTEGER := 255;
BEGIN
–get connection
l_conn := fn_begin_mail
(
p_sender => p_sender,
p_recipients => p_recipients,
p_subject => p_subject,
p_mime_type => pkg_mail.g_multipart_mime_type,
p_priority => NULL
);

--start email message
pkg_mail.prc_begin_attachment
(
  p_conn         => l_conn,
  p_mime_type    => 'text/html',
  p_inline       => TRUE,
  p_filename     => NULL,
  p_transfer_enc => NULL
);

--write email message
pkg_mail.prc_write_text
(
  p_conn    => l_conn,
  p_message => p_message
);

--end email message
pkg_mail.prc_end_attachment
(
  p_conn => l_conn,
  p_last => FALSE
);

--start file attachment
pkg_mail.prc_begin_attachment
(
  p_conn      => l_conn,
  p_mime_type => 'text/html',
  p_inline    => FALSE,
  p_filename  => p_file_name
);

l_clob_temp := p_file_content;

LOOP
  EXIT WHEN (l_clob_temp = empty_clob OR l_clob_temp IS NULL);

  pkg_mail.prc_write_text
  (
    p_conn    => l_conn,
    p_message => SUBSTR(l_clob_temp, 1, l_const_buffer_size)
  );

  l_clob_temp := SUBSTR(l_clob_temp, l_const_buffer_size + 1);
END LOOP;

--end file attachment
pkg_mail.prc_end_attachment
(
  p_conn => l_conn,
  p_last => TRUE
);

--end email
pkg_mail.prc_end_mail( p_conn => l_conn );

END prc_mail_file;

PROCEDURE prc_mail_file_blob
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
, p_file_name IN VARCHAR2
, p_file_content IN BLOB
)
IS
l_mail_conn UTL_SMTP.connection;
l_boundary VARCHAR2(50) := ‘—-=#abc1234321cba#=’;
l_step PLS_INTEGER := 57;
my_recipients VARCHAR2 (32767) := p_recipients;
l_smtp_host VARCHAR2(256) := pkg_mail.fn_get_attribute(p_attr_name=>’EMAIL_HOST’);
BEGIN
l_mail_conn := UTL_SMTP.open_connection(l_smtp_host, g_smtp_from_port);
UTL_SMTP.helo(l_mail_conn, l_smtp_host);
UTL_SMTP.mail(l_mail_conn, p_sender);
— UTL_SMTP.rcpt(l_mail_conn, p_recipients);
— Specify recipient(s) of the email.
WHILE (my_recipients IS NOT NULL) LOOP
utl_smtp.rcpt( l_mail_conn, fn_get_address( my_recipients ) );
END LOOP;

UTL_SMTP.open_data(l_mail_conn);

UTL_SMTP.write_data(l_mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'To: ' || p_recipients || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'From: ' || p_sender || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'Subject: ' || p_subject || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'Reply-To: ' || p_sender || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
UTL_SMTP.write_data(l_mail_conn, 'Content-Type: multipart/mixed; boundary="' || l_boundary || '"' || UTL_TCP.crlf || UTL_TCP.crlf);

IF p_message IS NOT NULL THEN
  UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Content-Type: text/plain; charset="iso-8859-1"' || UTL_TCP.crlf || UTL_TCP.crlf);

  UTL_SMTP.write_data(l_mail_conn, p_message);
  UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
END IF;

IF p_file_name IS NOT NULL THEN
  UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Content-Type: application/zip; name="' || p_file_name || '"' || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Content-Disposition: attachment; filename="' || p_file_name || '"' || UTL_TCP.crlf || UTL_TCP.crlf);

  FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_file_content) - 1 )/l_step) LOOP
    UTL_SMTP.write_data(l_mail_conn, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_file_content, l_step, i * l_step + 1))) || UTL_TCP.crlf);
  END LOOP;

  UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf);
END IF;

UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || '--' || UTL_TCP.crlf);
UTL_SMTP.close_data(l_mail_conn);

UTL_SMTP.quit(l_mail_conn);

END prc_mail_file_blob;

— Return the next email address in the list of email addresses, separated
— by either a “,” or a “;”. The format of mailbox may be in one of these:
— someone@some-domain
— “Someone at some domain”
— Someone at some domain
FUNCTION fn_get_address
(
p_addr_list IN OUT VARCHAR2
)
RETURN VARCHAR2
IS
addr VARCHAR2 (256);
I PLS_INTEGER;

  FUNCTION fn_lookup_unquoted_char
  (
     str    IN   VARCHAR2
   , chrs   IN   VARCHAR2
  )
  RETURN PLS_INTEGER
  AS
     C                                  VARCHAR2 (5);
     I                                  PLS_INTEGER;
     len                                PLS_INTEGER;
     inside_quote                       BOOLEAN;
  BEGIN
     inside_quote := FALSE;
     I := 1;
     len := LENGTH (str);
     WHILE (I <= len) LOOP
        C := substr (str
                   , I
                   , 1
                    );
        IF (inside_quote) THEN
           IF (C = '"') THEN
              inside_quote := FALSE;
           ELSIF (C = '\') THEN
              I := I + 1;   -- Skip the quote character
           END IF;
           GOTO next_char;
        END IF;
        IF (C = '"') THEN
           inside_quote := TRUE;
           GOTO next_char;
        END IF;
        IF (instr (chrs, C) >= 1) THEN
           RETURN I;
        END IF;
        <<next_char>>
        I := I + 1;
     END LOOP;
     RETURN 0;
  END;

BEGIN
p_addr_list := LTRIM (p_addr_list);
I := fn_lookup_unquoted_char (p_addr_list, ‘,;’);
IF (I >= 1) THEN
addr := substr (p_addr_list
, 1
, I – 1
);
p_addr_list := substr (p_addr_list, I + 1);
ELSE
addr := p_addr_list;
p_addr_list := ”;
END IF;

  I := fn_lookup_unquoted_char (addr, '<');

  IF (I >= 1) THEN
     addr := substr (addr, I + 1);
     I := instr (addr, '>');
     IF (I >= 1) THEN
        addr := substr (addr
                      , 1
                      , I - 1
                       );
     END IF;
  END IF;
  RETURN addr;

END;

— Write a MIME header
PROCEDURE prc_write_mime_header
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_name IN VARCHAR2
, p_value IN VARCHAR2
)
IS
BEGIN
utl_smtp.write_data (p_conn, p_name || ‘: ‘ || p_value || utl_tcp.crlf);
END;

— Mark a message-part boundary. Set to TRUE for the last boundary.
PROCEDURE prc_write_boundary
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_last IN BOOLEAN DEFAULT FALSE
)
AS
BEGIN
IF (p_last) THEN
utl_smtp.write_data (p_conn, g_last_boundary);
ELSE
utl_smtp.write_data (p_conn, g_first_boundary);
END IF;
END;

PROCEDURE prc_mail
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_message IN VARCHAR2
)
IS
l_conn utl_smtp.connection;
BEGIN
l_conn := fn_begin_mail
(
p_sender
, p_recipients
, p_subject
);

 prc_write_text (l_conn, p_message);

 prc_end_mail (l_conn);

END;

FUNCTION fn_begin_mail
(
p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_priority IN PLS_INTEGER DEFAULT NULL
)
RETURN utl_smtp.connection
IS
l_conn utl_smtp.connection;
BEGIN
l_conn := fn_begin_session;

 prc_begin_mail_in_session
 (
   l_conn
    , p_sender
    , p_recipients
    , p_subject
    , p_mime_type
    , p_priority
 );

 RETURN l_conn;

END;

PROCEDURE prc_write_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN VARCHAR2
)
IS
BEGIN
utl_smtp.write_data (p_conn, p_message);
END;

PROCEDURE prc_write_mb_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN VARCHAR2
)
IS
BEGIN
utl_smtp.write_raw_data (p_conn, utl_raw.cast_to_raw (p_message));
END;

PROCEDURE prc_write_raw
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_message IN RAW
)
IS
BEGIN
utl_smtp.write_raw_data (p_conn, p_message);
END;

PROCEDURE prc_attach_text
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
)
IS
BEGIN
prc_begin_attachment
(
p_conn
, p_mime_type
, p_inline
, p_filename
);

 prc_write_text (p_conn, p_data);

 prc_end_attachment (p_conn, p_last);

END;

PROCEDURE prc_attach_clob
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN CLOB
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
)
IS
— Constants
c_buffer_size CONSTANT PLS_INTEGER := 255;
— Variables
l_clob_temp CLOB;
BEGIN
prc_begin_attachment
(
p_conn => p_conn
, p_mime_type => p_mime_type
, p_inline => p_inline
, p_filename => p_filename
);

  l_clob_temp := p_data;

  LOOP
    EXIT WHEN (   l_clob_temp = empty_clob OR l_clob_temp IS NULL );

    prc_write_text
    (
     p_conn    => p_conn,
     p_message => substr( l_clob_temp, 1, c_buffer_size )
    );

    l_clob_temp := substr (l_clob_temp, c_buffer_size + 1);
  END LOOP;

  prc_end_attachment (p_conn      => p_conn, p_last => p_last);

END prc_attach_clob;

PROCEDURE prc_attach_base64
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_data IN RAW
, p_mime_type IN VARCHAR2 DEFAULT ‘application/octet’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_last IN BOOLEAN DEFAULT FALSE
)
IS
I PLS_INTEGER;
len PLS_INTEGER;
BEGIN
prc_begin_attachment
(
p_conn
, p_mime_type
, p_inline
, p_filename
, ‘base64’
);

  -- Split the Base64-encoded attachment into multiple lines
  I := 1;
  len := utl_raw.LENGTH (p_data);

  WHILE (I < len)
  LOOP
    IF (I + g_max_base64_line_width < len) THEN
      utl_smtp.write_raw_data (p_conn, utl_encode.base64_encode(utl_raw.substr(p_data, I, g_max_base64_line_width)));
    ELSE
      utl_smtp.write_raw_data (p_conn, utl_encode.base64_encode(utl_raw.substr(p_data, I)));
    END IF;

    utl_smtp.write_data (p_conn, utl_tcp.crlf);

    I := I + g_max_base64_line_width;
  END LOOP;

  prc_end_attachment (p_conn, p_last);

END;

PROCEDURE prc_begin_attachment
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_inline IN BOOLEAN DEFAULT TRUE
, p_filename IN VARCHAR2 DEFAULT NULL
, p_transfer_enc IN VARCHAR2 DEFAULT NULL
)
IS
BEGIN
prc_write_boundary( p_conn );

prc_write_mime_header
(
    p_conn
  , 'Content-Type'
  , p_mime_type
);

IF (p_filename IS NOT NULL) THEN
  IF (p_inline) THEN
    prc_write_mime_header
    (
        p_conn
      , 'Content-Disposition'
      , 'inline; filename="' || p_filename || '"'
    );
  ELSE
    prc_write_mime_header
    (
        p_conn
      , 'Content-Disposition'
      , 'attachment; filename="' || p_filename || '"'
    );
  END IF;
END IF;

IF p_transfer_enc IS NOT NULL THEN
  prc_write_mime_header
  (
      p_conn
    , 'Content-Transfer-Encoding'
    , p_transfer_enc
  );
END IF;

utl_smtp.write_data( p_conn, utl_tcp.crlf );

END;

PROCEDURE prc_end_attachment
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_last IN BOOLEAN DEFAULT FALSE
)
IS
BEGIN
utl_smtp.write_data( p_conn, utl_tcp.crlf );

  IF (p_last) THEN
    prc_write_boundary( p_conn, p_last );
  END IF;

END;

PROCEDURE prc_end_mail
(
p_conn IN OUT NOCOPY utl_smtp.connection
)
IS
BEGIN
prc_end_mail_in_session( p_conn );
prc_end_session( p_conn );
END;

FUNCTION fn_begin_session
RETURN utl_smtp.connection
IS
l_conn utl_smtp.connection;
l_smtp_host VARCHAR2(256) := pkg_mail.fn_get_attribute(p_attr_name=>’EMAIL_HOST’);
BEGIN
— open SMTP connection
l_conn := utl_smtp.open_connection( l_smtp_host, g_smtp_from_port, g_smtp_to_port );

 utl_smtp.helo( l_conn, l_smtp_host );

 RETURN l_conn;

END;

PROCEDURE prc_begin_mail_in_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
, p_sender IN VARCHAR2
, p_recipients IN VARCHAR2
, p_subject IN VARCHAR2
, p_mime_type IN VARCHAR2 DEFAULT ‘text/plain’
, p_priority IN PLS_INTEGER DEFAULT NULL
)
IS
my_recipients VARCHAR2 (32767) := p_recipients;
my_sender VARCHAR2 (32767) := p_sender;
BEGIN
— Specify sender’s address (our server allows bogus address
— as long as it is a full email address (xxx@yyy.com).
utl_smtp.mail (p_conn, fn_get_address (my_sender));
— Specify recipient(s) of the email.
WHILE (my_recipients IS NOT NULL) LOOP
utl_smtp.rcpt( p_conn, fn_get_address( my_recipients ) );
END LOOP;

  -- Start body of email
  utl_smtp.open_data( p_conn );

  -- Set "From" MIME header
  prc_write_mime_header
  (
      p_conn
    , 'From'
    , p_sender
  );

  -- Set "To" MIME header
  prc_write_mime_header
  (
      p_conn
    , 'To'
    , p_recipients
  );

  -- Set "Subject" MIME header
  prc_write_mime_header
  (
      p_conn
    , 'Subject'
    , p_subject
  );

  -- Set "Content-Type" MIME header
  prc_write_mime_header
  (
      p_conn
    , 'Content-Type'
    , p_mime_type
  );

  -- Set "X-Mailer" MIME header
  prc_write_mime_header
  (
      p_conn
    , 'X-Mailer'
    , g_mailer_id
  );

  -- Set priority:
  --   High      Normal       Low
  --   1     2     3     4     5
  IF (p_priority IS NOT NULL) THEN
    prc_write_mime_header
    (
        p_conn
      , 'X-Priority'
      , p_priority
    );
  END IF;

  -- Send an empty line to denotes end of MIME headers and
  -- beginning of message body.
  utl_smtp.write_data (p_conn, utl_tcp.crlf);

  IF (p_mime_type LIKE 'multipart/mixed%') THEN
    prc_write_text (p_conn, 'This is a multi-part message in MIME format.' || utl_tcp.crlf);
  END IF;

END;

PROCEDURE prc_end_mail_in_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
)
IS
BEGIN
utl_smtp.close_data( p_conn );
END;

PROCEDURE prc_end_session
(
p_conn IN OUT NOCOPY utl_smtp.connection
)
IS
BEGIN
utl_smtp.quit( p_conn );
END;

END pkg_mail;

/