[CmdletBinding()]
param([string]$Path = (Join-Path $PSScriptRoot '..\README.md'))

$ErrorActionPreference = 'Stop'
$t = Get-Content -Raw -LiteralPath $Path
$r = @(
    @{N='objetivo';P='## 1. Objetivo'}, @{N='escopo';P='## 2. Escopo'},
    @{N='limitacoes';P='## 3. Limitações técnicas'}, @{N='requisitos';P='## 5. Requisitos funcionais'},
    @{N='aceitacao';P='## 11. Testes de aceitação'}, @{N='conclusao';P='## 13. Critério de conclusão'},
    @{N='rastreabilidade';P='## 15. Rastreabilidade obrigatória antes do merge'}, @{N='observabilidade';P='## 16. Automação, logs e observabilidade'},
    @{N='fundamentacao';P='## 17. Fundamentação científica e acadêmica'}, @{N='referencias';P='## 18. Referências'},
    @{N='perfil';P='923be7'}, @{N='doh';P='https://dns.nextdns.io/923be7'}, @{N='dot';P='923be7.dns.nextdns.io'},
    @{N='ipv6';P='2a07:a8c0::92:3be7'}, @{N='historico';P='Registro de alterações'}, @{N='abnt';P='ABNT NBR 6023:2018'},
    @{N='actions';P='.github/workflows/verify.yml'}, @{N='segredo';P='NEXTDNS_API_KEY'}
)
$e = @($r | Where-Object { $t -notmatch [regex]::Escape($_.P) })
if ($e) { $e | ForEach-Object { Write-Error "README requirement missing: $($_.N)" }; exit 1 }
if ($t -notmatch 'releases/download/v0\.1\.9/Windows-Network-Control-v0\.1\.9\.zip') { throw 'remote release command version is outdated' }
if ($t -notmatch 'db6555758e750f3513effc5b8db1b1bfaaa3cd4b1b8bc582841743276684584c') { throw 'remote release command hash is outdated' }
$n = ([regex]::Matches($t, '(?m)^\| 20\d\d-\d\d-\d\d \|')).Count
if ($n -lt 1) { Write-Error 'README change log is empty'; exit 1 }
"README validation passed: $($r.Count) requirements, $n change-log entries"
