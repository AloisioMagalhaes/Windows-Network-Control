# Windows Network Control

## 1. Objetivo

Criar um repositório cujo artefato principal seja um script PowerShell para controlar o acesso de rede no Windows Defender Firewall e aplicar filtragem DNS por API.

O sistema deverá bloquear conexões de entrada e saída por padrão, preservar componentes essenciais do Windows e permitir somente aplicações, serviços, domínios e recursos explicitamente autorizados.

## 2. Escopo

O projeto deverá:

- Configurar os perfis Domínio, Privado e Público.
- Definir bloqueio padrão para entrada e saída.
- Criar regras locais para processos, serviços, portas, protocolos, endereços IP, domínios resolvidos e interfaces de rede.
- Bloquear aplicações não essenciais cadastradas pelo usuário.
- Bloquear navegadores somente quando explicitamente configurado; navegadores deverão permanecer permitidos por padrão.
- Bloquear torrent, pornografia, anúncios, rastreadores e jogos online por filtragem DNS categorizada.
- Bloquear emuladores e aplicações relacionadas por executável, serviço, driver, porta, endereço IP ou interface de rede conhecida.
- Permitir listas de inclusão e exclusão.
- Registrar todas as alterações e permitir reversão segura.

## 3. Limitações técnicas

- O Firewall do Windows não identifica virtualização genericamente.
- O bloqueio de emuladores deverá usar processos, serviços, drivers, interfaces, portas, endereços IP e caminhos conhecidos.
- DNS bloqueia domínios, não processos locais, virtualização ou todo tráfego criptografado.
- Domínios novos, CDNs compartilhadas, VPNs, DoH, DoT e endereços IP diretos podem contornar filtros DNS.
- O bloqueio por domínio deverá ser implementado pelo provedor DNS ou por resolução controlada; regras nativas do firewall deverão ser usadas para controles locais.

## 4. Provedor DNS

O sistema deverá permitir configurar um provedor via arquivo de configuração ou parâmetros do script.

### Provedor recomendado

CleanBrowsing, por oferecer API documentada e categorias para:

- publicidade e rastreamento;
- conteúdo adulto;
- torrents e compartilhamento P2P;
- jogos online;
- proxies e VPNs.

Documentação: https://cleanbrowsing.org/api/

### Alternativas

- NextDNS: https://nextdns.github.io/api/
- Cloudflare Gateway: https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/
- Control D: https://docs.controld.com/reference/get-started

O projeto deverá abstrair o provedor para permitir substituição futura sem alterar o núcleo do firewall.

## 5. Requisitos funcionais

### RF01 — Privilégios

Exigir execução como Administrador e interromper a operação com mensagem clara quando os privilégios forem insuficientes.

### RF02 — Backup

Exportar a configuração atual do firewall antes de qualquer alteração.

### RF03 — Aplicação

Aplicar as políticas de bloqueio aos perfis Domínio, Privado e Público.

### RF04 — Regras próprias

Identificar todas as regras criadas pelo sistema com prefixo exclusivo e metadados suficientes para reversão.

### RF05 — Processos

Permitir bloquear executáveis por caminho absoluto e validar se o arquivo existe antes de criar a regra.

### RF06 — Serviços e drivers

Permitir cadastrar serviços, drivers e componentes associados a emuladores e plataformas de virtualização.

### RF07 — Emuladores

Incluir configuração para aplicações como BlueStacks, Android Studio Emulator, VirtualBox, VMware, Hyper-V, WSL e Windows Subsystem for Android, sem presumir que estejam instaladas.

### RF08 — Rede

Permitir regras por direção, protocolo, porta, endereço remoto, endereço local e interface de rede.

### RF09 — DNS

Configurar o provedor DNS selecionado, autenticar a API com segredo fornecido pelo usuário e aplicar categorias configuradas.

### RF10 — Categorias

Permitir ativar ou desativar independentemente as categorias de anúncios, rastreadores, pornografia, torrent, P2P, jogos online, proxy, VPN e malware.

### RF11 — Exceções

Permitir exceções para Windows, navegadores, atualizações, DNS, DHCP, NTP, segurança, gerenciamento, domínios confiáveis, executáveis confiáveis e serviços essenciais.

### RF12 — Simulação

Oferecer modo de simulação que liste as alterações sem aplicá-las.

### RF13 — Validação

Validar privilégios, perfis, caminhos, serviços, parâmetros, conectividade DNS e respostas da API antes da aplicação.

### RF14 — Auditoria

Gerar log local com data, operação, regra, resultado e erro, sem registrar chaves de API ou informações sensíveis.

### RF15 — Consulta

Permitir listar regras próprias, exceções ativas, categorias DNS, processos cadastrados e estado atual.

### RF16 — Reversão

Permitir restaurar o backup ou remover exclusivamente as regras criadas pelo sistema.

### RF17 — Idempotência

Executar repetidamente sem duplicar regras nem alterar configurações fora do escopo.

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
- Processos e serviços cadastrados são bloqueados nas direções configuradas.
- Logs não expõem segredos.

## 12. Entrega

A release deverá conter:

- script PowerShell executável;
- arquivos de configuração de exemplo;
- testes;
- documentação de instalação, uso, validação e reversão;
- lista de limitações;
- histórico de alterações;
- instruções para criar e publicar a release no GitHub.

## 13. Critério de conclusão

O projeto será considerado concluído quando o script puder criar backup, simular, aplicar, validar, consultar e reverter as regras de firewall, integrar um provedor DNS por API, bloquear as categorias configuradas e preservar as exclusões padrão sem duplicar regras ou expor segredos.

## 14. Desenvolvimento atual

O primeiro incremento implementado contém:

- configuração de exemplo;
- validação de categorias DNS;
- nomes estáveis para regras gerenciadas;
- modo de simulação;
- consulta de status;
- listagem e remoção de regras próprias;
- testes automatizados com Pester 3.4 ou superior.

Execute os testes com:

```powershell
Invoke-Pester .\tests\NetworkControl.Tests.ps1 -PassThru
```

O modo `Apply` ainda exige `-ConfirmApply` e o backup, a integração efetiva com a API DNS e a restauração serão implementados nos próximos ciclos TDD.
