CREATE OR REPLACE PACKAGE BODY PKG_UTIL_MAIL
AS
  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN PKG_UTIL_REPORT.fn_get_config(p_config_key, p_default);
  END fn_get_config;

  FUNCTION fn_mail_enabled
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN CASE WHEN UPPER(TRIM(fn_get_config('MAIL_ENABLED', 'N'))) = 'Y' THEN 'Y' ELSE 'N' END;
  END fn_mail_enabled;

  FUNCTION fn_get_address
  (
    p_addr_list IN OUT VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_addr VARCHAR2(256);
    l_idx  PLS_INTEGER;

    FUNCTION fn_lookup_unquoted_char
    (
      p_str  IN VARCHAR2,
      p_chrs IN VARCHAR2
    )
    RETURN PLS_INTEGER
    IS
      l_char         VARCHAR2(1);
      l_idx          PLS_INTEGER := 1;
      l_len          PLS_INTEGER := LENGTH(p_str);
      l_inside_quote BOOLEAN := FALSE;
    BEGIN
      WHILE l_idx <= l_len LOOP
        l_char := SUBSTR(p_str, l_idx, 1);

        IF l_inside_quote THEN
          IF l_char = '"' THEN
            l_inside_quote := FALSE;
          ELSIF l_char = '\' THEN
            l_idx := l_idx + 1;
          END IF;
        ELSIF l_char = '"' THEN
          l_inside_quote := TRUE;
        ELSIF INSTR(p_chrs, l_char) >= 1 THEN
          RETURN l_idx;
        END IF;

        l_idx := l_idx + 1;
      END LOOP;

      RETURN 0;
    END fn_lookup_unquoted_char;
  BEGIN
    p_addr_list := LTRIM(p_addr_list);
    l_idx := fn_lookup_unquoted_char(p_addr_list, ',;');

    IF l_idx >= 1 THEN
      l_addr := SUBSTR(p_addr_list, 1, l_idx - 1);
      p_addr_list := SUBSTR(p_addr_list, l_idx + 1);
    ELSE
      l_addr := p_addr_list;
      p_addr_list := NULL;
    END IF;

    l_idx := INSTR(l_addr, '<');
    IF l_idx >= 1 THEN
      l_addr := SUBSTR(l_addr, l_idx + 1);
      l_idx := INSTR(l_addr, '>');
      IF l_idx >= 1 THEN
        l_addr := SUBSTR(l_addr, 1, l_idx - 1);
      END IF;
    END IF;

    RETURN TRIM(l_addr);
  END fn_get_address;

  PROCEDURE prc_write_mime_header
  (
    p_conn  IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  IS
  BEGIN
    UTL_SMTP.WRITE_DATA(p_conn, p_name || ': ' || p_value || UTL_TCP.CRLF);
  END prc_write_mime_header;

  PROCEDURE prc_write_boundary
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT FALSE
  )
  IS
  BEGIN
    IF p_last THEN
      UTL_SMTP.WRITE_DATA(p_conn, g_last_boundary);
    ELSE
      UTL_SMTP.WRITE_DATA(p_conn, g_first_boundary);
    END IF;
  END prc_write_boundary;

  FUNCTION fn_begin_session
  RETURN UTL_SMTP.CONNECTION
  IS
    l_host VARCHAR2(256) := fn_get_config('SMTP_HOST');
    l_port PLS_INTEGER := TO_NUMBER(fn_get_config('SMTP_PORT', '25'));
    l_conn UTL_SMTP.CONNECTION;
  BEGIN
    IF l_host IS NULL THEN
      RAISE_APPLICATION_ERROR(-20700, 'SMTP_HOST is required when MAIL_ENABLED=Y');
    END IF;

    l_conn := UTL_SMTP.OPEN_CONNECTION(l_host, l_port);
    UTL_SMTP.HELO(l_conn, l_host);
    RETURN l_conn;
  END fn_begin_session;

  PROCEDURE prc_begin_mail_in_session
  (
    p_conn       IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  )
  IS
    l_recipients VARCHAR2(32767) := p_recipients;
    l_sender     VARCHAR2(32767) := p_sender;
    l_addr       VARCHAR2(256);
  BEGIN
    IF p_sender IS NULL THEN
      RAISE_APPLICATION_ERROR(-20701, 'Sender address is required');
    ELSIF p_recipients IS NULL THEN
      RAISE_APPLICATION_ERROR(-20702, 'Recipient address is required');
    END IF;

    UTL_SMTP.MAIL(p_conn, fn_get_address(l_sender));

    WHILE l_recipients IS NOT NULL LOOP
      l_addr := fn_get_address(l_recipients);
      IF l_addr IS NOT NULL THEN
        UTL_SMTP.RCPT(p_conn, l_addr);
      END IF;
    END LOOP;

    UTL_SMTP.OPEN_DATA(p_conn);
    prc_write_mime_header(p_conn, 'From', p_sender);
    prc_write_mime_header(p_conn, 'To', p_recipients);
    prc_write_mime_header(p_conn, 'Subject', p_subject);
    prc_write_mime_header(p_conn, 'Content-Type', p_mime_type);
    prc_write_mime_header(p_conn, 'X-Mailer', g_mailer_id);

    IF p_priority IS NOT NULL THEN
      prc_write_mime_header(p_conn, 'X-Priority', TO_CHAR(p_priority));
    END IF;

    UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);

    IF p_mime_type LIKE 'multipart/mixed%' THEN
      prc_write_text(p_conn, 'This is a multi-part message in MIME format.' || UTL_TCP.CRLF);
    END IF;
  END prc_begin_mail_in_session;

  FUNCTION fn_begin_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  )
  RETURN UTL_SMTP.CONNECTION
  IS
    l_conn UTL_SMTP.CONNECTION;
  BEGIN
    l_conn := fn_begin_session;
    prc_begin_mail_in_session(l_conn, p_sender, p_recipients, p_subject, p_mime_type, p_priority);
    RETURN l_conn;
  END fn_begin_mail;

  PROCEDURE prc_write_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  )
  IS
  BEGIN
    UTL_SMTP.WRITE_DATA(p_conn, p_message);
  END prc_write_text;

  PROCEDURE prc_write_mb_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  )
  IS
  BEGIN
    UTL_SMTP.WRITE_RAW_DATA(p_conn, UTL_RAW.CAST_TO_RAW(p_message));
  END prc_write_mb_text;

  PROCEDURE prc_write_raw
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN RAW
  )
  IS
  BEGIN
    UTL_SMTP.WRITE_RAW_DATA(p_conn, p_message);
  END prc_write_raw;

  PROCEDURE prc_begin_attachment
  (
    p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
    p_inline       IN BOOLEAN DEFAULT TRUE,
    p_filename     IN VARCHAR2 DEFAULT NULL,
    p_transfer_enc IN VARCHAR2 DEFAULT NULL
  )
  IS
  BEGIN
    prc_write_boundary(p_conn);
    prc_write_mime_header(p_conn, 'Content-Type', p_mime_type);

    IF p_filename IS NOT NULL THEN
      prc_write_mime_header(
        p_conn,
        'Content-Disposition',
        CASE WHEN p_inline THEN 'inline' ELSE 'attachment' END || '; filename="' || p_filename || '"'
      );
    END IF;

    IF p_transfer_enc IS NOT NULL THEN
      prc_write_mime_header(p_conn, 'Content-Transfer-Encoding', p_transfer_enc);
    END IF;

    UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);
  END prc_begin_attachment;

  PROCEDURE prc_end_attachment
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT FALSE
  )
  IS
  BEGIN
    UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);

    IF p_last THEN
      prc_write_boundary(p_conn, TRUE);
    END IF;
  END prc_end_attachment;

  PROCEDURE prc_attach_clob
  (
    p_conn      IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_data      IN CLOB,
    p_mime_type IN VARCHAR2 DEFAULT 'text/plain',
    p_inline    IN BOOLEAN DEFAULT TRUE,
    p_filename  IN VARCHAR2 DEFAULT NULL,
    p_last      IN BOOLEAN DEFAULT FALSE
  )
  IS
    l_pos PLS_INTEGER := 1;
    l_len PLS_INTEGER := NVL(DBMS_LOB.GETLENGTH(p_data), 0);
    l_chunk VARCHAR2(32767);
  BEGIN
    prc_begin_attachment(p_conn, p_mime_type, p_inline, p_filename);

    WHILE l_pos <= l_len LOOP
      l_chunk := DBMS_LOB.SUBSTR(p_data, 32000, l_pos);
      prc_write_text(p_conn, l_chunk);
      l_pos := l_pos + 32000;
    END LOOP;

    prc_end_attachment(p_conn, p_last);
  END prc_attach_clob;

  PROCEDURE prc_end_mail_in_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  )
  IS
  BEGIN
    UTL_SMTP.CLOSE_DATA(p_conn);
  END prc_end_mail_in_session;

  PROCEDURE prc_end_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  )
  IS
  BEGIN
    UTL_SMTP.QUIT(p_conn);
  END prc_end_session;

  PROCEDURE prc_end_mail
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  )
  IS
  BEGIN
    prc_end_mail_in_session(p_conn);
    prc_end_session(p_conn);
  END prc_end_mail;

  PROCEDURE prc_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_message    IN VARCHAR2
  )
  IS
    l_conn UTL_SMTP.CONNECTION;
  BEGIN
    IF fn_mail_enabled <> 'Y' THEN
      RETURN;
    END IF;

    l_conn := fn_begin_mail(p_sender, p_recipients, p_subject);
    prc_write_text(l_conn, p_message);
    prc_end_mail(l_conn);
  END prc_mail;

  PROCEDURE prc_mail_file
  (
    p_sender       IN VARCHAR2,
    p_recipients   IN VARCHAR2,
    p_subject      IN VARCHAR2,
    p_message      IN VARCHAR2,
    p_file_name    IN VARCHAR2,
    p_file_content IN CLOB
  )
  IS
    l_conn UTL_SMTP.CONNECTION;
  BEGIN
    IF fn_mail_enabled <> 'Y' THEN
      RETURN;
    END IF;

    l_conn := fn_begin_mail(p_sender, p_recipients, p_subject, g_multipart_mime_type);
    prc_attach_clob(l_conn, TO_CLOB(p_message), 'text/html', TRUE, NULL, FALSE);
    prc_attach_clob(l_conn, p_file_content, 'text/html', FALSE, p_file_name, TRUE);
    prc_end_mail(l_conn);
  END prc_mail_file;

  PROCEDURE prc_send_html
  (
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_html       IN CLOB
  )
  IS
    l_sender     VARCHAR2(4000) := fn_get_config('MAIL_FROM');
    l_recipients VARCHAR2(4000) := NVL(p_recipients, fn_get_config('MAIL_TO'));
  BEGIN
    IF fn_mail_enabled <> 'Y' THEN
      RETURN;
    END IF;

    prc_mail_file(l_sender, l_recipients, p_subject, 'HTML report attached.', 'report.html', p_html);
  END prc_send_html;

  PROCEDURE prc_send_report
  (
    p_report_name IN VARCHAR2,
    p_recipients  IN VARCHAR2 DEFAULT NULL,
    p_subject     IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_report CLOB;
  BEGIN
    l_report := PKG_UTIL_REPORT.fn_report_html(p_report_name);
    prc_send_html(p_recipients, NVL(p_subject, p_report_name), l_report);
  END prc_send_report;
END PKG_UTIL_MAIL;
/
