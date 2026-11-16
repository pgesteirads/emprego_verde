# Classificação de texto com modelos de linguagem: o que a literatura recomenda e como aplicar ao índice

Levantamento feito em novembro de 2026 para orientar a nova rodada de classificação das atividades
candidatas e a redação do artigo. Separa-se, em cada ponto, o que a literatura estabelece e o que se
propõe para o projeto.

Nota de verificação: Cass et al. (2026) foi lido no texto integral (está em `green skills -
bibliografia/`). As demais referências foram conferidas pelo resumo e por trechos acessíveis nas
páginas indicadas ao final; antes de citar números específicos no artigo, conferir no texto integral.

## 1. O uso de modelos de linguagem para anotação é aceito, desde que validado

**O que a literatura mostra.** Gilardi, Alizadeh e Kubli (2023, PNAS) mostraram que um modelo de
linguagem, sem exemplos, superou trabalhadores de plataforma em tarefas de anotação de texto, com
concordância interna maior e custo muito menor. O precedente mais próximo do nosso problema é
Eloundou et al. (2023), que aplicaram uma rubrica de exposição à IA às tarefas do O*NET usando
anotadores humanos e o GPT-4 em paralelo, e reportaram concordância comparável entre humano e
máquina no nível da tarefa. Na economia verde, Cass et al. (2026) classificam competências de
vagas com modelos de linguagem ancorados no Regulamento Delegado (UE) 2021/2139.

**A ressalva que acompanha todos esses trabalhos.** O desempenho varia muito entre tarefas.
Pangakis, Wolken e Fasching (2023) replicaram 27 tarefas de anotação de artigos publicados e
encontraram precisão ou revocação abaixo de 0,5 em nove delas. Reiss (2023) mostrou que pequenas
mudanças de redação do prompt, ou a simples repetição da mesma entrada, alteram classificações.
A conclusão comum é que **a validação contra rótulos humanos é obrigatória, tarefa por tarefa**.

## 2. A rubrica deve funcionar como um livro de códigos

**Literatura.** Halterman e Keith (2026, Political Analysis) defendem que o modelo siga definições
e critérios de exclusão explícitos de um livro de códigos, e não apenas o nome da classe. Propõem
cinco etapas: preparar o livro de códigos, testes de comportamento sem rótulos, avaliação contra
uma amostra codificada à mão, análise de erros e, se necessário, ajuste do modelo. Cass et al.
(2026) acrescentam que a classificação é mais confiável quando o espaço de rótulos é fixado de
antemão e verificado em etapas, em vez de um julgamento único.

**Para o projeto.** A `RUBRICA.md` já é um livro de códigos nesse sentido: definição de
referência, quatro classes, seis casos de NEUTRO obrigatório e regras de decisão. Faltam duas
coisas: (a) testes de comportamento antes da rodada completa, com os exemplos da própria rubrica,
verificando se cada modelo reproduz as classes que a rubrica atribui a eles; (b) pedir na resposta,
além da classe, **qual regra da rubrica foi aplicada** (por exemplo, "NEUTRO, caso 4") e uma
justificativa curta. Isso torna cada decisão auditável e substitui as justificativas que se perderam.

## 3. Um painel de modelos de empresas diferentes reduz o viés de um único modelo

**Literatura.** Verga et al. (2024) mostram que um painel de modelos de famílias diferentes
apresenta menos viés intramodelo do que um único modelo grande, e correlaciona melhor com o
julgamento humano. Panickssery, Bowman e Feng (2024) documentam que modelos reconhecem e favorecem
os próprios textos, o que alerta para erros correlacionados quando o mesmo modelo produz e avalia.
Cass et al. (2026) aplicam essa lógica à classificação: rodam os mesmos prompts em **sete modelos
de seis empresas** (OpenAI, DeepSeek, Mistral, Meta, Anthropic e Google, incluindo modelos de
pesos abertos), agregam por regras de votação declaradas e enviam à revisão humana os casos
limítrofes. Uma inclusão ou exclusão contra a votação exige a concordância de quatro dos cinco
autores. Justificam o painel citando a evidência de que o erro de classificação varia com o modelo
e com o prompt (Schoenegger et al., 2024).

**Para o projeto.** Substituir as "duas passagens" do mesmo modelo por um **painel de três
modelos de três empresas**, por exemplo Anthropic, OpenAI e Google, cada um no modelo de ponta da
data, com o identificador exato registrado. Número ímpar para permitir maioria. Regras de agregação
fixadas antes da rodada:

