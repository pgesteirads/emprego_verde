# Rubrica de classificação de atividades ocupacionais quanto ao conteúdo ambiental

Este documento é o critério de classificação. Ele define o que conta como conteúdo ambiental em
um enunciado de atividade da CBO 2002 e é o que torna o indicador reprodutível: a planilha
registra o resultado da classificação, mas é esta rubrica que registra a regra. Qualquer
reclassificação, extensão a novo corpus ou auditoria deve usar este texto sem alteração, ou
declarar explicitamente em que ponto se afastou dele.

Projeto Green Skills. Macroplan e Instituto de Economia da UFRJ.

## Contexto de aplicação

Você está classificando enunciados de atividade da Classificação Brasileira de Ocupações
(CBO 2002). Cada enunciado foi previamente capturado por um dicionário de termos
(`lexico.py`), que serve apenas para gerar candidatos. A sua tarefa é decidir, lendo o
enunciado, qual é a classificação correta.

O dicionário não é o classificador. Parte das suas capturas não tem conteúdo ambiental algum.

## Definição de referência

Uma tarefa é **verde** quando tem por objeto reduzir o impacto ambiental de firmas ou de
consumidores. Essa é a definição de Granata e Posadas (2024) e do Cedefop (2012). Não basta
que a tarefa mencione uma palavra ambiental: é preciso que o objeto da ação seja a redução do
impacto.

## As quatro classes

**VERDE.** A tarefa tem por objeto reduzir o impacto ambiental. Inclui:

- gestão, segregação, destinação, tratamento ou reciclagem de resíduos e efluentes;
- controle, medição ou redução de poluição, emissões e ruído;
- geração ou instalação de energia renovável (solar, eólica, biomassa, biogás);
- eficiência energética e redução de consumo de energia;
- conservação de recursos naturais, fauna, flora, solo, água e biodiversidade;
- licenciamento, fiscalização, auditoria, perícia e estudo de impacto ambiental;
- educação ambiental e sensibilização ambiental;
- saneamento, tratamento de água e de esgoto;
- recuperação e remediação de áreas degradadas ou contaminadas.

**POTENCIAL.** O conteúdo verde depende do contexto ou do estágio de esverdeamento da
economia. Seguindo Granata e Posadas, entram aqui:

- atividades agrícolas, florestais e de irrigação sem qualificador ambiental explícito;
- reparo, conserto, recondicionamento e reforma de bens (prolongam a vida útil, mas podem ser
  intensivos em energia);
- transporte coletivo, ferroviário, metroviário e cicloviário;
- isolamento e conforto térmico em edificações.

**MARROM.** A tarefa tem por objeto operar, produzir ou processar em atividade ambientalmente
intensiva. Inclui extração, refino e manuseio de combustíveis fósseis; mineração e
beneficiamento mineral; siderurgia, metalurgia e fundição; produção e aplicação de cimento,
concreto e asfalto; motores a combustão; produção e transformação de plásticos; aplicação de
agrotóxicos e defensivos.

**NEUTRO.** O termo do dicionário apareceu, mas a tarefa não tem conteúdo ambiental. Esta
classe é decisiva e é frequente. Classifique como NEUTRO, obrigatoriamente, os seis casos
abaixo.

## Os seis casos de NEUTRO obrigatório

**1. Cláusula genérica de conformidade.** Enunciados que apenas citam "preservação ambiental"
ou "meio ambiente" ao lado de saúde e segurança do trabalho, sem descrever ação ambiental
própria. Exemplos: "Cumprir normas regulamentadoras de saúde, segurança no trabalho e de
preservação ambiental"; "Atender normas de segurança, saúde, higiene e meio ambiente". Essa
fórmula aparece no bloco de competências pessoais de centenas de ocupações e não descreve
tarefa ambiental.

Atenção: "Cumprir normas ambientais", isolado e sem menção a segurança do trabalho, é VERDE.

**2. Condições ambientais no sentido físico.** "Condições ambientais" designando luz,
temperatura, umidade, pressão ou ruído do local de trabalho, de laboratório, de armazenamento
ou de calibração. Exemplos: "Controlar condições ambientais envolvidas no experimento (luz,
temperatura, umidade, radiação)"; "Providenciar condições ambientais (luz, ar condicionado)".

