/* =========================================================================================
   WHAT HAPPENED – window forensic kit (SQL Server 2012+; testowane na 2016/2019/2022)
   Autor: Duduś dla marcin
   Wejście: podaj zakres CZASU LOKALNEGO (serwera), skrypt sam przeliczy na UTC dla XEvent.
   Wyniki (kolejne result sety):
     1) LOGI z system_health (error_reported, attention, deadlock)
     2) CPU (cały sqlservr) z system_health (timeline)
     3) CPU ~per database (przybliżenie na podstawie dm_exec_query_stats w oknie)
     4) I/O per dysk i per plik (stan bieżący od startu instancji)
     5) Sesje teraz + aktywne żądania + top waity teraz + drzewko blokad
   ========================================================================================= */

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE 
    @StartLocal datetime2(0) = DATEADD(MINUTE, -60, SYSDATETIME()), -- domyślnie ostatnia godzina
    @EndLocal   datetime2(0) = SYSDATETIME();

-- Konwersja: lokalny -> UTC (z użyciem offsetu GETDATE/GETUTCDATE)
DECLARE @LocalToUtcOffsetMin int = DATEDIFF(MINUTE, GETDATE(), GETUTCDATE());
DECLARE @StartUtc datetime2(0) = DATEADD(MINUTE, @LocalToUtcOffsetMin, @StartLocal);
DECLARE @EndUtc   datetime2(0) = DATEADD(MINUTE, @LocalToUtcOffsetMin, @EndLocal);

-- Ścieżka do plików XEvent system_health (działa na domyślnej lokalizacji)
DECLARE @xe_path nvarchar(260) = N'system_health*.xel';

PRINT CONCAT('Okno lokalne: ', CONVERT(varchar(19), @StartLocal, 120), ' — ', CONVERT(varchar(19), @EndLocal, 120));
PRINT CONCAT('Okno UTC:     ', CONVERT(varchar(19), @StartUtc,   120), ' — ', CONVERT(varchar(19), @EndUtc,   120));
PRINT '---';

--------------------------------------------------------------------------------------------
-- 1) LOGI z system_health: błędy, attention (przerwane zapytania), deadlocki — w oknie
--------------------------------------------------------------------------------------------
;WITH xe AS (
    SELECT
        DATEADD(MINUTE, DATEDIFF(MINUTE, GETUTCDATE(), SYSDATETIMEOFFSET()),
                CAST(event_data_xml.value('(event/@timestamp)[1]', 'datetime2') AS datetime2)) AS [event_time_local],
        event_data_xml.value('(event/@name)[1]', 'nvarchar(128)') AS event_name,
        event_data_xml.value('(event/data[@name="error_number"]/value)[1]', 'int') AS error_number,
        event_data_xml.value('(event/data[@name="severity"]/value)[1]', 'int') AS severity,
        event_data_xml.value('(event/data[@name="state"]/value)[1]', 'int') AS state,
        event_data_xml.value('(event/data[@name="message"]/value)[1]', 'nvarchar(max)') AS message_text,
        event_data_xml.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
        event_data_xml.value('(event/action[@name="database_name"]/value)[1]', 'sysname') AS database_name,
        event_data_xml.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(256)') AS host_name,
        event_data_xml.value('(event/action[@name="username"]/value)[1]', 'nvarchar(256)') AS login_name,
        event_data_xml.value('(event/action[@name="session_id"]/value)[1]', 'int') AS session_id
    FROM (
        SELECT CONVERT(xml, event_data) AS event_data_xml
        FROM sys.fn_xe_file_target_read_file(@xe_path, NULL, NULL, NULL)
    ) AS src
    WHERE event_data_xml.value('(event/@timestamp)[1]', 'datetime2') BETWEEN @StartUtc AND @EndUtc
      AND event_data_xml.value('(event/@name)[1]', 'nvarchar(128)') IN 
          (N'error_reported', N'attention', N'deadlock')
)
SELECT TOP (1000)
    event_time_local, event_name, error_number, severity, state,
    database_name, host_name, login_name, session_id,
    message_text,
    sql_text
