#Leitura da PNADC trimestral (especificamente do trimestre 4)

#Leitura pnadc

lista_arquivos_pnadc <- list.files(path = "C:\\Users\\Pedro Gesteira\\OneDrive - Macroplan\\pnadc\\trimestral\\4\\dados_original",full.names = TRUE)

periodo <- 2012:2024

for (anos in periodo) {
  
   {
    
    lista_arquivos_pnadc_input <- 
      
      lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*txt)(?=.*input)"))]
    
    lista_arquivos_pnadc_dict <- 
      
      lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*dicionario)"))]
    
    lista_arquivos_pnadc_microdados <- 
      lista_arquivos_pnadc[
        !stringr::str_detect(lista_arquivos_pnadc, "input") &
          stringr::str_detect(lista_arquivos_pnadc, sprintf("PNADC_\\d{2}%s\\.txt$", anos))
      ]
    
  }
  
  
  df <- 
    read_pnadc(microdata = lista_arquivos_pnadc_microdados,
               input_txt = lista_arquivos_pnadc_input) %>% 
    pnadc_labeller(dictionary.file = lista_arquivos_pnadc_dict)
  
  df %>%
    arrow::write_parquet(., glue::glue("dados/pnadc_trim/pnadc_04",anos,".parquet"))
  
}