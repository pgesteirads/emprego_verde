# Histórico da construção da medida de esverdeamento ocupacional

Registro detalhado da conversa de trabalho em que a medida de esverdeamento ocupacional foi concebida, construída, validada e documentada (agosto a novembro de 2026). Serve para retomar o trabalho em outra conta sem perder contexto. Complementa o `TRANSFERENCIA.md`, que se concentra nas decisões metodológicas e nas pendências; este documento registra o percurso.

As etapas estão em ordem cronológica. Para cada uma: o que foi pedido, o que foi feito, o que foi produzido e onde está, e o que se aprendeu ou decidiu.

## Visão de conjunto

O trabalho percorreu quatro fases:

1. **Diagnóstico** (etapas 1 a 8): entender por que a rota de Winkler et al. (2024), prevista no projeto, não funciona para o Brasil, e comunicar isso à equipe.
2. **Reorientação** (etapas 9 a 12): leitura da bibliografia, escolha da abordagem de tarefas como principal, descoberta do QBQ e do Perfil Ocupacional como fontes nacionais.
3. **Construção e validação** (etapas 13 a 15): nota metodológica e execução definitiva da medida, com quatro testes.
4. **Preservação** (etapas 16 a 18): reconstrução do pipeline perdido e documentação para transferência.

## Fase 1. Diagnóstico

### Etapa 1. Resumo executivo do relatório CBO × O*NET

**Pedido:** ler o relatório técnico sobre a compatibilização da CBO 2002 com o O*NET e preparar resumo executivo para os pares de pesquisa (problema, contexto, caminhos).

**Base:** `analise_cbo_onnet/Relatorio_CBO2002_x_ONET.docx` e os arquivos de tábua de correspondência da mesma pasta. A tábua encadeia CBO 2002 → CIUO-88 → ISCO-08 → SOC 2010 → SOC 2018.

**Resultados centrais da tábua:** 2.185 ocupações da CBO vinculadas a algum código SOC (80,2 por cento); só 253 com correspondência unívoca (12,0 por cento); mediana de 4 códigos SOC por ocupação, média de 6,7, máximo de 40; 728 ocupações com mais de seis correspondências.

**Produto:** resumo entregue no chat (não salvo em arquivo).

### Etapa 2. Citação de fonte da PNADc

**Pedido:** formatar a citação de fonte da PNAD Contínua para 2014, 2016, 2019 e 2024. Entregue no chat.

### Etapa 3. Reorientação do objetivo

**Pedido:** deixar de lado a proposta do iCS. O objetivo passou a ser explicitamente **uma medida de esverdeamento de cada ocupação**. Explicação refeita em linguagem didática, porque o usuário retomava o tema após intervalo e não dominava parte dos termos.

### Etapa 4. Registro acadêmico

**Pedido:** reescrever a explicação em linguagem acadêmica impessoal, ainda didática, **sem travessões longos**. Essa restrição vale para todos os textos desde então.

### Etapa 5. Apresentação para a equipe

**Pedido:** apresentação em HTML para colegas.

**Produto:** `produtos/apresentacoes/Esverdeamento_ocupacional_apresentacao.html`, 18 slides navegáveis. O usuário **recusou a publicação como página web (Artifact)**; desde então as entregas vão como arquivo para a pasta.

### Etapa 6. Correção do caso 732140

**Pedido:** o usuário questionou a explicação de que a ocupação 732140 (instalador de sistemas fotovoltaicos) "não consta da tábua oficial e herda o código da família". Com razão: o código havia acabado de ser mostrado.

**Verificação nos dados:** a 732140 recebe o mesmo código CIUO-88 (7245, eletricistas e reparadores de linhas) que todas as sete ocupações irmãs da família 7321. Não há herança: há atribuição idêntica. **A causa real é que a CIUO-88, de 1988, não tem categoria para instalação fotovoltaica.** Consequência: migrar para a CIUO-08 não resolveria o caso.

**Lição registrada:** verificar nos dados antes de afirmar causalidade. A versão corrigida está na apresentação e na nota.

### Etapa 7. Conversão para PDF

Orientação sobre a melhor forma de converter o HTML em PDF. Produto: `produtos/apresentacoes/Esverdeamento_ocupacional_apresentacao.pdf`.

