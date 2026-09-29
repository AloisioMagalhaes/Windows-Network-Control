[CmdletBinding()]
param(
    [ValidateSet('Simulate','Status','ListRules','Apply','RemoveManagedRules','Restore')]
    [string]$Mode='Simulate',
    [string]$ConfigPath,
    [switch]$ConfirmApply
)

$script:NcCategories = @('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')

function Get-NcDefaultConfig {
    [pscustomobject]@{
        RulePrefix='NWC'
        Dns=[pscustomobject]@{Provider='Technitium';Categories=@('advertising_tracking','adult','torrents','p2p_file_sharing','gaming','proxy_vpn')}
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
    if ($Config.Dns.Provider -notin @('Technitium','AdGuardHome','Pi-hole')) { throw 'DNS provider must be a self-hosted open-source provider' }
    $bad = @($Config.Dns.Categories | Where-Object { $_ -notin $script:NcCategories })
    if ($bad) { throw "Unsupported DNS category: $($bad -join ', ')" }
    $true
}

function Invoke-Nc([string]$Mode,$Config) {
    Test-NcConfig $Config | Out-Null
    switch ($Mode) {
        Simulate { 'SIMULATION: no changes applied' }
        Status { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction }
        ListRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" }
        Apply {
            if (!$ConfirmApply) { throw 'Apply requires -ConfirmApply' }
            Get-NetFirewallProfile | Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block
        }
        RemoveManagedRules { Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like "$($Config.RulePrefix)-*" | Remove-NetFirewallRule }
        Restore { throw 'Restore requires a backup path in a future increment' }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $c = if ($ConfigPath) { Get-Content $ConfigPath -Raw | ConvertFrom-Json } else { Get-NcDefaultConfig }
    Invoke-Nc $Mode $c
}
