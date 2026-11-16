# ==============================================================================
# PAINEL DE MODELOS - 01. PREPARACAO DOS ITENS E DAS INSTRUCOES
# ==============================================================================
# Requer as etapas 00 a 04 do pipeline do indice (candidatos, perfil).
# Grava itens.tsv (o que sera classificado) e as instrucoes de sistema.
# O registro de hashes (registrar_protocolo) vai para o protocolo.
# ==============================================================================

etapa("Painel 01. Itens e instrucoes")

prompts <- montar_prompts()

itens <- data.frame(
  ID        = id_item(candidatos$chave),
  ATIVIDADE = perfil$NOME_ATIVIDADE[match(candidatos$chave, perfil$chave)],
  chave     = candidatos$chave,
  stringsAsFactors = FALSE
)
stopifnot(!anyDuplicated(itens$ID))
itens <- itens[order(itens$ID), ]
gravar_tsv(itens[, c("ID", "ATIVIDADE")], CAMINHOS_PAINEL$itens)

registro_protocolo <- list(
  data             = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  modo             = MODO_PAINEL,
  n_itens          = nrow(itens),
  hash_itens       = hash_arquivo(CAMINHOS_PAINEL$itens),
  hash_rubrica     = hash_arquivo(file.path(RAIZ, "metodologia", "RUBRICA.md")),
  hash_dicionario  = hash_arquivo(ARQ_INSUMOS$dicionario),
  hash_excecoes    = hash_arquivo(ARQ_INSUMOS$excecoes),
  hash_prompt      = prompts$hash_principal,
  hash_prompt_variante = prompts$hash_variante,
  painel           = lapply(PAINEL, function(m) m[c("provedor", "modelo")])
)
writeLines(jsonlite::toJSON(registro_protocolo, auto_unbox = TRUE, pretty = TRUE),
           file.path(CAMINHOS_PAINEL$base, "registro_protocolo.json"), useBytes = TRUE)

cat("itens:", nrow(itens), "\n")
cat("hash das instrucoes:", prompts$hash_principal, "\n")
cat("instrucoes em", CAMINHOS_PAINEL$prompt, "(", nchar(prompts$principal), "caracteres )\n")
