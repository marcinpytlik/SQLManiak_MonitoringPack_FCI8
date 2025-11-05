param([string]$ConfigPath = ".\Config\instances.json",[string]$Recipients = "dba@yourdomain.local",[int]$TopN = 10)
$ErrorActionPreference = "Stop"
$cfg = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$central = $cfg.central_repository.datasource
$q1 = @"
SELECT
 (SELECT COUNT(*) FROM DBAAdmin.dbo.BackupStatus WHERE IsStale=1 AND CollectedAt>=DATEADD(day,-30,SYSUTCDATETIME())) AS StaleBackups30d,
 (SELECT COUNT(*) FROM DBAAdmin.dbo.SqlJobLastRuns WHERE LastRunStatus='Failed' AND CollectedAt>=DATEADD(day,-30,SYSUTCDATETIME())) AS FailedJobs30d,
 (SELECT COUNT(*) FROM DBAAdmin.dbo.AuditEvents WHERE EventTime>=DATEADD(day,-30,SYSUTCDATETIME())) AS AuditEvents30d,
 (SELECT COUNT(*) FROM DBAAdmin.dbo.ClusterEvents WHERE EventTime>=DATEADD(day,-30,SYSUTCDATETIME())) AS ClusterEvents30d;
"@
$q2 = @"
WITH s AS (
 SELECT InstanceName,DatabaseName,CollectedOn,DataSizeMB,
 LAG(DataSizeMB) OVER (PARTITION BY InstanceName,DatabaseName ORDER BY CollectedOn) AS PrevMB
 FROM DBAAdmin.dbo.DbSizeDaily
 WHERE CollectedOn>=DATEADD(day,-30,CAST(SYSUTCDATETIME() AS date))
)
SELECT TOP (@TopN) InstanceName,DatabaseName,
 SUM(CASE WHEN PrevMB IS NULL THEN 0 ELSE DataSizeMB-PrevMB END) AS GrowthMB_30d
FROM s GROUP BY InstanceName,DatabaseName ORDER BY GrowthMB_30d DESC;
"@
$q3 = @"
SELECT TOP (@TopN) InstanceName,JobName,MAX(LastRunTime) AS LastFailedAt
FROM DBAAdmin.dbo.SqlJobLastRuns
WHERE LastRunStatus='Failed' AND CollectedAt>=DATEADD(day,-30,SYSUTCDATETIME())
GROUP BY InstanceName,JobName ORDER BY LastFailedAt DESC;
"@
$q4 = @"
SELECT InstanceName,DatabaseName,MAX(CollectedAt) AS LastChecked,MAX(LastFull) AS LastFull,MAX(LastLog) AS LastLog,MAX(RecoveryModel) AS RecoveryModel
FROM DBAAdmin.dbo.BackupStatus WHERE IsStale=1 GROUP BY InstanceName,DatabaseName ORDER BY InstanceName,DatabaseName;
"@
$q5 = @"
SELECT TOP (@TopN) ISNULL(ActionId,'N/A') AS ActionId,COUNT(*) AS Cnt
FROM DBAAdmin.dbo.AuditEvents WHERE EventTime>=DATEADD(day,-30,SYSUTCDATETIME())
GROUP BY ActionId ORDER BY Cnt DESC;
"@
$summary = Invoke-Sqlcmd -ServerInstance $central -Database master -Query $q1
$topGrowth = Invoke-Sqlcmd -ServerInstance $central -Database master -Query $q2 -Variable TopN=$TopN
$failed = Invoke-Sqlcmd -ServerInstance $central -Database master -Query $q3 -Variable TopN=$TopN
$stale = Invoke-Sqlcmd -ServerInstance $central -Database master -Query $q4
$audit = Invoke-Sqlcmd -ServerInstance $central -Database master -Query $q5 -Variable TopN=$TopN
function To-HtmlTable { param([Parameter(ValueFromPipeline)]$rows) process {
 if(-not $rows){ return "" } $props=$rows[0].psobject.Properties.Name
 $thead=($props|% { "<th>$($_)</th>" }) -join ""
 $trs = foreach($r in $rows){ $tds=foreach($p in $props){ "<td>$($r.$p)</td>" } -join ""; "<tr>$tds</tr>" }
 "<table><thead><tr>$thead</tr></thead><tbody>$($trs -join '')</tbody></table>"
}}
$css = "<style>body{font-family:Segoe UI,Arial;font-size:12px} table{border-collapse:collapse;width:100%} th,td{border:1px solid #ddd;padding:6px}</style>"
$now=Get-Date
$html = @"
$css
<h1>SQLManiak – Miesięczny raport monitoringu (ostatnie 30 dni)</h1>
<div>Generowano: $($now.ToString('yyyy-MM-dd HH:mm'))</div>
<h2>Podsumowanie</h2> $(To-HtmlTable @($summary))
<h2>Top $TopN wzrostów rozmiaru baz (MB)</h2> $(To-HtmlTable $topGrowth)
<h2>Ostatnie błędy jobów</h2> $(To-HtmlTable $failed)
<h2>Stare/backlog backupy</h2> $(To-HtmlTable $stale)
<h2>Najczęstsze typy zdarzeń audytu</h2> $(To-HtmlTable $audit)
"@
$send = "EXEC msdb.dbo.sp_send_dbmail @profile_name='DBA-Profile',@recipients='"+$Recipients+"',@subject='[SQLManiak] Raport miesięczny monitoringu',@body=N'"+($html.Replace(\"'\",\"''\"))+"',@body_format='HTML';"
Invoke-Sqlcmd -ServerInstance $central -Database master -Query $send
Write-Host "Monthly report sent to $Recipients"
