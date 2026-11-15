###############################################################################
#                                                                             #
#   EMPREGO VERDE - 11. DE-PARA SETOR x ATIVIDADE (CNAE)                       #
#                                                                             #
#   Gera a tabela de-para (mapeamento) entre os SETORES (setor_cnae20) e as   #
#   ATIVIDADES (cnaedom) usados no projeto, com as respectivas classificações #
#   verdes. Serve para documentar/consultar quais atividades compõem cada     #
#   setor.                                                                     #
#                                                                             #
#   Estrutura da saída (1 linha por atividade):                               #
#     setor_cnae20_cod | setor_cnae20_nome | class_verde_setor |              #
#     cnaedom_cod | cnaedom_nome | class_verde_atividade                       #
#                                                                             #
#   OBS: no projeto, a "abertura por atividade" é a coluna `cnaedom_nome`     #
#   (não existe 'atividade_cnae20_nome'); o "setor" é `setor_cnae20_nome`.    #
#                                                                             #
#   Fonte: objeto `cnae_verde` (se já carregado pelo módulo 05) ou, na        #
#   falta dele, a planilha dados/processados/classif_cnae_verde.xlsx.         #
#                                                                             #
#   Saída: produtos/tabelas/de_para_setor_atividade.xlsx                       #
#                                                                             #
#   Dependências: 00_config.R (pacotes e caminhos). O módulo 05 é opcional.   #
#   Encoding: arquivo em UTF-8; nenhuma string funcional usa acento (apenas   #
#   comentários), então roda igual sob latin1 ou UTF-8.                        #
#                                                                             #
###############################################################################

message("  Gerando de-para Setor x Atividade...")

# --- Fonte dos dados: usa `cnae_verde` do ambiente; se não existir, lê o xlsx ---
if (exists("cnae_verde")) {
  fonte_cnae <- cnae_verde
} else {
  caminho_classif <- file.path(
    if (exists("CAMINHO_DADOS_FINAL")) CAMINHO_DADOS_FINAL
    else here::here("dados", "processados"),
    "classif_cnae_verde.xlsx"
  )
  message(glue::glue("  [INFO] cnae_verde não encontrado; lendo {caminho_classif}"))
  fonte_cnae <- readxl::read_xlsx(caminho_classif)
}

# --- Montar o de-para (uma linha por atividade -> seu setor) ---
de_para_setor_atividade <- fonte_cnae %>%
  dplyr::select(
    setor_cnae20_cod, setor_cnae20_nome, class_verde_setor,
    cnaedom_cod, cnaedom_nome, class_verde_atividade
  ) %>%
  dplyr::distinct() %>%
  dplyr::arrange(setor_cnae20_cod, cnaedom_cod)

# --- Exportar ---
caminho_saida <- file.path(
  if (exists("CAMINHO_PRODUTOS_TAB")) CAMINHO_PRODUTOS_TAB
  else here::here("produtos", "tabelas"),
  "de_para_setor_atividade.xlsx"
)

writexl::write_xlsx(de_para_setor_atividade, path = caminho_saida)

message(glue::glue(
  "  [OK] Salvo: {caminho_saida} ",
  "({nrow(de_para_setor_atividade)} atividades em ",
  "{dplyr::n_distinct(de_para_setor_atividade$setor_cnae20_nome, na.rm = TRUE)} setores)"
))
