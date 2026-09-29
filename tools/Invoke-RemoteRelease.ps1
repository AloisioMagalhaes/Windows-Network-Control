[CmdletBinding()]
param(
    [ValidateSet('Simulate','Status','ListRules','ListPrograms','ConfigureDns','ConfigureBrowserPolicies','BlockPrograms','UnblockPrograms','Apply','RemoveManagedRules','Restore')]
    [string]$Mode='Simulate',
    [string]$ConfigPath,
    [string[]]$ProgramPath,
    [switch]$ConfirmApply
)
$ErrorActionPreference='Stop'
$repo='AloisioMagalhaes/Windows-Network-Control'
$r=Invoke-WebRequest "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$n=$r.tag_name
$a=$r.assets | Where-Object name -eq "Windows-Network-Control-$n.zip"
$s=$r.assets | Where-Object name -eq "Windows-Network-Control-$n.zip.sha256"
if (!$a -or !$s) { throw 'Release assets not found' }
$d=Join-Path $env:TEMP "NWC-$n"
$z="$d.zip"
$q="$d.sha256"
Remove-Item $d,$z,$q -Recurse -Force -ErrorAction SilentlyContinue
Invoke-WebRequest $a.browser_download_url -OutFile $z -UseBasicParsing
Invoke-WebRequest $s.browser_download_url -OutFile $q -UseBasicParsing
$h=(Get-Content $q -Raw).Trim().Split()[0].ToLowerInvariant()
if ((Get-FileHash $z -Algorithm SHA256).Hash.ToLowerInvariant() -ne $h) { Remove-Item $z,$q -Force -ErrorAction SilentlyContinue; throw 'SHA-256 validation failed' }
Expand-Archive $z $d -Force
$p=Join-Path $d 'src\NetworkControl.ps1'
if (!(Test-Path $p -PathType Leaf)) { throw 'NetworkControl.ps1 not found' }
$x=@{Mode=$Mode}
if ($ConfigPath) { $x.ConfigPath=$ConfigPath } else { $x.ConfigPath=Join-Path $d 'config\example.json' }
if ($ProgramPath) { $x.ProgramPath=$ProgramPath }
if ($ConfirmApply) { $x.ConfirmApply=$true }
& $p @x
exit $LASTEXITCODE
