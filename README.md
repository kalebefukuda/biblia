# Bíblia

App pessoal de leitura bíblica para iPhone (SwiftUI, iOS 17+). Funciona sem internet.

- Várias versões (ARA, NVI…) importadas por você, com troca rápida.
- Leitor por capítulo: rola para baixo e desliza para o lado para trocar de capítulo.
- Toque no versículo para destacar (5 cores), sublinhar, salvar, anotar, copiar ou enviar.
- Busca por referência ("Jo 3:16", "1 Co 13:4-7") e por palavras, ignorando acentos.
- Mapa de leitura estilo GitHub, dias seguidos e estatísticas.
- Lembrete diário que não toca se você já leu no dia.
- Planos: Bíblia em 1 ano, NT em 90 dias, Evangelhos em 30 dias, Salmos em 30 dias, Provérbios em 31 dias.
- Widgets: sequência de leitura e versículo do dia.
- Cópia de segurança em arquivo JSON.

## Textos bíblicos

O repositório **não contém** nenhum texto bíblico. ARA e NAA são da Sociedade Bíblica do Brasil; NVI é da Biblica. Use apenas edições que você tem direito de usar, para uso pessoal.

Formatos aceitos (JSON, 66 livros na ordem canônica):

```json
[{"abbrev": "Gn", "chapters": [["texto do v1", "texto do v2"], ["..."]]}]
```

```json
{"books": [{"chapters": [{"verses": [{"text": "texto do v1"}]}]}]}
```

O nome do arquivo vira a sigla da versão (`ARA.json` → ARA). Para desenvolver, coloque os arquivos em `Versoes/` (ignorada pelo git).

## Rodar no simulador

Requer Xcode 16+ e [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
```

```bash
xcodebuild test -project Biblia.xcodeproj -scheme Biblia -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Depois de instalar no simulador, copie as versões para a pasta Documentos do app; ele importa ao abrir:

```bash
cp Versoes/*.json "$(xcrun simctl get_app_container booted com.kalebefukuda.biblia data)/Documents/"
```

## Instalar no iPhone (Apple ID gratuito)

1. Rode `xcodegen generate` e abra `Biblia.xcodeproj` no Xcode.
2. Xcode → Settings → Accounts: entre com seu Apple ID.
3. Nos alvos **Biblia** e **BibliaWidget**, em Signing & Capabilities, escolha seu time pessoal ("Personal Team"). Se o identificador `com.kalebefukuda.biblia` estiver em uso, troque o prefixo nos dois alvos e no App Group.
4. Conecte o iPhone por cabo, ative o Modo de Desenvolvedor (Ajustes → Privacidade e Segurança) e rode (⌘R).
5. No iPhone: Ajustes → Geral → VPN e Gerenciamento de Dispositivos → confie no seu perfil de desenvolvedor.
6. Importe as versões: Ajustes do app → Importar versão (Arquivos, iCloud Drive ou AirDrop), ou arraste os JSON pelo Finder (iPhone → Arquivos → Bíblia).

Limitações da conta gratuita:

- A instalação vale **7 dias**. Depois disso, conecte e rode de novo pelo Xcode; seus dados continuam no aparelho.
- **App Group**: se o Xcode recusar essa capability no time pessoal, remova-a dos dois alvos. O app continua funcionando (guarda tudo no próprio container), mas os widgets ficam sem dados. Em Ajustes → Sobre, "Widget" mostra se o App Group está ativo.
- Sem iCloud: use **Exportar cópia de segurança** de vez em quando.

## Privacidade e segurança

- O app não acessa a internet, não usa bibliotecas de terceiros e não grava logs.
- Destaques, notas e histórico de leitura ficam só no aparelho, protegidos pela criptografia do iOS (Data Protection). Esses dados podem revelar convicção religiosa, que a LGPD trata como dado pessoal sensível (art. 5º, II). Guarde o arquivo de cópia de segurança em local seguro.
- Arquivos importados (versões e cópias de segurança) são tratados como dados não confiáveis: têm tamanho limitado, são validados contra os 66 livros do cânon e nada neles é executado.
- Links do widget (`biblia://`) só aceitam referências válidas.

## Estrutura

```
Biblia/          app (telas em Features/, regras em Core/)
BibliaWidget/    extensão de widgets
Shared/          código usado pelo app e pelo widget (cânon, estatísticas, resumo do widget)
BibliaTests/     testes (Swift Testing)
project.yml      definição do projeto (XcodeGen)
```