FROM xe
ORDER BY event_time_local;

--------------------------------------------------------------------------------------------
-- 2) CPU (cały sqlservr) – timeline z system_health (scheduler_monitor_system_health...)
--------------------------------------------------------------------------------------------
;WITH xe AS (
    SELECT
        DATEADD(MINUTE, DATEDIFF(MINUTE, GETUTCDATE(), SYSDATETIMEOFFSET()),
                CAST(event_data_xml.value('(event/@timestamp)[1]', 'datetime2') AS datetime2)) AS event_time_local,
        event_data_xml.value('(event/data[@name="systemHealth"]/value/record/@record_id)[1]', 'int') AS record_id,
        event_data_xml.value('(event/data[@name="systemHealth"]/value/record/schedulerMonitorEvent/systemHealth/ProcessUtilization)[1]', 'int') AS process_utilization_percent,
        event_data_xml.value('(event/data[@name="systemHealth"]/value/record/schedulerMonitorEvent/systemHealth/SystemIdle)[1]', 'int') AS system_idle_percent
    FROM (
        SELECT CONVERT(xml, event_data) AS event_data_xml
        FROM sys.fn_xe_file_target_read_file(@xe_path, NULL, NULL, NULL)
    ) s
    WHERE event_data_xml.value('(event/@name)[1]', 'nvarchar(200)') = N'scheduler_monitor_system_health_ring_buffer_record'
      AND event_data_xml.value('(event/@timestamp)[1]', 'datetime2') BETWEEN @StartUtc AND @EndUtc
)
SELECT event_time_local,
       process_utilization_percent AS CPU_sqlservr_percent,
       system_idle_percent AS CPU_system_idle_percent
FROM xe
ORDER BY event_time_local;

--------------------------------------------------------------------------------------------
-- 3) CPU ~per database (przybliżenie): sum(worker_time) dla planów wykonywanych w oknie
--    Źródło: plan cache; grupowanie po database_id z atrybutów planu.
--    Ograniczenia: to nie pełny „timeline”, a suma dla zapytań, których last_execution_time
--    wpada w okno. Daje szybki obraz „które DB spalały CPU” w badanym zakresie.
--------------------------------------------------------------------------------------------
;WITH qs AS (
    SELECT 
        qs.total_worker_time,
        qs.last_execution_time,
        CONVERT(int, MAX(CASE WHEN pa.attribute = 'dbid' THEN pa.value END)) AS database_id
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
    WHERE qs.last_execution_time BETWEEN @StartLocal AND @EndLocal
    GROUP BY qs.plan_handle, qs.total_worker_time, qs.last_execution_time
)
SELECT TOP (50)
    DB_NAME(database_id) AS database_name,
    SUM(total_worker_time) / 1000.0 AS worker_time_ms_approx
FROM qs
WHERE database_id IS NOT NULL
GROUP BY database_id
ORDER BY worker_time_ms_approx DESC;

--------------------------------------------------------------------------------------------
-- 4) I/O per dysk i per plik – stan bieżący (od startu instancji).
--    Jeżeli potrzebujesz „dokładnie w oknie”, dołóż krótkie próbkowanie t1/t2 do tabeli tymczasowej.
--------------------------------------------------------------------------------------------
-- per plik
SELECT 
    DB_NAME(vfs.database_id) AS database_name,
    mf.file_id,
    mf.type_desc,
    mf.physical_name,
    (vfs.num_of_reads)  AS reads,
    (vfs.num_of_writes) AS writes,
    (vfs.num_of_bytes_read)  AS bytes_read,
    (vfs.num_of_bytes_written) AS bytes_written,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    vfs.io_stall
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
  ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY (vfs.num_of_reads + vfs.num_of_writes) DESC;

