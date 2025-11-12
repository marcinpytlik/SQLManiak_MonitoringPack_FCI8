/* Health_Insert_FCI.sql – INSERT do DBAdmin.dbadmin.HealthFCI */
SET NOCOUNT ON;
IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    RAISERROR('Brak bazy DBAdmin – uruchom 00_Create_DBAdmin.sql',16,1);
    RETURN;
END

USE [DBAdmin];

INSERT INTO dbadmin.HealthFCI (CollectedAt, IsClustered, ActiveNode, MachineName, ServerName)
SELECT
    SYSUTCDATETIME(),
    CAST(SERVERPROPERTY('IsClustered') AS bit),
    CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)),
    CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)),
    CAST(SERVERPROPERTY('ServerName') AS nvarchar(128));