/* Baseline_Insert_Instance.sql – INSERT do DBAdmin.dbadmin.InstanceBaseline */
SET NOCOUNT ON;
IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    RAISERROR('Brak bazy DBAdmin – uruchom 00_Create_DBAdmin.sql',16,1);
    RETURN;
END

USE [DBAdmin];

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