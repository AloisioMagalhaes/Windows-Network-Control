# Windows Network Control

## Comece aqui: explicação para iniciantes

Este projeto é um **controle de rede para Windows**. Pense nele como três camadas:

1. **Firewall:** controla quais programas podem receber ou enviar conexões.
2. **NextDNS:** filtra sites por categorias, como anúncios, pornografia, pirataria e jogos.
3. **Políticas dos navegadores:** orientam Chrome, Edge, Firefox e Brave a usar o DNS configurado no Windows.

O programa não “vigia” a tela dos alunos e não bloqueia todos os programas automaticamente. O administrador escolhe os executáveis que deseja bloquear. O DNS também não identifica todos os processos: ele filtra nomes de sites.

### Caminho seguro de cinco passos

Abra o PowerShell como **Administrador**. Primeiro baixe a ferramenta publicada e valide a release antes de executá-la:

```powershell
$d="$env:TEMP\NWC-bootstrap.ps1"; Invoke-WebRequest 'https://raw.githubusercontent.com/AloisioMagalhaes/Windows-Network-Control/v0.1.34/tools/Invoke-RemoteRelease.ps1' -OutFile $d; Unblock-File $d; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Simulate
```

1. Veja o que aconteceria, sem alterar o computador:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Simulate
```

2. Veja o estado atual:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Status
```

3. Faça um backup antes de aplicar mudanças:

```powershell
$b="$env:USERPROFILE\Desktop\NWC-firewall-backup-$(Get-Date -Format yyyyMMdd-HHmmss).wfw"; netsh advfirewall export $b; Test-Path $b
```

4. Configure o DNS e os navegadores, se essa for a política desejada:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ConfigureDns -ConfirmApply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ConfigureBrowserPolicies -ConfirmApply
```

5. Para desfazer as configurações gerenciadas pelo projeto:

```powershell
& $d -Mode RemoveManagedConfiguration -ConfirmApply
```

**Regra simples:** `Simulate` apenas informa; `List` apenas consulta; `Block`, `Configure`, `Apply` e `Remove` alteram o computador; `Restore` usa um backup para voltar ao estado salvo.

### Dicionário rápido

| Termo | Explicação simples |
|---|---|
| DoH | DNS protegido dentro de HTTPS. |
| API key | Senha técnica usada para alterar o perfil NextDNS. |
| Programa bloqueado | Executável com regra de firewall impedindo entrada e saída. |
| Regra `NWC-*` | Regra criada e identificada por este projeto. |
| `-ConfirmApply` | Confirma que uma operação poderá alterar o Windows. |
| Backup `.wfw` | Arquivo com as regras do firewall para restauração. |

As seções seguintes detalham requisitos, limitações, arquitetura, testes e rastreabilidade para quem precisa auditar o projeto.

## 1. Objetivo

Criar um script PowerShell rastreável para configurar o DNS-over-HTTPS nativo do Windows, administrar um perfil NextDNS por API e aplicar uma política inicial do Windows Defender Firewall.

O estado atual é um MVP administrativo: ele configura DoH, sincroniza a política remota quando há API key, exporta backup e ajusta as ações padrão dos perfis do firewall. Ele ainda não implementa uma allowlist completa de aplicações, políticas automáticas de navegadores ou detecção genérica de virtualização.

## 2. Escopo

O escopo planejado inclui:

- Configurar os perfis Domínio, Privado e Público.
- Definir bloqueio padrão para entrada e saída.
- Criar regras locais para processos, serviços, portas, protocolos, endereços IP, domínios resolvidos e interfaces de rede (planejado; não entregue integralmente no MVP atual).
- Bloquear aplicações não essenciais cadastradas pelo usuário.
- Bloquear navegadores somente quando explicitamente configurado; navegadores deverão permanecer permitidos por padrão.
- Bloquear torrent, pornografia, anúncios, rastreadores e jogos online por filtragem DNS categorizada.
- Bloquear emuladores e aplicações relacionadas por executável, serviço, driver, porta, endereço IP ou interface de rede conhecida.
- Permitir listas de inclusão e exclusão.
- Registrar alterações e permitir reversão segura. No MVP atual, a auditoria detalhada ainda é limitada ao transcript do operador e aos logs do workflow.

## 3. Limitações técnicas

- O Firewall do Windows não identifica virtualização genericamente.
- O bloqueio de emuladores deverá usar processos, serviços, drivers, interfaces, portas, endereços IP e caminhos conhecidos.
- DNS bloqueia domínios, não processos locais, virtualização ou todo tráfego criptografado.
- Domínios novos, CDNs compartilhadas, VPNs, DoH, DoT e endereços IP diretos podem contornar filtros DNS.
- O bloqueio por domínio é realizado pelo perfil NextDNS; o script não inspeciona o conteúdo das conexões nem identifica processos a partir de consultas DNS.
- O modo `Apply` altera ações padrão dos perfis do firewall, mas não cria automaticamente uma allowlist completa de aplicações.

## 4. Provedor DNS remoto

O sistema deverá configurar o DNS remoto diretamente no Windows, sem instalar cliente, serviço, daemon, runtime ou dependência adicional no computador.

### Requisito de custo e licença

O provedor DNS deverá possuir plano gratuito documentado, API HTTPS, filtragem por perfil e limite compatível com o MVP. O limite gratuito deverá ser verificado antes de cada release, pois pode mudar.

O projeto não deverá depender de um servidor DNS local. A API será usada somente para administrar o perfil remoto; as consultas do Windows serão encaminhadas ao provedor pela configuração nativa de DNS sobre HTTPS (DoH).

### Provedor selecionado para o MVP

NextDNS será o primeiro adaptador remoto. A lista Free-for-Dev registra 300 mil consultas mensais gratuitas. A API oficial permite administrar perfis, listas permitidas, listas negadas e categorias; o Windows 11 permite configurar o endpoint DoH nativamente usando os endereços de bootstrap `45.90.28.0` e `45.90.30.0`.

Referências: https://github.com/ripienaar/free-for-dev, https://nextdns.github.io/api/, https://learn.microsoft.com/en-us/powershell/module/dnsclient/get-dnsclientdohserveraddress

### Perfil configurado no MVP

O arquivo `config/example.json` usa o perfil remoto `923be7`:

| Transporte | Configuração |
|---|---|
| DNS over HTTPS | `https://dns.nextdns.io/923be7` |
| DNS over TLS/QUIC | `923be7.dns.nextdns.io` |
| IPv6 primário | `2a07:a8c0::92:3be7` |
| IPv6 secundário | `2a07:a8c1::92:3be7` |
| IPv4 bootstrap DoH | `45.90.28.0`, `45.90.30.0` |
| IPv4 com IP vinculado | `45.90.28.212`, `45.90.30.212` |

