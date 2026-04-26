# Emprego Verde

Classificação e análise do mercado de trabalho brasileiro sob a ótica ambiental, utilizando microdados da PNADc/IBGE.

---

## Sobre o Projeto

O projeto categoriza atividades econômicas e ocupações em três grupos — **Green**, **Neutral** e **Brown** — e analisa o perfil sociodemográfico dos trabalhadores em cada categoria ao longo do tempo.

| Categoria | Rótulo Original | Descrição |
|-----------|----------------|-----------|
| **Green** | Verde | Atividades diretamente ligadas à preservação ambiental, energias renováveis, gestão de resíduos |
| **Neutral** | Limpa | Atividades sem impacto ambiental significativo (serviços, educação, saúde) |
| **Brown** | Ambientalmente Sensível | Atividades com alto impacto ambiental (mineração, pecuária intensiva, indústria pesada) |

**Período de análise:** 2014, 2016, 2019 e 2024 (4º trimestre da PNADc).

**Início do projeto:** 2022 | **Última atualização:** abril de 2026.

---

## Classificação Verde — Metodologia

### Dimensão principal: Atividade (CNAE)

A classificação verde por atividade segue este processo:

1. **Harmonização CNAE Dom → CNAE 2.0:** cada código CNAE Domiciliar (variável `V4013` da PNADc) é mapeado para uma ou mais atividades da CNAE 2.0, que possuem classificação verde na literatura internacional. O mapeamento está na planilha `dados/referencia/Harmonizacao.xlsx`.

2. **Resolução de divergências via RAIS:** quando uma atividade CNAE Domiciliar mapeia para múltiplas atividades CNAE 2.0 com classificações diferentes, prevalece a classificação da atividade com maior quantidade de emprego formal na RAIS (anos: 2012, 2016, 2019, 2021). Os dados da RAIS são obtidos via BigQuery/BasedosDados.

3. **Classificação dos setores:** após classificar as atividades, os setores CNAE 2.0 (agrupamento de atividades) recebem classificação pelo mesmo critério de maior emprego.

4. **Tabela final:** o resultado é `dados/processados/classif_cnae_verde.xlsx`, contendo para cada CNAE Domiciliar: `class_verde_atividade` e `class_verde_setor`.

### Variantes testadas

A planilha de harmonização contém quatro colunas de classificação, representando variantes testadas ao longo do projeto. A adotada é `class_verde_definitiva`:

| Coluna | Descrição |
|--------|-----------|
| `class_verde_cnae20` | Classificação original baseada na CNAE 2.0 |
| `class_verde_cnae20_alternativo` | Variante alternativa |
| `class_verde_cnae20_alternativo_adm_pub` | Variante com tratamento especial para administração pública |
| `class_verde_definitiva` | **Classificação final adotada** — Verde (82), Limpa (133), Amb. Sensível (490), NA (294) |

### Dimensão secundária: Ocupação (CBO)

Baseada em Caruso (2010), classifica ocupações pela CBO Domiciliar. A referência é `dados/referencia/cbodom_classverde_caruso.xlsx`.

---

## Estrutura de Pastas