### Etapa 8. Fundo preto

**Pedido:** a impressão saía com fundo branco. A apresentação foi refeita com tema escuro único, inclusive em `@media print`. Preferência permanente para apresentações.

## Fase 2. Reorientação

### Etapa 9. Leitura integral da bibliografia

**Pedido:** ler os 24 PDFs de `green skills - bibliografia/`, recontextualizar o problema, listar os caminhos para medir esverdeamento por competências ou habilidades e propor ordem de prioridade de leitura antes da reunião da equipe. O usuário indicou o texto da União Europeia como prioritário.

**Mapa conceitual estabelecido** (Apostel e Barslund, 2024; Granata e Posadas, 2024): quatro abordagens de mensuração.

- Produto: a firma produz bem verde. Classifica a recepcionista de fábrica de filtros como verde.
- Processo: a firma adota tecnologia verde. Não implica mudança nas tarefas do trabalhador.
- Conteúdo de tarefas: o que o trabalhador efetivamente faz. Medida contínua possível.
- Requisitos de competências: o que o trabalhador precisa saber. Margem extensiva excessiva quando usada sozinha.

**Rotas por competências identificadas:**

1. Rotulagem verde da ESCO (EU, 2022): 591 conceitos verdes (386 competências, 205 conhecimentos), em português. Exigiria ponte ISCO → CBO.
2. Rotulagem direta de uma base nacional de competências (o que depois se viabilizou com o QBQ).
3. Identificação indireta por regressão (Vona et al., 2018): regredir o escore de cada competência contra o esverdeamento por tarefas; as de coeficiente positivo e significativo são as verdes. Não exige rotular competência alguma.
4. Classificação por conjunto de modelos de linguagem com votação (Cass et al., 2026), ancorada no Regulamento Delegado (UE) 2021/2139.

**Leitura prioritária recomendada:** EU (2022) para o protocolo de rotulagem e a categoria neutra; Granata e Posadas (2024) para o método de tarefas; Janser (2019) e Bachmann et al. (2026) para a dimensão marrom e o índice líquido; Maldonado et al. (2024) para a comparação entre abordagens; Vona (2021, o guia do JRC) para a medida contínua.

### Etapa 10. Decisão: tarefas como modus operandi