**3. Risco ambiental no sentido de higiene ocupacional.** No Brasil, "riscos ambientais" é o
termo da NR-9 e do PPRA para agentes físicos, químicos e biológicos no ambiente de trabalho.
Exemplos: "Elaborar programas de prevenção de risco ambiental (ppra)"; "Elaborar mapa de
riscos ambientais e de segurança". NEUTRO.

**4. Resíduo no sentido de sobra a ser limpa.** "Resíduo" designando sujeira, sobra ou depósito
a ser removido de máquina, peça, superfície, ferramenta ou paciente, sem gestão de resíduos.
Exemplos: "Remover resíduos das placas de impressão"; "Retirar resíduos de areia das peças";
"Remover resíduos de gesso do paciente"; "Verificar resíduos após lavagem". NEUTRO.

Atenção: "Descartar resíduos", "Segregar resíduos", "Destinar resíduos", "Coletar resíduos
industriais" são VERDE, porque o objeto é a destinação.

**5. Usos clínicos, anatômicos, artísticos, jurídicos, pedagógicos e metafóricos.** Exemplos:
ginecologia capturada por "ecolog"; plexo solar; artes plásticas; reparação de dano moral;
reforma curricular; irrigação vesical; ruído cardíaco; estímulo ambiental em psicologia;
enriquecimento ambiental em bem-estar animal.

**6. Menção incidental sem ação ambiental.** Exemplos: "Acionar órgãos especializados (iml,
bombeiros, meio ambiente)"; "Determinar padrões (produção, manutenção, ambientais etc)".

## Regras de decisão

- Se o enunciado descreve mais de uma ação e ao menos uma é claramente ambiental, classifique
  pela ação ambiental.
- Se o enunciado é ambíguo entre VERDE e NEUTRO, e a leitura mais natural do texto não indica
  redução de impacto ambiental, classifique NEUTRO. **O viés deve ser conservador.**
- Se o enunciado combina conteúdo verde e marrom (por exemplo, tratar efluentes de mineração),
  classifique VERDE, pois o objeto da ação é a mitigação.
- Nunca classifique como VERDE apenas porque a ocupação parece ambiental. Julgue o enunciado.

## Protocolo de aplicação

A classificação da base atual seguiu o desenho em três etapas de European Commission (2022):

1. duas passagens independentes sobre o mesmo conjunto de enunciados, sem que uma tenha acesso
   ao resultado da outra;
2. aceitação automática dos casos de concordância;
3. arbitragem por terceira leitura nos casos de discordância, com justificativa registrada.

Resultado obtido: concordância bruta de 95,3 por cento, kappa de Cohen de 0,934, 84
discordâncias arbitradas (45 confirmaram a primeira passagem, 35 a segunda, 4 adotaram classe
distinta das duas).

A auditoria de recall sorteou 800 enunciados entre os não capturados pelo dicionário e aplicou
a eles a mesma rubrica, em duas passagens independentes. Resultado: 26 falsos negativos por
consenso (3,3 por cento), dos quais 17 POTENCIAL, 8 MARROM e apenas 1 VERDE. Daí a qualificação
de uso registrada na nota metodológica: o índice verde é estimativa pontual, o marrom e o amplo
são limites inferiores.

## Formato de saída

Uma linha por item, exatamente neste formato, sem texto adicional antes ou depois:

```
ID<TAB>CLASSE
```

onde CLASSE é uma de: VERDE, POTENCIAL, MARROM, NEUTRO.

Classifique todos os itens do arquivo, na ordem, sem omitir nenhum. Não escreva justificativas.

## Referências da rubrica

- CEDEFOP. *Green skills and environmental awareness in vocational education and training.*
  Luxembourg: Publications Office of the European Union, 2012.
- EUROPEAN COMMISSION. *Green skills and knowledge concepts: labelling the ESCO
  classification.* Technical report. Brussels: ESCO, 2022.
- GRANATA, J.; POSADAS, J. *Why look at tasks when designing skills policy for the green
  transition?* Policy Research Working Paper n. 10753. Washington: World Bank, 2024.

## Histórico de alterações

| Data | Alteração | Motivo |
|---|---|---|
| 2026-11-16 | Em "Contexto de aplicação", a frase "Cerca de um quinto das suas capturas não tem conteúdo ambiental algum" passou a "Parte das suas capturas não tem conteúdo ambiental algum". | A proporção vinha do resultado da rodada de setembro de 2026 e poderia ancorar a classificação na rodada por painel de modelos. Alteração feita antes do pré-registro do protocolo; nenhuma regra de classificação mudou. |
