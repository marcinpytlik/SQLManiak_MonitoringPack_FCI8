-- CHECKDB (every 60 days) + Weekly msdb maintenance
USE msdb;
GO
-- MAINT: DBCC CHECKDB (full)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'MAINT: DBCC CHECKDB')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'MAINT: DBCC CHECKDB',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Every60Days_0100')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Every60Days_0100',@freq_type=4,@freq_interval=60,@active_start_time=010000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'MAINT: DBCC CHECKDB' AND sc.name=N'Every60Days_0100')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'MAINT: DBCC CHECKDB',@schedule_name=N'Every60Days_0100';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: DBCC CHECKDB' AND s.step_name=N'Run CHECKDB')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: DBCC CHECKDB',@step_name=N'Run CHECKDB',@subsystem=N'TSQL',@database_name=N'master',@command=N'
DECLARE @db sysname,@sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM sys.databases WHERE database_id>4 AND state=0;
OPEN c; FETCH NEXT FROM c INTO @db;
WHILE @@FETCH_STATUS=0
BEGIN SET @sql=N''DBCC CHECKDB(''+QUOTENAME(@db)+N'') WITH NO_INFOMSGS, ALL_ERRORMSGS;''; BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH RAISERROR (''CHECKDB failed for %s: %s'',16,1,@db,ERROR_MESSAGE()); END CATCH;
FETCH NEXT FROM c INTO @db; END
CLOSE c; DEALLOCATE c;';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'MAINT: DBCC CHECKDB';
-- MAINT: Weekly MSDB Maintenance
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'MAINT: Weekly MSDB Maintenance')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'MAINT: Weekly MSDB Maintenance',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Weekly_Sun_0200')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Weekly_Sun_0200',@freq_type=8,@freq_interval=1,@active_start_time=020000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'MAINT: Weekly MSDB Maintenance' AND sc.name=N'Weekly_Sun_0200')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'MAINT: Weekly MSDB Maintenance',@schedule_name=N'Weekly_Sun_0200';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: Weekly MSDB Maintenance' AND s.step_name=N'Index Maintenance')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: Weekly MSDB Maintenance',@step_name=N'Index Maintenance',@subsystem=N'TSQL',@database_name=N'msdb',@command=N'
;WITH fr AS (
  SELECT object_id,index_id,avg_fragmentation_in_percent
  FROM sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,''SAMPLED'') WHERE index_id>0
)
SELECT 1;
DECLARE @obj sysname,@idx sysname,@frag float,@cmd nvarchar(4000);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT o.name,i.name,fr.avg_fragmentation_in_percent FROM fr
JOIN sys.indexes i ON i.object_id=fr.object_id AND i.index_id=fr.index_id
JOIN sys.objects o ON o.object_id=fr.object_id WHERE o.type=''U'';
OPEN cur; FETCH NEXT FROM cur INTO @obj,@idx,@frag;
WHILE @@FETCH_STATUS=0
BEGIN
  IF @frag BETWEEN 5 AND 30 SET @cmd=N''ALTER INDEX ''+QUOTENAME(@idx)+N'' ON ''+QUOTENAME(@obj)+N'' REORGANIZE;'';
  ELSE IF @frag>30 SET @cmd=N''ALTER INDEX ''+QUOTENAME(@idx)+N'' ON ''+QUOTENAME(@obj)+N'' REBUILD WITH (ONLINE=ON);''; ELSE SET @cmd=NULL;
  IF @cmd IS NOT NULL EXEC(@cmd);
  FETCH NEXT FROM cur INTO @obj,@idx,@frag;
END
CLOSE cur; DEALLOCATE cur;';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: Weekly MSDB Maintenance' AND s.step_name=N'Update Stats')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: Weekly MSDB Maintenance',@step_name=N'Update Stats',@subsystem=N'TSQL',@database_name=N'msdb',@command=N'
DECLARE @sql nvarchar(max)=N'''';
SELECT @sql=@sql+N''UPDATE STATISTICS ''+QUOTENAME(OBJECT_SCHEMA_NAME(object_id))+N''.''+QUOTENAME(OBJECT_NAME(object_id))+N'' WITH FULLSCAN;''+CHAR(10)
FROM sys.objects WHERE type=''U''; EXEC sp_executesql @sql;';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: Weekly MSDB Maintenance' AND s.step_name=N'Cleanup History')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: Weekly MSDB Maintenance',@step_name=N'Cleanup History',@subsystem=N'TSQL',@database_name=N'msdb',@command=N'
DECLARE @DaysToKeep int=60;
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date=DATEADD(DAY,-@DaysToKeep,GETDATE());
EXEC msdb.dbo.sp_purge_jobhistory   @oldest_date=DATEADD(DAY,-@DaysToKeep,GETDATE());';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'MAINT: Weekly MSDB Maintenance';
GO
