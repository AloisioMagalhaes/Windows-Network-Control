[CmdletBinding()]
param(
    [ValidateSet('Simulate','Status','ListRules','Apply','RemoveManagedRules','Restore')]
    [string]$Mode='Simulate',
    [string]$ConfigPath,
    [string]$BackupPath,
    [switch]$ConfirmApply
)

$script:NcCategories = @('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')

function Get-NcDefaultConfig {
    [pscustomobject]@{
        RulePrefix='NWC'
        BackupDirectory='backups'
        Dns=[pscustomobject]@{Provider='Technitium';Endpoint='https://127.0.0.1:5380';Categories=@('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')}
        AllowedPrograms=@()
        BlockedPrograms=@()
        BlockedServices=@()
        BlockedPorts=@()
        Exceptions=[pscustomobject]@{AllowBrowsers=$true;AllowWindowsCore=$true;AllowUpdates=$true}
    }
}

function Get-NcRuleName([string]$Kind,[string]$Value) {
    "NWC-$Kind-$([IO.Path]::GetFileName($Value))"
}

function Test-NcConfig($Config) {
    if (!$Config.BackupDirectory) { throw 'BackupDirectory is required' }
    if ($Config.Dns.Provider -notin @('Technitium','AdGuardHome','Pi-hole')) { throw 'DNS provider must be a self-hosted open-source provider' }
    if ($Config.Dns.Endpoint -and $Config.Dns.Endpoint -notmatch '^https://') { throw 'DNS endpoint must use HTTPS' }
    $bad = @($Config.Dns.Categories | Where-Object { $_ -notin $script:NcCategories })
    if ($bad) { throw "Unsupported DNS category: $($bad -join ', ')" }
    $true
}

function Get-NcBackupPath($Config) {
    Join-Path $Config.BackupDirectory ("NWC-firewall-{0}.wfw" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

function Export-NcFirewallBackup($Config) {
    New-Item -ItemType Directory -Path $Config.BackupDirectory -Force | Out-Null
    $p = Get-NcBackupPath $Config
    netsh advfirewall export $p | Out-Null
    if (!(Test-Path $p)) { throw "Firewall backup failed: $p" }
    $p
}

function Restore-NcFirewallBackup([string]$Path) {
    if (!(Test-Path $Path)) { throw "Backup not found: $Path" }
    netsh advfirewall import $Path | Out-Null
}

function Invoke-Nc([string]$Mode,$Config) {
    Test-NcConfig $Config | Out-Null
    switch ($Mode) {
        Simulate { 'SIMULATION: no changes applied' }
        Status { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction }
        ListRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" }
        Apply {
            if (!$ConfirmApply) { throw 'Apply requires -ConfirmApply' }
            Export-NcFirewallBackup $Config | Out-Null
            Get-NetFirewallProfile | Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block
        }
        RemoveManagedRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" | Remove-NetFirewallRule }
        Restore { Restore-NcFirewallBackup $BackupPath }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $c = if ($ConfigPath) { Get-Content $ConfigPath -Raw | ConvertFrom-Json } else { Get-NcDefaultConfig }
    Invoke-Nc $Mode $c
}
