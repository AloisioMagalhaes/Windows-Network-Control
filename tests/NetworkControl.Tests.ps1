Describe 'NetworkControl' {
    . "$PSScriptRoot\..\src\NetworkControl.ps1"

    It 'gera nomes de regra estáveis' {
        Get-NcRuleName -Kind 'Program' -Value 'C:\App\a.exe' | Should Be 'NWC-Program-a.exe'
    }

    It 'aceita categorias DNS suportadas' {
        { Test-NcConfig -Config @{ Dns = @{ Provider = 'CleanBrowsing'; Categories = @('adult','torrents') } } } | Should Not Throw
    }

    It 'rejeita categoria DNS desconhecida' {
        $threw = $false
        try { Test-NcConfig -Config @{ Dns = @{ Provider = 'CleanBrowsing'; Categories = @('unknown') } } } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'mantém navegadores permitidos por padrão' {
        $c = Get-NcDefaultConfig
        $c.Exceptions.AllowBrowsers | Should Be $true
    }

    It 'simulação não aplica regras' {
        Invoke-Nc -Mode Simulate -Config (Get-NcDefaultConfig) | Should Match 'SIMULATION'
    }
}
