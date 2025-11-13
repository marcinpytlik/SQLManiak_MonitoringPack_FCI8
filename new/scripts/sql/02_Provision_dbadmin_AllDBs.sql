/* 02_Provision_dbadmin_AllDBs.sql  (v2)
   - Tworzy usera [dbadmin] i schemat [dbadmin] we WSZYSTKICH bazach użytkownika
   - DODATKOWO: w bazie [DBAdmin] tworzy zestaw tabel administracyjnych (schemat dbadmin)
*/
SET NOCOUNT ON;

------------------------------------------------------------
-- 1) Użytkownik + schemat we wszystkich bazach użytkownika
------------------------------------------------------------
DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE database_id > 4      -- pomiń systemowe
      AND state = 0;           -- ONLINE

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';
    -- Użytkownik powiązany z loginem dbadmin
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''dbadmin'')
        CREATE USER [dbadmin] FOR LOGIN [dbadmin];

    -- Schemat dbadmin (na potrzeby obiektów monitoringu, np. widoków, procedur)
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N''dbadmin'')
        EXEC(''CREATE SCHEMA [dbadmin]'');

    -- Uprawnienia minimalne do diagnostyki
    GRANT CONNECT TO [dbadmin];
    GRANT VIEW DATABASE STATE TO [dbadmin];
    ';
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs; DEALLOCATE dbs;

----------------------------------------------
-- 2) Baza DBAdmin: user + schemat + TABEL(E)
----------------------------------------------
IF DB_ID(N'DBAdmin') IS NOT NULL
BEGIN
    USE [DBAdmin];

    -- Użytkownik i schemat (jeśli brak)
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'dbadmin')
        CREATE USER [dbadmin] FOR LOGIN [dbadmin];
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dbadmin')
        EXEC('CREATE SCHEMA [dbadmin]');

    ----------------------------------------------------
    -- Tabele administracyjne (mogą już istnieć - IF)
    ----------------------------------------------------

    -- 2.1) Instance baseline
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.InstanceBaseline') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.InstanceBaseline (
            Id               bigint IDENTITY(1,1) CONSTRAINT PK_InstanceBaseline PRIMARY KEY CLUSTERED,
            CollectedAt      datetime2(3) NOT NULL CONSTRAINT DF_InstanceBaseline_CollectedAt DEFAULT (sysdatetime()),
            ServerName       nvarchar(128) NULL,
            ProductVersion   nvarchar(50)  NULL,
            ProductLevel     nvarchar(20)  NULL,
            Edition          nvarchar(128) NULL,
            EngineEdition    int           NULL,
            NodeName         nvarchar(128) NULL,
            IsClustered      bit           NULL,
            MachineName      nvarchar(128) NULL,
            DefaultDataPath  nvarchar(260) NULL,
            DefaultLogPath   nvarchar(260) NULL
        );
    END

    -- 2.2) Database baseline
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.DatabaseBaseline') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.DatabaseBaseline (
            Id                   bigint IDENTITY(1,1) CONSTRAINT PK_DatabaseBaseline PRIMARY KEY CLUSTERED,
            CollectedAt          datetime2(3) NOT NULL CONSTRAINT DF_DatabaseBaseline_CollectedAt DEFAULT (sysdatetime()),
            DatabaseName         sysname       NOT NULL,
            DatabaseId           int           NOT NULL,
            CompatibilityLevel   tinyint       NULL,
            StateDesc            nvarchar(60)  NULL,
            RecoveryModelDesc    nvarchar(60)  NULL,
            UserAccessDesc       nvarchar(60)  NULL,
            DbSizeMB             decimal(18,2) NULL,
            LogSizeMB            decimal(18,2) NULL,
            LogUsedMB            decimal(18,2) NULL
        );
        CREATE INDEX IX_DatabaseBaseline_When_Db ON dbadmin.DatabaseBaseline(CollectedAt, DatabaseName);
    END

    -- 2.3) Health – FCI
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.HealthFCI') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.HealthFCI (
            Id          bigint IDENTITY(1,1) PRIMARY KEY CLUSTERED,
            CollectedAt datetime2(3) NOT NULL CONSTRAINT DF_HealthFCI_CollectedAt DEFAULT (sysdatetime()),
            IsClustered bit          NULL,
            ActiveNode  nvarchar(128) NULL,
            MachineName nvarchar(128) NULL,
            ServerName  nvarchar(128) NULL
        );
    END

    -- 2.4) Health – HADR
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.HealthHADR') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.HealthHADR (
            Id                 bigint IDENTITY(1,1) PRIMARY KEY CLUSTERED,
            CollectedAt        datetime2(3) NOT NULL CONSTRAINT DF_HealthHADR_CollectedAt DEFAULT (sysdatetime()),
            AGName             nvarchar(128) NULL,
            RoleDesc           nvarchar(60)  NULL,
            SyncHealthDesc     nvarchar(60)  NULL,
            ReplicaServerName  nvarchar(128) NULL
        );
        CREATE INDEX IX_HealthHADR_When_AG ON dbadmin.HealthHADR(CollectedAt, AGName);
    END

    -- 2.5) Errorlog (opcjonalny zrzut)
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.AuditErrorlog') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.AuditErrorlog (
            Id          bigint IDENTITY(1,1) PRIMARY KEY CLUSTERED,
            LogDate     datetime2(3) NULL,
            LogSource   nvarchar(64) NULL,
            Message     nvarchar(max) NULL
        );
        CREATE INDEX IX_AuditErrorlog_LogDate ON dbadmin.AuditErrorlog(LogDate DESC);
    END

    -- 2.6) Pliki XE (rejestr metadanych)
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbadmin.XEFiles') AND type = 'U')
    BEGIN
        CREATE TABLE dbadmin.XEFiles (
            Id           bigint IDENTITY(1,1) PRIMARY KEY CLUSTERED,
            SessionName  nvarchar(128) NOT NULL,
            FilePath     nvarchar(4000) NOT NULL,
            CollectedAt  datetime2(3) NOT NULL CONSTRAINT DF_XEFiles_CollectedAt DEFAULT (sysdatetime())
        );
    END

    -- Granty na schemat/tabele dla dbadmin (SELECT/INSERT)
    GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbadmin TO [dbadmin];
