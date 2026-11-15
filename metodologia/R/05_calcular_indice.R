# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 05. CALCULO DO INDICE
# ==============================================================================
#
# Formulas (por ocupacao):
#
#   Denominador amplo:    N  = numero de registros de atividade da ocupacao
#   Denominador restrito: NE = numero de atividades EXCLUSIVAS da ocupacao,
#                              isto e, que nenhuma outra ocupacao da mesma
#                              familia tem (aproxima a "tarefa especifica" de
#                              Vona et al., 2018, que a CBO nao marca)
#
#   Verde_amplo        = nV / N             (so VERDE: verde estrito)
#   Verde_amplo_broad  = (nV + nP) / N      (VERDE + POTENCIAL)
#   Marrom             = nM / N
#   Liquido            = (nV - nM) / N
#   Liquido_broad      = (nV + nP - nM) / N
#   Verde_especifico   = nVE / NE
#   Marrom_especifico  = nME / NE
#   Liquido_especifico = (nVE - nME) / NE
#
# Os numeradores contam atividades distintas da ocupacao com a classe.
#
# Atencao ao vocabulario: "amplo" no nome da coluna se refere ao denominador
# (todas as atividades); "broad" se refere a inclusao de POTENCIAL.
#
# Qualificacao de uso (auditoria de recall): o verde estrito e estimativa
# pontual; o marrom e as medidas com POTENCIAL sao limites inferiores.
#
# Produz no ambiente: pares (ocupacao x atividade com classe), indice
# ==============================================================================

etapa("05. Calculo do indice")

# Denominador amplo: registros de atividade da ocupacao
n_ativ <- table(perfil$COD_OCUPACAO)

# Pares ocupacao x atividade distinta, com a classe (NA = sem conteudo
# ambiental capturado)
pares <- unique(perfil[, c("COD_OCUPACAO", "COD_FAMILIA", "chave")])
pares$classe <- unname(classe_de[pares$chave])

# Atividade exclusiva: so esta ocupacao a tem dentro da familia
usos <- aggregate(COD_OCUPACAO ~ COD_FAMILIA + chave, data = pares, FUN = length)
names(usos)[3] <- "n_usos_familia"
pares <- merge(pares, usos, by = c("COD_FAMILIA", "chave"))
pares$exclusiva <- pares$n_usos_familia <= 1

ocup <- sort(names(n_ativ))
conta <- function(filtro) {
  x <- tapply(filtro, pares$COD_OCUPACAO, sum)[ocup]
  x[is.na(x)] <- 0
  as.integer(x)
}

nv  <- conta(pares$classe %in% "VERDE")
np  <- conta(pares$classe %in% "POTENCIAL")
nm  <- conta(pares$classe %in% "MARROM")
nn  <- conta(pares$classe %in% "NEUTRO")
ne  <- conta(pares$exclusiva)
nve <- conta(pares$exclusiva & pares$classe %in% "VERDE")
nme <- conta(pares$exclusiva & pares$classe %in% "MARROM")
n   <- as.integer(n_ativ[ocup])

familia <- tapply(pares$COD_FAMILIA, pares$COD_OCUPACAO, `[`, 1)[ocup]

indice <- data.frame(
  CBO                = ocup,
  Ocupacao           = unname(titulos_ocup[ocup]),
  Familia            = unname(familia),
  Titulo_familia     = unname(titulos_fam[familia]),
  N_atividades       = n,
  Reportavel         = ifelse(n >= MINIMO_ATIVIDADES, "sim", "nao"),
  Verde_amplo        = razao(nv, n),
  Verde_amplo_broad  = razao(nv + np, n),
  Marrom             = razao(nm, n),
  Liquido            = razao(nv - nm, n),
  Liquido_broad      = razao(nv + np - nm, n),
  N_ativ_verdes      = nv,
  N_ativ_potenciais  = np,
  N_ativ_marrons     = nm,
  N_ativ_neutras     = nn,
  N_ativ_especificas = ne,
  Verde_especifico   = razao(nve, ne),
  Marrom_especifico  = razao(nme, ne),
  Liquido_especifico = razao(nve - nme, ne),
  stringsAsFactors   = FALSE,
  row.names          = NULL
)

cat("ocupacoes:", nrow(indice), "| reportaveis:",
    sum(indice$Reportavel == "sim"), "\n")
cat("ocupacoes com alguma atividade verde:", sum(nv > 0), "\n")
cat("ocupacoes com alguma atividade marrom:", sum(nm > 0), "\n")
