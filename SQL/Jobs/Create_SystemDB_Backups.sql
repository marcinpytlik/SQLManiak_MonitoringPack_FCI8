-- Daily backups for master/model/msdb with compression + checksum
USE msdb; GO
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'BACKUP: System Databases (Daily)')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'BACKUP: System Databases (Daily)',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Daily_0300')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Daily_0300',@freq_type=4,@freq_interval=1,@active_start_time=030000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'BACKUP: System Databases (Daily)' AND sc.name=N'Daily_0300')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'BACKUP: System Databases (Daily)',@schedule_name=N'Daily_0300';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'BACKUP: System Databases (Daily)' AND s.step_name=N'Backup system DBs')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'BACKUP: System Databases (Daily)',@step_name=N'Backup system DBs',@subsystem=N'TSQL',@database_name=N'master',@command=N'
DECLARE @base nvarchar(260)=N''E:\SQLBackups\SystemDBs''; DECLARE @dt nvarchar(32)=CONVERT(nvarchar(32),GETDATE(),112)+''_''+REPLACE(CONVERT(nvarchar(8),GETDATE(),108),'':'','''');
DECLARE @db sysname; DECLARE @cmd nvarchar(max);
DECLARE @dbs table(name sysname); INSERT @dbs(name) VALUES(N''master''),(N''model''),(N''msdb'');
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @dbs; OPEN c; FETCH NEXT FROM c INTO @db;
WHILE @@FETCH_STATUS=0
BEGIN SET @cmd=N''BACKUP DATABASE ''+QUOTENAME(@db)+N'' TO DISK=N''''''+@base+N''\'''+@db+N''_''+@dt+N''.bak'''''' WITH INIT, COMPRESSION, CHECKSUM, STATS=5;''; EXEC(@cmd);
FETCH NEXT FROM c INTO @db; END CLOSE c; DEALLOCATE c;';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'BACKUP: System Databases (Daily)';
GO
