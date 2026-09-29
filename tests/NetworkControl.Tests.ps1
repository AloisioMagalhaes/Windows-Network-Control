Import-Module "$PSScriptRoot\..\src\NetworkControl.psm1" -Force

Describe 'NetworkControl' {

    It 'gera nomes de regra estáveis' {
        if ((Get-NcRuleName -Kind 'Program' -Value 'C:\App\a.exe') -ne 'NWC-Program-a.exe') { throw 'unexpected rule name' }
    }

    It 'aceita categorias DNS suportadas' {
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'NextDNS'; ProfileId='abc123'; ApiBaseUrl='https://api.nextdns.io'; DohTemplate='https://dns.nextdns.io/{ProfileId}'; Categories = @('adult','torrents') } } } catch { throw }
    }

    It 'rejeita categoria DNS desconhecida' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'NextDNS'; ProfileId='abc123'; ApiBaseUrl='https://api.nextdns.io'; DohTemplate='https://dns.nextdns.io/{ProfileId}'; Categories = @('unknown') } } } catch { $threw = $true }
        if (!$threw) { throw 'unknown category was accepted' }
    }

    It 'rejeita provedor pago ou não auto-hospedado' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'CleanBrowsing'; Categories = @() } } } catch { $threw = $true }
        if (!$threw) { throw 'unsupported provider was accepted' }
    }

    It 'mantém navegadores permitidos por padrão' {
        $c = Get-NcDefaultConfig
        if (!$c.Exceptions.AllowBrowsers) { throw 'browsers are not allowed by default' }
    }

    It 'simulação não aplica regras' {
        if ((Invoke-Nc -Mode Simulate -Config (Get-NcDefaultConfig)) -notmatch 'SIMULATION') { throw 'simulation marker missing' }
    }

    It 'gera caminho de backup dentro do diretório configurado' {
        $p = Get-NcBackupPath -Config ([pscustomobject]@{ BackupDirectory = 'C:\Backups' })
        if ($p -notmatch '^C:\\Backups\\NWC-firewall-[0-9]{8}-[0-9]{6}\.wfw$') { throw "unexpected backup path: $p" }
    }

    It 'exige diretório de backup na configuração' {
        $threw = $false
        try { Test-NcConfig -Config @{ Dns = @{ Provider = 'NextDNS'; Categories = @() } } } catch { $threw = $true }
        if (!$threw) { throw 'missing backup directory was accepted' }
    }

    It 'rejeita endpoint DNS remoto sem HTTPS' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'NextDNS'; ProfileId='abc123'; ApiBaseUrl='https://api.nextdns.io'; DohTemplate='http://dns.local'; Categories = @() } } } catch { $threw = $true }
        if (!$threw) { throw 'insecure DNS endpoint was accepted' }
    }

    It 'aceita NextDNS como provedor remoto' {
        $c = Get-NcDefaultConfig
        $c.Dns.Provider = 'NextDNS'
        $c.Dns.ProfileId = 'abc123'
        $c.Dns.ApiBaseUrl = 'https://api.nextdns.io'
        if (!(Test-NcConfig $c)) { throw 'NextDNS configuration was rejected' }
    }

    It 'gera plano DoH nativo sem dependência local' {
        $p = Get-NcRemoteDnsPlan -Config ([pscustomobject]@{ BackupDirectory='C:\Backups'; Dns = [pscustomobject]@{ Provider='NextDNS'; ProfileId='abc123'; ApiBaseUrl='https://api.nextdns.io'; Mode='DoH'; DohBootstrapServers=@('45.90.28.0','45.90.30.0'); DohTemplate='https://dns.nextdns.io/{ProfileId}'; DotHostname='{ProfileId}.dns.nextdns.io'; Ipv6Servers=@('2a07:a8c0::92:3be7','2a07:a8c1::92:3be7'); LinkedIpv4Servers=@('45.90.28.212','45.90.30.212'); Categories=@() } })
        if ($p.Provider -ne 'NextDNS' -or $p.Template -ne 'https://dns.nextdns.io/abc123' -or $p.DotHostname -ne 'abc123.dns.nextdns.io' -or $p.BootstrapServers.Count -ne 2 -or $p.Ipv6Servers.Count -ne 2 -or $p.LinkedIpv4Servers.Count -ne 2) { throw 'invalid remote DNS plan' }
    }

    It 'mapeia categorias suportadas para ações da API remota' {
        $c = Get-NcDefaultConfig
        $c.Dns.ProfileId = 'abc123'
        $a = Get-NcNextDnsActions $c
        if (($a.Id -notcontains 'porn') -or ($a.Id -notcontains 'nextdns-recommended')) { throw 'required NextDNS actions missing' }
    }

    It 'mantém recursos obrigatórios do NextDNS ativados' {
        $c = Get-NcDefaultConfig
        if (@(Get-NcRequiredNextDnsFeatures $c).Count) { throw 'mandatory NextDNS features are disabled' }
        if ($c.Dns.MandatoryFeatures.AllowAffiliateTrackingLinks) { throw 'affiliate tracking is enabled' }
    }

    It 'gera payload completo para proteção NextDNS' {
        $p = Get-NcNextDnsProfilePayload (Get-NcDefaultConfig)
        if (!$p.security.threatIntelligenceFeeds -or !$p.security.aiThreatDetection -or !$p.security.googleSafeBrowsing -or !$p.security.cryptojacking -or !$p.security.dnsRebinding -or !$p.security.idnHomographs -or !$p.security.typosquatting -or !$p.security.dga -or !$p.security.nrd -or !$p.security.ddns -or !$p.security.parking -or !$p.security.csam -or !$p.privacy.disguisedTrackers -or $p.privacy.allowAffiliate -or !$p.parentalControl.safeSearch -or !$p.parentalControl.youtubeRestrictedMode -or !$p.parentalControl.blockBypass -or ($p.parentalControl.categories.id -notcontains 'porn') -or ($p.parentalControl.categories.id -notcontains 'piracy') -or !$p.settings.logs.enabled -or !$p.settings.blockPage.enabled) { throw 'incomplete NextDNS payload' }
    }

    It 'oferece modo de configuração DoH sem API key' {
        if ((Get-Content (Join-Path $PSScriptRoot '..\src\NetworkControl.ps1') -Raw) -notmatch "ConfigureDns") { throw 'ConfigureDns mode missing' }
    }

    It 'preserva saída padrão para evitar perda de serviços essenciais' {
        $p = Get-NcSafeFirewallPolicy (Get-NcDefaultConfig)
        if ($p.Inbound -ne 'Block' -or $p.Outbound -ne 'Allow') { throw 'unsafe firewall baseline' }
    }
}
