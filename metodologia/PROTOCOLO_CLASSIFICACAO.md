# Protocolo da rodada de classificação por painel de modelos (pré-registro)

**Situação: ALTERNATIVA ARQUIVADA, NÃO EXECUTADA.** Em 16/11/2026 a equipe optou pela
classificação inteiramente humana (`PROTOCOLO_CLASSIFICACAO_HUMANA.md`). Este protocolo e o
código em `metodologia/R/painel/` ficam guardados para uso eventual como comparação.

**Situação original: RASCUNHO.** Este documento passa a valer como pré-registro quando os campos marcados
com `[DEFINIR]` forem preenchidos e o arquivo for enviado ao Git **antes** da rodada real. O
commit com data é o registro de que as regras abaixo não foram ajustadas depois de ver os
resultados. Qualquer desvio posterior deve ser registrado na seção 10, com data e motivo.

Fundamentação: `metodologia/REVISAO_ANOTACAO_LLM.md`. Código: `metodologia/R/painel/`.

## 1. Objetivo

Reclassificar, de forma independente da rodada de setembro de 2026, as atividades candidatas do
Perfil Ocupacional da CBO 2002 nas quatro classes da `metodologia/RUBRICA.md` (VERDE, POTENCIAL,
MARROM, NEUTRO), com um painel de três modelos de linguagem de empresas diferentes, arbitragem
pela equipe e validação contra codificação humana às cegas.

## 2. Itens

- Universo: as atividades distintas capturadas pelo dicionário (`metodologia/insumos/dicionario.csv`
  com `excecoes.csv`), após normalização. Na versão atual do corpus, 1.866 atividades.
- Identificador de cada item: os 12 primeiros caracteres do MD5 da chave normalizada. É estável
  entre execuções e independe da ordem.
- Hash dos insumos no momento do registro: `[DEFINIR: preencher com a saída de registrar_protocolo()]`

## 3. Painel

| Membro | Empresa | Modelo (identificador exato) | Variável de ambiente da chave |
|---|---|---|---|
| A | Anthropic | `claude-opus-5-5` | `ANTHROPIC_API_KEY` |
| B | OpenAI | `[DEFINIR: confirmar com listar_modelos("openai")]` | `OPENAI_API_KEY` |
| C | Google | `[DEFINIR: confirmar com listar_modelos("google")]` | `GEMINI_API_KEY` |

Critério de escolha: o modelo de uso geral mais capaz de cada empresa disponível na API na data
da rodada. Parâmetros: os padrões de cada fornecedor, exceto o esforço de raciocínio do modelo A,
fixado em `medium`. Nenhum parâmetro de amostragem é enviado (os modelos atuais não aceitam fixar
a temperatura); a reprodutibilidade decorre do registro integral das respostas (seção 6).

## 4. Instruções enviadas aos modelos

- **Instrução de sistema:** as seções da `RUBRICA.md` de "Contexto de aplicação" até "Regras de
  decisão", sem alteração, seguidas de um bloco fixo que pede a resposta em JSON. Ficam de fora,
  de propósito: "Protocolo de aplicação" (contém os resultados da rodada anterior, que
  ancorariam o modelo), "Formato de saída" (substituído pelo JSON) e "Referências".
- **Mensagem de cada item:** somente o enunciado da atividade, no texto original.
- **Cegamento:** o modelo não recebe o termo do dicionário que capturou a atividade, nem o título
  da ocupação, nem a classe atribuída em setembro, nem a resposta dos outros membros do painel.
- **Uma chamada por item**, sem histórico.
- **Resposta estruturada** (validada por esquema JSON): `classe`, `regra` e `justificativa`.
  `regra` identifica o trecho da rubrica aplicado: `VERDE`, `POTENCIAL`, `MARROM`, `NEUTRO_1` a
  `NEUTRO_6` (os seis casos obrigatórios) ou `NEUTRO_CONSERVADOR` (dúvida resolvida pelo viés
  conservador). Resposta em que `regra` não corresponde a `classe` é tratada como inválida.
