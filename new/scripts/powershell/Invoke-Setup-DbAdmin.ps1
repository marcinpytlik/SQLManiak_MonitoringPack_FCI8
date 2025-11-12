param([Parameter(Mandatory=$true)][string]$ServerName,[switch]$SqlAuth,[string]$SqlUser,[System.Security.SecureString]$SqlPassword)
function Invoke-TsqlFile([string]$FilePath){
  if(-not (Test-Path $FilePath)){ throw "Brak pliku: $FilePath" }
  $params=@{ServerInstance=$ServerName;InputFile=$FilePath;ErrorAction='Stop'}
  if($SqlAuth){
    if(-not $SqlUser -or -not $SqlPassword){throw "-SqlAuth wymaga -SqlUser i -SqlPassword"}
    $params.Username=$SqlUser
    $params.Password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword))}
  Invoke-Sqlcmd @params
}
if(-not (Get-Module -ListAvailable -Name SqlServer)){ throw "Install-Module SqlServer -Scope CurrentUser" }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sql = Join-Path $here "..\sql"
('00_Create_DBAdmin.sql','01_Create_Login_dbadmin.sql','02_Provision_dbadmin_AllDBs.sql','03_msdb_Roles.sql') | ForEach-Object { Invoke-TsqlFile (Join-Path $sql $_) }
Write-Host "dbadmin + DBAdmin gotowe." -ForegroundColor Green