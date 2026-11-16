# ==============================================================================
# PAINEL DE MODELOS - 00. CONFIGURACAO
# ==============================================================================
#
# Tudo o que o protocolo (metodologia/PROTOCOLO_CLASSIFICACAO.md) fixa esta
# aqui. Alterar qualquer valor depois do pre-registro e um desvio: registre
# na secao 10 do protocolo.
#
# MODO
#   "simulado": nao chama API nenhuma; cada membro devolve uma classe gerada a
#               partir dos rotulos de setembro com ruido. Serve so para testar
#               o encadeamento das etapas. Saidas em metodologia/painel_simulado/
#   "real":     chama as APIs (custa dinheiro). Saidas em metodologia/painel/
#
# CHAVES DE API: nunca escreva a chave em codigo. Coloque no arquivo .Renviron
# do usuario (usethis::edit_r_environ() ou crie ~/.Renviron) as linhas
#   ANTHROPIC_API_KEY=...
#   OPENAI_API_KEY=...
#   GEMINI_API_KEY=...
# e reinicie o R.
# ==============================================================================

if (!exists("MODO_PAINEL")) MODO_PAINEL <- "simulado"
stopifnot(MODO_PAINEL %in% c("simulado", "real"))

PAINEL <- list(
  A = list(provedor = "anthropic", modelo = "claude-opus-5-5",
           chave = "ANTHROPIC_API_KEY", esforco = "medium"),
  # [DEFINIR] confirmar o identificador com listar_modelos("openai")
  B = list(provedor = "openai", modelo = "DEFINIR",
           chave = "OPENAI_API_KEY"),
  # [DEFINIR] confirmar o identificador com listar_modelos("google")
  C = list(provedor = "google", modelo = "DEFINIR",
           chave = "GEMINI_API_KEY")
)

DIR_PAINEL <- file.path(RAIZ, "metodologia",
                        if (MODO_PAINEL == "real") "painel" else "painel_simulado")
CAMINHOS_PAINEL <- list(
  base        = DIR_PAINEL,
  prompt      = file.path(DIR_PAINEL, "prompt_sistema.txt"),
  prompt_var  = file.path(DIR_PAINEL, "prompt_sistema_variante.txt"),
  itens       = file.path(DIR_PAINEL, "itens.tsv"),
  respostas   = file.path(DIR_PAINEL, "respostas"),
  estabilidade = file.path(DIR_PAINEL, "estabilidade"),
  resultados  = file.path(DIR_PAINEL, "resultados"),
  validacao   = file.path(DIR_PAINEL, "validacao_humana")
)
for (d in CAMINHOS_PAINEL[c("base", "respostas", "estabilidade", "resultados",
                            "validacao")]) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

# Parametros do protocolo
SEMENTE_ESTABILIDADE <- 20261115
N_ESTABILIDADE       <- 200
SEMENTE_VALIDACAO    <- 20261116
N_VALIDACAO_CLASSE   <- 100
N_ALT_TEST           <- 100
MAX_ERROS_COMPORTAMENTO <- 2

# Chamadas
MAX_TENTATIVAS <- 4       # novas tentativas em erro de rede, 429 ou 5xx
TIMEOUT_SEG    <- 180
MAX_TOKENS     <- 2000

# Regras validas e classe correspondente (secao 4 do protocolo)
REGRAS <- c(VERDE = "VERDE", POTENCIAL = "POTENCIAL", MARROM = "MARROM",
            NEUTRO_1 = "NEUTRO", NEUTRO_2 = "NEUTRO", NEUTRO_3 = "NEUTRO",
            NEUTRO_4 = "NEUTRO", NEUTRO_5 = "NEUTRO", NEUTRO_6 = "NEUTRO",
            NEUTRO_CONSERVADOR = "NEUTRO")
