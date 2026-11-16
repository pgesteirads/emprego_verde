# ==============================================================================
# PAINEL DE MODELOS - 02. TESTES DE COMPORTAMENTO
# ==============================================================================
# Cada membro classifica os exemplos citados na propria RUBRICA.md. Detecta
# falhas grosseiras de seguimento da rubrica antes da rodada completa
# (Halterman e Keith, 2026). Nao e validacao: os exemplos estao no prompt.
# ==============================================================================

etapa("Painel 02. Testes de comportamento")

exemplos_rubrica <- data.frame(
  ATIVIDADE = c(
    "Cumprir normas regulamentadoras de saúde, segurança no trabalho e de preservação ambiental",
    "Atender normas de segurança, saúde, higiene e meio ambiente",
    "Cumprir normas ambientais",
    "Controlar condições ambientais envolvidas no experimento (luz, temperatura, umidade, radiação)",
    "Providenciar condições ambientais (luz, ar condicionado)",
    "Elaborar programas de prevenção de risco ambiental (ppra)",
    "Elaborar mapa de riscos ambientais e de segurança",
    "Remover resíduos das placas de impressão",
    "Retirar resíduos de areia das peças",
    "Remover resíduos de gesso do paciente",
    "Segregar resíduos de serviços de saúde",
    "Coletar resíduos industriais",
    "Acionar órgãos especializados (iml, bombeiros, meio ambiente)",
    "Tratar efluentes de mineração"),
  ESPERADO = c("NEUTRO", "NEUTRO", "VERDE", "NEUTRO", "NEUTRO", "NEUTRO", "NEUTRO",
               "NEUTRO", "NEUTRO", "NEUTRO", "VERDE", "VERDE", "NEUTRO", "VERDE"),
  REGRA_ESPERADA = c("NEUTRO_1", "NEUTRO_1", "VERDE", "NEUTRO_2", "NEUTRO_2",
                     "NEUTRO_3", "NEUTRO_3", "NEUTRO_4", "NEUTRO_4", "NEUTRO_4",
                     "VERDE", "VERDE", "NEUTRO_6", "VERDE"),
  stringsAsFactors = FALSE
)
exemplos_rubrica$ID <- sprintf("T%02d", seq_len(nrow(exemplos_rubrica)))
exemplos_rubrica$chave <- chave(exemplos_rubrica$ATIVIDADE)

testes_comportamento <- function(membros = names(PAINEL)) {
  res <- list()
  for (m in membros) {
    arq <- file.path(CAMINHOS_PAINEL$resultados, paste0("testes_comportamento_", m, ".jsonl"))
    rodar_membro(m, exemplos_rubrica, prompts$principal, prompts$hash_principal, arq,
                 progresso = 100)
    r <- respostas_validas(arq, prompts$hash_principal)
    x <- merge(exemplos_rubrica, r, by.x = "ID", by.y = "id", all.x = TRUE)
    x$membro <- m
    x$acerto_classe <- !is.na(x$classe) & x$classe == x$ESPERADO
    x$acerto_regra  <- !is.na(x$regra) & x$regra == x$REGRA_ESPERADA
    res[[m]] <- x
  }
  tab <- do.call(rbind, res)
  gravar_csv(tab[, c("membro", "ID", "ATIVIDADE", "ESPERADO", "classe",
                     "REGRA_ESPERADA", "regra", "acerto_classe", "acerto_regra",
                     "justificativa")],
             file.path(CAMINHOS_PAINEL$resultados, "testes_comportamento.csv"))
  resumo <- aggregate(cbind(erros_classe = !acerto_classe, erros_regra = !acerto_regra)
                      ~ membro, data = tab, FUN = sum)
  resumo$aprovado <- resumo$erros_classe <= MAX_ERROS_COMPORTAMENTO
  print(resumo, row.names = FALSE)
  if (any(!resumo$aprovado)) {
    warning("Membro(s) reprovado(s) nos testes de comportamento: ",
            paste(resumo$membro[!resumo$aprovado], collapse = ", "),
            ". Investigar antes da rodada completa (protocolo, secao 5).")
  }
  invisible(resumo)
}
