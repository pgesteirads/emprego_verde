# ==============================================================================
# PAINEL DE MODELOS - 03. RODADA COMPLETA
# ==============================================================================
# Classifica todos os itens com cada membro do painel. Pode ser interrompida e
# retomada: o que ja tem resposta valida nao e chamado de novo.
#
# Uso: rodar_painel()            # os tres membros, em sequencia
#      rodar_painel("B")         # so um membro
# Para ganhar tempo, cada membro pode rodar numa sessao do R separada.
# ==============================================================================

etapa("Painel 03. Rodada completa (funcoes carregadas)")

arquivo_respostas <- function(m) file.path(CAMINHOS_PAINEL$respostas, paste0(m, ".jsonl"))

rodar_painel <- function(membros = names(PAINEL)) {
  for (m in membros) {
    rodar_membro(m, itens, prompts$principal, prompts$hash_principal,
                 arquivo_respostas(m))
  }
  # Segunda passagem para os itens que falharam (rede, JSON invalido etc.)
  for (m in membros) {
    rodar_membro(m, itens, prompts$principal, prompts$hash_principal,
                 arquivo_respostas(m))
  }
}
