# ==============================================================================
# PAINEL DE MODELOS - FUNCOES
# ==============================================================================
# Montagem das instrucoes, chamadas as tres APIs, registro e retomada.
# Sem efeitos colaterais ao ser carregado. ASCII puro de proposito.
# ==============================================================================

# ------------------------------------------------------------------------------
# Instrucoes
# ------------------------------------------------------------------------------

# Os blocos de tarefa ficam em arquivos de texto (UTF-8) ao lado deste script,
# para que o texto exato enviado aos modelos possa ser lido e citado.
#   bloco_tarefa.txt           instrucao principal
#   bloco_tarefa_variante.txt  mesma instrucao com outra redacao e outra ordem,
#                              usada so no teste de estabilidade
ler_bloco <- function(arq) {
  paste(readLines(file.path(RAIZ, "metodologia", "R", "painel", arq),
                  encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

# Extrai da RUBRICA.md as secoes de "Contexto de aplicacao" ate "Regras de
# decisao" (inclusive), sem alterar o texto.
extrair_rubrica <- function(caminho = file.path(RAIZ, "metodologia", "RUBRICA.md")) {
  linhas <- readLines(caminho, encoding = "UTF-8", warn = FALSE)
  ini <- grep("^## Contexto de aplica", linhas)
  fim <- grep("^## Protocolo de aplica", linhas) - 1
  stopifnot(length(ini) == 1, length(fim) == 1, fim > ini)
  titulo <- linhas[1]
  paste(c(titulo, "", linhas[ini:fim]), collapse = "\n")
}

montar_prompts <- function() {
  rub <- extrair_rubrica()
  p  <- paste(rub, ler_bloco("bloco_tarefa.txt"), sep = "\n\n")
  pv <- paste(rub, ler_bloco("bloco_tarefa_variante.txt"), sep = "\n\n")
  escrever_utf8 <- function(txt, arq) {
    con <- file(arq, open = "wb"); on.exit(close(con))
    writeBin(charToRaw(enc2utf8(txt)), con)
  }
  escrever_utf8(p, CAMINHOS_PAINEL$prompt)
  escrever_utf8(pv, CAMINHOS_PAINEL$prompt_var)
  list(principal = p, variante = pv,
       hash_principal = hash_texto(p), hash_variante = hash_texto(pv))
}

# hash_texto() e id_item() estao em metodologia/R/funcoes.R

# Esquema JSON da resposta
esquema_resposta <- function() {
  list(
    type = "object",
    properties = list(
      classe        = list(type = "string", enum = CLASSES),
      regra         = list(type = "string", enum = names(REGRAS)),
      justificativa = list(type = "string")
    ),
    required = list("classe", "regra", "justificativa"),
    additionalProperties = FALSE
  )
}

# ------------------------------------------------------------------------------
# Chamadas por provedor
# ------------------------------------------------------------------------------

chave_api <- function(membro) {
  k <- Sys.getenv(membro$chave)
  if (!nzchar(k)) stop("Variavel de ambiente ", membro$chave, " nao definida. ",
                       "Veja as instrucoes em 00_config_painel.R.")
  k
}

requisicao_base <- function(req) {
  req |>
    httr2::req_timeout(TIMEOUT_SEG) |>
    httr2::req_retry(max_tries = MAX_TENTATIVAS,
                     is_transient = function(resp) httr2::resp_status(resp) %in% c(408, 429, 500, 502, 503, 504, 529),
                     backoff = function(i) min(60, 2^i)) |>
    httr2::req_error(is_error = function(resp) FALSE)
}

req_anthropic <- function(membro, sistema, texto) {
  corpo <- list(
    model = membro$modelo,
    max_tokens = MAX_TOKENS,
    system = list(list(type = "text", text = sistema,
                       cache_control = list(type = "ephemeral"))),
    messages = list(list(role = "user",
                         content = paste0("Enunciado de atividade: ", texto))),
    output_config = list(effort = membro$esforco,
                         format = list(type = "json_schema",
                                       schema = esquema_resposta()))
  )
  httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(`x-api-key` = chave_api(membro),
                       `anthropic-version` = "2026-10-21",
                       `content-type` = "application/json") |>
    httr2::req_body_json(corpo, auto_unbox = TRUE)
}

ler_anthropic <- function(j) {
  if (!is.null(j$stop_reason) && j$stop_reason == "refusal") stop("recusa do modelo")
  txt <- NULL
  for (b in j$content) if (identical(b$type, "text")) txt <- b$text
  list(texto = txt, modelo = j$model)
}

req_openai <- function(membro, sistema, texto) {
  corpo <- list(
    model = membro$modelo,
    messages = list(
      list(role = "system", content = sistema),
      list(role = "user", content = paste0("Enunciado de atividade: ", texto))
    ),
    response_format = list(type = "json_schema",
                           json_schema = list(name = "classificacao",
                                              strict = TRUE,
                                              schema = esquema_resposta()))
  )
  httr2::request("https://api.openai.com/v1/chat/completions") |>
    httr2::req_auth_bearer_token(chave_api(membro)) |>
    httr2::req_body_json(corpo, auto_unbox = TRUE)
}

ler_openai <- function(j) {
  m <- j$choices[[1]]$message
  if (!is.null(m$refusal)) stop("recusa do modelo: ", m$refusal)
  list(texto = m$content, modelo = j$model)
}

# Esquema no formato OpenAPI aceito pelo Gemini
esquema_gemini <- function() {
  list(
    type = "OBJECT",
    properties = list(
      classe        = list(type = "STRING", enum = CLASSES),
      regra         = list(type = "STRING", enum = names(REGRAS)),
      justificativa = list(type = "STRING")
    ),
    required = list("classe", "regra", "justificativa")
  )
}

req_google <- function(membro, sistema, texto) {
  corpo <- list(
    systemInstruction = list(parts = list(list(text = sistema))),
    contents = list(list(role = "user",
                         parts = list(list(text = paste0("Enunciado de atividade: ", texto))))),
    generationConfig = list(responseMimeType = "application/json",
                            responseSchema = esquema_gemini())
  )
  url <- sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent",
                 membro$modelo)
  httr2::request(url) |>
    httr2::req_headers(`x-goog-api-key` = chave_api(membro)) |>
    httr2::req_body_json(corpo, auto_unbox = TRUE)
}

ler_google <- function(j) {
  cand <- j$candidates[[1]]
  if (is.null(cand$content)) stop("sem conteudo; finishReason = ", cand$finishReason)
  partes <- vapply(cand$content$parts, function(p) if (is.null(p$text)) "" else p$text,
                   character(1))
  list(texto = paste(partes, collapse = ""), modelo = j$modelVersion)
}

# Modo simulado: deriva a classe dos rotulos de setembro, com ruido diferente
# por membro. NAO e classificacao; serve so para testar o encadeamento.
classificar_simulado <- function(membro_id, chave_item) {
  set.seed(strtoi(substr(hash_texto(paste(membro_id, chave_item)), 1, 7), 16L))
  base <- unname(classe_todas[chave_item])
  if (is.na(base)) base <- "NEUTRO"
  cls <- if (runif(1) < 0.07) sample(setdiff(CLASSES, base), 1) else base
  regra <- if (cls == "NEUTRO") sample(c("NEUTRO_1", "NEUTRO_4", "NEUTRO_CONSERVADOR"), 1) else cls
  list(texto = jsonlite::toJSON(list(classe = cls, regra = regra,
                                     justificativa = "simulado"), auto_unbox = TRUE),
       modelo = paste0("simulado-", membro_id))
}

# ------------------------------------------------------------------------------
# Classificacao de um item e registro
# ------------------------------------------------------------------------------

validar_resposta <- function(texto) {
  r <- tryCatch(jsonlite::fromJSON(texto), error = function(e) NULL)
  if (is.null(r) || is.null(r$classe) || is.null(r$regra)) {
    return(list(ok = FALSE, erro = "JSON invalido ou incompleto"))
  }
  if (!r$classe %in% CLASSES) return(list(ok = FALSE, erro = "classe invalida"))
  if (!r$regra %in% names(REGRAS) || REGRAS[[r$regra]] != r$classe) {
    return(list(ok = FALSE, erro = paste("regra incompativel com a classe:", r$regra)))
  }
  list(ok = TRUE, classe = r$classe, regra = r$regra,
       justificativa = if (is.null(r$justificativa)) NA_character_ else r$justificativa)
}

classificar_item <- function(membro_id, item_id, texto, chave_item, sistema, hash_prompt) {
  membro <- PAINEL[[membro_id]]
  reg <- list(id = item_id, membro = membro_id, provedor = membro$provedor,
              modelo_solicitado = membro$modelo, modelo_resposta = NA_character_,
              data_hora = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
              hash_prompt = hash_prompt, status_http = NA_integer_,
              resposta_bruta = NA_character_, classe = NA_character_,
              regra = NA_character_, justificativa = NA_character_, erro = NA_character_)
  res <- tryCatch({
    if (MODO_PAINEL == "simulado") {
      reg$status_http <- 200L
      out <- classificar_simulado(membro_id, chave_item)
      reg$resposta_bruta <- as.character(out$texto)
      out
    } else {
      req <- switch(membro$provedor,
                    anthropic = req_anthropic(membro, sistema, texto),
                    openai    = req_openai(membro, sistema, texto),
                    google    = req_google(membro, sistema, texto))
      resp <- requisicao_base(req) |> httr2::req_perform()
      reg$status_http <- httr2::resp_status(resp)
      reg$resposta_bruta <- httr2::resp_body_string(resp)
      if (reg$status_http != 200) stop("HTTP ", reg$status_http)
      j <- jsonlite::fromJSON(reg$resposta_bruta, simplifyVector = FALSE)
      switch(membro$provedor, anthropic = ler_anthropic(j),
             openai = ler_openai(j), google = ler_google(j))
    }
  }, error = function(e) { reg$erro <<- conditionMessage(e); NULL })

  if (!is.null(res)) {
    reg$modelo_resposta <- if (is.null(res$modelo)) NA_character_ else res$modelo
    v <- validar_resposta(res$texto)
    if (v$ok) {
      reg$classe <- v$classe; reg$regra <- v$regra; reg$justificativa <- v$justificativa
    } else {
      reg$erro <- v$erro
    }
  }
  reg
}

anexar_jsonl <- function(reg, arquivo) {
  linha <- jsonlite::toJSON(reg, auto_unbox = TRUE, na = "null")
  con <- file(arquivo, open = "ab"); on.exit(close(con))
  writeBin(charToRaw(paste0(enc2utf8(as.character(linha)), "\n")), con)
}

ler_jsonl <- function(arquivo) {
  if (!file.exists(arquivo)) return(NULL)
  linhas <- readLines(arquivo, encoding = "UTF-8", warn = FALSE)
  linhas <- linhas[nzchar(linhas)]
  if (!length(linhas)) return(NULL)
  regs <- lapply(linhas, jsonlite::fromJSON)
  campos <- c("id", "membro", "modelo_solicitado", "modelo_resposta", "data_hora",
              "hash_prompt", "status_http", "classe", "regra", "justificativa", "erro")
  as.data.frame(do.call(rbind, lapply(regs, function(r) {
    vapply(campos, function(f) if (is.null(r[[f]])) NA_character_ else as.character(r[[f]]),
           character(1))
  })), stringsAsFactors = FALSE)
}

# Roda um membro sobre um conjunto de itens. Retoma de onde parou: itens que
# ja tem resposta valida no arquivo nao sao chamados de novo.
rodar_membro <- function(membro_id, itens, sistema, hash_prompt, arquivo,
                         progresso = 50) {
  feitos <- ler_jsonl(arquivo)
  ja_ok <- if (is.null(feitos)) character(0) else
    feitos$id[!is.na(feitos$classe) & feitos$hash_prompt == hash_prompt]
  pend <- itens[!itens$ID %in% ja_ok, ]
  cat(sprintf("membro %s (%s, %s): %d itens, %d ja feitos, %d a fazer\n",
              membro_id, PAINEL[[membro_id]]$provedor, PAINEL[[membro_id]]$modelo,
              nrow(itens), nrow(itens) - nrow(pend), nrow(pend)))
  if (MODO_PAINEL == "real" && nrow(pend) > 0) {
    stopifnot("Modelo do membro ainda nao definido no 00_config_painel.R" =
                PAINEL[[membro_id]]$modelo != "DEFINIR")
    invisible(chave_api(PAINEL[[membro_id]]))
  }
  n_erro <- 0
  for (i in seq_len(nrow(pend))) {
    reg <- classificar_item(membro_id, pend$ID[i], pend$ATIVIDADE[i], pend$chave[i],
                            sistema, hash_prompt)
    anexar_jsonl(reg, arquivo)
    if (!is.na(reg$erro)) n_erro <- n_erro + 1
    if (i %% progresso == 0) cat(sprintf("  %d/%d (erros: %d)\n", i, nrow(pend), n_erro))
  }
  cat(sprintf("  concluido; erros nesta execucao: %d\n", n_erro))
  invisible(n_erro)
}

# Ultima resposta valida de cada item, por membro
respostas_validas <- function(arquivo, hash_prompt) {
  r <- ler_jsonl(arquivo)
  if (is.null(r)) return(data.frame(id = character(), classe = character(),
                                    regra = character(), justificativa = character()))
  r <- r[!is.na(r$classe) & r$hash_prompt == hash_prompt, ]
  r <- r[!duplicated(r$id, fromLast = TRUE), ]
  r[, c("id", "classe", "regra", "justificativa", "modelo_resposta")]
}

# Lista os modelos disponiveis na conta de cada provedor
listar_modelos <- function(provedor) {
  membro <- Filter(function(m) m$provedor == provedor, PAINEL)[[1]]
  req <- switch(provedor,
    anthropic = httr2::request("https://api.anthropic.com/v1/models") |>
      httr2::req_headers(`x-api-key` = chave_api(membro), `anthropic-version` = "2026-10-21"),
    openai = httr2::request("https://api.openai.com/v1/models") |>
      httr2::req_auth_bearer_token(chave_api(membro)),
    google = httr2::request("https://generativelanguage.googleapis.com/v1beta/models") |>
      httr2::req_headers(`x-goog-api-key` = chave_api(membro)))
  j <- httr2::req_perform(req) |> httr2::resp_body_json()
  ids <- switch(provedor,
    anthropic = vapply(j$data, `[[`, "", "id"),
    openai    = vapply(j$data, `[[`, "", "id"),
    google    = sub("^models/", "", vapply(j$models, `[[`, "", "name")))
  sort(ids)
}

# Kappa de Fleiss para varios classificadores (itens com todas as respostas)
kappa_fleiss <- function(m, niveis = CLASSES) {
  m <- m[stats::complete.cases(m), , drop = FALSE]
  n <- ncol(m)
  cont <- t(apply(m, 1, function(z) table(factor(z, levels = niveis))))
  p_j <- colSums(cont) / (nrow(m) * n)
  P_i <- (rowSums(cont^2) - n) / (n * (n - 1))
  P_bar <- mean(P_i); P_e <- sum(p_j^2)
  list(n = nrow(m), kappa = (P_bar - P_e) / (1 - P_e))
}
