# ==============================================================================
# PAINEL DE MODELOS - SCRIPT MESTRE
# ==============================================================================
#
# Carrega o pipeline do indice (etapas 00 a 04) e as funcoes do painel. NAO
# chama API nenhuma ao ser carregado: cada passo e disparado a mao, na ordem
# do protocolo (metodologia/PROTOCOLO_CLASSIFICACAO.md).
#
#   MODO_PAINEL <- "simulado"   # ou "real" (custa dinheiro)
#   source("metodologia/R/painel/_run_painel.R")
#
#   testes_comportamento()      # secao 5: exemplos da rubrica, 14 chamadas por membro
#   rodar_painel()              # secao 3: todos os itens x 3 membros
#   agregar_painel()            # secao 7: votacao, concordancia, arbitragem.tsv
#     -> a equipe preenche resultados/arbitragem.tsv
#   rotulos <- finalizar_painel()
#   rodar_estabilidade(); avaliar_estabilidade()   # secao 8
#   sortear_validacao(rotulos)  # secao 9: gera as planilhas dos codificadores
#     -> os dois codificadores preenchem as planilhas
#   avaliar_validacao()
#
# Documentacao: metodologia/R/painel/LEIA-ME.md
# ==============================================================================

local({
  base <- file.path("metodologia", "R")
  for (a in c("00_config.R", "funcoes.R", "01_extrair_insumos.R", "02_ler_corpus.R",
              "03_gerar_candidatos.R", "04_rotulagem.R")) {
    source(file.path(base, a), encoding = "UTF-8", local = globalenv())
  }
  for (a in c("00_config_painel.R", "funcoes_painel.R", "01_preparar.R",
              "02_testes_comportamento.R", "03_rodar_painel.R", "04_agregar.R",
              "05_estabilidade.R", "06_validacao_humana.R")) {
    source(file.path(base, "painel", a), encoding = "UTF-8", local = globalenv())
  }
})

cat("\nModo:", MODO_PAINEL, "| saidas em", CAMINHOS_PAINEL$base, "\n")
for (m in names(PAINEL)) {
  cat(sprintf("  membro %s: %-9s %-20s chave %s\n", m, PAINEL[[m]]$provedor,
              PAINEL[[m]]$modelo,
              if (nzchar(Sys.getenv(PAINEL[[m]]$chave))) "definida" else "AUSENTE"))
}
