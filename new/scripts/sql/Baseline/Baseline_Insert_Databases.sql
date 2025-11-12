/* Baseline_Insert_Databases.sql – INSERT do DBAdmin.dbadmin.DatabaseBaseline */
SET NOCOUNT ON;
IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    RAISERROR('Brak bazy DBAdmin – uruchom 00_Create_DBAdmin.sql',16,1);
    RETURN;
END

USE [DBAdmin];

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