-- Database Mail + operator + alert jobs (Stale Backups, Failed Jobs, Priv Changes)
USE msdb;
GO
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'Database Mail XPs',1; RECONFIGURE;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name='DBA-Mail')
  EXEC msdb.dbo.sysmail_add_account_sp @account_name='DBA-Mail',@email_address='dba@yourdomain.local',@display_name='SQLManiak DBA Mail',@mailserver_name='smtp.yourdomain.local';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name='DBA-Profile')
BEGIN EXEC msdb.dbo.sysmail_add_profile_sp @profile_name='DBA-Profile';
EXEC msdb.dbo.sysmail_add_profileaccount_sp @profile_name='DBA-Profile',@account_name='DBA-Mail',@sequence_number=1; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_principalprofile WHERE profile_id=(SELECT profile_id FROM msdb.dbo.sysmail_profile WHERE name='DBA-Profile'))
  EXEC msdb.dbo.sysmail_add_principalprofile_sp @profile_name='DBA-Profile',@principal_id=0,@is_default=1;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name=N'DBA-OnCall')
  EXEC msdb.dbo.sp_add_operator @name=N'DBA-OnCall',@enabled=1,@email_address=N'dba@yourdomain.local';
-- Job: ALERT: Stale Backups (Every 30 min)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'ALERT: Stale Backups')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'ALERT: Stale Backups',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall';
EXEC msdb.dbo.sp_add_jobstep @job_name=N'ALERT: Stale Backups',@step_name=N'Check',@subsystem=N'TSQL',@database_name=N'DBAAdmin',@command=N'
IF EXISTS (SELECT 1 FROM dbo.BackupStatus WHERE IsStale=1 AND CollectedAt>=DATEADD(HOUR,-2,SYSUTCDATETIME()))
BEGIN DECLARE @body nvarchar(max)=(SELECT STRING_AGG(CONCAT(InstanceName,''.'',DatabaseName,'': FULL='',CONVERT(varchar(16),LastFull,120),'' LOG='',CONVERT(varchar(16),LastLog,120)),CHAR(10)) FROM dbo.BackupStatus WHERE IsStale=1 AND CollectedAt>=DATEADD(HOUR,-2,SYSUTCDATETIME()));
EXEC msdb.dbo.sp_send_dbmail @profile_name=''DBA-Profile'',@recipients=''dba@yourdomain.local'',@subject=''[ALERT] Stale backups detected'',@body=@body; END';
EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Every30min',@freq_type=4,@freq_interval=1,@freq_subday_type=4,@freq_subday_interval=30,@active_start_time=0;
EXEC msdb.dbo.sp_attach_schedule @job_name=N'ALERT: Stale Backups',@schedule_name=N'Every30min';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'ALERT: Stale Backups'; END
-- Job: ALERT: Failed Jobs
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'ALERT: Failed Jobs')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'ALERT: Failed Jobs',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall';
EXEC msdb.dbo.sp_add_jobstep @job_name=N'ALERT: Failed Jobs',@step_name=N'Check',@subsystem=N'TSQL',@database_name=N'DBAAdmin',@command=N'
IF EXISTS (SELECT 1 FROM dbo.SqlJobLastRuns WHERE LastRunStatus=''Failed'' AND CollectedAt>=DATEADD(MINUTE,-30,SYSUTCDATETIME()))
BEGIN DECLARE @body nvarchar(max)=(SELECT STRING_AGG(CONCAT(InstanceName,'': '',JobName,'' @ '',CONVERT(varchar(16),LastRunTime,120),'' - '',LastRunMessage),CHAR(10)) FROM dbo.SqlJobLastRuns WHERE LastRunStatus=''Failed'' AND CollectedAt>=DATEADD(MINUTE,-30,SYSUTCDATETIME()));
EXEC msdb.dbo.sp_send_dbmail @profile_name=''DBA-Profile'',@recipients=''dba@yourdomain.local'',@subject=''[ALERT] Job failures detected'',@body=@body; END';
EXEC msdb.dbo.sp_attach_schedule @job_name=N'ALERT: Failed Jobs',@schedule_name=N'Every30min';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'ALERT: Failed Jobs'; END
-- Job: ALERT: Privilege Changes
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'ALERT: Privilege Changes')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'ALERT: Privilege Changes',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall';
EXEC msdb.dbo.sp_add_jobstep @job_name=N'ALERT: Privilege Changes',@step_name=N'Check',@subsystem=N'TSQL',@database_name=N'DBAAdmin',@command=N'
IF EXISTS (SELECT 1 FROM dbo.AuditEvents WHERE EventTime>=DATEADD(MINUTE,-60,SYSUTCDATETIME()))
BEGIN DECLARE @cnt int=(SELECT COUNT(*) FROM dbo.AuditEvents WHERE EventTime>=DATEADD(MINUTE,-60,SYSUTCDATETIME()));
EXEC msdb.dbo.sp_send_dbmail @profile_name=''DBA-Profile'',@recipients=''dba@yourdomain.local'',@subject=''[ALERT] Privilege changes detected'',@body=CONCAT(''Detected events: '',@cnt); END';
EXEC msdb.dbo.sp_attach_schedule @job_name=N'ALERT: Privilege Changes',@schedule_name=N'Every30min';
EXEC msdb.dbo.sp_add_jobserver @job_name=N'ALERT: Privilege Changes'; END
GO
