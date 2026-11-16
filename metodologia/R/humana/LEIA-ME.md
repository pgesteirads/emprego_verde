# Classificação humana das atividades

Implementa `metodologia/PROTOCOLO_CLASSIFICACAO_HUMANA.md`. Três codificadores classificam, cada
um sozinho e às cegas, todas as atividades capturadas pelo dicionário, aplicando a
`RUBRICA.md`. As divergências são decididas em reunião, e uma amostra de atividades não
capturadas mede o que o dicionário deixa escapar.

## Antes de começar

1. Preencher os nomes em `CODIFICADORES` e a regra de decisão em `OPCAO_DECISAO` ("A" ou "B")
   em `00_config_humana.R`.
2. Preencher os campos `[DEFINIR]` do protocolo e fazer commit **antes** de gerar as planilhas.
   Esse commit é o pré-registro.

## Passo a passo

```r
source("metodologia/R/humana/_run_humana.R")
gerar_planilhas()
```

Gera, em `metodologia/classificacao_humana/planilhas/`, nove arquivos Excel:

| Arquivo | Linhas por pessoa | Conteúdo |
|---|---|---|
| `calibracao_C1.xlsx` (C2, C3) | 40 | Atividades para treinar a aplicação da rubrica |
| `principal_C1.xlsx` (C2, C3) | 1.917 | As 1.826 atividades restantes, mais 91 repetições escondidas |
| `recall_C1.xlsx` (C2, C3) | 800 | Atividades que o dicionário não capturou |

Cada planilha tem a ordem sorteada só para aquele codificador, mostra apenas o enunciado e traz
listas suspensas para CLASSE e REGRA. Entregar a cada pessoa os seus três arquivos.

**Calibração.** Cada um preenche a planilha de calibração. Depois:

```r
concordancia("calibracao")
preparar_reuniao("calibracao")   # gera resultados/reuniao_calibracao.xlsx
```

Na reunião, os três discutem as 40 atividades e preenchem DECISÃO, REGRA e JUSTIFICATIVA.
Ajustes de redação na rubrica, se houver, entram no histórico de alterações dela antes da etapa
principal.

**Classificação principal e recall.** Cada um preenche as suas planilhas, sem conversar sobre
itens específicos. Depois:

```r
concordancia("principal")
preparar_reuniao("principal")    # gera resultados/reuniao_principal.xlsx
```

A planilha da reunião tem duas abas: **Decidir** (atividades sem decisão automática, todas
obrigatórias) e **Conferir_alto_impacto** (atividades presentes em 10 ou mais ocupações que já
têm classe; preencher só se for mudar). As linhas vêm ordenadas pelo número de ocupações.

**Fechamento.**

```r
rotulos <- finalizar_rotulos()   # grava metodologia/insumos/rotulos_atividade_humana.csv
avaliar_recall()
```

## Conferências automáticas

- Linha sem classe, com classe ou regra inválida, ou com regra incompatível com a classe: o
  script para e lista as linhas em `resultados/pendencias_<etapa>.csv`.
- Planilha com linhas reordenadas ou apagadas: o script para.
- Reunião com linha sem decisão, regra ou justificativa: o script para.
- As planilhas existentes nunca são sobrescritas.

## Resultados (`metodologia/classificacao_humana/resultados/`)

| Arquivo | Conteúdo |
|---|---|
| `concordancia_<etapa>.csv` | Kappa por par, kappa de Fleiss, unanimidade e consistência de cada um nas repetições |
| `respostas_<etapa>.csv` | As três classificações individuais de cada atividade, com a decisão automática |
| `reuniao_<etapa>.xlsx` | O que foi decidido em conjunto, com justificativa |
| `recall_resumo.csv` e `recall_falsos_negativos.csv` | Taxa de falsos negativos do dicionário, com intervalo de confiança, e a lista dos casos |

Os rótulos finais registram, para cada atividade, a classe de cada codificador, como a classe
final foi decidida e a justificativa da reunião. Trocar o insumo do índice para esses rótulos é
um passo à parte (protocolo, seção 9).

## Teste

O fluxo foi testado de ponta a ponta no modo simulado (`MODO_HUMANA <- "simulado"`, saídas em
`metodologia/classificacao_humana_simulada/`, fora do Git), com codificadores simulados, um erro
proposital de preenchimento e uma reunião incompleta. Com 8% de discordância simulada por pessoa,
a opção A levou 312 atividades à reunião, e a opção B, 85.
