param([Parameter(Mandatory=$true)][string]$ServerName,[switch]$SqlAuth,[string]$SqlUser,[System.Security.SecureString]$SqlPassword)
if(-not (Get-Module -ListAvailable -Name SqlServer)){ throw "Install-Module SqlServer -Scope CurrentUser" }
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sqlDir = Join-Path $root "..\sql\XE"
$invoke = @{ ServerInstance=$ServerName; ErrorAction='Stop' }
if($SqlAuth){
  if(-not $SqlUser -or -not $SqlPassword){throw "-SqlAuth wymaga -SqlUser i -SqlPassword"}
  $invoke.Username=$SqlUser
  $invoke.Password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword))
}
Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlDir "Create_XE_SystemHealth_Clone.sql")
Invoke-Sqlcmd @invoke -InputFile (Join-Path $sqlDir "Create_XE_UserActivity.sql")
Write-Host "XE: system_health_clone (ON) + user_activity (OFF) wdrożone." -ForegroundColor Green