. "$PSScriptRoot\..\src\NetworkControl.ps1"

Describe 'NetworkControl' {

    It 'gera nomes de regra estáveis' {
        if ((Get-NcRuleName -Kind 'Program' -Value 'C:\App\a.exe') -ne 'NWC-Program-a.exe') { throw 'unexpected rule name' }
    }

    It 'aceita categorias DNS suportadas' {
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Categories = @('adult','torrents') } } } catch { throw }
    }

    It 'rejeita categoria DNS desconhecida' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Categories = @('unknown') } } } catch { $threw = $true }
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
        try { Test-NcConfig -Config @{ Dns = @{ Provider = 'Technitium'; Categories = @() } } } catch { $threw = $true }
        if (!$threw) { throw 'missing backup directory was accepted' }
    }

    It 'rejeita endpoint DNS remoto sem HTTPS' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Endpoint = 'http://dns.local'; Categories = @() } } } catch { $threw = $true }
        if (!$threw) { throw 'insecure DNS endpoint was accepted' }
    }
}