**Decisão do usuário:** "Nós faremos por tarefas mesmo." A abordagem de tarefas é a principal; competências são avaliadas como complemento. O usuário descobriu o **QBQ** (https://qbq.trabalho.gov.br/oqbq), base de competências do MTE construída sobre a CBO.

### Etapa 11. Avaliação dos microdados do QBQ e do Perfil Ocupacional

**Pedido:** avaliar como o acesso a essas duas bases qualifica o relatório.

**Bases:** `analise_cbo_onnet/QBQ_microdados.xlsx` e `analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - PerfilOcupacional.csv`.

**Achados:**

- Perfil Ocupacional: 192.745 registros de atividade, 2.700 ocupações, mediana de 68 atividades por ocupação, enunciados curtos (mediana de 35 caracteres). Base mais rica que a da ISCO usada por Granata e Posadas (mediana de 7 tarefas por ocupação). Construída pela metodologia DACUM, ou seja, as atividades são o fundamento da classificação, não subproduto.
- QBQ: Conhecimento I (86.319 registros, 1.899 ocupações) e II (60.722, 719 ocupações) com escalas de profundidade, frequência e importância de 1 a 5; Habilidade (104.712) com frequência e importância; Atitude (7.210) com importância. As 87 habilidades e 22 atitudes são genéricas; o conteúdo ambiental se concentra nos conhecimentos. Não traz nenhuma rotulagem ambiental.
- Compartilhamento na família: mediana de apenas 2,7 por cento de atividades exclusivas por ocupação; 981 ocupações sem nenhuma atividade exclusiva. Isso permitiu derivar empiricamente a noção de "tarefa específica" de Vona et al., que a CBO não marca.
- Pré-teste com dicionário ingênuo revelou falsos positivos graves (a armadilha CIMENTO dentro de CONHECIMENTO, ginecologia capturada por "ecolog", mineração de dados, artes plásticas).

**Produto:** `analise_cbo_onnet/QBQ_CBO_prototipo_esverdeamento.xlsx` (protótipo; **superado** pela planilha definitiva da etapa 15).

### Etapa 12. Recapitulação para a reunião

Passo a passo das possibilidades e da fundamentação na literatura, entregue no chat imediatamente antes da reunião da equipe.

## Fase 3. Construção e validação

### Etapa 13. Nota metodológica, primeira versão

**Pedido:** nota acadêmica sobre a construção da medida, partindo da proposta `Projeto Green SKills (1).docx` (que previa seguir Winkler). Devia explicar o método de tarefas, sua conexão com competências como próximo passo, e por que difere de Winkler e é melhor. Times New Roman 12, título em negrito e caixa alta, texto corrido, sem travessões longos.

**Produto:** `Nota_metodologica_esverdeamento_ocupacional.docx` (esta versão foi substituída na etapa 15).

### Etapa 14. Execução definitiva da medida

**Pedido:** "rodar novamente esse teste, agora de modo definitivo", absorvendo as considerações do pré-teste.

**O que foi feito:**

1. **Corpus:** 192.745 registros, 50.952 enunciados distintos, nenhum enunciado composto (segmentação dispensada). Limiar de 15 atividades: 2.672 ocupações reportáveis, 28 suprimidas.
2. **Dicionário:** 183 termos (100 verde estrito, 30 verde potencial, 53 marrom) a partir de Granata e Posadas, ESCO, Janser, Lightcast e Cass et al.; fronteiras de palavra obrigatórias; 24 regras de exceção; 15 termos descartados (emissão, carbono, descarte, energia, verde, incineração e outros).
3. **Classificação no nível da atividade:** 1.868 candidatas geradas pelo dicionário (1.870 rotuladas, incluindo duas suprimidas por exceção). Duas passagens independentes sob a rubrica: 95,3 por cento de concordância, kappa 0,934. 84 discordâncias arbitradas. Resultado: VERDE 825, POTENCIAL 348, MARROM 311, NEUTRO 386 (20,6 por cento).
4. **Auditoria de recall:** 800 atividades sorteadas entre as não capturadas; 26 falsos negativos por consenso (3,3 por cento), sendo 17 POTENCIAL, 8 MARROM e 1 VERDE.
5. **Índice:** margem extensiva verde de 51,2 por cento; mediana 0,0081; máximo 0,275. Marrom presente em 10,5 por cento das ocupações, máximo 0,400.
6. **Teste 1** (classificação binária de referência, 443 famílias): kappa 0,138, AUC 0,623, razão de médias 1,92. Concordância fraca, explicada por diferença de conceito, de nível e por defeito na referência.
7. **Teste 2** (julgamento holístico independente, 170 ocupações): avaliadores entre si com kappa 0,651; índice contra julgamento com correlação de postos 0,730, AUC 0,978 (verde) e 0,925 (marrom).
8. **Teste 3** (convergência com o QBQ, 2.580 ocupações): Pearson 0,442 verde, 0,573 marrom, 0,449 líquido. O QBQ varia muito mais dentro das famílias (só 4,7 por cento das famílias sem variação, contra 38,4 por cento no índice de tarefas).
9. **Teste 4** (extremos): topo em 862310 (operador de forno de incineração no tratamento de efluentes, 0,275), agroecólogo, oceanógrafo; base em 811620 (enfornamento de coque, menos 0,400), bomba de concreto, lavra de minas. Caso 732140: 0,101 amplo e 0,900 restrito, contra cerca de 0,010 nas irmãs.

**Problemas encontrados e tratados:**

- O arquivo `dados/referencia/cbo02_classverde_caruso.xlsx` está corrompido (ver `TRANSFERENCIA.md`, seção 6). O Teste 1 usou o de nível familiar.
- O download do O*NET foi bloqueado por política de rede do ambiente. O teste correspondente ficou pendente.

### Etapa 15. Planilha final e nota atualizada

**Produtos:**

- `analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx`: dez abas (Leia-me, Resumo, Indice_por_ocupacao, Ranking, Dicionario, Excecoes, Termos_descartados, Atividades_classificadas, Teste1_Caruso, Teste2_Julgamento). **Fonte canônica.**
- `Nota_metodologica_esverdeamento_ocupacional.docx` e `.pdf`: 29 páginas, dez seções. Todo o pré-teste removido a pedido; procedimento reescrito como executado; nova seção 6 com os quatro testes; agregação (7), competências (8), delimitações (9), cronograma e produtos (10).

## Fase 4. Preservação

### Etapa 16. Transferência para outra conta

**Pergunta:** como transferir o projeto, sendo esta a conversa mais importante.

**Constatações:**

- Conversas e projetos do Claude não são transferíveis entre contas pessoais. O export de dados existe, mas não pode ser importado.
- O ambiente de processamento onde o pipeline rodou havia sido reciclado. Perderam-se os scripts, os objetos intermediários e a rubrica, que existia só ali e no histórico da conversa.

**Reconstruído e gravado na pasta:**

- `metodologia/RUBRICA.md`: critério de classificação.
- `metodologia/lexico.py`: léxico como código; revalidado contra as 1.870 atividades (1.868 casam, as 2 restantes são as suprimidas por exceção).
- `metodologia/rotulos_atividade.json`: os 1.870 rótulos com as duas passagens.
- `metodologia/construir_indice.py`: pipeline que refaz o índice; fórmulas conferidas contra a planilha (a versão em R e a execução sobre o corpus completo vieram na etapa 18).
- `TRANSFERENCIA.md`: decisões, mapa de arquivos, pendências.

**Não recuperado:** a rotulagem dos 2.413 conceitos de conhecimento do QBQ usada no Teste 3; precisa ser refeita para o indicador de competências.

### Etapa 17. Instruções do projeto e este histórico

Produzidos `INSTRUCOES_PROJETO_CLAUDE.md` (texto para as instruções do projeto na nova conta) e este documento.

### Etapa 18. Pipeline em R e execução sobre o corpus completo

**Pedido:** ter o script de reconstrução do índice em R, linguagem do restante do projeto.

**Produto:** `metodologia/construir_indice.R`. Lê o dicionário e os rótulos diretamente da planilha canônica, aplica as expressões com o motor PCRE (`perl = TRUE`), e grava `metodologia/saida/indice_por_ocupacao_R.csv` em UTF-8 com separador ponto e vírgula e decimal vírgula. A leitura e a gravação foram escritas para funcionar em qualquer configuração regional, o que foi testado em dois locales diferentes.

**Verificação:** as versões em R e em Python foram executadas sobre os 192.745 registros. Os oito indicadores de conferência batem com a nota; R e Python coincidem célula a célula; contra a planilha, só 2 contagens de atividades exclusivas diferem em uma unidade, sem efeito em índice algum. Com isso, a pendência de executar o pipeline reconstruído foi resolvida.

## Estado atual

| Item | Situação |
|---|---|
| Índice de esverdeamento por tarefas, 2.700 ocupações | concluído e validado |
| Nota metodológica | concluída, versão final |
| Pipeline reprodutível (R e Python) | reconstruído e verificado sobre o corpus completo |
| Teste com O*NET | pendente |
| Indicador de competências (QBQ) | por fazer; rotulagem a refazer |
| Agregação com RAIS e aplicação à PNADc | por fazer |
| Arquivo Caruso de nível ocupacional | defeituoso, não usar |

## Próximos passos sugeridos, em ordem

1. Fazer commit e push da pasta `metodologia/` e dos documentos da raiz.
2. Aplicar o índice à RAIS, com ponderação pelo emprego, para as estimativas de referência; depois à PNAD Contínua, documentando a perda de resolução da CBO Domiciliar.
3. Executar o teste do O*NET localmente.
4. Refazer a rotulagem dos conhecimentos do QBQ com a mesma rubrica e o mesmo protocolo, e estimar a regressão de Vona et al. para identificar habilidades verdes brasileiras.
5. Decidir a ancoragem normativa da rubrica e resolver a procedência e a citação da classificação Caruso.

## Como retomar na nova conta

Com a pasta conectada e as instruções do projeto preenchidas, uma primeira mensagem eficaz é: pedir que se leia `TRANSFERENCIA.md`, este histórico e `metodologia/RUBRICA.md`, e em seguida indicar qual dos próximos passos será atacado. Não é necessário repetir o contexto; ele está nestes arquivos.
