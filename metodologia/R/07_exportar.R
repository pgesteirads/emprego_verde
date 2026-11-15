# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 07. EXPORTACAO
# ==============================================================================
#
# Grava em metodologia/saida/:
#
#   indice_por_ocupacao.csv     o indice, uma linha por ocupacao (versionado)
#   atividades_por_ocupacao.csv cada atividade classificada de cada ocupacao,
#                               com a classe e os termos que a capturaram.
#                               Responde "por que a ocupacao X tem esse valor?"
#   indice_esverdeamento.xlsx   as mesmas tabelas, mais a validacao e os
#                               metadados, para uso em planilha
#   metadados.json              data, versoes do R e dos pacotes, hash MD5 de
#                               cada insumo e fonte, parametros e contagens
#
# CSV em UTF-8 com BOM, separador ; e decimal virgula (abre direto no Excel).
# ==============================================================================

etapa("07. Exportacao")

# --- Atividades classificadas por ocupacao (trilha de auditoria) ---
ativ <- pares[!is.na(pares$classe), c("COD_OCUPACAO", "COD_FAMILIA", "chave",
                                      "classe", "exclusiva")]
texto_orig <- perfil$NOME_ATIVIDADE[match(ativ$chave, perfil$chave)]
ativ <- data.frame(
  CBO        = ativ$COD_OCUPACAO,
  Ocupacao   = unname(titulos_ocup[ativ$COD_OCUPACAO]),
  Familia    = ativ$COD_FAMILIA,
  Atividade  = texto_orig,
  Classe     = ativ$classe,
  Exclusiva  = ifelse(ativ$exclusiva, "sim", "nao"),
  Termos_dicionario = candidatos$termos[match(ativ$chave, candidatos$chave)],
  stringsAsFactors = FALSE
)
ativ <- ativ[order(ativ$CBO, match(ativ$Classe, CLASSES), ativ$Atividade), ]

# --- Metadados ---
pacotes <- c("readxl", "stringi", "writexl", "jsonlite")
metadados <- list(
  gerado_em        = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  r_versao         = R.version.string,
  pacotes          = setNames(lapply(pacotes, function(p) as.character(packageVersion(p))), pacotes),
  parametros       = list(minimo_atividades = MINIMO_ATIVIDADES),
  fontes_primarias = setNames(as.list(fontes$md5), fontes$arquivo),
  insumos_md5      = lapply(ARQ_INSUMOS, hash_arquivo),
  contagens        = list(
    registros_atividade   = nrow(perfil),
    enunciados_distintos  = length(distintos),
    termos_dicionario     = nrow(dicionario),
    excecoes              = nrow(excecoes),
    candidatas            = nrow(candidatos),
    candidatas_sem_rotulo = length(sem_rotulo),
    ocupacoes             = nrow(indice),
    ocupacoes_reportaveis = sum(indice$Reportavel == "sim")
  ),
  validacao = list(verificacoes = nrow(validacao),
                   falhas = sum(validacao$situacao != "ok"))
)

# --- Gravacao ---
gravar_csv(indice, file.path(CAMINHOS$saida, "indice_por_ocupacao.csv"))
gravar_csv(ativ,   file.path(CAMINHOS$saida, "atividades_por_ocupacao.csv"))
writeLines(jsonlite::toJSON(metadados, auto_unbox = TRUE, pretty = TRUE),
           file.path(CAMINHOS$saida, "metadados.json"), useBytes = TRUE)

leia_me <- data.frame(Item = c(
  "Indice de esverdeamento ocupacional pela abordagem de conteudo de tarefas, CBO 2002.",
  paste0("Gerado por metodologia/R/_run_indice.R em ", metadados$gerado_em, "."),
  "Indice = atividades da classe / total de atividades da ocupacao (Perfil Ocupacional).",
  "Colunas 'amplo': denominador com todas as atividades. 'especifico': so atividades exclusivas na familia.",
  "Colunas 'broad': incluem POTENCIAL junto com VERDE.",
  "Verde estrito e estimativa pontual; marrom e medidas com POTENCIAL sao limites inferiores (auditoria de recall).",
  "Nao usar ocupacoes com Reportavel = nao (menos de 15 atividades).",
  "Agregar sempre ponderando pelo emprego, nunca por media simples.",
  "Criterio de classificacao: metodologia/RUBRICA.md."
))
writexl::write_xlsx(list(
  `Leia-me`               = leia_me,
  Indice_por_ocupacao     = indice,
  Atividades_por_ocupacao = ativ,
  Validacao               = validacao,
  Auditoria_termos        = auditoria_termos,
  Auditoria_excecoes      = auditoria_excecoes
), file.path(CAMINHOS$saida, "indice_esverdeamento.xlsx"))

cat("gravado em", CAMINHOS$saida, ":\n")
cat("  indice_por_ocupacao.csv (", nrow(indice), " ocupacoes)\n", sep = "")
cat("  atividades_por_ocupacao.csv (", nrow(ativ), " linhas)\n", sep = "")
cat("  indice_esverdeamento.xlsx\n  metadados.json\n  validacao.csv\n")
