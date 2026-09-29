[CmdletBinding()]
param(
    [ValidateSet('Simulate','Status','ListRules','ListPrograms','ConfigureDns','ConfigureBrowserPolicies','BlockPrograms','UnblockPrograms','Apply','RemoveManagedRules','RemoveManagedConfiguration','Restore')]
    [string]$Mode='Simulate',
    [string]$ConfigPath,
    [string]$BackupPath,
    [switch]$ConfirmApply
    ,[string[]]$ProgramPath
)

$script:NcCategories = @('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')

function Get-NcDefaultConfig {
    [pscustomobject]@{
        RulePrefix='NWC'
        BackupDirectory='backups'
        Firewall=[pscustomobject]@{DefaultInboundAction='Block';DefaultOutboundAction='Allow'}
        Dns=[pscustomobject]@{Provider='NextDNS';ProfileId='923be7';ApiBaseUrl='https://api.nextdns.io';ApiKeyEnvironmentVariable='NEXTDNS_API_KEY';Mode='DoH';DohTemplate='https://dns.nextdns.io/{ProfileId}';DohBootstrapServers=@('45.90.28.0','45.90.30.0');DotHostname='{ProfileId}.dns.nextdns.io';Ipv6Servers=@('2a07:a8c0::92:3be7','2a07:a8c1::92:3be7');LinkedIpv4Servers=@('45.90.28.212','45.90.30.212');UseIpv6=$false;MandatoryFeatures=[pscustomobject]@{AdsTrackersBlocklist=$true;ThreatIntelligenceFeeds=$true;NativeTrackingProtection=$true;DisguisedThirdPartyTrackers=$true;BlockBypassMethods=$true;PornCategory=$true;PiracyCategory=$true;SafeSearch=$true;YouTubeRestrictedMode=$true;AllowAffiliateTrackingLinks=$false};NextDnsCategories=@('porn','piracy','gambling','dating','gaming','social-networks','video-streaming');NextDnsServices=@();Categories=@('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')}
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

function Get-NcInstalledPrograms {
    $roots=@('C:\Program Files','C:\Program Files (x86)') | Where-Object { Test-Path $_ }
    Get-ChildItem $roots -Filter *.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -Unique | Sort-Object
}

function Get-NcProgramPaths([string[]]$Paths) {
    $p=@($Paths | Where-Object { $_ } | ForEach-Object { (Resolve-Path $_ -ErrorAction Stop).Path })
    if (!$p) { throw 'Informe ao menos um executável com -ProgramPath' }
    $p | Where-Object { $_ -match '(?i)^[A-Z]:\\' -and [IO.Path]::GetExtension($_) -ieq '.exe' -and (Test-Path $_ -PathType Leaf) } | Select-Object -Unique
}

function Set-NcProgramRules([string[]]$Paths,[bool]$Block) {
    foreach ($p in Get-NcProgramPaths $Paths) {
        $n=Get-NcRuleName 'Program' $p
        if (!$Block) { Get-NetFirewallRule -DisplayName "$n-Inbound","$n-Outbound" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue; continue }
        foreach ($d in 'Inbound','Outbound') { if (!(Get-NetFirewallRule -DisplayName "$n-$d" -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName "$n-$d" -Direction $d -Program $p -Action Block -Profile Any -Group NWC -Description 'Managed by Windows-Network-Control' | Out-Null } }
    }
}

function Set-NcBrowserPolicies {
    $keys=@(
        @('HKLM:\SOFTWARE\Policies\Google\Chrome','DnsOverHttpsMode','off'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Edge','DnsOverHttpsMode','off'),
        @('HKLM:\SOFTWARE\Policies\BraveSoftware\Brave','DnsOverHttpsMode','off')
    )
    foreach ($x in $keys) { New-Item $x[0] -Force | Out-Null; New-ItemProperty $x[0] $x[1] -Value $x[2] -PropertyType String -Force | Out-Null }
    $f='HKLM:\SOFTWARE\Policies\Mozilla\Firefox'; New-Item $f -Force | Out-Null; New-ItemProperty $f 'DNSOverHTTPS' -Value 0 -PropertyType DWord -Force | Out-Null; New-ItemProperty $f 'DNSOverHTTPSLocked' -Value 1 -PropertyType DWord -Force | Out-Null
}

function Remove-NcBrowserPolicies {
    @(@('HKLM:\SOFTWARE\Policies\Google\Chrome','DnsOverHttpsMode'),@('HKLM:\SOFTWARE\Policies\Microsoft\Edge','DnsOverHttpsMode'),@('HKLM:\SOFTWARE\Policies\BraveSoftware\Brave','DnsOverHttpsMode'),@('HKLM:\SOFTWARE\Policies\Mozilla\Firefox','DNSOverHTTPS'),@('HKLM:\SOFTWARE\Policies\Mozilla\Firefox','DNSOverHTTPSLocked')) | ForEach-Object { if (Test-Path $_[0]) { Remove-ItemProperty $_[0] $_[1] -ErrorAction SilentlyContinue } }
}

function Remove-NcWindowsRemoteDns($Config) {
    $p=Get-NcRemoteDnsPlan $Config
    if (Get-Command Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue) { foreach ($s in $p.BootstrapServers) { Remove-DnsClientDohServerAddress -ServerAddress $s -ErrorAction SilentlyContinue } }
    Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses }
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
    $ids = if ($Config.Dns.NextDnsCategories) { @($Config.Dns.NextDnsCategories) } else { @('porn','piracy') }
    $c = @($ids | ForEach-Object { @{id=$_;active=$true} })
    $s = @($Config.Dns.NextDnsServices | ForEach-Object { @{id=$_;active=$true} })
    @{security=@{threatIntelligenceFeeds=$true;aiThreatDetection=$true;googleSafeBrowsing=$true;cryptojacking=$true;dnsRebinding=$true;idnHomographs=$true;typosquatting=$true;dga=$true;nrd=$true;ddns=$true;parking=$true;csam=$true};privacy=@{blocklists=@(@{id='nextdns-recommended'});natives=@(@{id='windows'});disguisedTrackers=$true;allowAffiliate=$false};parentalControl=@{services=$s;categories=$c;safeSearch=$true;youtubeRestrictedMode=$true;blockBypass=$true};settings=@{logs=@{enabled=$true;drop=@{ip=$true;domain=$false}};blockPage=@{enabled=$true};performance=@{cnameFlattening=$true}}}
}

function Get-NcSafeFirewallPolicy($Config) {
    $f = $Config.Firewall
    [pscustomobject]@{Inbound=if ($f.DefaultInboundAction) { $f.DefaultInboundAction } else { 'Block' };Outbound=if ($f.DefaultOutboundAction) { $f.DefaultOutboundAction } else { 'Allow' }}
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
        ListPrograms { Get-NcInstalledPrograms }
        ConfigureDns {
            if (!$ConfirmApply) { throw 'ConfigureDns requires -ConfirmApply' }
            Set-NcWindowsRemoteDns $Config | Out-Null
        }
        ConfigureBrowserPolicies { if (!$ConfirmApply) { throw 'ConfigureBrowserPolicies requires -ConfirmApply' }; Set-NcBrowserPolicies }
        BlockPrograms { if (!$ConfirmApply) { throw 'BlockPrograms requires -ConfirmApply' }; Set-NcProgramRules $ProgramPath $true }
        UnblockPrograms { if (!$ConfirmApply) { throw 'UnblockPrograms requires -ConfirmApply' }; Set-NcProgramRules $ProgramPath $false }
        Apply {
            if (!$ConfirmApply) { throw 'Apply requires -ConfirmApply' }
            Export-NcFirewallBackup $Config | Out-Null
            Invoke-NcNextDnsProfile $Config
            $p = Get-NcSafeFirewallPolicy $Config
            Get-NetFirewallProfile | Set-NetFirewallProfile -DefaultInboundAction $p.Inbound -DefaultOutboundAction $p.Outbound
            Set-NcWindowsRemoteDns $Config | Out-Null
        }
        RemoveManagedRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" | Remove-NetFirewallRule }
        RemoveManagedConfiguration { if (!$ConfirmApply) { throw 'RemoveManagedConfiguration requires -ConfirmApply' }; Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" | Remove-NetFirewallRule; Remove-NcBrowserPolicies; Remove-NcWindowsRemoteDns $Config }
        Restore { Restore-NcFirewallBackup $BackupPath }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $c = if ($ConfigPath) { Get-Content $ConfigPath -Raw | ConvertFrom-Json } else { Get-NcDefaultConfig }
    Invoke-Nc $Mode $c
}

if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Get-NcDefaultConfig,Get-NcRuleName,Get-NcInstalledPrograms,Get-NcProgramPaths,Get-NcDefaultConfig,Test-NcConfig,Get-NcBackupPath,Export-NcFirewallBackup,Restore-NcFirewallBackup,Get-NcRemoteDnsPlan,Get-NcNextDnsHeaders,Invoke-NcNextDnsCategory,Get-NcNextDnsActions,Get-NcRequiredNextDnsFeatures,Get-NcNextDnsProfilePayload,Get-NcSafeFirewallPolicy,Invoke-NcNextDnsProfile,Set-NcWindowsRemoteDns,Remove-NcWindowsRemoteDns,Invoke-Nc
}