END
USE DBAdmin;
GO

------------------------------------------------------------
-- 1) XE – uproszczone logowanie zdarzeń
------------------------------------------------------------
IF OBJECT_ID('dbadmin.XEEvents','U') IS NULL
BEGIN
    CREATE TABLE dbadmin.XEEvents (
        Id              bigint IDENTITY(1,1) PRIMARY KEY,
        CollectedAt     datetime2(3) NOT NULL CONSTRAINT DF_XEEvents_CollectedAt DEFAULT (sysutcdatetime()),
        ServerName      sysname      NOT NULL,
        SessionName     nvarchar(128) NOT NULL,
        EventName       nvarchar(128) NOT NULL,
        EventTime       datetime2(3)  NOT NULL,
        Severity        int           NULL,      -- dla error_reported
        ErrorNumber     int           NULL,
        DurationMs      bigint        NULL,
        CpuTimeMs       bigint        NULL,
        LogicalReads    bigint        NULL,
        Username        nvarchar(256) NULL,
        ClientHost      nvarchar(256) NULL,
        AppName         nvarchar(256) NULL,
        DatabaseName    nvarchar(256) NULL,
        SqlText         nvarchar(max) NULL
    );
    CREATE INDEX IX_XEEvents_When_Server ON dbadmin.XEEvents(EventTime DESC, ServerName);
END
GO

------------------------------------------------------------
-- 2) Joby SQL Agenta – definicje
------------------------------------------------------------
IF OBJECT_ID('dbadmin.AgentJobs','U') IS NULL
BEGIN
    CREATE TABLE dbadmin.AgentJobs (
        Id              bigint IDENTITY(1,1) PRIMARY KEY,
        CollectedAt     datetime2(3) NOT NULL CONSTRAINT DF_AgentJobs_CollectedAt DEFAULT (sysutcdatetime()),
        ServerName      sysname      NOT NULL,
        JobId           uniqueidentifier NOT NULL,
        JobName         sysname      NOT NULL,
        Enabled         bit          NOT NULL,
        Owner           sysname      NULL,
        Category        sysname      NULL,
        Description     nvarchar(512) NULL
    );
    CREATE INDEX IX_AgentJobs_Server ON dbadmin.AgentJobs(ServerName, JobName);
END
GO

------------------------------------------------------------
-- 3) Joby SQL Agenta – ostatnie wykonania
------------------------------------------------------------
IF OBJECT_ID('dbadmin.AgentJobHistory','U') IS NULL
BEGIN
    CREATE TABLE dbadmin.AgentJobHistory (
        Id              bigint IDENTITY(1,1) PRIMARY KEY,
        CollectedAt     datetime2(3) NOT NULL CONSTRAINT DF_AgentJobHistory_CollectedAt DEFAULT (sysutcdatetime()),
        ServerName      sysname      NOT NULL,
        JobId           uniqueidentifier NOT NULL,
        JobName         sysname      NOT NULL,
        RunDateTime     datetime2(0) NOT NULL,
        RunDurationSec  int          NULL,
        RunStatus       int          NOT NULL,     -- 0=Failed,1=Succeeded,2=Retry,3=Cancelled
        Message         nvarchar(max) NULL
    );
    CREATE INDEX IX_AgentJobHistory_Server_When ON dbadmin.AgentJobHistory(ServerName, RunDateTime DESC);
END
GO

------------------------------------------------------------
-- 4) Maintenance – snapshot indeksów
------------------------------------------------------------
IF OBJECT_ID('dbadmin.IndexStatsSnapshot','U') IS NULL
BEGIN
    CREATE TABLE dbadmin.IndexStatsSnapshot (
        Id                      bigint IDENTITY(1,1) PRIMARY KEY,
        CollectedAt             datetime2(3) NOT NULL CONSTRAINT DF_IndexStatsSnapshot_CollectedAt DEFAULT (sysutcdatetime()),
        ServerName              sysname      NOT NULL,
        DatabaseName            sysname      NOT NULL,
        ObjectName              sysname      NOT NULL,
        IndexName               sysname      NOT NULL,
        AvgFragmentationPercent float        NULL,
        PageCount               bigint       NULL
    );
    CREATE INDEX IX_IndexStatsSnapshot_Server_Db ON dbadmin.IndexStatsSnapshot(ServerName, DatabaseName, CollectedAt DESC);
END

ELSE
BEGIN
    RAISERROR('Baza [DBAdmin] nie istnieje – uruchom najpierw 00_Create_DBAdmin.sql', 16, 1);
    RETURN;
END
GO