| Situação | Regra |
|---|---|
| Os três concordam | Classe aceita |
| Dois concordam | Classe da maioria aceita; entra no sorteio da verificação humana |
| Os três divergem, ou a maioria diverge em VERDE contra NEUTRO | Arbitragem pela equipe, com justificativa escrita |

A regra da última linha protege o ponto mais sensível do índice: a fronteira entre VERDE e NEUTRO,
onde está a armadilha que motivou o desenho do projeto.

## 4. Independência, cegamento e estabilidade

**Literatura.** Törnberg (2024, Sociologica) propõe práticas mínimas: prompts estruturados,
**análise de estabilidade do prompt** (repetir com variações de redação e medir a mudança),
validação rigorosa e preferência por modelos abertos. Pangakis et al. (2023) mostram que a
consistência entre execuções repetidas sinaliza bem os casos difíceis.

**Para o projeto.**

- **Uma atividade por chamada.** Elimina efeitos de ordem e de contexto entre itens.
- **Cegamento.** O modelo recebe só o enunciado da atividade. Não recebe o termo do dicionário que
  a capturou (que puxaria a resposta para a classe do termo) nem o título da ocupação (a rubrica
  manda julgar o enunciado, nunca a ocupação, e o título induziria esse viés).
- **Estabilidade.** Numa subamostra de cerca de 200 atividades: (a) repetir a chamada com o mesmo
  prompt, para medir a consistência teste-reteste; (b) rodar uma paráfrase das instruções, para
  medir a sensibilidade à redação. Reportar as duas medidas.
- **Estabilidade em relação à rodada de setembro.** Comparar os rótulos novos com os antigos.
  Não é validação (os antigos também vieram de modelo), mas mede o quanto a medida depende da
  rodada.

## 5. Validação humana: quanto e como

**Literatura.** Ludwig, Mullainathan e Rambachan (2025) tratam o modelo de linguagem como
instrumento de medida em econometria aplicada. Para problemas de estimação, mostram que **uma
amostra de validação com rótulos humanos é indispensável**: sem ela não há como avaliar os erros,
e escolhas aparentemente inocentes (qual modelo, qual prompt) podem mudar muito as estimativas.
Calderon, Reichart e Dror (2025) propõem um teste estatístico formal, o *alternative annotator
test*, para justificar a substituição de anotadores humanos por um modelo. O teste exige de 50 a
100 itens anotados por pelo menos dois humanos e verifica se o modelo representa o consenso
humano melhor do que cada humano isolado.

**Para o projeto.**

- **Amostra de validação:** cerca de 400 atividades sorteadas, estratificadas pela classe do
  painel, com probabilidades de seleção registradas. Duas pessoas da equipe classificam às cegas
  (sem ver a classe do painel), aplicando a mesma rubrica.
- **Medidas a reportar:** kappa humano × humano; kappa humano × painel; matriz de confusão por
  classe; o *alternative annotator test* sobre um subconjunto de 100 itens.
- **Limiar fixado antes:** por exemplo, kappa humano × painel de pelo menos 0,70 e o painel
  aprovado no *alternative annotator test*. Se falhar, revisa-se a rubrica (com a revisão
  registrada no Git) e roda-se de novo.

## 6. Do rótulo ao índice: corrigir o erro de medida na agregação

**Literatura.** Egami, Hinck, Stewart e Wei (2023, NeurIPS) mostram que usar rótulos de modelo
diretamente em análises posteriores pode produzir viés substancial e intervalos de confiança
inválidos, **mesmo com acurácia de 80 a 90 por cento**. O estimador que propõem
(*design-based supervised learning*) combina os rótulos do modelo com uma amostra humana sorteada
com probabilidades conhecidas e garante inferência válida mesmo quando o modelo erra de forma
sistemática. Ludwig et al. (2025) chegam à mesma conclusão: os rótulos do modelo ampliam o valor
da amostra de validação, mas não a substituem.

**Para o projeto.** A amostra humana da seção 5, por ter sido sorteada com probabilidades
conhecidas, serve também para estimar as taxas de erro do painel por classe e corrigir as
estimativas agregadas (participação de emprego verde na RAIS, por exemplo). É o argumento mais
forte do artigo contra a objeção "o índice herda os erros do modelo".

## 7. Reprodutibilidade com modelos comerciais

**Literatura.** Spirling (2023, Nature) argumenta que modelos fechados podem mudar ou ser
descontinuados sem aviso, o que compromete a reprodução, e recomenda modelos abertos sempre que
possível. Törnberg (2024) segue a mesma linha. Cass et al. (2026) incluem modelos de pesos abertos
no painel.

