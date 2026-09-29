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

### Requisito de custo e licença

O provedor DNS deverá ser 100% gratuito para uso local, sem assinatura obrigatória, sem limite artificial de consultas e preferencialmente publicado como software livre ou código aberto.

O projeto não deverá depender de uma API SaaS paga. A API deverá ser executada em uma instância controlada pelo usuário, na rede local ou no próprio computador, sem envio obrigatório de consultas ou chaves para terceiros.

### Provedor principal

Technitium DNS Server deverá ser a integração principal por ser gratuito, open source sob GPLv3, compatível com Windows e possuir API HTTP para configuração. A filtragem deverá usar DNSBL, listas de bloqueio e regras locais.

Documentação: https://technitium.com/dns/

### Alternativas open source

- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome
- Pi-hole: https://docs.pi-hole.net/api/

O projeto deverá abstrair o provedor por meio de um adaptador para permitir substituição sem alterar o núcleo do firewall.

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

O segundo incremento implementado contém:

- diretório de backup configurável;
- exportação automática da configuração do firewall antes de `Apply`;
- restauração por arquivo `.wfw`;
- validação de endpoint DNS com HTTPS;
- configuração padrão do Technitium DNS Server.

Execute os testes com:

```powershell
Invoke-Pester .\tests\NetworkControl.Tests.ps1 -PassThru
```

Para simular:

```powershell
.\src\NetworkControl.ps1 -Mode Simulate
```

Para aplicar as políticas, após revisar a simulação:

```powershell
.\src\NetworkControl.ps1 -Mode Apply -ConfigPath .\config\example.json -ConfirmApply
```

Para restaurar um backup:

```powershell
.\src\NetworkControl.ps1 -Mode Restore -BackupPath .\backups\NWC-firewall-AAAAMMDD-HHMMSS.wfw
```

O modo `Apply` exige `-ConfirmApply` e cria o backup automaticamente. A integração efetiva com a API HTTP do Technitium, a criação das regras por processo e a filtragem das categorias DNS ainda serão implementadas nos próximos ciclos TDD. O uso de `netsh advfirewall` para exportação e importação segue a necessidade de preservar uma cópia reversível da política, conforme a recomendação de documentação e manutenção da política de firewall (NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY, 2009).

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
| 2026-09-29 | `0ee10f8` | Exigência de provedor DNS gratuito, auto-hospedado e open source | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 6 testes aprovados com Pester 3.4 | API DNS ainda não integrada |
| 2026-09-29 | `abfcbd7` | Inclusão de referências para MVP, requisitos, qualidade e testes | `README.md` | Revisão bibliográfica concluída | Referências normativas podem exigir acesso institucional |
| 2026-09-29 | `PENDENTE` | Backup, restauração e validação de endpoint DNS HTTPS | `README.md`, `config/example.json`, `src/NetworkControl.ps1`, `tests/NetworkControl.Tests.ps1` | 9 testes aprovados com Pester 3.4 | API DNS e regras de processos ainda não integradas |

Nenhuma alteração deverá ser mesclada em `main` sem uma nova linha neste registro.

## 16. Fundamentação científica e acadêmica

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

Toda afirmação técnica, requisito baseado em norma, decisão de arquitetura, limitação de segurança, critério de teste ou conclusão de qualidade deverá conter citação autor-data no próprio texto e referência completa na seção 17, preferencialmente em fonte primária, acadêmica, normativa ou documentação oficial. Não serão apresentadas como fatos conclusões sem fonte, sem teste reproduzível ou sem indicação explícita de que são hipóteses do MVP.

As citações deverão seguir o sistema autor-data da ABNT. Exemplos: (INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION; INSTITUTE OF ELECTRICAL AND ELECTRONICS ENGINEERS, 2018), (RIES, 2011) e (ROMAN; MNICH, 2021).

## 17. Referências

As referências seguem a ABNT NBR 6023:2018.

EUROPEAN UNION AGENCY FOR CYBERSECURITY. *Security and privacy for public DNS resolvers*. Heraklion: ENISA, 2020. Disponível em: <https://www.enisa.europa.eu/sites/default/files/publications/ENISA_Report_-_Security_and_Privacy_for_Public_DNS_Resolvers.pdf>. Acesso em: 29 set. 2026.

INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION; INSTITUTE OF ELECTRICAL AND ELECTRONICS ENGINEERS. *ISO/IEC/IEEE 29148:2018: systems and software engineering: life cycle processes: requirements engineering*. Geneva: ISO, 2018. Disponível em: <https://standards.ieee.org/ieee/29148/6937/>. Acesso em: 29 set. 2026.

INTERNATIONAL ORGANIZATION FOR STANDARDIZATION; INTERNATIONAL ELECTROTECHNICAL COMMISSION. *ISO/IEC 25010:2023: systems and software engineering: SQuaRE: product quality model*. Geneva: ISO, 2023. Disponível em: <https://www.iso.org/standard/78176.html>. Acesso em: 29 set. 2026.

FUCCI, Davide et al. A dissection of the test-driven development process: does it really matter to test-first or to test-last? *IEEE Transactions on Software Engineering*, v. 43, n. 7, p. 597-614, 2017. DOI: 10.1109/TSE.2016.2616567. Disponível em: <https://doi.org/10.1109/TSE.2016.2616567>. Acesso em: 29 set. 2026.

NATIONAL INSTITUTE OF STANDARDS AND TECHNOLOGY. *Guidelines on firewalls and firewall policy*. Gaithersburg: NIST, 2009. (Special Publication 800-41, Revision 1). Disponível em: <https://nvlpubs.nist.gov/nistpubs/legacy/sp/nistspecialpublication800-41r1.pdf>. Acesso em: 29 set. 2026.

RIES, Eric. *The lean startup: how today’s entrepreneurs use continuous innovation to create radically successful businesses*. New York: Crown Business, 2011. Disponível em: <https://theleanstartup.com/>. Acesso em: 29 set. 2026.

ROMAN, Adam; MNICH, Michal. Test-driven development with mutation testing: an experimental study. *Software Quality Journal*, v. 29, p. 1-38, 2021. DOI: 10.1007/s11219-020-09534-x. Disponível em: <https://doi.org/10.1007/s11219-020-09534-x>. Acesso em: 29 set. 2026.

ROMANO, Simone et al. Findings from a multi-method study on test-driven development. *Information and Software Technology*, v. 89, p. 64-77, 2017. DOI: 10.1016/j.infsof.2017.03.010. Disponível em: <https://doi.org/10.1016/j.infsof.2017.03.010>. Acesso em: 29 set. 2026.