-- per dysk (litera woluminu)
;WITH files AS (
    SELECT 
        UPPER(LEFT(mf.physical_name, 1)) AS drive_letter,
        vfs.*
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
    JOIN sys.master_files mf
      ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
)
SELECT 
    drive_letter,
    SUM(num_of_reads) AS reads,
    SUM(num_of_writes) AS writes,
    SUM(num_of_bytes_read) AS bytes_read,
    SUM(num_of_bytes_written) AS bytes_written,
    SUM(io_stall_read_ms) AS io_stall_read_ms,
    SUM(io_stall_write_ms) AS io_stall_write_ms,
    SUM(io_stall) AS io_stall_ms
FROM files
GROUP BY drive_letter
ORDER BY (SUM(num_of_reads) + SUM(num_of_writes)) DESC;

--------------------------------------------------------------------------------------------
-- 5) Sytuacja TERAZ: ile sesji, kto co robi, waity i blokady (snapshot)
--------------------------------------------------------------------------------------------

-- 5a) Liczba sesji teraz
SELECT 
    COUNT(*) AS SessionsTotal,
    SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END) AS SessionsRunning,
    SUM(CASE WHEN is_user_process = 1 THEN 1 ELSE 0 END) AS UserSessions
FROM sys.dm_exec_sessions;

-- 5b) Aktywne żądania (top 50)
SELECT TOP (50)
    r.session_id, s.login_name, s.host_name, s.program_name, s.database_id, DB_NAME(s.database_id) AS database_name,
    r.status, r.command, r.cpu_time, r.total_elapsed_time,
    r.reads, r.writes, r.logical_reads,
    r.wait_type, r.wait_time, r.wait_resource,
    r.blocking_session_id,
    SUBSTRING(t.text, (r.statement_start_offset/2)+1,
              CASE WHEN r.statement_end_offset = -1 
                   THEN (LEN(CONVERT(nvarchar(max), t.text)) - (r.statement_start_offset/2) + 1)
                   ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1 END) AS stmt_text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
ORDER BY r.cpu_time DESC;

-- 5c) Top bieżące waity (z aktywnych zadań)
SELECT TOP (20)
    w.wait_type,
    COUNT(*) AS waiting_tasks,
    SUM(w.wait_duration_ms) AS wait_duration_ms_sum
FROM sys.dm_os_waiting_tasks w
GROUP BY w.wait_type
ORDER BY wait_duration_ms_sum DESC;

-- 5d) Drzewo blokad teraz
;WITH l AS (
    SELECT 
        s.session_id,
        s.login_name,
        s.host_name,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        DB_NAME(r.database_id) AS database_name,
        r.command
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s
      ON r.session_id = s.session_id
    WHERE r.blocking_session_id <> 0
)
SELECT * FROM l ORDER BY wait_time DESC;

-- (Opcjonalnie) pełne drzewko blokad jako hierarchia:
;WITH src AS (
    SELECT 
        r.session_id,
        r.blocking_session_id,
        s.login_name,
        s.host_name,
        DB_NAME(r.database_id) AS database_name,
        r.wait_type,
        r.wait_time,
        r.command
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
),
rec AS (
    SELECT session_id, blocking_session_id, login_name, host_name, database_name, wait_type, wait_time, command, 
           0 AS lvl, CAST(CONCAT('SPID ', session_id) AS nvarchar(4000)) AS path
    FROM src WHERE blocking_session_id = 0
    UNION ALL
    SELECT c.session_id, c.blocking_session_id, c.login_name, c.host_name, c.database_name, c.wait_type, c.wait_time, c.command,
           p.lvl + 1,
           CAST(CONCAT(p.path, N' -> SPID ', c.session_id) AS nvarchar(4000))
    FROM src c
    JOIN rec p ON c.blocking_session_id = p.session_id
)
SELECT * FROM rec ORDER BY path OPTION (MAXRECURSION 1000);
GO