USE msdb; GO
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'REPORT: Monthly Monitoring Summary')
BEGIN EXEC msdb.dbo.sp_add_job @job_name=N'REPORT: Monthly Monitoring Summary',@enabled=1,@notify_level_email=2,@notify_email_operator_name=N'DBA-OnCall'; END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Monthly_1st_0800')
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'Monthly_1st_0800',@freq_type=16,@freq_interval=1,@active_start_time=080000;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js JOIN msdb.dbo.sysschedules sc ON js.schedule_id=sc.schedule_id JOIN msdb.dbo.sysjobs j ON j.job_id=js.job_id WHERE j.name=N'REPORT: Monthly Monitoring Summary' AND sc.name=N'Monthly_1st_0800')
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'REPORT: Monthly Monitoring Summary',@schedule_name=N'Monthly_1st_0800';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps s JOIN msdb.dbo.sysjobs j ON s.job_id=j.job_id WHERE j.name=N'REPORT: Monthly Monitoring Summary' AND s.step_name=N'Generate & Send')
EXEC msdb.dbo.sp_add_jobstep @job_name=N'REPORT: Monthly Monitoring Summary',@step_name=N'Generate & Send',@subsystem=N'PowerShell',@command=N'powershell -NoProfile -ExecutionPolicy Bypass -File ".\PowerShell\Report-MonthlySummary.ps1" -Recipients "dba@yourdomain.local"',@on_fail_action=2;
EXEC msdb.dbo.sp_add_jobserver @job_name=N'REPORT: Monthly Monitoring Summary';
GO
