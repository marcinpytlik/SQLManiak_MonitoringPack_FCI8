/* ==========================================================
   Baseline pack (MVP) – SQL Server 2022
   - DB: DBA_tools
   - Schema: baseline
   - Captures: instance info, waits, perf counters, file IO, 
               memory clerks, top queries (Query Store), blocking
   ========================================================== */

IF DB_ID(N'DBA_tools') IS NULL
BEGIN
    CREATE DATABASE DBA_tools;
END
GO

USE DBA_tools;
GO

IF SCHEMA_ID(N'baseline') IS NULL
    EXEC(N'CREATE SCHEMA baseline AUTHORIZATION dbo;');
GO

-- "Run" header (one row per capture)
IF OBJECT_ID(N'baseline.Run', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.Run
    (
        run_id           uniqueidentifier NOT NULL CONSTRAINT DF_baseline_Run_run_id DEFAULT NEWID(),
        capture_utc      datetime2(3)     NOT NULL CONSTRAINT DF_baseline_Run_capture_utc DEFAULT SYSUTCDATETIME(),
        capture_local    datetime2(3)     NOT NULL CONSTRAINT DF_baseline_Run_capture_local DEFAULT SYSDATETIME(),
        server_name      sysname          NOT NULL CONSTRAINT DF_baseline_Run_server DEFAULT @@SERVERNAME,
        instance_name    sysname          NULL,
        sql_version      nvarchar(128)    NULL,
        product_level    nvarchar(128)    NULL,
        edition          nvarchar(128)    NULL,
        is_clustered     bit              NULL,
        num_cpu          int              NULL,
        max_server_mem_mb int             NULL,
        notes            nvarchar(4000)   NULL,
        CONSTRAINT PK_baseline_Run PRIMARY KEY (run_id)
    );
END
GO

-- Wait stats snapshot
IF OBJECT_ID(N'baseline.WaitStats', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.WaitStats
    (
        run_id              uniqueidentifier NOT NULL,
        wait_type           nvarchar(60)     NOT NULL,
        waiting_tasks_count bigint           NOT NULL,
        wait_time_ms        bigint           NOT NULL,
        max_wait_time_ms    bigint           NOT NULL,
        signal_wait_time_ms bigint           NOT NULL,
        CONSTRAINT PK_baseline_WaitStats PRIMARY KEY (run_id, wait_type),
        CONSTRAINT FK_baseline_WaitStats_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

-- Perf counters snapshot (sys.dm_os_performance_counters)
IF OBJECT_ID(N'baseline.PerfCounters', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.PerfCounters
    (
        run_id        uniqueidentifier NOT NULL,
        object_name   nvarchar(128)    NOT NULL,
        counter_name  nvarchar(128)    NOT NULL,
        instance_name nvarchar(128)    NOT NULL,
        cntr_value    bigint           NOT NULL,
        cntr_type     int              NOT NULL,
        CONSTRAINT PK_baseline_PerfCounters PRIMARY KEY (run_id, object_name, counter_name, instance_name),
        CONSTRAINT FK_baseline_PerfCounters_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

-- File IO stats snapshot
IF OBJECT_ID(N'baseline.FileIO', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.FileIO
    (
        run_id                  uniqueidentifier NOT NULL,
        database_id             int              NOT NULL,
        file_id                 int              NOT NULL,
        file_logical_name       sysname          NULL,
        file_physical_name      nvarchar(260)    NULL,
        num_of_reads            bigint           NOT NULL,
        num_of_writes           bigint           NOT NULL,
        io_stall_read_ms        bigint           NOT NULL,
        io_stall_write_ms       bigint           NOT NULL,
        size_on_disk_bytes      bigint           NOT NULL,
        CONSTRAINT PK_baseline_FileIO PRIMARY KEY (run_id, database_id, file_id),
        CONSTRAINT FK_baseline_FileIO_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

-- Memory clerks snapshot
IF OBJECT_ID(N'baseline.MemoryClerks', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.MemoryClerks
    (
        run_id        uniqueidentifier NOT NULL,
        clerk_name    nvarchar(256)    NOT NULL,
        pages_kb      bigint           NOT NULL,
        virtual_mem_kb bigint          NOT NULL,
        CONSTRAINT PK_baseline_MemoryClerks PRIMARY KEY (run_id, clerk_name),
        CONSTRAINT FK_baseline_MemoryClerks_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

-- Blocking snapshot (lightweight)
IF OBJECT_ID(N'baseline.Blocking', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.Blocking
    (
        run_id              uniqueidentifier NOT NULL,
        session_id          smallint         NOT NULL,
        blocking_session_id smallint         NOT NULL,
        wait_type           nvarchar(60)     NULL,
        wait_time_ms        int              NULL,
        wait_resource       nvarchar(256)    NULL,
        database_name       sysname          NULL,
        login_name          sysname          NULL,
        host_name           sysname          NULL,
        program_name        nvarchar(256)    NULL,
        statement_text      nvarchar(max)    NULL,
        CONSTRAINT PK_baseline_Blocking PRIMARY KEY (run_id, session_id),
        CONSTRAINT FK_baseline_Blocking_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

-- Top queries from Query Store (if enabled)
IF OBJECT_ID(N'baseline.TopQueryStore', N'U') IS NULL
BEGIN
    CREATE TABLE baseline.TopQueryStore
    (
        run_id            uniqueidentifier NOT NULL,
        database_id       int              NOT NULL,
        query_id          bigint           NOT NULL,
        plan_id           bigint           NOT NULL,
        avg_duration_ms   float            NULL,
        avg_cpu_ms        float            NULL,
        avg_logical_io    float            NULL,
        avg_physical_io   float            NULL,
        exec_count        bigint           NULL,
        query_sql_text    nvarchar(max)    NULL,
        CONSTRAINT PK_baseline_TopQueryStore PRIMARY KEY (run_id, database_id, query_id, plan_id),
        CONSTRAINT FK_baseline_TopQueryStore_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
    );
END
GO

/* =========================
   Instance configurations
   ========================= */
IF OBJECT_ID(N'baseline.InstanceConfig', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.InstanceConfig
  (
      run_id        uniqueidentifier NOT NULL,
      name          sysname          NOT NULL,
      value         sql_variant      NULL,
      value_in_use  sql_variant      NULL,
      minimum       sql_variant      NULL,
      maximum       sql_variant      NULL,
      is_dynamic    bit              NULL,
      is_advanced   bit              NULL,
      description   nvarchar(255)    NULL,
      CONSTRAINT PK_baseline_InstanceConfig PRIMARY KEY (run_id, name),
      CONSTRAINT FK_baseline_InstanceConfig_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Trace flags
   ========================= */
IF OBJECT_ID(N'baseline.TraceFlags', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.TraceFlags
  (
      run_id      uniqueidentifier NOT NULL,
      trace_flag  int              NOT NULL,
      status      bit              NOT NULL,
      is_global   bit              NOT NULL,
      is_session  bit              NOT NULL,
      CONSTRAINT PK_baseline_TraceFlags PRIMARY KEY (run_id, trace_flag, is_global, is_session),
      CONSTRAINT FK_baseline_TraceFlags_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   tempdb layout
   ========================= */
IF OBJECT_ID(N'baseline.TempdbFiles', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.TempdbFiles
  (
      run_id            uniqueidentifier NOT NULL,
      file_id           int              NOT NULL,
      logical_name      sysname          NOT NULL,
      type_desc         nvarchar(60)     NOT NULL,
      physical_name     nvarchar(260)    NOT NULL,
      size_mb           decimal(18,2)    NOT NULL,
      growth            int              NOT NULL,
      is_percent_growth bit              NOT NULL,
      max_size          int              NOT NULL,
      CONSTRAINT PK_baseline_TempdbFiles PRIMARY KEY (run_id, file_id),
      CONSTRAINT FK_baseline_TempdbFiles_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Per-DB: sizes, log reuse, VLF
   ========================= */
IF OBJECT_ID(N'baseline.DbSizes', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.DbSizes
  (
      run_id        uniqueidentifier NOT NULL,
      database_id   int              NOT NULL,
      db_name       sysname          NOT NULL,
      data_size_mb  decimal(18,2)    NOT NULL,
      log_size_mb   decimal(18,2)    NOT NULL,
      total_size_mb decimal(18,2)    NOT NULL,
      CONSTRAINT PK_baseline_DbSizes PRIMARY KEY (run_id, database_id),
      CONSTRAINT FK_baseline_DbSizes_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

IF OBJECT_ID(N'baseline.DbLogReuse', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.DbLogReuse
  (
      run_id               uniqueidentifier NOT NULL,
      database_id          int              NOT NULL,
      db_name              sysname          NOT NULL,
      recovery_model_desc  nvarchar(60)     NOT NULL,
      log_reuse_wait_desc  nvarchar(120)    NOT NULL,
      CONSTRAINT PK_baseline_DbLogReuse PRIMARY KEY (run_id, database_id),
      CONSTRAINT FK_baseline_DbLogReuse_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

IF OBJECT_ID(N'baseline.DbVLF', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.DbVLF
  (
      run_id        uniqueidentifier NOT NULL,
      database_id   int              NOT NULL,
      db_name       sysname          NOT NULL,
      vlf_count     int              NOT NULL,
      active_vlfs   int              NOT NULL,
      total_log_mb  decimal(18,2)    NOT NULL,
      CONSTRAINT PK_baseline_DbVLF PRIMARY KEY (run_id, database_id),
      CONSTRAINT FK_baseline_DbVLF_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Per-DB: top tables
   ========================= */
IF OBJECT_ID(N'baseline.TopTables', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.TopTables
  (
      run_id        uniqueidentifier NOT NULL,
      database_id   int              NOT NULL,
      db_name       sysname          NOT NULL,
      schema_name   sysname          NOT NULL,
      table_name    sysname          NOT NULL,
      row_count     bigint           NOT NULL,
      reserved_mb   decimal(18,2)    NOT NULL,
      data_mb       decimal(18,2)    NOT NULL,
      index_mb      decimal(18,2)    NOT NULL,
      unused_mb     decimal(18,2)    NOT NULL,
      CONSTRAINT PK_baseline_TopTables PRIMARY KEY (run_id, database_id, schema_name, table_name),
      CONSTRAINT FK_baseline_TopTables_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Per-DB: top indexes by usage (dm_db_index_usage_stats)
   ========================= */
IF OBJECT_ID(N'baseline.TopIndexes', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.TopIndexes
  (
      run_id        uniqueidentifier NOT NULL,
      database_id   int              NOT NULL,
      db_name       sysname          NOT NULL,
      schema_name   sysname          NOT NULL,
      table_name    sysname          NOT NULL,
      index_name    sysname          NULL,
      index_id      int              NOT NULL,
      user_seeks    bigint           NULL,
      user_scans    bigint           NULL,
      user_lookups  bigint           NULL,
      user_updates  bigint           NULL,
      last_user_seek   datetime      NULL,
      last_user_scan   datetime      NULL,
      last_user_lookup datetime      NULL,
      last_user_update datetime      NULL,
      CONSTRAINT PK_baseline_TopIndexes PRIMARY KEY (run_id, database_id, schema_name, table_name, index_id),
      CONSTRAINT FK_baseline_TopIndexes_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Top queries from dm_exec_query_stats (QS OFF friendly)
   ========================= */
IF OBJECT_ID(N'baseline.TopExecQueryStats', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.TopExecQueryStats
  (
      run_id              uniqueidentifier NOT NULL,
      captured_utc        datetime2(3)     NOT NULL CONSTRAINT DF_baseline_TopExecQueryStats_cutc DEFAULT SYSUTCDATETIME(),
      database_name       sysname          NULL,
      query_hash          binary(8)        NULL,
      query_plan_hash     binary(8)        NULL,
      execution_count     bigint           NOT NULL,
      total_worker_time_ms bigint          NOT NULL,
      total_elapsed_time_ms bigint         NOT NULL,
      total_logical_reads bigint           NOT NULL,
      total_logical_writes bigint          NOT NULL,
      total_physical_reads bigint          NOT NULL,
      sql_handle          varbinary(64)    NOT NULL,
      plan_handle         varbinary(64)    NOT NULL,
      statement_start_offset int           NOT NULL,
      statement_end_offset   int           NOT NULL,
      statement_text      nvarchar(max)    NULL,
      CONSTRAINT PK_baseline_TopExecQueryStats PRIMARY KEY (run_id, plan_handle, statement_start_offset, statement_end_offset),
      CONSTRAINT FK_baseline_TopExecQueryStats_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   Ring buffer + scheduler health
   ========================= */
IF OBJECT_ID(N'baseline.RingBuffer', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.RingBuffer
  (
      run_id       uniqueidentifier NOT NULL,
      record_id    int              NOT NULL,
      ring_type    nvarchar(64)     NOT NULL,
      event_time_utc datetime2(3)   NULL,
      record_xml   xml              NOT NULL,
      CONSTRAINT PK_baseline_RingBuffer PRIMARY KEY (run_id, ring_type, record_id),
      CONSTRAINT FK_baseline_RingBuffer_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

IF OBJECT_ID(N'baseline.SchedulerHealth', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.SchedulerHealth
  (
      run_id              uniqueidentifier NOT NULL,
      scheduler_id        int              NOT NULL,
      status              nvarchar(60)     NOT NULL,
      is_online           bit              NOT NULL,
      current_tasks_count int              NULL,
      runnable_tasks_count int             NULL,
      work_queue_count    bigint           NULL,
      load_factor         int              NULL,
      CONSTRAINT PK_baseline_SchedulerHealth PRIMARY KEY (run_id, scheduler_id),
      CONSTRAINT FK_baseline_SchedulerHealth_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

/* =========================
   XE spikes: deadlock + blocked process from system_health ring_buffer
   ========================= */
IF OBJECT_ID(N'baseline.XEDeadlocks', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.XEDeadlocks
  (
      run_id         uniqueidentifier NOT NULL,
      event_utc      datetime2(3)     NOT NULL,
      deadlock_xml   xml              NOT NULL,
      CONSTRAINT PK_baseline_XEDeadlocks PRIMARY KEY (run_id, event_utc),
      CONSTRAINT FK_baseline_XEDeadlocks_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

IF OBJECT_ID(N'baseline.XEBlockedProcess', N'U') IS NULL
BEGIN
  CREATE TABLE baseline.XEBlockedProcess
  (
      run_id       uniqueidentifier NOT NULL,
      event_utc    datetime2(3)     NOT NULL,
      report_xml   xml              NOT NULL,
      CONSTRAINT PK_baseline_XEBlockedProcess PRIMARY KEY (run_id, event_utc),
      CONSTRAINT FK_baseline_XEBlockedProcess_Run FOREIGN KEY (run_id) REFERENCES baseline.Run(run_id)
  );
END
GO

-- Main capture proc
USE DBA_tools;
GO

CREATE OR ALTER PROCEDURE baseline.usp_CaptureBaseline
(
      @CaptureTopQueryStore bit = 1
    , @TopN int = 25
    , @Notes nvarchar(4000) = NULL

    , @CaptureInstanceConfig bit = 1
    , @CaptureTraceFlags bit = 1
    , @CaptureTempdbLayout bit = 1
    , @CapturePerDb bit = 1
    , @CaptureTopExecQueryStats bit = 1
    , @CaptureRingBuffer bit = 1
    , @CaptureSchedulerHealth bit = 1
    , @CaptureXESpikes bit = 1

    , @RingBufferTop int = 200
    , @XETop int = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @run_id uniqueidentifier = NEWID();

    /* -------------------------
       Run header (TO MUSI BYĆ, inaczej FK poleci)
       ------------------------- */
    INSERT baseline.Run
    (
        run_id, notes,
        instance_name, sql_version, product_level, edition,
        is_clustered, num_cpu, max_server_mem_mb
    )
    SELECT
        @run_id, @Notes,
        CAST(SERVERPROPERTY('InstanceName') AS sysname),
        CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)),
        CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)),
        CAST(SERVERPROPERTY('Edition') AS nvarchar(128)),
        CAST(SERVERPROPERTY('IsClustered') AS bit),
        si.cpu_count,
        CAST(cfg.value_in_use AS int)
    FROM sys.dm_os_sys_info si
    CROSS JOIN sys.configurations cfg
    WHERE cfg.name = N'max server memory (MB)';

    /* -------------------------
       Instance config
       ------------------------- */
    IF @CaptureInstanceConfig = 1
    BEGIN
      INSERT baseline.InstanceConfig (run_id, name, value, value_in_use, minimum, maximum, is_dynamic, is_advanced, description)
      SELECT
          @run_id,
          name,
          value,
          value_in_use,
          minimum,
          maximum,
          is_dynamic,
          is_advanced,
          description
      FROM sys.configurations;
    END

    /* -------------------------
       Trace flags
       ------------------------- */
    IF @CaptureTraceFlags = 1
    BEGIN
      DECLARE @tf TABLE (TraceFlag int, Status int, Global int, Session int);
      INSERT @tf EXEC(N'DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;');

      INSERT baseline.TraceFlags (run_id, trace_flag, status, is_global, is_session)
      SELECT
        @run_id,
        TraceFlag,
        CAST(Status AS bit),
        CAST(Global AS bit),
        CAST(Session AS bit)
      FROM @tf;
    END

    /* -------------------------
       Tempdb layout
       ------------------------- */
    IF @CaptureTempdbLayout = 1
    BEGIN
      INSERT baseline.TempdbFiles (run_id, file_id, logical_name, type_desc, physical_name, size_mb, growth, is_percent_growth, max_size)
      SELECT
        @run_id,
        file_id,
        name,
        type_desc,
        physical_name,
        CAST(size AS decimal(18,2)) * 8 / 1024.0,
        growth,
        is_percent_growth,
        max_size
      FROM tempdb.sys.database_files;
    END

    /* -------------------------
       Wait stats
       ------------------------- */
    INSERT baseline.WaitStats (run_id, wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms)
    SELECT @run_id, wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT LIKE N'SLEEP%' 
      AND wait_type NOT IN
      (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
        N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
        N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
        N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
        N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
        N'PREEMPTIVE_OS_AUTHENTICATIONOPS', N'PREEMPTIVE_OS_AUTHORIZATIONOPS',
        N'PREEMPTIVE_OS_COMOPS', N'PREEMPTIVE_OS_VERIFYTRUST',
        N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK',
        N'SLEEP_SYSTEMTASK', N'SLEEP_TASK', N'SOS_WORK_DISPATCHER',
        N'SQLTRACE_BUFFER_FLUSH', N'WAITFOR', N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT'
      );

    /* -------------------------
       Perf counters (subset)
       ------------------------- */
    INSERT baseline.PerfCounters (run_id, object_name, counter_name, instance_name, cntr_value, cntr_type)
    SELECT @run_id, object_name, counter_name, instance_name, cntr_value, cntr_type
    FROM sys.dm_os_performance_counters
    WHERE
        (object_name LIKE N'%Buffer Manager%' AND counter_name IN (N'Page life expectancy', N'Buffer cache hit ratio', N'Checkpoint pages/sec'))
        OR (object_name LIKE N'%SQL Statistics%' AND counter_name IN (N'Batch Requests/sec', N'SQL Compilations/sec', N'SQL Re-Compilations/sec'))
        OR (object_name LIKE N'%General Statistics%' AND counter_name IN (N'User Connections', N'Processes blocked'))
        OR (object_name LIKE N'%Access Methods%' AND counter_name IN (N'Full Scans/sec', N'Page Splits/sec'))
        OR (object_name LIKE N'%Databases%' AND counter_name IN (N'Log Flushes/sec', N'Log Flush Wait Time', N'Log Flush Waits/sec') AND instance_name = N'_Total');

    /* -------------------------
       File IO
       ------------------------- */
    INSERT baseline.FileIO (run_id, database_id, file_id, file_logical_name, file_physical_name,
                            num_of_reads, num_of_writes, io_stall_read_ms, io_stall_write_ms, size_on_disk_bytes)
    SELECT
        @run_id,
        vfs.database_id,
        vfs.file_id,
        mf.name,
        mf.physical_name,
        vfs.num_of_reads,
        vfs.num_of_writes,
        vfs.io_stall_read_ms,
        vfs.io_stall_write_ms,
        vfs.size_on_disk_bytes
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
    JOIN sys.master_files mf
      ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id;

    /* -------------------------
       Memory clerks (top)
       ------------------------- */
 -- Memory clerks (top) - FIX: agregacja per type (unikamy duplikatów PK)
INSERT baseline.MemoryClerks (run_id, clerk_name, pages_kb, virtual_mem_kb)
SELECT TOP (50)
    @run_id,
    mc.type AS clerk_name,
    SUM(mc.pages_kb) AS pages_kb,
    SUM(mc.virtual_memory_committed_kb) AS virtual_mem_kb
FROM sys.dm_os_memory_clerks mc
GROUP BY mc.type
ORDER BY SUM(mc.pages_kb) DESC;


    /* -------------------------
       Blocking snapshot
       ------------------------- */
    ;WITH r AS
    (
        SELECT
            r.session_id,
            r.blocking_session_id,
            r.wait_type,
            r.wait_time AS wait_time_ms,
            r.wait_resource,
            r.database_id,
            s.login_name,
            s.host_name,
            s.program_name,
            r.sql_handle,
            r.statement_start_offset,
            r.statement_end_offset
        FROM sys.dm_exec_requests r
        JOIN sys.dm_exec_sessions s
          ON s.session_id = r.session_id
        WHERE r.blocking_session_id <> 0
    )
    INSERT baseline.Blocking
    (
        run_id, session_id, blocking_session_id, wait_type, wait_time_ms, wait_resource,
        database_name, login_name, host_name, program_name, statement_text
    )
    SELECT
        @run_id,
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time_ms,
        r.wait_resource,
        DB_NAME(r.database_id),
        r.login_name,
        r.host_name,
        r.program_name,
        SUBSTRING(t.text,
            (r.statement_start_offset/2)+1,
            CASE WHEN r.statement_end_offset = -1
                 THEN (DATALENGTH(t.text) - r.statement_start_offset)/2 + 1
                 ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1
            END)
    FROM r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t;

    /* -------------------------
       Per-DB: sizes, log reuse, VLF, top tables, top indexes
       ------------------------- */
    IF @CapturePerDb = 1
    BEGIN
      INSERT baseline.DbSizes (run_id, database_id, db_name, data_size_mb, log_size_mb, total_size_mb)
      SELECT
        @run_id,
        d.database_id,
        d.name,
        CAST(SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size END) * 8 / 1024.0 AS decimal(18,2)) AS data_size_mb,
        CAST(SUM(CASE WHEN mf.type_desc = 'LOG'  THEN mf.size END) * 8 / 1024.0 AS decimal(18,2)) AS log_size_mb,
        CAST(SUM(mf.size) * 8 / 1024.0 AS decimal(18,2)) AS total_size_mb
      FROM sys.databases d
      JOIN sys.master_files mf ON mf.database_id = d.database_id
      WHERE d.state_desc = N'ONLINE'
      GROUP BY d.database_id, d.name;

      INSERT baseline.DbLogReuse (run_id, database_id, db_name, recovery_model_desc, log_reuse_wait_desc)
      SELECT
        @run_id, database_id, name, recovery_model_desc, log_reuse_wait_desc
      FROM sys.databases
      WHERE state_desc = N'ONLINE';

      INSERT baseline.DbVLF (run_id, database_id, db_name, vlf_count, active_vlfs, total_log_mb)
      SELECT
        @run_id,
        d.database_id,
        d.name,
        COUNT(*) AS vlf_count,
        SUM(CASE WHEN li.vlf_active = 1 THEN 1 ELSE 0 END) AS active_vlfs,
        CAST(SUM(li.vlf_size_mb) AS decimal(18,2)) AS total_log_mb
      FROM sys.databases d
      CROSS APPLY sys.dm_db_log_info(d.database_id) li
      WHERE d.state_desc = N'ONLINE'
      GROUP BY d.database_id, d.name;

      DECLARE @db sysname, @dbid int, @sql nvarchar(max);

      DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
      SELECT name, database_id
      FROM sys.databases
      WHERE state_desc = N'ONLINE'
        AND database_id > 4;

      OPEN dbs;
      FETCH NEXT FROM dbs INTO @db, @dbid;

      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sql = N'
        USE ' + QUOTENAME(@db) + N';

        ;WITH t AS
        (
          SELECT
            s.name AS schema_name,
            o.name AS table_name,
            SUM(ps.row_count) AS row_count,
            SUM(ps.reserved_page_count) AS reserved_pages,
            SUM(ps.used_page_count) AS used_pages,
            SUM(ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) AS data_pages
          FROM sys.dm_db_partition_stats ps
          JOIN sys.objects o ON o.object_id = ps.object_id
          JOIN sys.schemas s ON s.schema_id = o.schema_id
          WHERE o.type = ''U'' AND o.is_ms_shipped = 0
          GROUP BY s.name, o.name
        )
        INSERT DBA_tools.baseline.TopTables
          (run_id, database_id, db_name, schema_name, table_name, row_count, reserved_mb, data_mb, index_mb, unused_mb)
        SELECT TOP (' + CAST(@TopN AS nvarchar(10)) + N')
          ' + QUOTENAME(CAST(@run_id AS nvarchar(36)),'''') + N',
          ' + CAST(@dbid AS nvarchar(10)) + N',
          ' + QUOTENAME(@db,'''') + N',
          schema_name,
          table_name,
          row_count,
          CAST(reserved_pages * 8 / 1024.0 AS decimal(18,2)),
          CAST(data_pages     * 8 / 1024.0 AS decimal(18,2)),
          CAST((used_pages - data_pages) * 8 / 1024.0 AS decimal(18,2)),
          CAST((reserved_pages - used_pages) * 8 / 1024.0 AS decimal(18,2))
        FROM t
        ORDER BY reserved_pages DESC;

        INSERT DBA_tools.baseline.TopIndexes
          (run_id, database_id, db_name, schema_name, table_name, index_name, index_id,
           user_seeks, user_scans, user_lookups, user_updates,
           last_user_seek, last_user_scan, last_user_lookup, last_user_update)
        SELECT TOP (' + CAST(@TopN AS nvarchar(10)) + N')
          ' + QUOTENAME(CAST(@run_id AS nvarchar(36)),'''') + N',
          ' + CAST(@dbid AS nvarchar(10)) + N',
          ' + QUOTENAME(@db,'''') + N',
          sc.name,
          ob.name,
          ix.name,
          ix.index_id,
          us.user_seeks,
          us.user_scans,
          us.user_lookups,
          us.user_updates,
          us.last_user_seek,
          us.last_user_scan,
          us.last_user_lookup,
          us.last_user_update
        FROM sys.dm_db_index_usage_stats us
        JOIN sys.indexes ix ON ix.object_id = us.object_id AND ix.index_id = us.index_id
        JOIN sys.objects ob ON ob.object_id = us.object_id
        JOIN sys.schemas sc ON sc.schema_id = ob.schema_id
        WHERE us.database_id = DB_ID()
          AND ob.type = ''U'' AND ob.is_ms_shipped = 0
        ORDER BY (ISNULL(us.user_seeks,0) + ISNULL(us.user_scans,0) + ISNULL(us.user_lookups,0)) DESC;';

        EXEC sys.sp_executesql @sql;

        FETCH NEXT FROM dbs INTO @db, @dbid;
      END

      CLOSE dbs;
      DEALLOCATE dbs;
    END

    /* -------------------------
       Top queries via dm_exec_query_stats
       ------------------------- */
    IF @CaptureTopExecQueryStats = 1
    BEGIN
      ;WITH q AS
      (
        SELECT TOP (@TopN)
          qs.sql_handle,
          qs.plan_handle,
          qs.query_hash,
          qs.query_plan_hash,
          qs.execution_count,
          qs.total_worker_time / 1000 AS total_worker_time_ms,
          qs.total_elapsed_time / 1000 AS total_elapsed_time_ms,
          qs.total_logical_reads,
          qs.total_logical_writes,
          qs.total_physical_reads,
          qs.statement_start_offset,
          qs.statement_end_offset
        FROM sys.dm_exec_query_stats qs
        ORDER BY qs.total_worker_time DESC
      )
      INSERT baseline.TopExecQueryStats
      (
        run_id, database_name, query_hash, query_plan_hash, execution_count,
        total_worker_time_ms, total_elapsed_time_ms,
        total_logical_reads, total_logical_writes, total_physical_reads,
        sql_handle, plan_handle, statement_start_offset, statement_end_offset, statement_text
      )
      SELECT
        @run_id,
        DB_NAME(t.dbid),
        q.query_hash,
        q.query_plan_hash,
        q.execution_count,
        q.total_worker_time_ms,
        q.total_elapsed_time_ms,
        q.total_logical_reads,
        q.total_logical_writes,
        q.total_physical_reads,
        q.sql_handle,
        q.plan_handle,
        q.statement_start_offset,
        q.statement_end_offset,
        SUBSTRING(t.text,
            (q.statement_start_offset/2)+1,
            CASE WHEN q.statement_end_offset = -1
                 THEN (DATALENGTH(t.text) - q.statement_start_offset)/2 + 1
                 ELSE (q.statement_end_offset - q.statement_start_offset)/2 + 1
            END)
      FROM q
      CROSS APPLY sys.dm_exec_sql_text(q.sql_handle) t;
    END

    /* -------------------------
       Ring buffer (FIX: bez rb.record_id)
       ------------------------- */
    IF @CaptureRingBuffer = 1
    BEGIN
      DECLARE @ms_ticks bigint = (SELECT ms_ticks FROM sys.dm_os_sys_info);

      ;WITH rb AS
      (
        SELECT
          rb.ring_buffer_type,
          rb.[timestamp],
          CONVERT(xml, rb.record) AS record_xml,
          DATEADD(ms, -1 * (@ms_ticks - rb.[timestamp]), SYSUTCDATETIME()) AS event_time_utc
        FROM sys.dm_os_ring_buffers rb
        WHERE rb.ring_buffer_type IN (N'RING_BUFFER_SCHEDULER_MONITOR', N'RING_BUFFER_RESOURCE_MONITOR')
      ),
      x AS
      (
        SELECT TOP (@RingBufferTop)
          ring_buffer_type,
          [timestamp],
          event_time_utc,
          record_xml,
          ROW_NUMBER() OVER (PARTITION BY ring_buffer_type ORDER BY [timestamp] DESC) AS record_id
        FROM rb
        ORDER BY [timestamp] DESC
      )
      INSERT baseline.RingBuffer (run_id, record_id, ring_type, event_time_utc, record_xml)
      SELECT
        @run_id,
        record_id,
        ring_buffer_type,
        event_time_utc,
        record_xml
      FROM x;
    END

    /* -------------------------
       Scheduler health
       ------------------------- */
    IF @CaptureSchedulerHealth = 1
    BEGIN
      INSERT baseline.SchedulerHealth
        (run_id, scheduler_id, status, is_online, current_tasks_count, runnable_tasks_count, work_queue_count, load_factor)
      SELECT
        @run_id,
        scheduler_id,
        status,
        is_online,
        current_tasks_count,
        runnable_tasks_count,
        work_queue_count,
        load_factor
      FROM sys.dm_os_schedulers
      WHERE scheduler_id < 255;
    END

    /* -------------------------
       XE spikes from system_health ring_buffer
       ------------------------- */
    IF @CaptureXESpikes = 1
    BEGIN
      ;WITH x AS
      (
        SELECT CAST(st.target_data AS xml) AS target_data
        FROM sys.dm_xe_session_targets st
        JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
        WHERE s.name = N'system_health'
          AND st.target_name = N'ring_buffer'
      ),
      ev AS
      (
        SELECT
          n.value('(event/@name)[1]', 'nvarchar(256)') AS event_name,
          n.value('(event/@timestamp)[1]', 'datetime2(3)') AS event_utc,
          n.query('.') AS event_xml
        FROM x
        CROSS APPLY x.target_data.nodes('//RingBufferTarget/event') AS q(n)
      )
      INSERT baseline.XEDeadlocks (run_id, event_utc, deadlock_xml)
      SELECT TOP (@XETop)
        @run_id,
        event_utc,
        event_xml.query('(event/data/value/deadlock)[1]')
      FROM ev
      WHERE event_name = N'xml_deadlock_report'
      ORDER BY event_utc DESC;

      ;WITH x AS
      (
        SELECT CAST(st.target_data AS xml) AS target_data
        FROM sys.dm_xe_session_targets st
        JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
        WHERE s.name = N'system_health'
          AND st.target_name = N'ring_buffer'
      ),
      ev AS
      (
        SELECT
          n.value('(event/@name)[1]', 'nvarchar(256)') AS event_name,
          n.value('(event/@timestamp)[1]', 'datetime2(3)') AS event_utc,
          n.query('.') AS event_xml
        FROM x
        CROSS APPLY x.target_data.nodes('//RingBufferTarget/event') AS q(n)
      )
      INSERT baseline.XEBlockedProcess (run_id, event_utc, report_xml)
      SELECT TOP (@XETop)
        @run_id,
        event_utc,
        event_xml
      FROM ev
      WHERE event_name = N'blocked_process_report'
      ORDER BY event_utc DESC;
    END

    /* -------------------------
       Query Store top queries (per DB) – jeśli włączone
       ------------------------- */
    /* -------------------------
   Query Store top queries (per DB) – FIX: agregacja per plan_id
   ------------------------- */
IF @CaptureTopQueryStore = 1
BEGIN
    DECLARE @sqlqs nvarchar(max) = N'';

    SELECT @sqlqs = @sqlqs + N'
    IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id = ' + CAST(d.database_id AS nvarchar(10)) + N' AND is_query_store_on = 1)
    BEGIN
        ;WITH rsagg AS
        (
            SELECT
                q.query_id,
                p.plan_id,
                qt.query_sql_text,
                AVG(CAST(rs.avg_duration AS float))/1000.0 AS avg_duration_ms,
                AVG(CAST(rs.avg_cpu_time AS float))/1000.0 AS avg_cpu_ms,
                AVG(CAST(rs.avg_logical_io_reads AS float)) AS avg_logical_io,
                AVG(CAST(rs.avg_physical_io_reads AS float)) AS avg_physical_io,
                SUM(ISNULL(rs.count_executions,0)) AS exec_count
            FROM ' + QUOTENAME(d.name) + N'.sys.query_store_runtime_stats rs
            JOIN ' + QUOTENAME(d.name) + N'.sys.query_store_plan p ON p.plan_id = rs.plan_id
            JOIN ' + QUOTENAME(d.name) + N'.sys.query_store_query q ON q.query_id = p.query_id
            JOIN ' + QUOTENAME(d.name) + N'.sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
            WHERE rs.last_execution_time >= DATEADD(minute, -30, SYSUTCDATETIME())
            GROUP BY q.query_id, p.plan_id, qt.query_sql_text
        )
        INSERT DBA_tools.baseline.TopQueryStore
        (
            run_id, database_id, query_id, plan_id,
            avg_duration_ms, avg_cpu_ms, avg_logical_io, avg_physical_io,
            exec_count, query_sql_text
        )
        SELECT TOP (' + CAST(@TopN AS nvarchar(10)) + N')
            ' + QUOTENAME(CAST(@run_id AS nvarchar(36)),'''') + N' AS run_id,
            ' + CAST(d.database_id AS nvarchar(10)) + N' AS database_id,
            query_id,
            plan_id,
            avg_duration_ms,
            avg_cpu_ms,
            avg_logical_io,
            avg_physical_io,
            exec_count,
            query_sql_text
        FROM rsagg
        ORDER BY avg_cpu_ms DESC;
    END;'
    FROM sys.databases d
    WHERE d.state_desc = N'ONLINE'
      AND d.database_id > 4;

    EXEC sys.sp_executesql @sqlqs;
END


    SELECT @run_id AS run_id, SYSUTCDATETIME() AS captured_utc;
END
GO


CREATE OR ALTER PROCEDURE baseline.usp_ReportDelta
(
    @runA uniqueidentifier,   -- "before"
    @runB uniqueidentifier,   -- "after"
    @TopN int = 30
)
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================
       0) Meta / sanity check
       ========================= */
    SELECT
        'RunA' AS run_label, r.capture_utc, r.capture_local, r.server_name, r.sql_version, r.edition, r.notes
    FROM baseline.Run r WHERE r.run_id = @runA;

    SELECT
        'RunB' AS run_label, r.capture_utc, r.capture_local, r.server_name, r.sql_version, r.edition, r.notes
    FROM baseline.Run r WHERE r.run_id = @runB;

    /* =========================
       1) Waits - Top delta
       ========================= */
    ;WITH a AS
    (
      SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
      FROM baseline.WaitStats WHERE run_id = @runA
    ),
    b AS
    (
      SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
      FROM baseline.WaitStats WHERE run_id = @runB
    )
    SELECT TOP (@TopN)
      COALESCE(b.wait_type, a.wait_type) AS wait_type,
      ISNULL(a.wait_time_ms,0) AS wait_ms_A,
      ISNULL(b.wait_time_ms,0) AS wait_ms_B,
      ISNULL(b.wait_time_ms,0)-ISNULL(a.wait_time_ms,0) AS delta_wait_ms,
      ISNULL(a.signal_wait_time_ms,0) AS signal_ms_A,
      ISNULL(b.signal_wait_time_ms,0) AS signal_ms_B,
      ISNULL(b.signal_wait_time_ms,0)-ISNULL(a.signal_wait_time_ms,0) AS delta_signal_ms,
      ISNULL(a.waiting_tasks_count,0) AS tasks_A,
      ISNULL(b.waiting_tasks_count,0) AS tasks_B,
      ISNULL(b.waiting_tasks_count,0)-ISNULL(a.waiting_tasks_count,0) AS delta_tasks
    FROM a
    FULL JOIN b ON b.wait_type = a.wait_type
    ORDER BY delta_wait_ms DESC;

    /* =========================
       2) File IO - delta stalls / ops
       ========================= */
    SELECT TOP (@TopN)
      DB_NAME(b.database_id) AS db_name,
      b.file_logical_name,
      b.file_physical_name,
      (b.io_stall_read_ms  - a.io_stall_read_ms)  AS delta_read_stall_ms,
      (b.io_stall_write_ms - a.io_stall_write_ms) AS delta_write_stall_ms,
      (b.num_of_reads      - a.num_of_reads)      AS delta_reads,
      (b.num_of_writes     - a.num_of_writes)     AS delta_writes,
      (b.size_on_disk_bytes - a.size_on_disk_bytes) AS delta_size_bytes
    FROM baseline.FileIO a
    JOIN baseline.FileIO b
      ON b.database_id = a.database_id AND b.file_id = a.file_id
    WHERE a.run_id = @runA AND b.run_id = @runB
    ORDER BY (b.io_stall_write_ms - a.io_stall_write_ms) DESC;

    /* =========================
       3) Perf counters - delta values
       (uwaga: część liczników to rate-y liczone w czasie,
       ale my tu robimy prosty diff wartości - nadal przydatne)
       ========================= */
    SELECT TOP (@TopN)
      b.object_name, b.counter_name, b.instance_name,
      a.cntr_value AS value_A,
      b.cntr_value AS value_B,
      (b.cntr_value - a.cntr_value) AS delta_value,
      b.cntr_type
    FROM baseline.PerfCounters a
    JOIN baseline.PerfCounters b
      ON b.object_name = a.object_name
     AND b.counter_name = a.counter_name
     AND b.instance_name = a.instance_name
    WHERE a.run_id = @runA AND b.run_id = @runB
    ORDER BY ABS(b.cntr_value - a.cntr_value) DESC;

    /* =========================
       4) Per-DB: sizes delta
       ========================= */
    SELECT TOP (@TopN)
      b.db_name,
      a.data_size_mb AS data_mb_A, b.data_size_mb AS data_mb_B, (b.data_size_mb - a.data_size_mb) AS delta_data_mb,
      a.log_size_mb  AS log_mb_A,  b.log_size_mb  AS log_mb_B,  (b.log_size_mb  - a.log_size_mb)  AS delta_log_mb,
      a.total_size_mb AS total_mb_A, b.total_size_mb AS total_mb_B, (b.total_size_mb - a.total_size_mb) AS delta_total_mb
    FROM baseline.DbSizes a
    JOIN baseline.DbSizes b ON b.database_id = a.database_id
    WHERE a.run_id = @runA AND b.run_id = @runB
    ORDER BY (b.total_size_mb - a.total_size_mb) DESC;

    /* =========================
       5) Per-DB: VLF delta
       ========================= */
    SELECT TOP (@TopN)
      b.db_name,
      a.vlf_count AS vlf_A, b.vlf_count AS vlf_B, (b.vlf_count - a.vlf_count) AS delta_vlf,
      a.active_vlfs AS active_vlfs_A, b.active_vlfs AS active_vlfs_B, (b.active_vlfs - a.active_vlfs) AS delta_active_vlfs,
      a.total_log_mb AS log_mb_A, b.total_log_mb AS log_mb_B, (b.total_log_mb - a.total_log_mb) AS delta_log_mb
    FROM baseline.DbVLF a
    JOIN baseline.DbVLF b ON b.database_id = a.database_id
    WHERE a.run_id = @runA AND b.run_id = @runB
    ORDER BY (b.vlf_count - a.vlf_count) DESC;

    /* =========================
       6) Per-DB: log reuse wait changes
       ========================= */
    SELECT
      b.db_name,
      a.recovery_model_desc AS recovery_A,
      b.recovery_model_desc AS recovery_B,
      a.log_reuse_wait_desc AS log_reuse_A,
      b.log_reuse_wait_desc AS log_reuse_B,
      CASE WHEN a.log_reuse_wait_desc <> b.log_reuse_wait_desc THEN 1 ELSE 0 END AS changed
    FROM baseline.DbLogReuse a
    JOIN baseline.DbLogReuse b ON b.database_id = a.database_id
    WHERE a.run_id = @runA AND b.run_id = @runB
      AND (a.log_reuse_wait_desc <> b.log_reuse_wait_desc OR b.log_reuse_wait_desc <> N'NOTHING')
    ORDER BY changed DESC, b.db_name;

    /* =========================
       7) Scheduler health delta
       ========================= */
    SELECT TOP (@TopN)
      b.scheduler_id,
      b.status,
      b.is_online,
      a.runnable_tasks_count AS runnable_A,
      b.runnable_tasks_count AS runnable_B,
      (b.runnable_tasks_count - a.runnable_tasks_count) AS delta_runnable,
      a.work_queue_count AS workq_A,
      b.work_queue_count AS workq_B,
      (b.work_queue_count - a.work_queue_count) AS delta_workq,
      a.load_factor AS load_A,
      b.load_factor AS load_B,
      (b.load_factor - a.load_factor) AS delta_load
    FROM baseline.SchedulerHealth a
    JOIN baseline.SchedulerHealth b ON b.scheduler_id = a.scheduler_id
    WHERE a.run_id = @runA AND b.run_id = @runB
    ORDER BY (b.runnable_tasks_count - a.runnable_tasks_count) DESC;

    /* =========================
       8) Ring buffer quick summary (counts + latest)
       ========================= */
    SELECT
      'RunA' AS run_label, ring_type, COUNT(*) AS records, MAX(event_time_utc) AS latest_event_utc
    FROM baseline.RingBuffer
    WHERE run_id = @runA
    GROUP BY ring_type;

    SELECT
      'RunB' AS run_label, ring_type, COUNT(*) AS records, MAX(event_time_utc) AS latest_event_utc
    FROM baseline.RingBuffer
    WHERE run_id = @runB
    GROUP BY ring_type;

    /* =========================
       9) XE spikes summary
       ========================= */
    SELECT
      'RunA' AS run_label,
      (SELECT COUNT(*) FROM baseline.XEDeadlocks WHERE run_id = @runA) AS deadlocks,
      (SELECT COUNT(*) FROM baseline.XEBlockedProcess WHERE run_id = @runA) AS blocked_reports;

    SELECT
      'RunB' AS run_label,
      (SELECT COUNT(*) FROM baseline.XEDeadlocks WHERE run_id = @runB) AS deadlocks,
      (SELECT COUNT(*) FROM baseline.XEBlockedProcess WHERE run_id = @runB) AS blocked_reports;

    -- Latest XE events (RunB)
    SELECT TOP (@TopN)
      event_utc,
      deadlock_xml
    FROM baseline.XEDeadlocks
    WHERE run_id = @runB
    ORDER BY event_utc DESC;

    SELECT TOP (@TopN)
      event_utc,
      report_xml
    FROM baseline.XEBlockedProcess
    WHERE run_id = @runB
    ORDER BY event_utc DESC;

    /* =========================
       10) Top queries (dm_exec_query_stats capture)
       - Nowe w B (nie było w A) lub znacząco większy CPU
       ========================= */
    ;WITH a AS
    (
      SELECT
        query_hash,
        query_plan_hash,
        SUM(total_worker_time_ms) AS cpu_ms_A,
        SUM(total_elapsed_time_ms) AS elapsed_ms_A,
        SUM(total_logical_reads) AS reads_A,
        SUM(execution_count) AS exec_A,
        MAX(statement_text) AS sample_text_A
      FROM baseline.TopExecQueryStats
      WHERE run_id = @runA
      GROUP BY query_hash, query_plan_hash
    ),
    b AS
    (
      SELECT
        query_hash,
        query_plan_hash,
        SUM(total_worker_time_ms) AS cpu_ms_B,
        SUM(total_elapsed_time_ms) AS elapsed_ms_B,
        SUM(total_logical_reads) AS reads_B,
        SUM(execution_count) AS exec_B,
        MAX(statement_text) AS sample_text_B
      FROM baseline.TopExecQueryStats
      WHERE run_id = @runB
      GROUP BY query_hash, query_plan_hash
    )
    SELECT TOP (@TopN)
      COALESCE(b.query_hash, a.query_hash) AS query_hash,
      COALESCE(b.query_plan_hash, a.query_plan_hash) AS query_plan_hash,
      ISNULL(a.cpu_ms_A,0) AS cpu_ms_A,
      ISNULL(b.cpu_ms_B,0) AS cpu_ms_B,
      ISNULL(b.cpu_ms_B,0)-ISNULL(a.cpu_ms_A,0) AS delta_cpu_ms,
      ISNULL(a.elapsed_ms_A,0) AS elapsed_ms_A,
      ISNULL(b.elapsed_ms_B,0) AS elapsed_ms_B,
      ISNULL(b.elapsed_ms_B,0)-ISNULL(a.elapsed_ms_A,0) AS delta_elapsed_ms,
      ISNULL(a.reads_A,0) AS reads_A,
      ISNULL(b.reads_B,0) AS reads_B,
      ISNULL(b.reads_B,0)-ISNULL(a.reads_A,0) AS delta_reads,
      ISNULL(a.exec_A,0) AS exec_A,
      ISNULL(b.exec_B,0) AS exec_B,
      ISNULL(b.exec_B,0)-ISNULL(a.exec_A,0) AS delta_exec,
      COALESCE(b.sample_text_B, a.sample_text_A) AS statement_text
    FROM a
    FULL JOIN b
      ON b.query_hash = a.query_hash
     AND b.query_plan_hash = a.query_plan_hash
    ORDER BY delta_cpu_ms DESC;

    /* =========================
       11) “Nowe top” w RunB (nieobecne w RunA)
       ========================= */
    ;WITH a AS
    (
      SELECT DISTINCT query_hash, query_plan_hash
      FROM baseline.TopExecQueryStats
      WHERE run_id = @runA
    ),
    b AS
    (
      SELECT
        query_hash, query_plan_hash,
        SUM(total_worker_time_ms) AS cpu_ms_B,
        MAX(statement_text) AS statement_text
      FROM baseline.TopExecQueryStats
      WHERE run_id = @runB
      GROUP BY query_hash, query_plan_hash
    )
    SELECT TOP (@TopN)
      b.query_hash, b.query_plan_hash, b.cpu_ms_B, b.statement_text
    FROM b
    LEFT JOIN a ON a.query_hash = b.query_hash AND a.query_plan_hash = b.query_plan_hash
    WHERE a.query_hash IS NULL
    ORDER BY b.cpu_ms_B DESC;

END
GO