- O texto exato das instruções é gravado em `metodologia/painel/prompt_sistema.txt` e seu hash
  acompanha cada resposta.

## 5. Testes de comportamento (antes da rodada completa)

Cada modelo classifica os exemplos citados na própria rubrica (`testes_comportamento()`). Serve
para detectar falhas grosseiras de seguimento da rubrica, não como validação. Critério: um modelo
que erre mais de `[DEFINIR, sugestão: 2]` dos exemplos não entra no painel até que a causa seja
investigada.

## 6. Registro

Cada chamada gera uma linha em `metodologia/painel/respostas/<membro>.jsonl` com: identificador
do item, membro, modelo solicitado, modelo informado na resposta, data e hora, hash das
instruções, status HTTP, corpo integral da resposta, classe, regra, justificativa e erro, se
houver. Os arquivos são versionados no Git ao final da rodada.

## 7. Agregação (regras fixadas antes)

| Situação | Decisão | Marca |
|---|---|---|
| Os três membros concordam | Classe aceita | `unanimidade` |
| Dois concordam e o terceiro diverge, sem envolver o par VERDE e NEUTRO | Classe da maioria aceita | `maioria` |
| Dois concordam e o divergente forma com eles o par VERDE e NEUTRO | Arbitragem | `arbitragem` |
| Os três divergem | Arbitragem | `arbitragem` |
| Um membro sem resposta válida após as novas tentativas; os outros dois concordam | Classe aceita | `dois_membros` |
| Um membro sem resposta válida; os outros dois divergem | Arbitragem | `arbitragem` |

**Arbitragem:** feita por `[DEFINIR: nomes]`, com acesso ao enunciado, às três classes e às três
justificativas, aplicando a rubrica. Cada decisão tem justificativa escrita. Discordância entre os
árbitros é resolvida por `[DEFINIR: regra, por exemplo, terceiro membro da equipe]`.

## 8. Estabilidade

Numa amostra aleatória de 200 itens (semente fixa: `[DEFINIR, sugestão: 20261115]`), cada
membro é chamado de novo (a) com as mesmas instruções, para medir a consistência teste-reteste, e
(b) com uma variante de redação do bloco de tarefa, mantida a rubrica, para medir a sensibilidade
à redação. Reportam-se a concordância e o kappa de cada comparação, por membro.

## 9. Validação humana

- **Amostra:** 400 itens, sorteados depois da agregação e antes de qualquer leitura humana dos
  resultados, estratificados pela classe final do painel (100 por classe, ou todos os itens da
  classe se houver menos de 100), com a probabilidade de seleção de cada item registrada.
  Semente: `[DEFINIR]`.
- **Codificadores:** `[DEFINIR: dois nomes]`. Cada um classifica todos os 400 itens aplicando a
  rubrica, de forma independente, sem ver a classe do painel, a classe de setembro, o termo do
  dicionário ou a ocupação. A ordem dos itens é sorteada separadamente para cada codificador.
- **Medidas:** concordância e kappa de Cohen humano × humano; humano × painel; matriz de confusão
  por classe; *alternative annotator test* (Calderon, Reichart e Dror, 2025) nos 100 primeiros
  itens da ordem sorteada.
- **Critério de aceitação:** kappa entre o consenso humano e o painel de pelo menos `[DEFINIR,
  sugestão: 0,70]` e aprovação no *alternative annotator test*. Se o critério falhar, a rubrica é
  revisada (com a revisão registrada no Git), e a rodada é refeita.
- **Uso na agregação:** a amostra, por ter probabilidades de seleção conhecidas, é usada para
  estimar as taxas de erro do painel por classe e corrigir as estimativas agregadas (Egami et al.,
  2023).

## 10. Desvios do protocolo

Registrar aqui, com data e motivo, qualquer mudança feita depois do registro.

| Data | Mudança | Motivo |
|---|---|---|
| | | |