Os endereços com IP vinculado somente deverão ser usados depois que o IP público da rede estiver associado ao perfil NextDNS. Para computadores móveis, o MVP prioriza DoH por perfil. O perfil e seus limites devem ser confirmados antes de cada release.

### Recursos do provedor e política obrigatória

Com base nos recursos oficiais do NextDNS, o MVP deverá manter ativados:

- **NextDNS Ads & Trackers Blocklist**: bloqueio inicial de anúncios e rastreadores;
- **Threat Intelligence Feeds**: bloqueio de domínios associados a malware, phishing e ameaças conhecidas;
- **Native Tracking Protection**: proteção contra rastreamento em nível de sistema operacional;
- **Block Disguised Third-Party Trackers**: detecção de rastreadores que se apresentam como domínios próprios;
- **Block Bypass Methods**: bloqueio de métodos conhecidos de contorno, como proxies, VPNs e Tor, quando disponível no perfil;
- **Porn**: bloqueio obrigatório de conteúdo adulto;
- **Piracy**: bloqueio obrigatório de torrent e domínios de compartilhamento P2P classificados;
- **SafeSearch**: filtragem de resultados explícitos em mecanismos compatíveis.

O recurso **Allow Affiliate & Tracking Links** deverá permanecer desativado, pois o objetivo do projeto prioriza redução de rastreamento. Listas adicionais agressivas, como listas comunitárias extensas, são opcionais até que sejam avaliadas por falsos positivos e compatibilidade com Windows, atualizações e navegadores.

O bloqueio de jogos online deverá usar serviços e domínios explicitamente selecionados no controle parental; a existência de uma categoria de jogos não será presumida como universal. Emuladores, processos locais e virtualização continuam sendo responsabilidade das regras do firewall, pois blocklists DNS só atuam sobre domínios.