```
emprego_verde/
│
├── emprego_verde.Rproj                    # Projeto RStudio
├── README.md
├── .gitignore
├── documentacao_projeto_emprego_verde.docx # Documentação completa (Word)
│
├── script/
│   ├── emprego_verde_consolidado.R        # Script principal (~1.600 linhas)
│   └── legado/                            # Scripts individuais históricos (não usar)
│       ├── LEIA-ME.txt
│       ├── exercicio_2025.R
│       ├── gerando_class_verde.R
│       ├── gerando_class_verde_ocupacao.R
│       ├── leitura_pnadc_trim_4.R
│       ├── leitura_pnadc_visita1.R
│       ├── tratamento_base_dados.R
│       ├── tabelas_dos_graficos.R
│       ├── gera_tabela_bi.R
│       └── pnadc.R
│
├── dados/
│   ├── microdados_ibge/                   # Microdados brutos do FTP do IBGE
│   │   ├── LEIA-ME.txt
│   │   └── trimestral/                    # .txt do 4º trimestre + input + dicionário
│   │
│   ├── referencia/                        # Tabelas de referência e classificações
│   │   ├── Harmonizacao.xlsx              # Harmonização CNAE Dom ↔ CNAE 2.0 ↔ class. verde
│   │   ├── CNAE20_EstruturaDetalhada.xlsx
│   │   ├── cbo02_classverde_caruso.xlsx
│   │   ├── cbodom_classverde_caruso.xlsx
│   │   ├── Tradutor_KF.xlsx              # Compatibilização CNAE ↔ SCN
│   │   ├── uf_regiao.xlsx
│   │   └── ...
│   │
│   ├── processados/                       # Saídas intermediárias geradas pelos scripts
│   │   ├── classif_cnae_verde.xlsx        # Classificação verde final por CNAE Dom
│   │   ├── classif_divergentes.xlsx
│   │   ├── rais_vinculos.csv
│   │   └── ...
│   │
│   ├── pnadc_trim/                        # Parquets do 4º trimestre (2012–2024)
│   ├── deflator/                          # Deflatores da PNADc
│   └── base_pnadc_tratada_trimestral_4.parquet
│
├── produtos/
│   ├── apresentacoes/                     # Apresentações (BNDES, etc.)
│   ├── graficos/                          # Gráficos em PNG, organizados por tema
│   │   ├── arvore/                        #   Treemaps de ocupações
│   │   ├── cor/                           #   Composição racial
│   │   ├── escolaridade/                  #   Escolaridade média e distribuição
│   │   ├── formalidade/                   #   Formal vs. informal
│   │   ├── genero/                        #   Composição por gênero
│   │   ├── idade/                         #   Idade média
│   │   ├── mapa/                          #   Mapas por UF
│   │   ├── quantidade_ocupacao/           #   Evolução de ocupados
│   │   ├── regiao/                        #   Distribuição por região
│   │   ├── regiao_metropolitana/          #   Metropolitana vs. não-metropolitana
│   │   ├── renda/                         #   Renda média, percentis, distribuição
│   │   └── urbano_rural/                  #   Urbano vs. rural
│   ├── tabelas/
│   │   ├── analise/                       #   Tabelas analíticas finais
│   │   ├── dados_graficos/                #   Dados subjacentes aos gráficos (01–26)
│   │   └── auxiliar/                      #   Matrizes, listas, tabelas auxiliares
│   └── textos/
│
└── analise_scn/                           # Análise por Sistema de Contas Nacionais
```

---

## Pipeline de Dados

O script `emprego_verde_consolidado.R` executa toda a pipeline em etapas sequenciais:

