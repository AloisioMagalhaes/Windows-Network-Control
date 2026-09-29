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
        Dns=[pscustomobject]@{Provider='NextDNS';ProfileId='923be7';ApiBaseUrl='https://api.nextdns.io';ApiKeyEnvironmentVariable='NEXTDNS_API_KEY';Mode='DoH';DohTemplate='https://dns.nextdns.io/{ProfileId}';DohBootstrapServers=@('45.90.28.0','45.90.30.0');DotHostname='{ProfileId}.dns.nextdns.io';Ipv6Servers=@('2a07:a8c0::92:3be7','2a07:a8c1::92:3be7');LinkedIpv4Servers=@('45.90.28.212','45.90.30.212');UseIpv6=$false;MandatoryFeatures=[pscustomobject]@{AdsTrackersBlocklist=$true;ThreatIntelligenceFeeds=$true;NativeTrackingProtection=$true;DisguisedThirdPartyTrackers=$true;BlockBypassMethods=$true;PornCategory=$true;PiracyCategory=$true;SafeSearch=$true;AllowAffiliateTrackingLinks=$false};Categories=@('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')}
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
    [pscustomobject]@{Provider=$Config.Dns.Provider;Mode=$Config.Dns.Mode;Template=$Config.Dns.DohTemplate.Replace('{ProfileId}',$Config.Dns.ProfileId);DotHostname=$Config.Dns.DotHostname.Replace('{ProfileId}',$Config.Dns.ProfileId);BootstrapServers=@($Config.Dns.DohBootstrapServers);Ipv6Servers=@($Config.Dns.Ipv6Servers);LinkedIpv4Servers=@($Config.Dns.LinkedIpv4Servers)}
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

function Get-NcRequiredNextDnsFeatures($Config) {
    $f = $Config.Dns.MandatoryFeatures
    @('AdsTrackersBlocklist','ThreatIntelligenceFeeds','NativeTrackingProtection','DisguisedThirdPartyTrackers','BlockBypassMethods','PornCategory','PiracyCategory','SafeSearch') | Where-Object { $f.$_ -ne $true }
}

function Get-NcNextDnsProfilePayload($Config) {
    Test-NcConfig $Config | Out-Null
    $f = $Config.Dns.MandatoryFeatures
    $c = @()
    if ('adult' -in $Config.Dns.Categories) { $c += @{id='porn';active=$true} }
    if ('p2p_file_sharing' -in $Config.Dns.Categories -or 'torrents' -in $Config.Dns.Categories) { $c += @{id='piracy';active=$true} }
    @{security=@{threatIntelligenceFeeds=($f.ThreatIntelligenceFeeds -eq $true)};privacy=@{blocklists=@(@{id='nextdns-recommended'});natives=@(@{id='windows'});disguisedTrackers=($f.DisguisedThirdPartyTrackers -eq $true);allowAffiliate=($f.AllowAffiliateTrackingLinks -eq $true)};parentalControl=@{categories=$c;safeSearch=($f.SafeSearch -eq $true);blockBypass=($f.BlockBypassMethods -eq $true)}}
}

function Invoke-NcNextDnsProfile($Config) {
    $u = "$($Config.Dns.ApiBaseUrl.TrimEnd('/'))/profiles/$($Config.Dns.ProfileId)"
    Invoke-RestMethod -Method Patch -Uri $u -Headers (Get-NcNextDnsHeaders $Config) -Body (Get-NcNextDnsProfilePayload $Config | ConvertTo-Json -Depth 8) | Out-Null
}

function Set-NcWindowsRemoteDns($Config) {
    if (!(Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)) { throw 'Windows native DoH cmdlets are unavailable' }
    $p = Get-NcRemoteDnsPlan $Config
    foreach ($s in $p.BootstrapServers) { Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $p.Template -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue }
    $a = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -ExpandProperty ifIndex)
    $s = if ($Config.Dns.UseIpv6) { @($p.BootstrapServers + $p.Ipv6Servers) } else { $p.BootstrapServers }
    foreach ($i in $a) { Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses $s }
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
    Export-ModuleMember -Function Get-NcDefaultConfig,Get-NcRuleName,Test-NcConfig,Get-NcBackupPath,Export-NcFirewallBackup,Restore-NcFirewallBackup,Get-NcRemoteDnsPlan,Get-NcNextDnsHeaders,Invoke-NcNextDnsCategory,Get-NcNextDnsActions,Get-NcRequiredNextDnsFeatures,Get-NcNextDnsProfilePayload,Invoke-NcNextDnsProfile,Set-NcWindowsRemoteDns,Invoke-Nc
}
