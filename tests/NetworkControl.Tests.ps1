Describe 'NetworkControl' {
    . "$PSScriptRoot\..\src\NetworkControl.ps1"

    It 'gera nomes de regra estáveis' {
        Get-NcRuleName -Kind 'Program' -Value 'C:\App\a.exe' | Should Be 'NWC-Program-a.exe'
    }

    It 'aceita categorias DNS suportadas' {
        { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Categories = @('adult','torrents') } } } | Should Not Throw
    }

    It 'rejeita categoria DNS desconhecida' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Categories = @('unknown') } } } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'rejeita provedor pago ou não auto-hospedado' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'CleanBrowsing'; Categories = @() } } } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'mantém navegadores permitidos por padrão' {
        $c = Get-NcDefaultConfig
        $c.Exceptions.AllowBrowsers | Should Be $true
    }

    It 'simulação não aplica regras' {
        Invoke-Nc -Mode Simulate -Config (Get-NcDefaultConfig) | Should Match 'SIMULATION'
    }

    It 'gera caminho de backup dentro do diretório configurado' {
        $p = Get-NcBackupPath -Config ([pscustomobject]@{ BackupDirectory = 'C:\Backups' })
        $p | Should Match '^C:\\Backups\\NWC-firewall-[0-9]{8}-[0-9]{6}\.wfw$'
    }

    It 'exige diretório de backup na configuração' {
        $threw = $false
        try { Test-NcConfig -Config @{ Dns = @{ Provider = 'Technitium'; Categories = @() } } } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'rejeita endpoint DNS remoto sem HTTPS' {
        $threw = $false
        try { Test-NcConfig -Config @{ BackupDirectory = 'C:\Backups'; Dns = @{ Provider = 'Technitium'; Endpoint = 'http://dns.local'; Categories = @() } } } catch { $threw = $true }
        $threw | Should Be $true
    }
}