```
┌──────────────────────────────────────────────────────────────────┐
│ Etapa 0: Parâmetros globais                                     │
│   Anos, trimestre, classificação escolhida, caminhos             │
└──────────────────────┬───────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Etapa 1: ler_pnadc_trimestral()                                 │
│   Microdados .txt (IBGE) → parquets em dados/pnadc_trim/        │
│   ⚠ Rodar apenas na primeira vez                                │
└──────────────────────┬───────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Etapa 2: gerar_classificacao_verde_cnae()                       │
│          carregar_classificacao_verde_cbo()                      │
│   Harmonizacao.xlsx + RAIS → classif_cnae_verde.xlsx             │
│   CBO Caruso → classificação por ocupação                        │
│   ⚠ Rodar apenas se classif_cnae_verde.xlsx não existir          │
└──────────────────────┬───────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Etapa 3: tratar_base_pnadc()                                    │
│   Seleção de variáveis + deflator → base tratada .parquet        │
└──────────────────────┬───────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Etapa 4: incluir_variaveis_derivadas()                          │
│   Formalidade, cor, região, classificação verde, renda           │
│   deflacionada, escolaridade, faixa etária, SCN                  │
└──────────────────────┬───────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Etapas 5–8: Análises                                            │
│   Survey design com pesos amostrais → tabelas descritivas        │
│   → gráficos (mapas, treemaps, barras, etc.) → exportação        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Como Rodar

### Pré-requisitos

- **R** (≥ 4.0) com **RStudio**
- **Conta Google Cloud** (projeto `emprego-verde`) para acesso à RAIS via BigQuery — necessário apenas na Etapa 2, se `classif_cnae_verde.xlsx` ainda não existir

### Instalação de pacotes

Os pacotes são instalados automaticamente na primeira execução via `librarian::shelf()`. Principais dependências:

| Categoria | Pacotes |
|-----------|---------|
| Manipulação de dados | `tidyverse`, `data.table`, `janitor`, `arrow` |
| PNADc | `PNADcIBGE` |
| Pesos amostrais | `survey`, `srvyr` |
| RAIS/BigQuery | `dbplyr`, `bigrquery` |
| Leitura/escrita | `readxl`, `writexl`, `openxlsx`, `haven`, `rio` |
| Visualização | `ggplot2`, `scales`, `treemapify`, `RColorBrewer` |
| Geoespacial | `geobr`, `sf` |

### Passo a passo

1. **Clonar o repositório** e abrir `emprego_verde.Rproj` no RStudio.

2. **Obter os microdados do IBGE.** Baixar os arquivos do 4º trimestre do [FTP do IBGE](https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/Trimestral/Microdados/) e colocá-los em `dados/microdados_ibge/trimestral/`. Os arquivos necessários são:
   - `PNADC_04XXXX.txt` (um por ano, 2012–2024)
   - `input_PNADC_trimestral.txt` (layout de leitura)
   - `dicionario_PNADC_microdados_trimestral.xls`
   - Deflator trimestral `.xls`

3. **Abrir `script/emprego_verde_consolidado.R`** e ajustar os parâmetros na seção 0 conforme necessário (anos de análise, classificação escolhida).

4. **Executar as etapas** sequencialmente. As etapas 1 e 2 possuem cache automático — se os arquivos de saída já existirem, são puladas com `[SKIP]`.

### Configuração da RAIS (apenas Etapa 2)

A Etapa 2 puxa dados da RAIS via [BasedosDados](https://basedosdados.org/) no Google BigQuery. Requisitos:

- Conta Google com projeto `emprego-verde` configurado no BigQuery
- Autorizar as permissões quando solicitado pelo R na primeira execução

Se `dados/processados/classif_cnae_verde.xlsx` já existir, esta etapa é pulada e o BigQuery não é necessário.

---

## Variáveis Derivadas

O script cria as seguintes variáveis a partir dos microdados:

| Variável | Fonte | Valores |
|----------|-------|---------|
| `class_verde_atividade` | `classif_cnae_verde.xlsx` via `V4013` | Green, Neutral, Brown |
| `class_verde_setor` | `classif_cnae_verde.xlsx` via `setor_cnae20_cod` | Green, Neutral, Brown |
| `class_verde_ocupacao` | Caruso (2010) via `V4010` | Green, Neutral, Brown |
| `formalidade` | Combinação de `VD4009` + `V4032` | Formal, Informal - Sem carteira, Informal - Conta própria, Informal, Ocupado sem informação |
| `cor` (recodificada) | `V2010` | Brancos e Amarelos, Pretos/Pardos/Indígenas, Ignorado |
| `renda_deflacionada` | `VD4016` × deflator Habitual | Contínua (R$) |
| `regiao_metrop` | `RM_RIDE` | Sim, Não |

---

## Produtos Gerados

### Gráficos (`produtos/graficos/`)

| Subpasta | Conteúdo |
|----------|----------|
| `arvore/` | Treemaps de composição das ocupações por classificação verde |
| `cor/` | Composição racial por classificação |
| `escolaridade/` | Escolaridade média e distribuição |
| `formalidade/` | Proporção formal/informal por classificação |
| `genero/` | Composição por gênero |
| `idade/` | Idade média por classificação |
| `mapa/` | Distribuição geográfica (UF) dos empregos |
| `quantidade_ocupacao/` | Evolução e proporção de ocupados |
| `regiao/` | Distribuição por grande região |
| `regiao_metropolitana/` | Metropolitana vs. não-metropolitana |
| `renda/` | Distribuição, média e percentis de renda |
| `urbano_rural/` | Distribuição urbano-rural |

### Tabelas (`produtos/tabelas/`)

| Subpasta | Conteúdo |
|----------|----------|
| `analise/` | Tabelas analíticas finais: total de ocupados, renda média, razão P90/P10, índice de Palma, características demográficas |
| `dados_graficos/` | Dados subjacentes a cada gráfico, numerados de 01 a 26 |
| `auxiliar/` | Matriz setor × ocupação, tabelas por atividade, por setor, IPEA |

---

## Fontes de Dados

| Fonte | Descrição | Acesso |
|-------|-----------|--------|
| **PNADc** (IBGE) | Pesquisa Nacional por Amostra de Domicílios Contínua — microdados do 4º trimestre | [FTP IBGE](https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_continua/) |
| **RAIS** (MTE) | Relação Anual de Informações Sociais — vínculos formais por CNAE | [BasedosDados](https://basedosdados.org/) via BigQuery |
| **CNAE 2.0** (IBGE) | Classificação Nacional de Atividades Econômicas | Incluída em `dados/referencia/` |
| **Caruso (2010)** | Classificação verde de ocupações (ISCO-08 / CBO) | Incluída em `dados/referencia/` |

---

## Licença

Projeto interno — Macroplan.
