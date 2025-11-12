/* Get-InstanceBaseline.sql – instancja */
SELECT
    @@SERVERNAME           AS server_name,
    SERVERPROPERTY('ProductVersion') AS product_version,
    SERVERPROPERTY('ProductLevel')   AS product_level,
    SERVERPROPERTY('Edition')        AS edition,
    SERVERPROPERTY('EngineEdition')  AS engine_edition,
    SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS node_name,
    SERVERPROPERTY('IsClustered')    AS is_clustered,
    SERVERPROPERTY('MachineName')    AS machine_name,
    SERVERPROPERTY('InstanceDefaultDataPath') AS default_data_path,
    SERVERPROPERTY('InstanceDefaultLogPath')  AS default_log_path,
    GETDATE() AS collected_at;
GO
SELECT name, value_in_use, value, description FROM sys.configurations ORDER BY name;
GO
SELECT * FROM sys.dm_db_persisted_sku_features;
GO
SELECT TOP (50) clerk_name = type, pages_kb = pages_kb FROM sys.dm_os_memory_clerks ORDER BY pages_kb DESC;
GO