Fonte da seleção: [NextDNS](https://nextdns.io/), [metadados oficiais de privacidade e controle parental](https://github.com/nextdns/metadata), [blocklist recomendada](https://github.com/nextdns/blocklists/blob/main/blocklists/nextdns-recommended.json) e [API de perfis](https://nextdns.github.io/api/).

### Política NextDNS maximizada

Quando `Apply` é executado com `NEXTDNS_API_KEY`, o payload ativa os recursos de segurança documentados pela API: Threat Intelligence, AI Threat Detection, Google Safe Browsing, Cryptojacking, DNS Rebinding, IDN Homographs, Typosquatting, DGA, NRD, DDNS, Parked Domains e CSAM. Também ativa blocklist recomendada, Native Tracking para Windows, rastreadores disfarçados, logs com remoção do IP, block page, SafeSearch, YouTube Restricted Mode e Block Bypass Methods.

O exemplo ativa as categorias NextDNS `porn`, `piracy`, `gambling`, `dating`, `gaming`, `social-networks` e `video-streaming`. Serviços específicos de jogos, redes sociais ou streaming devem ser adicionados em `NextDnsServices` somente após validação dos logs, porque o bloqueio por DNS pode afetar domínios compartilhados. Essas configurações ampliam a cobertura remota, mas não transformam DNS em identificação de processo, bloqueio de executável, controle de virtualização ou política de navegador.

### Configuração nativa no Windows 11

O modo padrão do projeto é DoH sem instalação de aplicativo:

1. Abra **Configurações** → **Rede e Internet**.
2. Selecione **Wi-Fi** ou **Ethernet**.
3. Abra **Propriedades de hardware** ou avance diretamente em Ethernet.
4. Em **Atribuição de servidor DNS**, selecione **Editar** e depois **Manual**.
5. Ative IPv4.
6. Informe `45.90.28.0` como DNS preferencial, ative DoH e use o modelo `https://dns.nextdns.io/923be7`.
7. Informe `45.90.30.0` como DNS alternativo, ative DoH e use o mesmo modelo.
8. Salve.

O script automatiza essa configuração quando executado como Administrador e quando os cmdlets nativos de DoH estiverem disponíveis.

### Configuração dos navegadores

Para evitar que um navegador use um resolvedor diferente do Windows, configure o mesmo endpoint personalizado:

- Chrome: **Configurações** → **Privacidade e segurança** → **Segurança** → **Usar DNS seguro** → provedor personalizado.
- Edge: **Configurações** → **Privacidade, pesquisa e serviços** → **Usar DNS seguro** → provedor personalizado.
- Brave: **Configurações** → **Privacidade e segurança** → **Segurança** → **Usar DNS seguro** → provedor personalizado.
- Firefox: **Configurações** → **Privacidade e segurança** → **DNS sobre HTTPS** → **Personalizado**.

Em todos os casos, use `https://dns.nextdns.io/923be7`.

### IPv6 e roteador

Em redes com IPv6, configure no roteador `2a07:a8c0::92:3be7` e `2a07:a8c1::92:3be7`. Se a interface não aceitar a forma abreviada, use `2a07:a8c0:0000:0000:0000:0000:0092:3be7` e `2a07:a8c1:0000:0000:0000:0000:0092:3be7`. O acesso ao roteador e a alteração de DNS são responsabilidades do usuário e não são executados pelo GitHub Actions.

O perfil NextDNS deverá ser criado pelo usuário. A chave ficará somente em `NEXTDNS_API_KEY` ou mecanismo equivalente de segredo. Ela nunca deverá ser gravada no repositório, no arquivo de configuração ou nos logs.

### Segredo do NextDNS

O segredo do repositório foi validado com o nome `NEXTDNS_API_KEY` em **Settings → Secrets and variables → Actions**. O valor nunca é exibido, lido ou gravado por este projeto. Para execução local, configure a mesma variável no perfil do usuário e abra um novo PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('NEXTDNS_API_KEY','SUA_CHAVE','User')
```

O modo `ConfigureDns` não exige essa chave. O modo `Apply` exige a variável para sincronizar a política remota do perfil `923be7`.

O projeto deverá abstrair o provedor por adaptador, mas não poderá considerar gratuito, remoto ou filtrável um provedor sem comprovação atual de API, limites e categorias.

## 5. Requisitos funcionais

### RF01 — Privilégios

Exigir execução como Administrador e interromper a operação com mensagem clara quando os privilégios forem insuficientes.

### RF02 — Backup

Exportar a configuração atual do firewall antes de qualquer alteração.

### RF03 — Aplicação

No MVP, aplicar ações padrão de bloqueio aos perfis Domínio, Privado e Público. Regras granulares de programas e serviços permanecem evolução planejada.

### RF04 — Regras próprias

Identificar todas as regras criadas pelo sistema com prefixo exclusivo e metadados suficientes para reversão.

### RF05 — Processos

Planejar bloqueio de executáveis por caminho absoluto e validação do arquivo. Esta capacidade não está completa no script atual.

### RF06 — Serviços e drivers

Planejar cadastro de serviços, drivers e componentes associados a emuladores e plataformas de virtualização. Não é aplicado automaticamente no MVP atual.

### RF07 — Emuladores

Manter uma lista configurável futura para aplicações como BlueStacks, Android Studio Emulator, VirtualBox, VMware, Hyper-V, WSL e Windows Subsystem for Android, sem presumir instalação. A identificação automática ainda não foi entregue.

### RF08 — Rede

Permitir regras por direção, protocolo, porta, endereço remoto, endereço local e interface de rede.

### RF09 — DNS

Configurar o endpoint DoH nativo sem API key no modo `ConfigureDns`; no modo `Apply`, autenticar a API com `NEXTDNS_API_KEY` e enviar o payload de segurança, privacidade e controle parental configurado.

### RF10 — Categorias

Enviar ao NextDNS a blocklist recomendada, inteligência de ameaças, proteção nativa, rastreadores disfarçados, SafeSearch, bloqueio de bypass, pornografia e pirataria. Jogos, processos, emuladores e VPNs locais ainda não possuem implementação granular completa.

### RF11 — Exceções

Preservar a configuração declarada de exceções no arquivo de exemplo; a aplicação granular dessas exceções no firewall permanece pendente.

### RF12 — Simulação

Oferecer modo de simulação que liste as alterações sem aplicá-las.

### RF13 — Validação

Validar privilégios, perfis, caminhos, serviços, parâmetros, conectividade DNS e respostas da API antes da aplicação.

### RF14 — Auditoria

Gerar transcript ou log operacional quando executado pelo operador ou workflow, sem registrar chaves de API. Auditoria detalhada por regra será implementada junto às regras granulares.

### RF15 — Consulta

Permitir listar regras próprias, exceções ativas, categorias DNS, processos cadastrados e estado atual.

### RF16 — Reversão

Permitir restaurar o backup ou remover exclusivamente as regras criadas pelo sistema.

### RF17 — Idempotência

Executar repetidamente sem duplicar regras nem alterar configurações fora do escopo.

### RF18 — DoH obrigatório no Windows

Configurar os servidores `45.90.28.0` e `45.90.30.0` com o modelo DoH do perfil `923be7`, sem fallback UDP, quando o modo `ConfigureDns` for executado como Administrador.

### RF19 — Políticas de navegadores

Administradores deverão poder impor o endpoint `https://dns.nextdns.io/923be7` como DNS seguro obrigatório em Chrome, Edge, Brave e Firefox. No estado atual, o repositório apenas documenta a política centralizada por Diretiva de Grupo ou Intune; a aplicação automática dessas políticas pelo script permanece pendente e não deve ser considerada entregue.

### RF20 — Bloqueio de contorno

Bloquear ou restringir DNS externo UDP/TCP 53, DNS-over-TLS TCP 853, provedores DoH não autorizados, VPN, proxy e Tor, preservando exceções administrativas documentadas. Atualmente, apenas o recurso `Block Bypass Methods` é enviado ao perfil NextDNS; o bloqueio local completo permanece pendente.

### RF21 — Implantação rastreável

Permitir execução por terminal administrativo em cada computador, validar o artefato por SHA-256, registrar transcript local e identificar o dispositivo no perfil NextDNS por nome compatível com a política do provedor.

## 6. Requisitos não funcionais

- Compatibilidade com Windows PowerShell 5.1.
- Compatibilidade com PowerShell 7 quando os cmdlets utilizados estiverem disponíveis.
- Nenhuma dependência externa obrigatória para o firewall.
- Nenhuma instalação silenciosa de software.
- Segredos fornecidos por parâmetro seguro, variável de ambiente ou arquivo protegido.
- Código modular, validado e reversível.
- Mensagens em português claro.
- Saída adequada para uso manual e automação.
- Códigos de retorno distintos para sucesso, erro de validação, erro de privilégio, falha de API e falha de aplicação.

## 7. Interface esperada

O script deverá oferecer operações equivalentes a:

```powershell
.\NetworkControl.ps1 -Mode Simulate
.\NetworkControl.ps1 -Mode ConfigureDns -ConfirmApply
.\NetworkControl.ps1 -Mode Apply
.\NetworkControl.ps1 -Mode Status
.\NetworkControl.ps1 -Mode ListRules
.\NetworkControl.ps1 -Mode Restore
.\NetworkControl.ps1 -Mode RemoveManagedRules
```

Os nomes finais dos parâmetros poderão ser ajustados, desde que documentados e consistentes.

## 8. Exclusões mínimas padrão

O sistema deverá preservar, salvo alteração explícita do usuário:

- componentes essenciais do Windows;
- Windows Update;
- DNS e DHCP;
- sincronização de horário;
- Microsoft Defender e recursos de segurança;
- gerenciamento remoto autorizado;
- navegadores instalados;
- serviços necessários ao funcionamento do sistema.

## 9. Estrutura esperada

```text
README.md
LICENSE
src/NetworkControl.ps1
config/default.json
config/example.json
tests/NetworkControl.Tests.ps1
docs/restore.md
docs/security.md
CHANGELOG.md
```

## 10. Segurança

- Nunca gravar chaves de API no repositório.
- Fornecer arquivo de exemplo sem segredos.
- Validar entradas contra injeção de argumentos e caminhos inválidos.
- Não remover regras existentes sem backup e confirmação explícita.
- Não desativar o firewall para aplicar configurações.
- Não bloquear componentes críticos automaticamente.
- Informar claramente que a configuração pode interromper conectividade.

## 11. Testes de aceitação

- O script recusa execução sem privilégios administrativos.
- O modo de simulação não altera o firewall.
- O backup é criado antes da aplicação.
- A aplicação é idempotente.
- As regras próprias podem ser listadas e removidas.
- A restauração recupera a configuração anterior.
- As categorias DNS configuradas são enviadas corretamente à API.
- Falhas da API não removem regras já existentes.
- Navegadores e componentes essenciais permanecem funcionais por padrão.
- Processos e serviços cadastrados serão bloqueados nas direções configuradas quando essa funcionalidade estiver implementada.
- Logs não expõem segredos.
- O modo `ConfigureDns` funciona sem API key e não altera o firewall.
- O modo `Apply` exige API key, privilégios administrativos e backup anterior.
- Quando políticas centralizadas forem aplicadas externamente, os navegadores administrados não poderão selecionar livremente outro provedor DoH.
- Cada computador pode ser associado a um nome observável nos registros NextDNS.

## 12. Entrega

A release deverá conter:

- script PowerShell executável;
- arquivos de configuração de exemplo;
- testes;
- documentação de instalação, uso, validação e reversão;
- lista de limitações;
- histórico de alterações;
- instruções para criar e publicar a release no GitHub.

### Versionamento e publicação contínua

Todo merge efetivado em `main` deverá passar pelos testes e gerar uma versão patch automática no formato `v0.x.y`. O mesmo job do GitHub Actions deverá criar a tag, empacotar o artefato, gerar SHA-256 e publicar a release, pois uma tag criada pelo `GITHUB_TOKEN` não dispara outro workflow. A publicação ocorrerá somente depois da validação do README e dos testes; falhas não deverão criar release.

Alterações que exigirem decisão humana de compatibilidade, segurança ou mudança de contrato deverão usar versão minor/major manual e não depender da publicação automática de patch.

## 12.1 Limitações e soluções planejadas

| Limitação | Solução planejada | Evidência de conclusão |
|---|---|---|
| Navegadores podem usar DoH próprio | Políticas GPO/Intune ou módulo de políticas por navegador | Política aplicada e teste de endpoint em Chrome, Edge, Brave e Firefox |
| DNS não identifica processos ou emuladores | Regras de firewall por caminho, serviço, driver e processo | Teste controlado com aplicação autorizada e bloqueada |
| VPN, Tor, proxy e DoH alternativo podem contornar DNS | Bloquear portas, endpoints conhecidos e binários, preservando administração | Testes de conectividade e reversão |
| Firewall pode interromper Windows Update ou administração | Allowlist explícita, backup e modo simulação | Atualização e gerenciamento preservados após `Apply` |
| Categorias DNS podem gerar falsos positivos | Aplicar por perfil, analisar logs e manter denylist incremental | Relatório de bloqueios e exceções revisado |
| Distribuição manual não escala para laboratório | GPO, Intune ou execução remota autenticada | Inventário de computadores e logs por dispositivo |
| API key é segredo operacional | GitHub Secret, variável local protegida e nunca registrar valor | Auditoria sem segredo nos logs |
| Release automática pode publicar mudança inadequada | Testes obrigatórios, revisão de PR e patch automático limitado | Workflow aprovado e tag única |

## 13. Critério de conclusão

O projeto será considerado concluído quando o script puder criar backup, simular, aplicar, validar, consultar e reverter as regras de firewall, integrar um provedor DNS por API, configurar DoH sem API key, aplicar políticas dos quatro navegadores, bloquear contornos locais e categorias configuradas e preservar as exclusões padrão sem duplicar regras ou expor segredos. A distribuição em massa e o bloqueio local completo de contornos ainda não estão concluídos.

## 14. Desenvolvimento atual

### Entregue e utilizável

- configuração declarativa do perfil NextDNS `923be7`;
- validação de categorias, endpoints HTTPS e configuração;
- modo `Simulate`, sem alteração do sistema;
- modo `ConfigureDns`, que configura DoH nativo do Windows sem API key;
- modo `Apply`, que cria backup, ajusta ações padrão do firewall, sincroniza o payload NextDNS e configura DoH;
- modos `Status`, `ListRules`, `Restore` e `RemoveManagedRules`;
- autenticação da API somente por `NEXTDNS_API_KEY`;
- testes Pester e validação automatizada do README;
- empacotamento e publicação por GitHub Actions com checksum SHA-256.
- inventário de executáveis em `C:\Program Files` e `C:\Program Files (x86)`;
- bloqueio e desbloqueio seletivo de entrada e saída por múltiplos executáveis;
- política automática para desativar DoH próprio em Chrome, Edge, Brave e Firefox.

### Parcial ou dependente de configuração externa

- identificação do dispositivo depende de nome no endpoint DoH;
- categorias, blocklists e controles parentais são aplicados pelo perfil remoto NextDNS;
- políticas dos navegadores exigem execução local como Administrador e reinício dos processos;
- bloqueio de contorno depende do recurso NextDNS e não substitui regras locais;
- observabilidade detalhada depende dos logs do NextDNS e do transcript do operador.

### Ainda não entregue

- allowlist granular automática de aplicações no firewall;
- bloqueio automático por serviço, driver ou emulador;
- detecção genérica de virtualização;
- bloqueio local completo de DNS externo, DoT, DoH alternativo, VPN, proxy e Tor;
- distribuição em massa para todos os computadores da sala;
- inventário de programas fora dos diretórios padrão do `C:`;
- restauração automática das políticas de navegador anteriores.

O próximo incremento deve implementar regras locais de contorno, allowlist granular e distribuição em massa somente após testes de reversão, preservação das exceções do Windows e validação em computador de laboratório.

Execute os testes com:

```powershell
Invoke-Pester .\tests\NetworkControl.Tests.ps1 -PassThru
```

Para simular:

```powershell
.\src\NetworkControl.ps1 -Mode Simulate
```

Para configurar somente o DNS sobre HTTPS, sem chave de API:

```powershell
.\src\NetworkControl.ps1 -Mode ConfigureDns -ConfigPath .\config\example.json -ConfirmApply
```

Para aplicar as políticas, após revisar a simulação:

```powershell
.\src\NetworkControl.ps1 -Mode Apply -ConfigPath .\config\example.json -ConfirmApply
```

Para restaurar um backup:

```powershell
.\src\NetworkControl.ps1 -Mode Restore -BackupPath .\backups\NWC-firewall-AAAAMMDD-HHMMSS.wfw
```

### Execução remota por terminal nos computadores dos alunos

Execute em PowerShell iniciado como Administrador. O procedimento baixa a release, valida o SHA-256, extrai em diretório temporário, desbloqueia o script, configura o DoH e grava um transcript local. O modo `ConfigureDns` não exige API key e não aplica firewall.

```powershell
$r=Invoke-RestMethod 'https://api.github.com/repos/AloisioMagalhaes/Windows-Network-Control/releases/latest'
$n=$r.tag_name
$a=$r.assets | Where-Object name -eq "Windows-Network-Control-$n.zip"
$s=$r.assets | Where-Object name -eq "Windows-Network-Control-$n.zip.sha256"
$d=Join-Path $env:TEMP "Windows-Network-Control-$n"
$z="$d.zip"
$q="$d.sha256"
Remove-Item $d,$z -Recurse -Force -ErrorAction SilentlyContinue
Invoke-WebRequest $a.browser_download_url -OutFile $z
Invoke-WebRequest $s.browser_download_url -OutFile $q
$h=(Get-Content $q -Raw).Split()[0].ToLower()
if ((Get-FileHash $z -Algorithm SHA256).Hash.ToLower() -ne $h) { throw 'SHA-256 inválido' }
Expand-Archive $z $d -Force
Unblock-File "$d\src\NetworkControl.ps1"
Start-Transcript "$d\configure-dns.log" -Force
& "$d\src\NetworkControl.ps1" -Mode ConfigureDns -ConfigPath "$d\config\example.json" -ConfirmApply
Stop-Transcript
```

Valide com `Get-DnsClientDohServerAddress` e em `https://test.nextdns.io`. O comando resolve a release publicada mais recente e valida o SHA-256 do respectivo arquivo, evitando atualizar manualmente versão e hash no README. Para vários computadores, use GPO, Intune ou ferramenta de administração remota autenticada. Não distribua a API key no comando; `Apply` exige `NEXTDNS_API_KEY` por mecanismo protegido. As políticas dos navegadores podem ser aplicadas pelo próprio bootstrap com `ConfigureBrowserPolicies`.

O modo `Apply` exige `-ConfirmApply`, a variável `NEXTDNS_API_KEY` e cria o backup automaticamente. Para evitar perda de serviços essenciais, o MVP mantém entrada bloqueada e saída permitida por padrão; a saída só deverá ser bloqueada depois que uma allowlist granular for implementada e validada. Essa escolha segue a orientação da Microsoft para manter saída permitida na maioria das implantações e a recomendação de bloquear por exceção somente com regras explícitas (MICROSOFT, 2026; NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY, 2009). O payload remoto maximizado cobre os recursos de segurança, privacidade e controle parental declarados no perfil; processos, emuladores, virtualização, políticas de navegador e bloqueios locais de contorno continuam limitações do MVP.

### Inventário, bloqueio seletivo e políticas dos navegadores

```powershell
.\src\NetworkControl.ps1 -Mode ListPrograms
.\src\NetworkControl.ps1 -Mode BlockPrograms -ProgramPath 'C:\Program Files\Exemplo\app.exe','C:\Program Files (x86)\Outro\outro.exe' -ConfirmApply
.\src\NetworkControl.ps1 -Mode UnblockPrograms -ProgramPath 'C:\Program Files\Exemplo\app.exe' -ConfirmApply
.\src\NetworkControl.ps1 -Mode ConfigureBrowserPolicies -ConfirmApply
```

`ListPrograms` inventaria executáveis em `C:\Program Files` e `C:\Program Files (x86)`. O bloqueio cria regras gerenciadas de entrada e saída somente para os caminhos selecionados; nenhum programa é bloqueado automaticamente. A política dos navegadores desativa o DoH próprio de Chrome, Edge, Brave e Firefox para que usem o DNS do Windows configurado pelo `ConfigureDns`; exige Administrador e reinício dos navegadores.

### Bootstrap remoto curto com validação

Depois de baixar a release manualmente e revisar o arquivo, execute o bootstrap local com uma linha:

```powershell
.\tools\Invoke-RemoteRelease.ps1 -Mode Simulate
```

O bootstrap consulta a release mais recente com `Invoke-WebRequest`, baixa o ZIP e o arquivo `.sha256`, valida o hash antes de `Expand-Archive` e somente então chama `NetworkControl.ps1`. Para configurar o DoH:

```powershell
.\tools\Invoke-RemoteRelease.ps1 -Mode ConfigureDns -ConfirmApply
```

Não use `Invoke-WebRequest URL | Invoke-Expression`: o projeto exige validação do artefato antes da execução.

### Erro de política de execução

Se aparecer `PSSecurityException`, `UnauthorizedAccess` ou “a execução de scripts está desabilitada”, consulte as políticas sem alterá-las:

```powershell
Get-ExecutionPolicy -List
```

Use o launcher de sessão abaixo, que não grava uma nova política no computador:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Status
```

Se `MachinePolicy` ou `UserPolicy` estiver definido por Política de Grupo, o administrador responsável deve autorizar uma política adequada ou assinar o script. O projeto não recomenda alterar permanentemente `LocalMachine` para contornar esse controle.

Para uso remoto em uma linha, o bootstrap pode ser carregado por `irm` e executado com parâmetros:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/AloisioMagalhaes/Windows-Network-Control/v0.1.34/tools/Invoke-RemoteRelease.ps1'))) -Mode Simulate
```

O uso de uma tag fixa é obrigatório para implantação rastreável. A URL `main` é adequada somente para teste controlado. Mesmo iniciado por `irm`/`iex`, o bootstrap valida o SHA-256 da release antes de extrair e executar o script principal; requer conexão à API pública e aos assets do GitHub.

### Teste local dos modos

Execute o PowerShell como Administrador e baixe o bootstrap da release publicada:

```powershell
$d="$env:TEMP\NWC-bootstrap.ps1"; Invoke-WebRequest 'https://raw.githubusercontent.com/AloisioMagalhaes/Windows-Network-Control/v0.1.30/tools/Invoke-RemoteRelease.ps1' -OutFile $d; Unblock-File $d
```

Teste sem alterar o computador:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Simulate
```

Consulte o estado do firewall:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Status
```

Liste executáveis instalados nos diretórios padrão:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ListPrograms
& $d -Mode ListPrograms | Out-File "$env:TEMP\programas.txt"
```

Liste regras gerenciadas pelo projeto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ListRules
```

Bloqueie entrada e saída de um ou mais executáveis selecionados:

```powershell
& $d -Mode BlockPrograms -ProgramPath 'C:\Program Files\Exemplo\app.exe' -ConfirmApply
& $d -Mode BlockPrograms -ProgramPath 'C:\App1\a.exe','C:\App2\b.exe' -ConfirmApply
```

Remova as regras de bloqueio gerenciadas:

```powershell
& $d -Mode UnblockPrograms -ProgramPath 'C:\Program Files\Exemplo\app.exe' -ConfirmApply
```

Configure somente o DNS-over-HTTPS do Windows, sem API key:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ConfigureDns -ConfirmApply
```

Desative o DoH próprio de Chrome, Edge, Firefox e Brave para que usem o DNS do Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode ConfigureBrowserPolicies -ConfirmApply
```

Para aplicar backup, firewall, DNS e política remota NextDNS, forneça a chave somente na sessão atual:

```powershell
$env:NEXTDNS_API_KEY='SUA_CHAVE'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $d -Mode Apply -ConfirmApply
```

Localize e restaure um backup do firewall:

```powershell
Get-ChildItem .\backups\*.wfw
& $d -Mode Restore -BackupPath 'C:\caminho\backups\NWC-firewall-AAAAMMDD-HHMMSS.wfw'
```

Remova todas as regras `NWC-*` gerenciadas pelo projeto:

```powershell
& $d -Mode RemoveManagedRules
```

Para remover todas as configurações gerenciadas pelo projeto — regras `NWC-*`, políticas DoH dos navegadores e DoH/DNS configurado pelo script — use o modo explícito abaixo:

```powershell
& $d -Mode RemoveManagedConfiguration -ConfirmApply
```

Esse modo redefine os servidores DNS das interfaces físicas para o comportamento automático do Windows e remove somente as propriedades de política criadas pelo projeto. Ele não restaura políticas anteriores personalizadas; para o firewall, use o backup `.wfw` com `Restore`.

Sequência recomendada: `Simulate`, `Status`, `ListPrograms`, `ConfigureDns`, `ConfigureBrowserPolicies`, `BlockPrograms`, `ListRules`, `UnblockPrograms`. Execute `Apply` somente após revisar backup, chave NextDNS e exceções. `Restore` requer um arquivo `.wfw` existente.

## 15. Rastreabilidade obrigatória antes do merge

Toda alteração no repositório deverá ser documentada no `README.md` antes de ser incorporada à branch principal `main`.

O fluxo obrigatório será:

1. Criar uma Issue descrevendo o objetivo e o requisito relacionado.
2. Criar uma branch de trabalho a partir de `main`.
3. Implementar a alteração seguindo TDD quando houver comportamento novo.
4. Executar os testes e registrar o resultado no Pull Request.
5. Atualizar esta seção do `README.md` com a alteração, os arquivos afetados, os testes executados e as limitações conhecidas.
6. Revisar o Pull Request e confirmar que a documentação corresponde ao código.
7. Fazer o merge somente após os testes aprovados e a documentação atualizada.
8. Registrar no histórico abaixo o commit ou Pull Request incorporado.

### Registro de alterações

| Data | Commit ou PR | Alteração | Arquivos | Validação | Limitações |
|---|---|---|---|---|---|
| 2026-09-29 | `e080e3e` | Atualização dos exemplos para a release corrigida `v0.1.34` | `README.md` | README validado localmente | A política de execução pode ser imposta por GPO |
| 2026-09-29 | `f9ad37e` | Tratamento documentado de `PSSecurityException` com launcher de sessão `ExecutionPolicy Bypass` | `README.md`, `tools/Invoke-RemoteRelease.cmd`, `tools/Test-Readme.ps1`, `tests/NetworkControl.Tests.ps1` | 22 testes Pester e README validados localmente | Políticas `MachinePolicy`/`UserPolicy` continuam sob controle administrativo |
| 2026-09-29 | `b2c0e2b` | Reorganização didática do README pela técnica Feynman, com caminho seguro, comandos essenciais e dicionário para leigos | `README.md` | 21 testes Pester e README validados localmente | As operações administrativas continuam exigindo elevação e revisão humana |
| 2026-09-29 | `cd0df98` | Inclusão de remoção de configuração gerenciada para firewall, DNS/DoH e políticas dos navegadores | `README.md`, `src/NetworkControl.ps1`, `tools/Invoke-RemoteRelease.ps1`, `tests/NetworkControl.Tests.ps1` | 21 testes Pester e README validados localmente | O modo redefine DNS para automático e não restaura políticas anteriores personalizadas |
| 2026-09-29 | `0837472` | Alinhamento das quatro seções de execução remota, inventário, bootstrap e teste local com a sequência da release `v0.1.26` | `README.md` | README validado localmente | Operações de alteração exigem Administrador; `Apply` exige API key |
| 2026-09-29 | `ebb7df1` | Inclusão de comandos e exemplos para testar todos os modos do script | `README.md` | 20 testes Pester e README validados localmente | Operações de alteração exigem Administrador e revisão prévia |
| 2026-09-29 | `071027b` | Correção da documentação para usar o bootstrap corrigido da `v0.1.24` | `README.md` | README validado localmente | `v0.1.22` não deve mais ser usada para execução remota |
| 2026-09-29 | `12a238c` | Correção do repasse de `-Mode` no bootstrap remoto usando parâmetros nomeados | `README.md`, `tools/Invoke-RemoteRelease.ps1`, `tests/NetworkControl.Tests.ps1` | 20 testes Pester e README validados localmente | A release anterior apresentava erro ao repassar argumentos ao script principal |
| 2026-09-29 | `be2d106` | Correção do validador do comando `irm` e atualização da tag fixa para `v0.1.18` | `README.md`, `tools/Test-Readme.ps1` | 19 testes Pester e README validados localmente | A release automática anterior foi publicada apesar da falha de validação documental |
| 2026-09-29 | `e91fa94` | Atualização do comando de uma linha para a release publicada `v0.1.20` | `README.md` | README validado localmente | A tag deve permanecer publicada antes da implantação |
| 2026-09-29 | `662da0f` | Requisito documentado para execução remota em uma linha via `irm` com tag fixa e validação anterior do artefato | `README.md`, `tools/Test-Readme.ps1` | 19 testes Pester e README validados localmente | `irm` executa o bootstrap remoto; a tag deve ser revisada antes da implantação |
| 2026-09-29 | `178b987` | Bootstrap remoto com `Invoke-WebRequest` e validação SHA-256 antes da execução | `README.md`, `tools/Invoke-RemoteRelease.ps1`, `tests/NetworkControl.Tests.ps1` | 19 testes Pester e README validados localmente | Requer acesso à API e aos assets públicos do GitHub |
| 2026-09-29 | `84fcbfe` | Correção do status real da release: inventário, bloqueio seletivo e políticas dos navegadores passam a constar como entregues | `README.md` | 18 testes Pester e README validados localmente | Regras de contorno, allowlist automática e distribuição em massa continuam pendentes |
| 2026-09-29 | `ed2ec1e` | Inventário de executáveis, bloqueio seletivo de entrada/saída e políticas DoH para Chrome, Edge, Firefox e Brave | `README.md`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 18 testes Pester e README validados localmente | Requer Administrador; não bloqueia programas automaticamente |
| 2026-09-29 | `0ee10f8` | Exigência de provedor DNS gratuito, auto-hospedado e open source | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 6 testes aprovados com Pester 3.4 | API DNS ainda não integrada |
| 2026-09-29 | `abfcbd7` | Inclusão de referências para MVP, requisitos, qualidade e testes | `README.md` | Revisão bibliográfica concluída | Referências normativas podem exigir acesso institucional |
| 2026-09-29 | `0880b64` | Backup, restauração e validação de endpoint DNS HTTPS | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 9 testes aprovados com Pester 3.4 | API DNS e regras de processos ainda não integradas |
| 2026-09-29 | `9b40f96` | Automação de testes, logs, simulação e releases via GitHub Actions | `README.md`, `.github/workflows/verify.yml` | 9 testes aprovados localmente | Execução do workflow depende do GitHub Actions |
| 2026-09-29 | `125e0e7` | Compatibilidade dos testes com Pester local e runner do GitHub Actions | `src/NetworkControl.psm1`, `tests/NetworkControl.Tests.ps1` | 9 testes aprovados localmente e no GitHub Actions: [run 36565772559](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36565772559) | Execução de firewall continua local |
| 2026-09-29 | `e25eea8` | Migração para provedor DNS remoto NextDNS sem dependência local, API e plano DoH nativo | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 12 testes aprovados localmente e no [Actions run 36566439511](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36566439511) | Execução do firewall continua local |
| 2026-09-29 | `0440802` | Inclusão do perfil NextDNS `923be7`, endpoints DoH, DoT/QUIC, IPv6 e IP vinculado | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 12 testes aprovados localmente e no [Actions run 36567012588](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36567012588) | Execução do firewall continua local |
| 2026-09-29 | `e60d0bb` | Política obrigatória de blocklists, inteligência de ameaças, proteção nativa e controle parental NextDNS | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 13 testes, README validado e workflow aprovado | [Actions 36568158342](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36568158342) |
| 2026-09-29 | `a93b822` | Payload completo de aplicação do perfil NextDNS via API | `README.md`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 14 testes, README validado e workflow aprovado | [Actions 36568433301](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36568433301) |
| 2026-09-29 | `f2d3ce3` | Modo ConfigureDns para automatizar DoH local sem API key | `README.md`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 15 testes, README validado e workflow aprovado | [Actions 36572548867](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36572548867) |
| 2026-09-29 | `97db1a2` | Documentação do segredo `NEXTDNS_API_KEY` e validação do repositório para nova release | `README.md` | 15 testes, README validado, segredo presente no GitHub e workflow aprovado | [Actions 36573070752](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36573070752) |
| 2026-09-29 | `1004adf` | Atualização do PRD para implantação em computadores de alunos e políticas DoH dos navegadores | `README.md` | README validado e workflow aprovado | [Actions 36573968150](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36573968150) |
| 2026-09-29 | `b522944` | Correção de escopo: políticas de navegador e bloqueio local de contorno marcados como pendentes | `README.md` | 15 testes, README validado e workflow aprovado | [Actions 36574541447](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36574541447) |
| 2026-09-29 | `262ad1b` | Revisão completa do PRD contra o comportamento real do script e reorganização do desenvolvimento atual | `README.md` | 15 testes, README validado e workflow aprovado | [Actions 36575368882](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36575368882) |
| 2026-09-29 | `0124161` | Ampliação do payload NextDNS para máxima cobertura de segurança, privacidade, controle parental e observabilidade | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 15 testes, README validado e workflow aprovado | [Actions 36575955282](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36575955282) |
| 2026-09-29 | `f426d15` | Política de versionamento patch e publicação automática após merge em `main`; soluções para limitações técnicas | `README.md` | README validado antes da alteração do workflow | Workflow em implementação |
| 2026-09-29 | `2667c72` | Correção documentada para o fluxo de release após limitação de eventos do `GITHUB_TOKEN` | `README.md` | Limitação reproduzida com a tag `v0.1.4` | Release `v0.1.4` permanece sem artefato |
| 2026-09-29 | `51bd38b` | Publicação da tag, artefato e release no mesmo job após merge em `main` | `.github/workflows/verify.yml` | Workflow local validado com 15 testes; publicação remota em andamento | Tag automática não deve ser recriada |
| 2026-09-29 | `v0.1.5` | Primeira release publicada pelo fluxo automático após merge em `main` | `Windows-Network-Control-v0.1.5.zip` | [Actions 36576733262](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36576733262) aprovado; [release v0.1.5](https://github.com/AloisioMagalhaes/Windows-Network-Control/releases/tag/v0.1.5) publicada | `v0.1.4` é uma tag histórica sem release |
| 2026-09-29 | `432dbc9` | Procedimento documentado de execução remota da release nos computadores dos alunos | `README.md` | README validado e workflow aprovado em [Actions 36577826258](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36577826258) | A aplicação em massa depende de GPO, Intune ou ferramenta administrativa |
| 2026-09-29 | `888a11c` | Baseline seguro do firewall: saída permitida até existir allowlist granular | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 16 testes, README validado e workflow aprovado em [Actions 36579146937](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36579146937) | Bloqueio granular de saída continua planejado |
| 2026-09-29 | `f39764a` | Comando remoto resolve a release mais recente e valida o SHA-256 publicado | `README.md`, `tools/Test-Readme.ps1` | 16 testes, README validado e [workflow aprovado](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36580187448) | A API pública do GitHub precisa estar acessível no computador |
| 2026-09-29 | `0dfef60` | Correção do gatilho de tags para publicação automática de releases | `README.md`, `.github/workflows/verify.yml` | [Actions run 36567731332](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36567731332) aprovado; [release v0.1.1](https://github.com/AloisioMagalhaes/Windows-Network-Control/releases/tag/v0.1.1) publicada | `v0.1.0` permanece apenas como tag |
| 2026-09-29 | `d7354e5` | Validação automatizada do PRD do README e observabilidade documental | `README.md`, `tools/Test-Readme.ps1`, `.github/workflows/verify.yml` | 18 requisitos, 12 testes e [Actions run 36567421143](https://github.com/AloisioMagalhaes/Windows-Network-Control/actions/runs/36567421143) aprovados | Execução do firewall continua local |

Nenhuma alteração deverá ser mesclada em `main` sem uma nova linha neste registro.

## 16. Automação, logs e observabilidade

O GitHub Actions executa a validação em cada `push` na `main`, Pull Request direcionado à `main` e execução manual. O workflow `.github/workflows/verify.yml`:

- executa os testes Pester em ambiente Windows;
- valida o PRD do README com `tools/Test-Readme.ps1`;
- publica o total de testes, aprovados e falhos no resumo da execução;
- grava transcript da execução e publica o log como artefato;
- interrompe o processo quando há falhas;
- executa apenas simulação durante o empacotamento;
- cria um arquivo ZIP da release com script, configuração, testes, README e log de simulação;
- gera checksum SHA-256;
- publica a release automaticamente para tags no formato `v*`.

Para publicar uma release observável:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

O workflow não aplica regras de firewall no runner nem em computadores de usuários. A aplicação continua sendo uma operação local, explícita e administrativa. Os logs de CI comprovam testes e simulação, mas não comprovam que o firewall de um computador específico foi alterado.

### Erros observados e correções no workflow

- O runner Windows utilizava Pester 5 enquanto o computador local utilizava Pester 3.4. Os testes foram convertidos para asserções PowerShell compatíveis com ambas as versões.
- O carregamento direto do `.ps1` não exportava funções no escopo do Pester 5. Foi criado `src/NetworkControl.psm1` e os testes passaram a importar o módulo.
- A execução remota confirmou 9 testes aprovados no run `36565772559`; o novo ciclo DNS ampliou a suíte para 11 testes.
- O aviso de migração do Node.js das ações externas permanece observável no GitHub Actions e deverá ser revisado quando as ações publicarem versões compatíveis.

Workflows são tratados como código sensível: as ações externas são fixadas por commit, o token recebe permissões mínimas e nenhum segredo DNS é impresso nos logs. Essa prática reduz riscos de cadeia de suprimentos e de exposição de credenciais (NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY, 2009).

## 17. Fundamentação científica e acadêmica

### 16.1 Objetivo e política de bloqueio

O objetivo de combinar firewall local, filtragem DNS e regras específicas para processos segue o princípio de defesa em camadas. A política de bloqueio padrão para conexões não autorizadas é coerente com a recomendação de negar tráfego por padrão e liberar apenas o que for necessário, desde que a política seja documentada, revisada e baseada em análise de risco (NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY, 2009, p. 27).

Por isso, o projeto mantém exclusões explícitas para componentes essenciais do Windows, navegadores e serviços necessários. O bloqueio indiscriminado poderia interromper atualizações, resolução de nomes, segurança e administração do sistema. A lista de exceções deverá ser revisada sempre que novas aplicações ou vulnerabilidades forem identificadas (NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY, 2009, p. 27, 40-41).

### 16.2 Filtragem DNS e limitações

O DNS será utilizado como camada de filtragem por domínio e categoria, não como mecanismo suficiente para identificar processos locais, emuladores ou virtualização. A literatura técnica destaca que DNS sobre HTTPS pode ocultar consultas em tráfego HTTPS e dificultar monitoramento e filtragem baseados em DNS (EUROPEAN UNION AGENCY FOR CYBERSECURITY, 2020, p. 30-31). Assim, o projeto combina DNS auto-hospedado com regras do firewall baseadas em executáveis, serviços, portas, endereços e interfaces.

Essa arquitetura não promete bloqueio absoluto. VPNs, DoH, DoT, endereços IP diretos, CDNs compartilhadas, túneis e domínios ainda não classificados podem reduzir a eficácia da filtragem. A conclusão deverá ser baseada em testes observáveis, logs e cenários documentados, e não na suposição de que uma categoria DNS representa todos os comportamentos de uma aplicação.

### 16.3 Metodologia TDD

O desenvolvimento utiliza ciclos de teste, implementação e refatoração. A evidência experimental sobre TDD não é uniforme: estudos relatam possíveis ganhos de qualidade, mas também efeitos dependentes do contexto, experiência dos participantes e forma de avaliação (ROMANO et al., 2017; FUCCI et al., 2017). Portanto, o projeto não declara que TDD garante qualidade; utiliza testes como evidência verificável para requisitos específicos.

Quando possível, os testes deverão ser escritos antes da implementação, incluir casos de erro e validar comportamento observável. A incorporação de mutation testing é uma melhoria planejada, pois experimento controlado encontrou testes mais fortes quando a mutação foi adicionada ao ciclo TDD (ROMAN; MNICH, 2021).

### 16.4 Critérios de conclusão

Os critérios de conclusão foram convertidos em evidências verificáveis: testes aprovados, simulação sem alteração do sistema, backup anterior à aplicação, idempotência, logs sem segredos, reversão funcional e validação de exclusões. Essa abordagem evita tratar cobertura de código isolada como prova suficiente de segurança ou eficácia, em conformidade com as limitações apontadas pela pesquisa empírica sobre TDD (ROMANO et al., 2017; ROMAN; MNICH, 2021).

### 16.5 Regra obrigatória de citação

Toda afirmação técnica, requisito baseado em norma, decisão de arquitetura, limitação de segurança, critério de teste ou conclusão de qualidade deverá conter citação autor-data no próprio texto e referência completa na seção 18, preferencialmente em fonte primária, acadêmica, normativa ou documentação oficial. Não serão apresentadas como fatos conclusões sem fonte, sem teste reproduzível ou sem indicação explícita de que são hipóteses do MVP.

As citações deverão seguir o sistema autor-data da ABNT. Exemplos: (INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION; INSTITUTE OF ELECTRICAL AND ELECTRONICS ENGINEERS, 2018), (RIES, 2011) e (ROMAN; MNICH, 2021).

## 18. Referências

As referências seguem a ABNT NBR 6023:2018.

EUROPEAN UNION AGENCY FOR CYBERSECURITY. *Security and privacy for public DNS resolvers*. Heraklion: ENISA, 2020. Disponível em: <https://www.enisa.europa.eu/sites/default/files/publications/ENISA_Report_-_Security_and_Privacy_for_Public_DNS_Resolvers.pdf>. Acesso em: 29 set. 2026.

INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION; INSTITUTE OF ELECTRICAL AND ELECTRONICS ENGINEERS. *ISO/IEC/IEEE 29148:2018: systems and software engineering: life cycle processes: requirements engineering*. Geneva: ISO, 2018. Disponível em: <https://standards.ieee.org/ieee/29148/6937/>. Acesso em: 29 set. 2026.

INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION. *ISO/IEC 25010:2023: systems and software engineering: SQuaRE: product quality model*. Geneva: ISO, 2023. Disponível em: <https://www.iso.org/standard/78176.html>. Acesso em: 29 set. 2026.

FUCCI, Davide et al. A dissection of the test-driven development process: does it really matter to test-first or to test-last? *IEEE Transactions on Software Engineering*, v. 43, n. 7, p. 597-614, 2017. DOI: 10.1109/TSE.2016.2616567. Disponível em: <https://doi.org/10.1109/TSE.2016.2616567>. Acesso em: 29 set. 2026.

NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY. *Guidelines on firewalls and firewall policy*. Gaithersburg: NIST, 2009. (Special Publication 800-41, Revision 1). Disponível em: <https://nvlpubs.nist.gov/nistpubs/legacy/sp/nistspecialpublication800-41r1.pdf>. Acesso em: 29 set. 2026.

RIES, Eric. *The lean startup: how today’s entrepreneurs use continuous innovation to create radically successful businesses*. New York: Crown Business, 2011. Disponível em: <https://theleanstartup.com/>. Acesso em: 29 set. 2026.

ROMAN, Adam; MNICH, Michal. Test-driven development with mutation testing: an experimental study. *Software Quality Journal*, v. 29, p. 1-38, 2021. DOI: 10.1007/s11219-020-09534-x. Disponível em: <https://doi.org/10.1007/s11219-020-09534-x>. Acesso em: 29 set. 2026.

ROMANO, Simone et al. Findings from a multi-method study on test-driven development. *Information and Software Technology*, v. 89, p. 64-77, 2017. DOI: 10.1016/j.infsof.2017.03.010. Disponível em: <https://doi.org/10.1016/j.infsof.2017.03.010>. Acesso em: 29 set. 2026.

RIPENAAR, Riaan (org.). *Free for developers*. [S. l.]: GitHub, 2026. Disponível em: <https://github.com/ripienaar/free-for-dev>. Acesso em: 29 set. 2026.

NEXTDNS. *NextDNS API documentation*. [S. l.]: NextDNS, [2026]. Disponível em: <https://nextdns.github.io/api/>. Acesso em: 29 set. 2026.

MICROSOFT. *Get-DnsClientDohServerAddress*. Redmond: Microsoft Learn, [2026]. Disponível em: <https://learn.microsoft.com/en-us/powershell/module/dnsclient/get-dnsclientdohserveraddress>. Acesso em: 29 set. 2026.

MICROSOFT. *Manage Windows Firewall with the command line*. Redmond: Microsoft Learn, [2026]. Disponível em: <https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/configure-with-command-line>. Acesso em: 29 set. 2026.














