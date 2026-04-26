#Visita 1 (2012 - 2019 e 2022 - 2024)

#Visita 5 (2020 e 2021)

#Leitura pnadc

lista_arquivos_pnadc <- list.files(path = "C:\\Users\\Pedro Gesteira\\OneDrive - Macroplan\\pnadc\\anual\\dados_original",full.names = TRUE)

arrow::read_parquet("dados/pnadc/pnadc_2023.parquet") %>% filter(VD3004 %in% c("Superior completo")) %>% 
  summarise(num = sum(V1032[which(VD4002 == "Pessoas desocupadas")],na.rm = TRUE),
                                                                    den = sum(V1032[which(VD4002 %in% c("Pessoas desocupadas", "Pessoas ocupadas") )],na.rm = TRUE)) %>% mutate(tx = num/den)

periodo <- 2012:2024

for (anos in periodo) {

  if (anos != 2013) {
    
  lista_arquivos_pnadc_input <- 
    
    lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*txt)(?=.*_",anos,"_)(?=.*input)"))]
  
  lista_arquivos_pnadc_dict <- 
    
    lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*dicionario)(?=.*_",anos,"_)"))]
  
  lista_arquivos_pnadc_microdados <- 
    lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,"(?=.*input)", negate = TRUE)][str_detect(lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,"(?=.*input)", negate = TRUE)],paste0("(?=.*txt)(?=.*_",anos,"_)"))]
  
  } else {
    
    lista_arquivos_pnadc_input <- 
      
      lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*txt)(?=.*_",2012,"_)(?=.*input)"))]
    
    lista_arquivos_pnadc_dict <- 
      
      lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,paste0("(?=.*dicionario)(?=.*_",2012,"_)"))]
    
    lista_arquivos_pnadc_microdados <- 
      lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,"(?=.*input)", negate = TRUE)][str_detect(lista_arquivos_pnadc[str_detect(lista_arquivos_pnadc,"(?=.*input)", negate = TRUE)],paste0("(?=.*txt)(?=.*_",anos,"_)"))]
    
  }

    
    df <- 
      read_pnadc(microdata = lista_arquivos_pnadc_microdados,
                 input_txt = lista_arquivos_pnadc_input) %>% 
      pnadc_labeller(dictionary.file = lista_arquivos_pnadc_dict)
  
    df %>%
    arrow::write_parquet(., glue::glue("dados/pnadc/pnadc_",anos,".parquet"))
  
}
