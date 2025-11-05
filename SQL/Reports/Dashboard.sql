USE DBAAdmin; 
IF OBJECT_ID('dbo.v_Dashboard_HealthSummary') IS NOT NULL DROP VIEW dbo.v_Dashboard_HealthSummary;
GO
CREATE VIEW dbo.v_Dashboard_HealthSummary AS
SELECT
 (SELECT COUNT(*) FROM dbo.BackupStatus WHERE IsStale=1 AND CollectedAt>=DATEADD(HOUR,-2,SYSUTCDATETIME())) AS StaleBackups,
 (SELECT COUNT(*) FROM dbo.SqlJobLastRuns WHERE LastRunStatus='Failed' AND CollectedAt>=DATEADD(HOUR,-2,SYSUTCDATETIME())) AS FailedJobs2h,
 (SELECT COUNT(*) FROM dbo.ClusterEvents WHERE EventTime>=DATEADD(HOUR,-24,SYSUTCDATETIME())) AS ClusterEvents24h,
 (SELECT COUNT(*) FROM dbo.AuditEvents WHERE EventTime>=DATEADD(HOUR,-24,SYSUTCDATETIME())) AS AuditEvents24h;
GO
IF OBJECT_ID('dbo.v_Dashboard_BackupMatrix') IS NOT NULL DROP VIEW dbo.v_Dashboard_BackupMatrix;
GO
CREATE VIEW dbo.v_Dashboard_BackupMatrix AS
SELECT InstanceName,DatabaseName,LastFull,LastDiff,LastLog,RecoveryModel,IsStale,CollectedAt FROM dbo.BackupStatus;
GO
IF OBJECT_ID('dbo.v_Dashboard_TopDbGrowth_30d') IS NOT NULL DROP VIEW dbo.v_Dashboard_TopDbGrowth_30d;
GO
CREATE VIEW dbo.v_Dashboard_TopDbGrowth_30d AS
WITH s AS (
 SELECT InstanceName,DatabaseName,CollectedOn,DataSizeMB,
 LAG(DataSizeMB) OVER (PARTITION BY InstanceName,DatabaseName ORDER BY CollectedOn) AS PrevMB
 FROM dbo.DbSizeDaily WHERE CollectedOn>=DATEADD(DAY,-30,CAST(SYSUTCDATETIME() AS date))
)
SELECT InstanceName,DatabaseName,SUM(CASE WHEN PrevMB IS NULL THEN 0 ELSE DataSizeMB-PrevMB END) AS GrowthMB_30d
FROM s GROUP BY InstanceName,DatabaseName ORDER BY GrowthMB_30d DESC;
GO
IF OBJECT_ID('dbo.usp_Dashboard_Snapshot') IS NOT NULL DROP PROCEDURE dbo.usp_Dashboard_Snapshot;
GO
CREATE PROCEDURE dbo.usp_Dashboard_Snapshot AS
BEGIN SET NOCOUNT ON;
 SELECT * FROM dbo.v_Dashboard_HealthSummary;
 SELECT TOP 50 * FROM dbo.v_Dashboard_BackupMatrix ORDER BY CollectedAt DESC;
 SELECT TOP 20 * FROM dbo.v_Dashboard_TopDbGrowth_30d;
 SELECT TOP 50 * FROM dbo.SqlJobLastRuns ORDER BY CollectedAt DESC;
END
GO
