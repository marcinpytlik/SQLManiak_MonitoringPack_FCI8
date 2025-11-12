/* Get-DatabaseBaseline.sql – bazy */
SELECT
    d.name,
    d.database_id,
    d.compatibility_level,
    d.state_desc,
    d.recovery_model_desc,
    d.user_access_desc,
    s.db_size_mb,
    s.log_size_mb,
    s.log_used_mb,
    GETDATE() as collected_at
FROM sys.databases d
CROSS APPLY (
    SELECT
      db_size_mb = SUM(CASE WHEN type_desc='ROWS' THEN size END)*8/1024.0,
      log_size_mb = SUM(CASE WHEN type_desc='LOG' THEN size END)*8/1024.0,
      log_used_mb = SUM(CASE WHEN type_desc='LOG' THEN size*FILEPROPERTY(name,'SpaceUsed')/size END)*8/1024.0
    FROM sys.master_files mf WHERE mf.database_id = d.database_id
) s
WHERE d.database_id > 1
ORDER BY d.name;
GO