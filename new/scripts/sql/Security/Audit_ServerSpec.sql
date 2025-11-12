/* Audit_ServerSpec.sql */
SELECT name, CAST(value_in_use AS sql_variant) AS value_in_use, description
FROM sys.configurations
WHERE name IN ('remote admin connections','xp_cmdshell','clr enabled','Ad Hoc Distributed Queries','optimize for ad hoc workloads','cost threshold for parallelism','max degree of parallelism')
ORDER BY name;
GO
SELECT * FROM sys.server_principals WHERE type IN ('S','U','G') ORDER BY name;
GO