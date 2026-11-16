# ==============================================================================
# PAINEL DE MODELOS - 05. ESTABILIDADE
# ==============================================================================
# Numa amostra fixa de itens, chama cada membro de novo (a) com as mesmas
# instrucoes (teste-reteste) e (b) com a variante de redacao do bloco de
# tarefa (sensibilidade a redacao). Compara com a rodada principal.
# Protocolo, secao 8.
# ==============================================================================

etapa("Painel 05. Estabilidade (funcoes carregadas)")

amostra_estabilidade <- function() {
  set.seed(SEMENTE_ESTABILIDADE)
  itens[sort(sample(nrow(itens), min(N_ESTABILIDADE, nrow(itens)))), ]
}

rodar_estabilidade <- function(membros = names(PAINEL)) {
  am <- amostra_estabilidade()
  for (m in membros) {
    rodar_membro(m, am, prompts$principal, prompts$hash_principal,
                 file.path(CAMINHOS_PAINEL$estabilidade, paste0(m, "_reteste.jsonl")))
    rodar_membro(m, am, prompts$variante, prompts$hash_variante,
                 file.path(CAMINHOS_PAINEL$estabilidade, paste0(m, "_variante.jsonl")))
  }
}

avaliar_estabilidade <- function(membros = names(PAINEL)) {
  am <- amostra_estabilidade()
  res <- do.call(rbind, lapply(membros, function(m) {
    princ <- respostas_validas(arquivo_respostas(m), prompts$hash_principal)
    ret <- respostas_validas(file.path(CAMINHOS_PAINEL$estabilidade,
                                       paste0(m, "_reteste.jsonl")), prompts$hash_principal)
    var <- respostas_validas(file.path(CAMINHOS_PAINEL$estabilidade,
                                       paste0(m, "_variante.jsonl")), prompts$hash_variante)
    p <- princ$classe[match(am$ID, princ$id)]
    k1 <- kappa_cohen(p, ret$classe[match(am$ID, ret$id)])
    k2 <- kappa_cohen(p, var$classe[match(am$ID, var$id)])
    data.frame(membro = m,
               comparacao = c("teste-reteste", "variante de redacao"),
               n = c(k1$n, k2$n),
               concordancia = round(c(k1$concordancia, k2$concordancia), 4),
               kappa = round(c(k1$kappa, k2$kappa), 4))
  }))
  gravar_csv(res, file.path(CAMINHOS_PAINEL$resultados, "estabilidade.csv"))
  print(res, row.names = FALSE)
  invisible(res)
}
