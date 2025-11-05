-- Weekly index & stats maintenance for USER databases
USE msdb; GO
-- Index maintenance
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'MAINT: Weekly UserDB Index Maintenance')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'MAINT: Weekly UserDB Index Maintenance',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Weekly_Sun_0130')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Weekly_Sun_0130',@freq_type=8,@freq_interval=1,@active_start_time=013000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'MAINT: Weekly UserDB Index Maintenance' AND sc.name=N'Weekly_Sun_0130')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'MAINT: Weekly UserDB Index Maintenance',@schedule_name=N'Weekly_Sun_0130';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: Weekly UserDB Index Maintenance' AND s.step_name=N'Index Maintenance')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: Weekly UserDB Index Maintenance',@step_name=N'Index Maintenance',@subsystem=N'TSQL',@database_name=N'master',@command=N'
DECLARE @db sysname,@sql nvarchar(max);
DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM sys.databases WHERE database_id>4 AND state=0;
OPEN dbs; FETCH NEXT FROM dbs INTO @db;
WHILE @@FETCH_STATUS=0
BEGIN SET @sql=N''; WITH fr AS (
  SELECT object_id,index_id,avg_fragmentation_in_percent FROM sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'''SAMPLED''') WHERE index_id>0
)
SELECT 1;
DECLARE @obj sysname,@idx sysname,@frag float,@cmd nvarchar(4000);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT o.name,i.name,fr.avg_fragmentation_in_percent FROM fr
JOIN sys.indexes i ON i.object_id=fr.object_id AND i.index_id=fr.index_id
JOIN sys.objects o ON o.object_id=fr.object_id WHERE o.type=''U'' AND i.type_desc IN (''CLUSTERED'',''NONCLUSTERED'');
OPEN cur; FETCH NEXT FROM cur INTO @obj,@idx,@frag;
WHILE @@FETCH_STATUS=0
BEGIN
  IF @frag BETWEEN 5 AND 30 SET @cmd=N''ALTER INDEX ''+QUOTENAME(@idx)+N'' ON ''+QUOTENAME(@obj)+N'' REORGANIZE;'';
  ELSE IF @frag>30 SET @cmd=N''ALTER INDEX ''+QUOTENAME(@idx)+N'' ON ''+QUOTENAME(@obj)+N'' REBUILD WITH (ONLINE=ON);''; ELSE SET @cmd=NULL;
  IF @cmd IS NOT NULL EXEC(@cmd);
  FETCH NEXT FROM cur INTO @obj,@idx,@frag;
END
CLOSE cur; DEALLOCATE cur;';
-- Stats
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'MAINT: Weekly UserDB Update Statistics')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'MAINT: Weekly UserDB Update Statistics',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Weekly_Sun_0330')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Weekly_Sun_0330',@freq_type=8,@freq_interval=1,@active_start_time=033000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'MAINT: Weekly UserDB Update Statistics' AND sc.name=N'Weekly_Sun_0330')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'MAINT: Weekly UserDB Update Statistics',@schedule_name=N'Weekly_Sun_0330';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'MAINT: Weekly UserDB Update Statistics' AND s.step_name=N'Update Stats')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'MAINT: Weekly UserDB Update Statistics',@step_name=N'Update Stats',@subsystem=N'TSQL',@database_name=N'master',@command=N'
DECLARE @db sysname,@sql nvarchar(max);
DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM sys.databases WHERE database_id>4 AND state=0;
OPEN dbs; FETCH NEXT FROM dbs INTO @db;
WHILE @@FETCH_STATUS=0
BEGIN SET @sql=N''DECLARE @cmd nvarchar(max)=N''''''''; SELECT @cmd=@cmd+N''''UPDATE STATISTICS ''''''+QUOTENAME(OBJECT_SCHEMA_NAME(object_id))+N''''.''''''+QUOTENAME(OBJECT_NAME(object_id))+N'''' WITH RESAMPLE;''''+CHAR(10) FROM sys.objects WHERE type=''U''; EXEC sp_executesql @cmd;'';
BEGIN TRY EXEC(N''USE ''+QUOTENAME(@db)+N''; ''+@sql); END TRY BEGIN CATCH RAISERROR(''Update statistics failed for %s: %s'',16,1,@db,ERROR_MESSAGE()); END CATCH;
FETCH NEXT FROM dbs INTO @db; END
CLOSE dbs; DEALLOCATE dbs;';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'MAINT: Weekly UserDB Update Statistics';
GO
