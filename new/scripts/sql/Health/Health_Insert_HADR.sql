/* Health_Insert_HADR.sql – INSERT do DBAdmin.dbadmin.HealthHADR (jeśli HADR włączony) */
SET NOCOUNT ON;
IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    RAISERROR('Brak bazy DBAdmin – uruchom 00_Create_DBAdmin.sql',16,1);
    RETURN;
END

IF SERVERPROPERTY('IsHadrEnabled') <> 1
    RETURN;

USE [DBAdmin];

INSERT INTO dbadmin.HealthHADR (CollectedAt, AGName, RoleDesc, SyncHealthDesc, ReplicaServerName)
SELECT
    SYSUTCDATETIME(),
    ag.name,
    ar.role_desc,
    ars.synchronization_health_desc,
    ar.replica_server_name
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;