# Painel de modelos para a classificação das atividades

Implementa o protocolo `metodologia/PROTOCOLO_CLASSIFICACAO.md`, cuja fundamentação está em
`metodologia/REVISAO_ANOTACAO_LLM.md`. Três modelos de empresas diferentes (Anthropic, OpenAI e
Google) classificam cada atividade candidata pela `RUBRICA.md`, de forma independente e às cegas.
As classes são agregadas por votação, as divergências são arbitradas pela equipe e o resultado é
validado contra codificação humana.

## Antes da rodada real

1. **Chaves de API.** Criar conta e chave em cada empresa e colocar no arquivo `.Renviron` do
   usuário (no R: `usethis::edit_r_environ()`), uma por linha:
   `ANTHROPIC_API_KEY=...`, `OPENAI_API_KEY=...`, `GEMINI_API_KEY=...`. Reiniciar o R. O
   `.gitignore` impede que `.Renviron` vá para o Git.
2. **Modelos.** Com as chaves definidas, rodar `listar_modelos("openai")` e
   `listar_modelos("google")`, escolher o modelo de uso geral mais capaz de cada empresa e
   preencher em `00_config_painel.R` e na seção 3 do protocolo.
3. **Protocolo.** Preencher os campos `[DEFINIR]` do protocolo (árbitros, codificadores,
   limiares) e fazer commit **antes** de rodar. Esse commit é o pré-registro.

## Como rodar

```r
MODO_PAINEL <- "real"          # "simulado" testa o encadeamento sem chamar API
source("metodologia/R/painel/_run_painel.R")

testes_comportamento()         # 14 exemplos da rubrica por membro
rodar_painel()                 # 1.866 itens x 3 membros; pode ser interrompido e retomado
agregar_painel()               # votação, concordância e resultados/arbitragem.tsv
# -> a equipe preenche ARBITRAGEM, REGRA, JUSTIFICATIVA e ARBITROS em arbitragem.tsv
rotulos <- finalizar_painel()  # grava insumos/rotulos_atividade_painel.csv
rodar_estabilidade(); avaliar_estabilidade()
sortear_validacao(rotulos)     # gera as planilhas dos dois codificadores
# -> cada codificador preenche a sua planilha, sem consultar a outra
avaliar_validacao()            # kappas, matriz de confusão, alternative annotator test
```

Carregar o script não chama nenhuma API: cada passo é disparado à mão.

## Arquivos

| Arquivo | Função |
|---|---|
| `00_config_painel.R` | Modo, membros do painel, sementes, tamanhos de amostra |
| `funcoes_painel.R` | Montagem das instruções, chamadas às três APIs, registro e retomada |
| `bloco_tarefa.txt` | Texto exato da tarefa enviado após a rubrica |
| `bloco_tarefa_variante.txt` | Mesma tarefa com outra redação, para o teste de estabilidade |
| `01_preparar.R` | Itens a classificar e registro dos hashes (`registro_protocolo.json`) |
| `02_testes_comportamento.R` | Exemplos da rubrica com a classe e a regra esperadas |
| `03_rodar_painel.R` | Rodada completa |
| `04_agregar.R` | Regras de votação, concordância, arbitragem e rótulos finais |
| `05_estabilidade.R` | Teste-reteste e variante de redação |
| `06_validacao_humana.R` | Sorteio da amostra, planilhas dos codificadores e avaliação |

## Saídas (`metodologia/painel/`, versionadas)

- `prompt_sistema.txt` e `prompt_sistema_variante.txt`: o texto integral enviado aos modelos.
- `itens.tsv`: os itens com o identificador estável.
- `registro_protocolo.json`: hashes da rubrica, do dicionário, dos itens e das instruções, e os
  modelos.
- `respostas/A.jsonl`, `B.jsonl`, `C.jsonl`: uma linha por chamada, com a resposta bruta integral.
- `resultados/`: testes de comportamento, painel agregado, concordância, arbitragem,
  estabilidade, validação humana.
- `validacao_humana/`: as planilhas dos codificadores e o gabarito (que os codificadores não
  devem abrir antes de terminar).

O modo simulado grava em `metodologia/painel_simulado/`, que não vai para o Git.

## Depois da rodada

Os rótulos finais ficam em `insumos/rotulos_atividade_painel.csv`, ao lado dos de setembro. Trocar
o insumo do índice para os novos rótulos é uma decisão à parte, depois da validação humana: muda
`ARQ_INSUMOS$rotulos` em `metodologia/R/00_config.R`, e os blocos B e C da validação do índice
passam a divergir da nota de setembro, como esperado. Atualizar `REFERENCIA_NOTA` no mesmo commit.

## O que não foi testado

O encadeamento foi testado de ponta a ponta no modo simulado. As chamadas reais às três APIs só
podem ser testadas com as chaves. O formato das requisições segue a documentação de cada empresa
consultada em novembro de 2026; se alguma API recusar a requisição, a mensagem de erro fica
registrada no `.jsonl` e o item é tentado de novo na execução seguinte.
