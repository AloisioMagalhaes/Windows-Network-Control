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
        Dns=[pscustomobject]@{Provider='NextDNS';ProfileId='SEU_PROFILE_ID';ApiBaseUrl='https://api.nextdns.io';ApiKeyEnvironmentVariable='NEXTDNS_API_KEY';DohTemplate='https://dns.nextdns.io/{ProfileId}';DohBootstrapServers=@('45.90.28.0','45.90.30.0');Categories=@('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')}
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
    if ($Config.Dns.Provider -ne 'NextDNS') { throw 'DNS provider must be the supported remote provider NextDNS' }
    if (!$Config.Dns.ProfileId) { throw 'NextDNS ProfileId is required' }
    if ($Config.Dns.ApiBaseUrl -notmatch '^https://api\.nextdns\.io/?$') { throw 'NextDNS API base URL is invalid' }
    if ($Config.Dns.DohTemplate -notmatch '^https://dns\.nextdns\.io/') { throw 'NextDNS DoH template is invalid' }
    if ($Config.Dns.Endpoint -and $Config.Dns.Endpoint -notmatch '^https://') { throw 'DNS endpoint must use HTTPS' }
    $bad = @($Config.Dns.Categories | Where-Object { $_ -notin $script:NcCategories })
    if ($bad) { throw "Unsupported DNS category: $($bad -join ', ')" }
    $true
}

function Get-NcRemoteDnsPlan($Config) {
    Test-NcConfig $Config | Out-Null
    if ($Config.Dns.ProfileId -eq 'SEU_PROFILE_ID') { throw 'NextDNS ProfileId must be configured' }
    [pscustomobject]@{Provider=$Config.Dns.Provider;Template=$Config.Dns.DohTemplate.Replace('{ProfileId}',$Config.Dns.ProfileId);BootstrapServers=@($Config.Dns.DohBootstrapServers)}
}

function Get-NcNextDnsHeaders($Config) {
    $n = if ($Config.Dns.ApiKeyEnvironmentVariable) { $Config.Dns.ApiKeyEnvironmentVariable } else { 'NEXTDNS_API_KEY' }
    $k = [Environment]::GetEnvironmentVariable($n)
    if (!$k) { throw "Missing environment variable: $n" }
    @{ 'X-Api-Key' = $k; 'Content-Type' = 'application/json' }
}

function Invoke-NcNextDnsCategory($Config,[string]$Category,[bool]$Active=$true) {
    $u = "$($Config.Dns.ApiBaseUrl.TrimEnd('/'))/profiles/$($Config.Dns.ProfileId)/parentalcontrol/categories/$Category"
    Invoke-RestMethod -Method Patch -Uri $u -Headers (Get-NcNextDnsHeaders $Config) -Body (@{active=$Active} | ConvertTo-Json)
}

function Get-NcNextDnsActions($Config) {
    Test-NcConfig $Config | Out-Null
    $a = @()
    if ('adult' -in $Config.Dns.Categories) { $a += [pscustomobject]@{Kind='category';Id='porn';Active=$true} }
    if ('advertising_tracking' -in $Config.Dns.Categories) { $a += [pscustomobject]@{Kind='blocklist';Id='nextdns-recommended';Active=$true} }
    $a
}

function Invoke-NcNextDnsProfile($Config) {
    foreach ($a in Get-NcNextDnsActions $Config) {
        $h = Get-NcNextDnsHeaders $Config
        if ($a.Kind -eq 'category') { $u = "$($Config.Dns.ApiBaseUrl.TrimEnd('/'))/profiles/$($Config.Dns.ProfileId)/parentalcontrol/categories/$($a.Id)" }
        else { $u = "$($Config.Dns.ApiBaseUrl.TrimEnd('/'))/profiles/$($Config.Dns.ProfileId)/privacy/blocklists/$($a.Id)" }
        Invoke-RestMethod -Method Patch -Uri $u -Headers $h -Body (@{active=$a.Active} | ConvertTo-Json) | Out-Null
    }
}

function Set-NcWindowsRemoteDns($Config) {
    if (!(Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)) { throw 'Windows native DoH cmdlets are unavailable' }
    $p = Get-NcRemoteDnsPlan $Config
    foreach ($s in $p.BootstrapServers) { Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $p.Template -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue }
    $a = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -ExpandProperty ifIndex)
    foreach ($i in $a) { Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses $p.BootstrapServers }
    $p
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
            Invoke-NcNextDnsProfile $Config
            Get-NetFirewallProfile | Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block
            Set-NcWindowsRemoteDns $Config | Out-Null
        }
        RemoveManagedRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" | Remove-NetFirewallRule }
        Restore { Restore-NcFirewallBackup $BackupPath }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $c = if ($ConfigPath) { Get-Content $ConfigPath -Raw | ConvertFrom-Json } else { Get-NcDefaultConfig }
    Invoke-Nc $Mode $c
}

if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Get-NcDefaultConfig,Get-NcRuleName,Test-NcConfig,Get-NcBackupPath,Export-NcFirewallBackup,Restore-NcFirewallBackup,Get-NcRemoteDnsPlan,Get-NcNextDnsHeaders,Invoke-NcNextDnsCategory,Get-NcNextDnsActions,Invoke-NcNextDnsProfile,Set-NcWindowsRemoteDns,Invoke-Nc
}
