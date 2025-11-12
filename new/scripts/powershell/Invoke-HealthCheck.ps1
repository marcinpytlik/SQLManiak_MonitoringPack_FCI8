param(
  [Parameter(Mandatory=$true)][string]$ServerName,
  [switch]$SqlAuth,[string]$SqlUser,[System.Security.SecureString]$SqlPassword,
  [switch]$NoCsv, [switch]$NoDbInsert
)
if(-not (Get-Module -ListAvailable -Name SqlServer)){ throw "Install-Module SqlServer -Scope CurrentUser" }
$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$sqlH  = Join-Path $root "..\sql\Health"
$out   = Join-Path $root "..\..\outputs"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$invoke = @{ ServerInstance=$ServerName; ErrorAction='Stop' }
if($SqlAuth){
  if(-not $SqlUser -or -not $SqlPassword){throw "-SqlAuth wymaga -SqlUser i -SqlPassword"}
  $invoke.Username=$SqlUser
  $invoke.Password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword))
}

# CSV export (default ON)
if(-not $NoCsv){
  $hadr = Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlH "HADR_AG_Health.sql")
  $fci  = Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlH "FCI_Health.sql")
  $hadr | Export-Csv (Join-Path $out ("HADR_{0}.csv" -f $ts)) -NoTypeInformation -Encoding UTF8
  $fci  | Export-Csv (Join-Path $out ("FCI_{0}.csv" -f $ts)) -NoTypeInformation -Encoding UTF8
  Write-Host "Health -> CSV zapisane w outputs/." -ForegroundColor Green
}

# DB inserts (default ON)
if(-not $NoDbInsert){
  Invoke-Sqlcmd @invoke -Database "DBAdmin" -InputFile (Join-Path $sqlH "Health_Insert_FCI.sql")
  Invoke-Sqlcmd @invoke -Database "DBAdmin" -InputFile (Join-Path $sqlH "Health_Insert_HADR.sql")
  Write-Host "Health -> INSERT do DBAdmin.dbadmin.* wykonane." -ForegroundColor Green
}