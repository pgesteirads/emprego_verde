# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - SCRIPT MESTRE
# ==============================================================================
#
# Refaz o indice do zero a partir das fontes primarias e dos insumos
# versionados, valida o resultado e exporta.
#
# Uso: abrir emprego_verde.Rproj e rodar
#
#     source("metodologia/R/_run_indice.R")
#
# ou, no terminal, a partir da raiz do projeto:
#
#     Rscript metodologia/R/_run_indice.R
#
# Etapas:
#   00_config.R           pacotes, caminhos, parametros
#   funcoes.R             funcoes auxiliares
#   01_extrair_insumos.R  planilha -> CSV versionados (so na primeira vez)
#   02_ler_corpus.R       Perfil Ocupacional da CBO
#   03_gerar_candidatos.R dicionario + excecoes -> atividades candidatas
#   04_rotulagem.R        classe de cada candidata (rubrica); rodadas novas
#   05_calcular_indice.R  contagens e indices por ocupacao
#   06_validar.R          testes; para o pipeline se algo divergir
#   07_exportar.R         CSV, xlsx e metadados em metodologia/saida/
#
# Documentacao: metodologia/R/LEIA-ME.md
# ==============================================================================

DIR_INDICE <- file.path("metodologia", "R")

t0 <- Sys.time()
for (arq in c("00_config.R", "funcoes.R", "01_extrair_insumos.R",
              "02_ler_corpus.R", "03_gerar_candidatos.R", "04_rotulagem.R",
              "05_calcular_indice.R", "06_validar.R", "07_exportar.R")) {
  source(file.path(DIR_INDICE, arq), encoding = "UTF-8")
}
cat(sprintf("\n=== INDICE CONCLUIDO em %.0f segundos ===\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
