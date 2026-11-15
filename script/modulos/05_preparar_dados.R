###############################################################################
#                                                                             #
#   EMPREGO VERDE - 05. PREPARAÇÃO DOS DADOS (EXECUÇÃO)                       #
#                                                                             #
#   Constrói os objetos centrais usados pelos módulos seguintes:             #
#     - base_pnadc : base tratada + variáveis derivadas                       #
#     - cnae_verde : tabela de classificação verde CNAE                       #
#                                                                             #
#   ATENÇÃO: este é um script de EXECUÇÃO. Deve rodar via _run_pipeline.R     #
#   (ou após sourçar 00-04), pois deixa objetos no ambiente global que os     #
#   módulos 06, 07 e 08 consomem.                                             #
#                                                                             #
#   Dependências: 00_config.R, 02_classificacoes_verdes.R, 03_tratamento_base.R
#   Origem: emprego_verde_consolidado.R, seção 6 (carregar e preparar dados). #
#                                                                             #
###############################################################################

message("=== INÍCIO DA EXECUÇÃO ===")

# Etapa 3: Tratar base
base_pnadc <- tratar_base_pnadc()

# Etapa 4: Incluir variáveis derivadas
base_pnadc <- incluir_variaveis_derivadas(base_pnadc)

# Carregar cnae_verde para uso nas tabelas e exportações
cnae_verde <- read_xlsx(file.path(CAMINHO_DADOS_FINAL, "classif_cnae_verde.xlsx"))
