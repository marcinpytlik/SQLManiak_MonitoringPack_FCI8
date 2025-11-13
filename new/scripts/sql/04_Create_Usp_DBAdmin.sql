IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    RAISERROR('Brak bazy DBAdmin – uruchom najpierw 00_Create_DBAdmin.sql',16,1);
    RETURN;
END
GO

USE [DBAdmin];
GO

------------------------------------------------------------
-- 1) Instance baseline
------------------------------------------------------------
IF OBJECT_ID('dbadmin.usp_CaptureInstanceBaseline','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureInstanceBaseline;
GO
CREATE PROCEDURE dbadmin.usp_CaptureInstanceBaseline
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbadmin.InstanceBaseline
    (
        CollectedAt, ServerName, ProductVersion, ProductLevel, Edition, EngineEdition,
        NodeName, IsClustered, MachineName, DefaultDataPath, DefaultLogPath
    )
    SELECT
        SYSUTCDATETIME(),
        @@SERVERNAME,
        CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)),
        CAST(SERVERPROPERTY('ProductLevel')   AS nvarchar(20)),
        CAST(SERVERPROPERTY('Edition')        AS nvarchar(128)),
        CAST(SERVERPROPERTY('EngineEdition')  AS int),
        CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)),
        CAST(SERVERPROPERTY('IsClustered')    AS bit),
        CAST(SERVERPROPERTY('MachineName')    AS nvarchar(128)),
        CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260)),
        CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(260));
END
GO

------------------------------------------------------------
-- 2) Database baseline
------------------------------------------------------------
IF OBJECT_ID('dbadmin.usp_CaptureDatabaseBaseline','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureDatabaseBaseline;
GO
CREATE PROCEDURE dbadmin.usp_CaptureDatabaseBaseline
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbadmin.DatabaseBaseline
    (
        CollectedAt, DatabaseName, DatabaseId, CompatibilityLevel, StateDesc,
        RecoveryModelDesc, UserAccessDesc, DbSizeMB, LogSizeMB, LogUsedMB
    )
    SELECT
        SYSUTCDATETIME(),
        d.name,
        d.database_id,
        d.compatibility_level,
        d.state_desc,
        d.recovery_model_desc,
        d.user_access_desc,
        s.db_size_mb,
        s.log_size_mb,
        s.log_used_mb
    FROM sys.databases d
    CROSS APPLY (
        SELECT
          db_size_mb = SUM(CASE WHEN mf.type_desc='ROWS' THEN mf.size END)*8/1024.0,
          log_size_mb = SUM(CASE WHEN mf.type_desc='LOG'  THEN mf.size END)*8/1024.0,
          log_used_mb = SUM(CASE WHEN mf.type_desc='LOG'  THEN (mf.size*FILEPROPERTY(mf.name,'SpaceUsed')/mf.size) END)*8/1024.0
        FROM sys.master_files mf WHERE mf.database_id = d.database_id
    ) s
    WHERE d.database_id > 1;
END
GO

------------------------------------------------------------
-- 3) Health FCI
------------------------------------------------------------
IF OBJECT_ID('dbadmin.usp_CaptureHealthFCI','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureHealthFCI;
GO
CREATE PROCEDURE dbadmin.usp_CaptureHealthFCI
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbadmin.HealthFCI (CollectedAt, IsClustered, ActiveNode, MachineName, ServerName)
    SELECT
        SYSUTCDATETIME(),
        CAST(SERVERPROPERTY('IsClustered') AS bit),
        CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)),
        CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)),
        CAST(SERVERPROPERTY('ServerName') AS nvarchar(128));
END
GO

------------------------------------------------------------
-- 4) Health HADR
------------------------------------------------------------
IF OBJECT_ID('dbadmin.usp_CaptureHealthHADR','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureHealthHADR;
GO
CREATE PROCEDURE dbadmin.usp_CaptureHealthHADR
AS
BEGIN
    SET NOCOUNT ON;

    IF SERVERPROPERTY('IsHadrEnabled') = 1
    BEGIN
        INSERT INTO dbadmin.HealthHADR
        (
            CollectedAt, AGName, RoleDesc, SyncHealthDesc, ReplicaServerName
        )
        SELECT
            SYSUTCDATETIME(),
            ag.name,
            ar.role_desc,
            ars.synchronization_health_desc,
            ar.replica_server_name
        FROM sys.availability_groups ag
        JOIN sys.availability_replicas ar
            ON ag.group_id = ar.group_id
        JOIN sys.dm_hadr_availability_replica_states ars
            ON ar.replica_id = ars.replica_id;
    END
END
GO

------------------------------------------------------------
-- 5) Wrappers: wszystko naraz
------------------------------------------------------------
IF OBJECT_ID('dbadmin.usp_CaptureBaselineAll','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureBaselineAll;
GO
CREATE PROCEDURE dbadmin.usp_CaptureBaselineAll
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbadmin.usp_CaptureInstanceBaseline;
    EXEC dbadmin.usp_CaptureDatabaseBaseline;
END
GO

IF OBJECT_ID('dbadmin.usp_CaptureHealthAll','P') IS NOT NULL
    DROP PROCEDURE dbadmin.usp_CaptureHealthAll;
GO
CREATE PROCEDURE dbadmin.usp_CaptureHealthAll
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbadmin.usp_CaptureHealthFCI;
    
END
GO
