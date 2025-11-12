param(
  [Parameter(Mandatory=$true)][string]$ServerName,
  [switch]$SqlAuth,[string]$SqlUser,[System.Security.SecureString]$SqlPassword,
  [switch]$NoCsv, [switch]$NoDbInsert
)
if(-not (Get-Module -ListAvailable -Name SqlServer)){ throw "Install-Module SqlServer -Scope CurrentUser" }
$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$sqlB  = Join-Path $root "..\sql\Baseline"
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
  $inst = Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlB "Get-InstanceBaseline.sql")
  $inst | Export-Csv (Join-Path $out ("InstanceBaseline_{0}.csv" -f $ts)) -NoTypeInformation -Encoding UTF8
  $dbs  = Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlB "Get-DatabaseBaseline.sql")
  $dbs  | Export-Csv (Join-Path $out ("DatabaseBaseline_{0}.csv" -f $ts)) -NoTypeInformation -Encoding UTF8
  Write-Host "Baseline -> CSV zapisane w outputs/." -ForegroundColor Green
}

# DB inserts (default ON)
if(-not $NoDbInsert){
  # Insert Instance baseline
  Invoke-Sqlcmd @invoke -Database "DBAdmin" -InputFile (Join-Path $sqlB "Baseline_Insert_Instance.sql")
  # Insert Databases baseline
  Invoke-Sqlcmd @invoke -Database "DBAdmin" -InputFile (Join-Path $sqlB "Baseline_Insert_Databases.sql")
  Write-Host "Baseline -> INSERT do DBAdmin.dbadmin.* wykonane." -ForegroundColor Green
}