# RADGenie

Status do projeto: **BETA**

O RADGenie é um pacote de extensão para Delphi IDE que adiciona geração assistida de código com IA a partir do contexto da unit aberta.

## Visão geral

Com o RADGenie você consegue:

- Acionar geração de código diretamente na IDE.
- Usar o conteúdo da unit ativa como contexto de prompt.
- Configurar provedor, URL base, API Key e modelo.
- Salvar configurações localmente para reutilização.

## Funcionalidades

- Integração com menu/contexto da IDE.
- Tela de configuração em **Tools > Options > RadGenieAI**.
- Suporte aos drivers:
  - OpenAI
  - Claude
  - Gemini
  - Ollama
- Listagem dinâmica de modelos por driver.
- Botão **Test Connection** para validar acesso e atualizar modelos.
- Botão **Get API Key** para abrir a página do provider selecionado.

## Configuração das opções

Na tela de opções, a ordem dos campos é:

1. Driver
2. Base URL
3. API Key
4. Model Name

Fluxo recomendado:

1. Selecione o driver.
2. Confira a Base URL padrão.
3. Clique em **Get API Key** se precisar gerar/chavear credenciais.
4. Informe a API Key.
5. Clique em **Test Connection** para carregar os modelos disponíveis.
6. Selecione o modelo e confirme em **OK**.

## Persistência

As configurações são salvas em:

- `Documentos\RADGenie\radGenieAI.json` (com fallback para diretório do usuário)

## Estrutura do projeto

```text
/src
  /Controller
  /Model
  /View
```

Arquivos principais:

- `src/Model/uRADGenie.Model.AI.pas`
- `src/View/uRADGenie.View.Options.pas`
- `src/View/uRADGenie.View.Options.dfm`
- `src/RADGenie.Design.dpk`
- `src/RADGenie.Design.dproj`

## Troubleshooting rápido

- **Erro ao salvar configurações (Access denied):**
  - Recompile o package e reinstale na IDE para garantir uso do código atualizado.
- **Modelos não aparecem:**
  - Verifique API Key.
  - Clique em **Test Connection**.
  - Confirme se o endpoint da Base URL está acessível.

## Observações

- O projeto está em evolução contínua.
- Mudanças de comportamento podem ocorrer durante o ciclo beta.
