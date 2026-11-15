###############################################################################
#                                                                             #
#   EMPREGO VERDE - 08. EXPORTAÇÃO DE RESULTADOS (EXECUÇÃO)                   #
#                                                                             #
#   Exporta todas as tabelas para Excel/PNG em CAMINHO_PRODUTOS_TAB:          #
#   tabelas descritivas, ocupados por classif./SCN, tabela demográfica        #
#   formatada, renda média, Índice de Palma, matriz setor x ocupação e a      #
#   tabela demográfica da ocupação verde (gt).                                #
#                                                                             #
#   ATENÇÃO: script de EXECUÇÃO. Requer os objetos do módulo 06 e a função    #
#   gerar_matriz_ocup_ativ().                                                  #
#   Dependências: 00_config.R, 04_funcoes_tabelas.R, 06_gerar_tabelas.R.      #
#   Origem: emprego_verde_consolidado.R, seção 8.                             #
#                                                                             #
###############################################################################

message("  Exportando resultados...")

# --- 8a. Tabelas descritivas em Excel ---

write.xlsx(tabelas_class,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_class.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_ativ,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_ativ.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_setor,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_setor.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_ocup,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_ocup.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)


# --- 8b. Total de ocupados por classificação ---

writexl::write_xlsx(tabela_ocupados_total,
                    path = file.path(CAMINHO_PRODUTOS_TAB, "ocupados_por_classif.xlsx"))


# --- 8c. Total de ocupados por SCN ---

writexl::write_xlsx(tabela_scn, "Total de ocupados por SCN e classificação verde.xlsx")


# --- 8d. Tabela demográfica formatada ---

wb <- createWorkbook()

addWorksheet(wb, "Tabela Demográfica")
apply_number_formats(wb, "Tabela Demográfica", tabela_demog_wide)

abas <- tabela_demog_wide %>% distinct(abertura) %>% pull()
sheet_names <- make.unique(sanitize_sheet(abas), sep = " ")

for (i in seq_along(abas)) {
  df_sub <- tabela_demog_wide %>% filter(abertura == abas[i]) %>% select(-abertura)
  addWorksheet(wb, sheet_names[i])
  apply_number_formats(wb, sheet_names[i], df_sub)
}

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "tabela_demografica.xlsx"))


# --- 8e. Tabela de renda média ---

writexl::write_xlsx(tabela_renda_wide,
                    file.path(CAMINHO_PRODUTOS_TAB, "tabela_renda_wide.xlsx"))


# --- 8f. Renda média por classificação e formalidade ---

wb <- createWorkbook()
addWorksheet(wb, "Renda x Class (wide)")
addWorksheet(wb, "Renda x Setor x Ano")

writeData(wb, "Renda x Class (wide)", renda_class_verde_wide, withFilter = TRUE)
writeData(wb, "Renda x Setor x Ano", renda_formal_setor_wide, withFilter = TRUE)

estilo_hdr   <- createStyle(textDecoration = "bold")
estilo_moeda <- createStyle(numFmt = "R$ #,##0.00")

for (aba in c("Renda x Class (wide)", "Renda x Setor x Ano")) {
  addStyle(wb, aba, estilo_hdr, rows = 1, cols = 1:20, gridExpand = TRUE)
}

setColWidths(wb, "Renda x Class (wide)", cols = 1:ncol(renda_class_verde_wide), widths = "auto")
setColWidths(wb, "Renda x Setor x Ano", cols = 1:ncol(renda_formal_setor_wide), widths = "auto")

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "renda_media_class_formalidade.xlsx"))


# --- 8g. Índice de Palma ---

wb <- createWorkbook()
addWorksheet(wb, "Palma x Class")
addWorksheet(wb, "Palma x Setor x Ano")

writeData(wb, "Palma x Class", palma_class_wide, withFilter = TRUE)
writeData(wb, "Palma x Setor x Ano", palma_formal_wide, withFilter = TRUE)

estilo_num <- createStyle(numFmt = "0.00")

for (aba in c("Palma x Class", "Palma x Setor x Ano")) {
  addStyle(wb, aba, estilo_hdr, rows = 1, cols = 1:20, gridExpand = TRUE)
}

setColWidths(wb, "Palma x Class", cols = 1:ncol(palma_class_wide), widths = "auto")
setColWidths(wb, "Palma x Setor x Ano", cols = 1:ncol(palma_formal_wide), widths = "auto")

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "indice_palma.xlsx"))


# --- 8h. Tabela de Palma demográfica ---

writexl::write_xlsx(tabela_palma_wide,
                    file.path(CAMINHO_PRODUTOS_TAB, "tabela_palma_wide.xlsx"))


# --- 8i. Matriz setor x ocupação ---

matriz_ocup_ativ <- gerar_matriz_ocup_ativ(base_pnadc, ANO_INICIAL, ANO_FINAL)

write.xlsx(matriz_ocup_ativ,
           file = file.path(CAMINHO_PRODUTOS_TAB, "matriz_setor_ocup.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)


# --- 8j. Tabela demográfica da ocupação verde (gt) ---

tabela_demo <- tabelas_ocup[1:min(10, length(tabelas_ocup))] %>%
  list_rbind(names_to = "caracteristica") %>%
  mutate(V2009 = as.character(V2009),
         descricao = coalesce(V2007, V2010, as.character(formalidade),
                              VD3004, VD3005, V2009, V1022, regiao_metrop, UF, regiao)) %>%
  select(caracteristica, descricao, everything(),
         -any_of(c("V2007", "V2010", "formalidade", "VD3004", "VD3005",
                    "V2009", "V1022", "regiao_metrop", "UF", "regiao"))) %>%
  filter(!(caracteristica %in% c("escolaridade_anos", "idade", "regiao_uf")))

write_xlsx(tabela_demo, path = file.path(CAMINHO_PRODUTOS_TAB, "tabela_demo.xlsx"))

# Tabela gt formatada (imagem PNG)
tabela_demo_gt <- tabela_demo %>%
  group_by(caracteristica) %>%
  gt(rowname_col = "descricao") %>%
  tab_spanner(label = as.character(ANO_INICIAL),
              columns = matches(paste0("_", ANO_INICIAL, "_"))) %>%
  tab_spanner(label = as.character(ANO_FINAL),
              columns = matches(paste0("_", ANO_FINAL, "_"))) %>%
  fmt_number(columns = starts_with("n"), scale_by = 0.000001, decimals = 2) %>%
  fmt_number(columns = starts_with("freq"), decimals = 2) %>%
  text_replace("NA", "-", locations = cells_body()) %>%
  text_transform(fn = function(x) paste(x, "mi"), locations = cells_body(columns = starts_with("n_"))) %>%
  text_transform(fn = function(x) paste0(x, "%"), locations = cells_body(columns = starts_with("freq")))

gt::gtsave(tabela_demo_gt, file.path(CAMINHO_PRODUTOS_TAB, "tabela_demo.png"))


message("=== EXECUÇÃO CONCLUÍDA COM SUCESSO ===")