**Para o projeto.** Os modelos comerciais atuais não aceitam fixar a temperatura, então uma nova
execução não reproduz cada resposta exatamente. A transparência vem de quatro elementos:
(a) gravar todas as respostas brutas, com identificador do modelo, data e hash do prompt;
(b) publicar o prompt e a rubrica; (c) reportar as medidas de estabilidade da seção 4;
(d) **opcionalmente, incluir um modelo de pesos abertos no painel** (ou como quarto membro, de
controle), porque seus pesos ficam fixos e qualquer pessoa pode reexecutar.

## 8. Pré-registro

O protocolo (modelos, prompt, regras de votação, desenho da amostra humana, métricas e limiares)
é escrito e enviado ao Git **antes** da rodada. O commit com data documenta que as regras não foram
ajustadas depois de ver os resultados.

## 9. Desenho proposto, em resumo

1. Registrar o protocolo no Git (seção 8).
2. Testes de comportamento de cada modelo com os exemplos da rubrica (seção 2).
3. Rodada completa: 1.866 atividades × 3 modelos de empresas diferentes, uma atividade por chamada,
   às cegas em relação ao termo e à ocupação, com classe, regra aplicada e justificativa
   (seções 2 a 4).
4. Agregação pelas regras de votação; arbitragem pela equipe nos casos definidos (seção 3).
5. Estabilidade: reteste e paráfrase numa subamostra (seção 4).
6. Validação humana às cegas de cerca de 400 atividades e *alternative annotator test* (seção 5).
7. Índice recalculado pelo pipeline; correção das estimativas agregadas com a amostra humana
   (seção 6).
8. Refazer a auditoria de recall e o Teste 2 com o mesmo desenho, com avaliadores humanos no
   critério externo.

## Referências

- Calderon, N.; Reichart, R.; Dror, R. (2025). The alternative annotator test for LLM-as-a-judge:
  how to statistically justify replacing human annotators with LLMs. ACL 2025.
  https://arxiv.org/abs/2501.10970
- Cass, et al. (2026). Returns to green tasks in Europe. Arquivo na bibliografia do projeto.
- Egami, N.; Hinck, M.; Stewart, B.; Wei, H. (2023). Using imperfect surrogates for downstream
  inference: design-based supervised learning for social science applications of large language
  models. NeurIPS 2023. https://arxiv.org/abs/2306.04746
- Eloundou, T.; Manning, S.; Mishkin, P.; Rock, D. (2023). GPTs are GPTs: an early look at the
  labor market impact potential of large language models. https://arxiv.org/abs/2303.10130
  (conferir a versão publicada antes de citar)
- Gilardi, F.; Alizadeh, M.; Kubli, M. (2023). ChatGPT outperforms crowd workers for
  text-annotation tasks. PNAS, 120(30), e2305016120.
- Halterman, A.; Keith, K. A. (2026). Codebook LLMs: evaluating LLMs as measurement tools for
  political science concepts. Political Analysis, 34, 188-204. https://arxiv.org/abs/2407.10747
- Ludwig, J.; Mullainathan, S.; Rambachan, A. (2025). Large language models: an applied
  econometric framework. NBER Working Paper 33344. https://arxiv.org/abs/2412.07031
- Pangakis, N.; Wolken, S.; Fasching, N. (2023). Automated annotation with generative AI requires
  validation. https://arxiv.org/abs/2306.00176
- Panickssery, A.; Bowman, S.; Feng, S. (2024). LLM evaluators recognize and favor their own
  generations. NeurIPS 2024. https://arxiv.org/abs/2404.13076
- Reiss, M. V. (2023). Testing the reliability of ChatGPT for text annotation and classification:
  a cautionary remark. https://arxiv.org/abs/2304.11085
- Schoenegger, P. et al. (2024). Wisdom of the silicon crowd: LLM ensemble prediction capabilities
  rival human crowd accuracy. Science Advances, 10(45). (citado por Cass et al.)
- Spirling, A. (2023). Why open-source generative AI models are an ethical way forward for science.
  Nature, 616, 413. https://www.nature.com/articles/d41586-023-01295-4
- Törnberg, P. (2024). Best practices for text annotation with large language models.
  Sociologica, 18(2), 67-85. https://sociologica.unibo.it/article/view/19461
- Verga, P. et al. (2024). Replacing judges with juries: evaluating LLM generations with a panel of
  diverse models. https://arxiv.org/abs/2404.18796
