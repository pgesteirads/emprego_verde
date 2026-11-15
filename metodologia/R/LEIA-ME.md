# Pipeline em R do índice de esverdeamento ocupacional

Este pipeline refaz do zero o índice de esverdeamento das 2.700 ocupações da CBO 2002, a partir
do Perfil Ocupacional e dos insumos versionados em `metodologia/insumos/`. Ele valida o
resultado contra a nota metodológica e contra o índice publicado em setembro de 2026, e grava
as saídas com metadados de rastreio.

## Como rodar

Abrir `emprego_verde.Rproj` no RStudio e executar:

```r
source("metodologia/R/_run_indice.R")
```

Leva cerca de 15 segundos. O console mostra cada etapa e, ao final, a tabela de validação. Se
qualquer verificação falhar, o pipeline para antes de exportar e diz onde olhar.

Requisito fora do git: `analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - PerfilOcupacional.csv` (e,
para os títulos, `CBO2002 - Ocupacao.csv` e `CBO2002 - Familia.csv`). O hash MD5 de cada um fica
registrado em `metodologia/saida/metadados.json`.

## As etapas

| Arquivo | O que faz |
|---|---|
| `00_config.R` | Pacotes, caminhos e todos os parâmetros que afetam o resultado |
| `funcoes.R` | Normalização de texto, leitura e gravação, kappa de Cohen |
| `01_extrair_insumos.R` | Só na primeira vez: tira da planilha canônica o dicionário, as exceções, os descartados, os rótulos e o índice publicado, e grava em CSV |
| `02_ler_corpus.R` | Lê o Perfil Ocupacional e cria a chave normalizada de cada enunciado |
| `03_gerar_candidatos.R` | Aplica o dicionário e as exceções; registra quais termos capturaram cada atividade |
| `04_rotulagem.R` | Junta a classe da rubrica a cada candidata; prepara rodadas para atividades novas |
| `05_calcular_indice.R` | Contagens, atividades exclusivas e índices |
| `06_validar.R` | 39 verificações em quatro blocos; para o pipeline se algo divergir |
| `07_exportar.R` | Grava CSV, xlsx e metadados |

## A separação mais importante

O **dicionário** (`insumos/dicionario.csv`) só seleciona as atividades que precisam ser lidas.
A **classe** de cada atividade vem de `insumos/rotulos_atividade.csv`, decidida pela leitura do
enunciado conforme `metodologia/RUBRICA.md`. Cerca de um quinto das capturas é NEUTRO: por
exemplo, "Retirar resíduos de areia das peças" casa com o termo `\bRESIDUO`, mas não é gestão de
resíduos. O pipeline nunca atribui classe pelo termo, e há um teste que garante isso.

## Insumos (`metodologia/insumos/`, versionados)

| Arquivo | Conteúdo |
|---|---|
| `dicionario.csv` | 183 expressões regulares (100 verde estrito, 30 potencial, 53 marrom), com categoria e fonte |
| `excecoes.csv` | 24 regras que suprimem capturas espúrias, com justificativa |
| `termos_descartados.csv` | 15 termos avaliados e rejeitados, com o motivo |
| `rotulos_atividade.csv` | 1.870 atividades com a classe final, as duas passagens, a arbitragem e a rodada de origem |
| `referencia_indice_2026_09.csv` | O índice publicado em setembro de 2026, para conferência |

Qualquer mudança nesses arquivos aparece no histórico do git. **Não editar os rótulos à mão**:
rótulos novos entram só pelo protocolo abaixo.

## Saídas (`metodologia/saida/`)

| Arquivo | Conteúdo |
|---|---|
| `indice_por_ocupacao.csv` | O índice, uma linha por ocupação |
| `atividades_por_ocupacao.csv` | Cada atividade classificada de cada ocupação, com a classe, se é exclusiva e os termos que a capturaram. Responde à pergunta "por que esta ocupação tem este valor?" |
| `indice_esverdeamento.xlsx` | As mesmas tabelas, mais a validação e a auditoria do dicionário |
| `validacao.csv` | Resultado das 39 verificações |
| `metadados.json` | Data, versões do R e dos pacotes, MD5 das fontes e dos insumos, contagens |
| `intermediarios/` | Candidatas, capturas por termo e supressões por exceção |

Os CSV estão em UTF-8, com separador ponto e vírgula e decimal vírgula, e abrem direto no Excel.

## O que a validação confere

- **A. Dicionário.** Os casos que definiram o desenho: "conhecimento" não pode casar com
  `\bCIMENTO\b`; "coquetel" não pode casar com coque; ginecologia, plexo solar, mineração de
  dados, artes plásticas, ruído cardíaco e dano moral não podem ser capturados.
- **B. Nota metodológica.** Os oito indicadores de conferência (2.672 ocupações reportáveis,
  margem extensiva verde de 51,2%, mediana de 0,0081 etc.) e o kappa de 0,934 entre as duas
  passagens da rodada original.
- **C. Índice publicado.** Comparação célula a célula das 13 colunas numéricas, nas 2.700
  ocupações. A única diferença aceita é a já documentada: duas contagens de atividades
  exclusivas (262615 e 325115) que diferem em uma unidade, sem efeito em nenhum índice.
- **D. Casos de controle.** Instalador fotovoltaico (732140): 0,101 na versão ampla e 0,900 na
  restrita.

Os blocos B e C valem enquanto corpus, dicionário e rótulos forem os da rodada original. Se um
deles mudar de propósito (nova versão da CBO, termo novo), a divergência é esperada: atualize
`REFERENCIA_NOTA` em `00_config.R` no mesmo commit e registre o motivo.

## Atividades novas: protocolo de rotulagem

Quando o dicionário captura uma atividade sem rótulo (nova versão da CBO ou termo novo), ela
**fica fora do índice** e o pipeline cria `metodologia/rotulagem/rodada_AAAA-MM-DD/` com
`itens.tsv` e instruções. O protocolo segue European Commission (2022):

1. Duas leituras independentes classificam `itens.tsv` conforme a rubrica e gravam
   `passagem_A.tsv` e `passagem_B.tsv` (colunas `ID` e `CLASSE`, separadas por TAB).
2. `avaliar_rodada("metodologia/rotulagem/rodada_AAAA-MM-DD")` calcula a concordância e o kappa
   e grava `divergencias.tsv`.
3. Uma terceira leitura preenche `ARBITRAGEM` e `JUSTIFICATIVA` nas divergências.
4. `incorporar_rodada("metodologia/rotulagem/rodada_AAAA-MM-DD")` acrescenta os rótulos a
   `insumos/rotulos_atividade.csv`, com o nome da rodada. Recusa-se a rodar se faltar arbitragem
   ou justificativa.
5. Rodar o pipeline de novo e fazer commit dos CSV e da pasta da rodada.

As funções ficam disponíveis no ambiente depois de rodar o pipeline.

## Relação com os scripts anteriores

`metodologia/construir_indice.R` e `construir_indice.py` são as reconstruções de novembro de
2026 e produzem o mesmo índice. Este pipeline os substitui no uso corrente porque lê os insumos
de CSV versionado (e não da planilha), registra a trilha de auditoria e para quando algo diverge.

## Próximo passo previsto

Etapa 08: aplicar o índice à RAIS, com ponderação pelo emprego na CBO a seis dígitos, para as
estimativas de referência. Agregar sempre ponderando, nunca por média simples.
