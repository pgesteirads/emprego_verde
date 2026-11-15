# -*- coding: utf-8 -*-
"""
Lexico de termos para identificacao de conteudo ambiental em enunciados de
atividade da CBO 2002.

Reconstruido a partir das abas Dicionario, Excecoes e Termos_descartados de
analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx, que e a fonte
canonica. Validado: as 183 expressoes reproduzem 1.868 das 1.870 atividades
candidatas da aba Atividades_classificadas; as 2 restantes sao justamente as
suprimidas por regra de excecao e foram mantidas na base rotuladas como NEUTRO.

As expressoes sao aplicadas sobre texto NORMALIZADO: maiusculas e sem
diacriticos. Use normalizar() antes de qualquer busca. Aplicar as expressoes
sobre o texto original NAO funciona.

O dicionario NAO e o classificador. Ele apenas gera candidatos. A classe de
cada atividade e decidida pela leitura do enunciado, conforme RUBRICA.md.
Cerca de um quinto das capturas nao tem conteudo ambiental.
"""

import re
import unicodedata


def normalizar(texto):
    """Maiusculas, sem diacriticos. Obrigatorio antes de aplicar as expressoes."""
    s = unicodedata.normalize('NFKD', str(texto))
    s = s.encode('ascii', 'ignore').decode('ascii')
    return s.upper()


# (ID, CLASSE, CATEGORIA, EXPRESSAO, FONTE)
# CLASSE: VERDE_ESTRITO | VERDE_POTENCIAL | MARROM
# FONTE: GP24 = Granata e Posadas (2024); ESCO = greenSkillsCollection;
#        JAN19 = Janser (2019); CASS26 = Cass et al. (2026);
#        LIGHTCAST = compilacao reproduzida em Bone et al. (2025)
TERMOS = [
    ('V001', 'VERDE_ESTRITO', 'Conhecimento ambiental', '\\bAMBIENTA(L|IS)\\b', 'GP24/ESCO'),
    ('V002', 'VERDE_ESTRITO', 'Conhecimento ambiental', 'MEIO AMBIENTE', 'GP24/ESCO'),
    ('V003', 'VERDE_ESTRITO', 'Conhecimento ambiental', '\\bECOLOG', 'GP24'),
    ('V004', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bECOSSISTEMA', 'ESCO'),
    ('V005', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bBIODIVERSID', 'ESCO'),
    ('V006', 'VERDE_ESTRITO', 'Conhecimento ambiental', 'SUSTENTABILIDADE', 'GP24/ESCO'),
    ('V007', 'VERDE_ESTRITO', 'Conhecimento ambiental', '\\bSUSTENTAVE(L|IS)\\b', 'GP24/ESCO'),
    ('V008', 'VERDE_ESTRITO', 'Conhecimento ambiental', '\\bECOEFICIEN', 'ESCO'),
    ('V010', 'VERDE_ESTRITO', 'Energia limpa', 'FOTOVOLTAIC', 'GP24/LIG'),
    ('V011', 'VERDE_ESTRITO', 'Energia limpa', '\\bSOLAR(ES)?\\b', 'GP24/LIG'),
    ('V012', 'VERDE_ESTRITO', 'Energia limpa', '\\bEOLIC', 'GP24/LIG'),
    ('V013', 'VERDE_ESTRITO', 'Energia limpa', 'RENOVAVE(L|IS)\\b', 'GP24/ESCO'),
    ('V014', 'VERDE_ESTRITO', 'Energia limpa', '\\bBIOMASSA', 'GP24'),
    ('V015', 'VERDE_ESTRITO', 'Energia limpa', 'BIOCOMBUSTIVE', 'GP24'),
    ('V016', 'VERDE_ESTRITO', 'Energia limpa', '\\bBIODIESEL', 'GP24'),
    ('V017', 'VERDE_ESTRITO', 'Energia limpa', '\\bBIOGAS', 'GP24'),
    ('V018', 'VERDE_ESTRITO', 'Energia limpa', '\\bBIOETANOL', 'GP24'),
    ('V019', 'VERDE_ESTRITO', 'Energia limpa', 'HIDROGENIO VERDE', 'CASS'),
    ('V020', 'VERDE_ESTRITO', 'Energia limpa', 'GEOTERMIC', 'GP24'),
    ('V021', 'VERDE_ESTRITO', 'Energia limpa', 'MAR(E|E-)MOTRIZ', 'GP24'),
    ('V022', 'VERDE_ESTRITO', 'Energia limpa', '\\bCOGERACAO', 'LIG'),
    ('V023', 'VERDE_ESTRITO', 'Energia limpa', 'ENERGIA(S)? LIMPA', 'GP24'),
    ('V030', 'VERDE_ESTRITO', 'Eficiencia energetica', 'EFICIENCIA ENERGETICA', 'GP24/ESCO'),
    ('V031', 'VERDE_ESTRITO', 'Eficiencia energetica', 'EFICIENTIZACAO', 'BR'),
    ('V032', 'VERDE_ESTRITO', 'Eficiencia energetica', 'ETIQUETAGEM ENERGETICA', 'BR'),
    ('V033', 'VERDE_ESTRITO', 'Eficiencia energetica', '\\bPROCEL\\b', 'BR'),
    ('V034', 'VERDE_ESTRITO', 'Eficiencia energetica', 'CONSERVACAO DE ENERGIA', 'GP24'),
    ('V035', 'VERDE_ESTRITO', 'Eficiencia energetica', '\\bDESPERDICIO DE ENERGIA', 'GP24'),
    ('V040', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'RECICLA', 'GP24/ESCO'),
    ('V041', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bRESIDUO', 'GP24/ESCO'),
    ('V042', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'REUTILIZ', 'GP24'),
    ('V043', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bREUSO', 'GP24'),
    ('V044', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'REAPROVEITAMENT', 'GP24'),
    ('V045', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'COMPOSTAGEM', 'GP24/ESCO'),
    ('V046', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'COLETA SELETIVA', 'BR'),
    ('V047', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'ATERRO SANITARIO', 'ESCO'),
    ('V048', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'LOGISTICA REVERSA', 'BR'),
    ('V049', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'ECONOMIA CIRCULAR', 'ESCO/CASS'),
    ('V050', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bLIXO\\b', 'BR'),
    ('V051', 'VERDE_ESTRITO', 'Reciclagem e reuso', 'REJEITO(S)?\\b', 'BR'),
    ('V060', 'VERDE_ESTRITO', 'Reducao de poluicao', 'EFLUENTE', 'GP24/ESCO'),
    ('V061', 'VERDE_ESTRITO', 'Reducao de poluicao', 'SANEAMENTO', 'GP24'),
    ('V062', 'VERDE_ESTRITO', 'Reducao de poluicao', '\\bESGOTO', 'GP24/ESCO'),
    ('V063', 'VERDE_ESTRITO', 'Reducao de poluicao', 'TRATAMENTO DE AGUA', 'GP24'),
    ('V064', 'VERDE_ESTRITO', 'Reducao de poluicao', 'TRATAMENTO DE ESGOTO', 'GP24'),
    ('V065', 'VERDE_ESTRITO', 'Reducao de poluicao', 'ESTACAO DE TRATAMENTO', 'BR'),
    ('V066', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'RECURSOS HIDRICOS', 'GP24'),
    ('V070', 'VERDE_ESTRITO', 'Reducao de poluicao', 'POLUICAO', 'GP24/ESCO'),
    ('V071', 'VERDE_ESTRITO', 'Reducao de poluicao', 'POLUENTE', 'GP24/ESCO'),
    ('V072', 'VERDE_ESTRITO', 'Reducao de poluicao', 'DESPOLUI', 'GP24'),
    ('V073', 'VERDE_ESTRITO', 'Reducao de poluicao', 'DESCONTAMINA', 'GP24'),
    ('V074', 'VERDE_ESTRITO', 'Reducao de poluicao', '\\bREMEDIACAO', 'GP24/ESCO'),
    ('V075', 'VERDE_ESTRITO', 'Reducao de GEE', 'GASES DE EFEITO ESTUFA', 'GP24/CASS'),
    ('V076', 'VERDE_ESTRITO', 'Reducao de GEE', 'EFEITO ESTUFA', 'GP24'),
    ('V077', 'VERDE_ESTRITO', 'Reducao de GEE', 'EMISSO?E(S)? (ATMOSFERICA|DE GAS|DE POLUENTE|VEICULAR)', 'GP24'),
    ('V078', 'VERDE_ESTRITO', 'Mudanca climatica', 'MUDANCA(S)? CLIMATICA', 'GP24/CASS'),
    ('V079', 'VERDE_ESTRITO', 'Mudanca climatica', 'AQUECIMENTO GLOBAL', 'GP24'),
    ('V080', 'VERDE_ESTRITO', 'Reducao de GEE', 'BAIXO CARBONO', 'CASS'),
    ('V081', 'VERDE_ESTRITO', 'Reducao de GEE', 'CREDITO(S)? DE CARBONO', 'BR'),
    ('V082', 'VERDE_ESTRITO', 'Reducao de GEE', 'PEGADA DE CARBONO', 'CASS'),
    ('V083', 'VERDE_ESTRITO', 'Reducao de GEE', 'SEQUESTRO DE CARBONO', 'CASS'),
    ('V084', 'VERDE_ESTRITO', 'Reducao de GEE', 'DESCARBONIZ', 'CASS'),
    ('V085', 'VERDE_ESTRITO', 'Reducao de poluicao', '\\bRUIDO(S)?\\b', 'GP24'),
    ('V086', 'VERDE_ESTRITO', 'Reducao de poluicao', 'MATERIAL PARTICULADO', 'GP24'),
    ('V090', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'REFLORESTA', 'GP24'),
    ('V091', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'FLORESTAMENTO', 'GP24'),
    ('V092', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'MANEJO FLORESTAL', 'GP24'),
    ('V093', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'DESMATAMENT', 'GP24'),
    ('V094', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'CONSERVACAO DO SOLO', 'GP24'),
    ('V095', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bEROSAO', 'GP24/ESCO'),
    ('V096', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'BACIA(S)? HIDROGRAFICA', 'BR'),
    ('V097', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'MATA(S)? CILIAR', 'BR'),
    ('V098', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'UNIDADE(S)? DE CONSERVACAO', 'BR'),
    ('V099', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'AREA(S)? DE PRESERVACAO', 'BR'),
    ('V100', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'CONSERVACAO DA NATUREZA', 'GP24'),
    ('V101', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bFAUNA\\b', 'ESCO'),
    ('V102', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'RECURSOS NATURAIS', 'GP24'),
    ('V103', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'ESPECIE(S)? AMEACADA', 'ESCO'),
    ('V104', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bDEGRADACAO AMBIENTAL', 'GP24'),
    ('V110', 'VERDE_ESTRITO', 'Certificacao ambiental', '\\bISO 14', 'GP24/LIG'),
    ('V111', 'VERDE_ESTRITO', 'Regulacao ambiental', '\\bCONAMA\\b', 'BR'),
    ('V112', 'VERDE_ESTRITO', 'Regulacao ambiental', '\\bIBAMA\\b', 'BR'),
    ('V113', 'VERDE_ESTRITO', 'Regulacao ambiental', 'LICENCIAMENTO AMBIENTAL', 'GP24'),
    ('V114', 'VERDE_ESTRITO', 'Certificacao ambiental', 'SELO VERDE', 'LIG'),
    ('V115', 'VERDE_ESTRITO', 'Certificacao ambiental', '\\bLEED\\b', 'GP24/LIG'),
    ('P200', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'AGRICULTURA ORGANICA', 'GP24'),
    ('P201', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'PRODUCAO ORGANICA', 'GP24'),
    ('P202', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'AGROECOLOG', 'GP24'),
    ('P203', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'ADUBACAO VERDE', 'GP24'),
    ('P204', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'ADUBO(S)? ORGANICO', 'GP24'),
    ('P205', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'CONTROLE BIOLOGICO', 'GP24'),
    ('P206', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'PLANTIO DIRETO', 'GP24'),
    ('P207', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'MANEJO INTEGRADO DE PRAGA', 'GP24'),
    ('P208', 'VERDE_POTENCIAL', 'Agricultura e floresta', '\\bSILVICULTURA', 'GP24'),
    ('P209', 'VERDE_POTENCIAL', 'Agricultura e floresta', '\\bIRRIGACAO', 'GP24'),
    ('P210', 'VERDE_POTENCIAL', 'Agricultura e floresta', '\\bAGROFLORESTA', 'GP24'),
    ('P220', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', 'VEICULO(S)? ELETRICO', 'GP24/CASS'),
    ('P221', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', 'TRANSPORTE COLETIVO', 'GP24'),
    ('P222', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', '\\bFERROVIARI', 'GP24'),
    ('P223', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', '\\bMETROVIARI', 'GP24'),
    ('P224', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', '\\bCICLOVIA', 'GP24'),
    ('P225', 'VERDE_POTENCIAL', 'Mobilidade de baixo carbono', '\\bBICICLETA', 'JAN19'),
    ('P230', 'VERDE_POTENCIAL', 'Reparo', '\\bREPARA(R|CAO|NDO|M|DO|DA)\\b', 'GP24'),
    ('P231', 'VERDE_POTENCIAL', 'Reparo', '\\bREPARO(S)?\\b', 'GP24'),
    ('P232', 'VERDE_POTENCIAL', 'Reparo', '\\bCONSERT', 'GP24'),
    ('P233', 'VERDE_POTENCIAL', 'Reparo', '\\bRECONDICION', 'GP24'),
    ('P234', 'VERDE_POTENCIAL', 'Reparo', '\\bREFORMA(R|NDO)?\\b', 'GP24'),
    ('P240', 'VERDE_POTENCIAL', 'Construcao de baixa emissao', 'ISOLAMENTO TERMICO', 'GP24'),
    ('P241', 'VERDE_POTENCIAL', 'Construcao de baixa emissao', 'CONFORTO TERMICO', 'GP24'),
    ('P242', 'VERDE_POTENCIAL', 'Construcao de baixa emissao', 'CAPTACAO DE AGUA(S)? (DA )?CHUVA', 'BR'),
    ('M300', 'MARROM', 'Combustiveis fosseis', '\\bPETROLEO', 'JAN19'),
    ('M301', 'MARROM', 'Combustiveis fosseis', 'PETROQUIMIC', 'JAN19'),
    ('M302', 'MARROM', 'Combustiveis fosseis', '\\bREFINARIA', 'JAN19'),
    ('M303', 'MARROM', 'Combustiveis fosseis', '\\bREFINO\\b', 'JAN19'),
    ('M304', 'MARROM', 'Combustiveis fosseis', '\\bCARVAO', 'JAN19'),
    ('M305', 'MARROM', 'Combustiveis fosseis', 'COMBUSTIVE(L|IS) FOSSE?I(L|S)', 'JAN19'),
    ('M306', 'MARROM', 'Combustiveis fosseis', '\\bGAS NATURAL', 'JAN19'),
    ('M307', 'MARROM', 'Combustiveis fosseis', '\\bDIESEL\\b', 'JAN19'),
    ('M308', 'MARROM', 'Combustiveis fosseis', '\\bGASOLINA', 'JAN19'),
    ('M309', 'MARROM', 'Combustiveis fosseis', '\\bQUEROSENE', 'JAN19'),
    ('M310', 'MARROM', 'Combustiveis fosseis', 'OLEO(S)? COMBUSTIVE', 'JAN19'),
    ('M311', 'MARROM', 'Combustiveis fosseis', '\\bGLP\\b', 'BR'),
    ('M312', 'MARROM', 'Combustiveis fosseis', 'PERFURACAO DE POCO', 'JAN19'),
    ('M313', 'MARROM', 'Combustiveis fosseis', '\\bSONDA(S)? DE PERFURACAO', 'JAN19'),
    ('M320', 'MARROM', 'Mineracao', '\\bMINERACAO', 'JAN19'),
    ('M321', 'MARROM', 'Mineracao', '\\bMINERIO', 'JAN19'),
    ('M322', 'MARROM', 'Mineracao', '\\bLAVRA\\b', 'BR'),
    ('M323', 'MARROM', 'Mineracao', '\\bGARIMPO', 'BR'),
    ('M324', 'MARROM', 'Mineracao', '\\bJAZIDA', 'BR'),
    ('M325', 'MARROM', 'Mineracao', 'DESMONTE DE ROCHA', 'BR'),
    ('M326', 'MARROM', 'Mineracao', '\\bBENEFICIAMENTO MINERAL', 'BR'),
    ('M330', 'MARROM', 'Siderurgia e metalurgia', 'SIDERURG', 'JAN19'),
    ('M331', 'MARROM', 'Siderurgia e metalurgia', 'METALURG', 'JAN19'),
    ('M332', 'MARROM', 'Siderurgia e metalurgia', '\\bFUNDICAO\\b', 'JAN19'),
    ('M333', 'MARROM', 'Siderurgia e metalurgia', 'ALTO(-| )FORNO', 'JAN19'),
    ('M334', 'MARROM', 'Siderurgia e metalurgia', '\\bACIARIA', 'JAN19'),
    ('M335', 'MARROM', 'Siderurgia e metalurgia', '\\bCOQUERIA', 'JAN19'),
    ('M336', 'MARROM', 'Siderurgia e metalurgia', '\\bCOQUE\\b', 'JAN19'),
    ('M337', 'MARROM', 'Siderurgia e metalurgia', '\\bLINGOTAMENTO', 'JAN19'),
    ('M340', 'MARROM', 'Cimento e asfalto', '\\bCIMENTO\\b', 'JAN19'),
    ('M341', 'MARROM', 'Cimento e asfalto', '\\bCONCRETO\\b', 'JAN19'),
    ('M342', 'MARROM', 'Cimento e asfalto', '\\bCLINQUER', 'JAN19'),
    ('M343', 'MARROM', 'Cimento e asfalto', '\\bASFALTO', 'JAN19'),
    ('M344', 'MARROM', 'Cimento e asfalto', '\\bASFALTIC', 'JAN19'),
    ('M345', 'MARROM', 'Cimento e asfalto', '\\bBETUME', 'JAN19'),
    ('M346', 'MARROM', 'Cimento e asfalto', '\\bARGAMASSA', 'JAN19'),
    ('M350', 'MARROM', 'Motores a combustao', 'MOTOR(ES)? (A|DE) COMBUSTAO', 'JAN19'),
    ('M351', 'MARROM', 'Motores a combustao', 'MOTOR(ES)? (A|DE) EXPLOSAO', 'JAN19'),
    ('M352', 'MARROM', 'Motores a combustao', 'MOTOR(ES)? DIESEL', 'JAN19'),
    ('M353', 'MARROM', 'Motores a combustao', '\\bCARBURADOR', 'JAN19'),
    ('M360', 'MARROM', 'Plasticos e quimica de base', '\\bPLASTICO(S)?\\b', 'JAN19'),
    ('M361', 'MARROM', 'Plasticos e quimica de base', '\\bPOLIMERIZACAO', 'JAN19'),
    ('M362', 'MARROM', 'Plasticos e quimica de base', '\\bPETROQUIMICA', 'JAN19'),
    ('M363', 'MARROM', 'Plasticos e quimica de base', '\\bCURTUME', 'BR'),
    ('M364', 'MARROM', 'Plasticos e quimica de base', 'GALVANOPLASTIA', 'BR'),
    ('M370', 'MARROM', 'Agroquimicos', 'AGROTOXIC', 'BR'),
    ('M371', 'MARROM', 'Agroquimicos', 'DEFENSIVO(S)? AGRICOLA', 'BR'),
    ('M372', 'MARROM', 'Agroquimicos', '\\bPESTICIDA', 'GP24'),
    ('M373', 'MARROM', 'Agroquimicos', '\\bHERBICIDA', 'GP24'),
    ('M374', 'MARROM', 'Agroquimicos', '\\bINSETICIDA', 'GP24'),
    ('M375', 'MARROM', 'Agroquimicos', '\\bFUNGICIDA', 'GP24'),
    ('V120', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'AREA(S)? DEGRADADA', 'sondagem FN'),
    ('V121', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'RECUPERACAO DE AREA', 'sondagem FN'),
    ('V122', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', 'NASCENTE(S)? (DO|DOS|DA|DAS) RIO', 'sondagem FN'),
    ('V123', 'VERDE_ESTRITO', 'Conservacao de recursos naturais', '\\bMANANCIA(L|IS)', 'sondagem FN'),
    ('V124', 'VERDE_ESTRITO', 'Reducao de GEE', 'MERCADO DE CARBONO', 'sondagem FN'),
    ('V125', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bSUCATA', 'sondagem FN'),
    ('V126', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bDEJETO', 'sondagem FN'),
    ('V127', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bENTULHO', 'sondagem FN'),
    ('V128', 'VERDE_ESTRITO', 'Reciclagem e reuso', '\\bCHORUME', 'sondagem FN'),
    ('V129', 'VERDE_ESTRITO', 'Reducao de poluicao', '\\bDERRAMAMENT', 'sondagem FN'),
    ('V130', 'VERDE_ESTRITO', 'Reducao de poluicao', 'VAZAMENTO DE (OLEO|PRODUTO QUIMICO|COMBUSTIVEL)', 'sondagem FN'),
    ('V131', 'VERDE_ESTRITO', 'Reducao de poluicao', '\\bAGUA(S)? (RESIDUARIA|SERVIDA)', 'sondagem FN'),
    ('P250', 'VERDE_POTENCIAL', 'Eficiencia energetica', 'CONSUMO DE ENERGIA', 'sondagem FN'),
    ('P251', 'VERDE_POTENCIAL', 'Energia limpa', 'HIDRELETRIC', 'sondagem FN'),
    ('P252', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'CULTIVO ORGANICO', 'sondagem FN'),
    ('P253', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'BIOFERTILIZ|BIOFERTIZ', 'sondagem FN'),
    ('P254', 'VERDE_POTENCIAL', 'Agricultura e floresta', 'COMPOSTO(S)? ORGANICO', 'sondagem FN'),
    ('M380', 'MARROM', 'Combustiveis fosseis', 'TERMELETRIC', 'sondagem FN'),
    ('M381', 'MARROM', 'Siderurgia e metalurgia', '\\bESCORIA', 'sondagem FN'),
    ('V132', 'VERDE_ESTRITO', 'Energia limpa', 'FONTE(S)? ALTERNATIVA(S)? DE ENERGIA', 'auditoria recall'),
    ('V133', 'VERDE_ESTRITO', 'Energia limpa', 'ENERGIA(S)? ALTERNATIVA', 'auditoria recall'),
    ('V134', 'VERDE_ESTRITO', 'Reducao de poluicao', 'SEPARA(R|CAO) (DE )?OLEO E AGUA|SEPARADOR DE AGUA E OLEO', 'auditoria recall'),
]

# (ID_DO_TERMO, EXPRESSAO_DE_EXCECAO, JUSTIFICATIVA)
# A excecao suprime a captura quando casa no mesmo enunciado.
EXCECOES = [
    ('V001', 'SANEAMENTO AMBIENTAL DOMICILIAR', 'conforme GP24, expressao nao ambiental no sentido estrito'),
    ('V003', 'GINECOLOG', 'ginecologia, exemplo canonico de GP24'),
    ('V003', '\\bECOLOGICA DA FAMILIA', 'uso metaforico'),
    ('V011', 'PLEXO SOLAR', 'termo anatomico'),
    ('V011', 'FISICA SOLAR|SISTEMA SOLAR|ANO SOLAR|LUZ SOLAR|RADIACAO SOLAR|PROTETOR SOLAR|FILTRO SOLAR|INSOLACAO', 'astronomia, meteorologia e saude ocupacional'),
    ('V050', 'LIXO ELETRONICO E PERIFERICOS', 'sem efeito pratico, mantido por transparencia'),
    ('V085', 'RUIDO(S)? (CARDIAC|PULMONAR|RESPIRATORI|ABDOMIN|INTESTIN)', 'semiologia clinica'),
    ('V085', 'RUIDO(S)? (NO|DO|DE) (MOTOR|EQUIPAMENTO|MAQUINA)', 'diagnostico mecanico, nao controle de poluicao sonora'),
    ('V101', '\\bFAUNA (BUCAL|INTESTINAL|MICROBIAN)', 'microbiologia'),
    ('V095', 'EROSAO (DENTARIA|DENTAL|CORNEAN|CUTANEA|GASTRICA|CERVICAL)', 'patologia'),
    ('V041', 'RESIDUO(S)? (DE SOLDA|DE TINTA NO PINCEL)', 'residuo no sentido de sobra de processo, sem gestao ambiental'),
    ('V074', 'REMEDIACAO (PEDAGOGICA|ESCOLAR|DE APRENDIZAGEM)', 'educacao'),
    ('M320', 'MINERACAO DE DADOS', 'mineracao de dados, exemplo de falso positivo'),
    ('M322', '\\bPALAVRA', 'radical contido em palavra'),
    ('M336', '\\bCOQUETEL|\\bCOQUEIRO', 'radical contido em outras palavras'),
    ('M360', 'EXPRESSAO PLASTICA|ARTES PLASTICAS|CIRURGIA PLASTICA|MASSA PLASTICA|DEFORMACAO PLASTICA|ARTE PLASTICA', 'artes, cirurgia e mecanica dos materiais'),
    ('M341', 'CONCRETO(S)? (ABSTRATO|MENTAL)', 'uso adjetivo'),
    ('M307', '\\bDIESELETRIC', 'tracao diesel-eletrica ferroviaria, tratada em mobilidade'),
    ('P230', 'REPARA(R|CAO) (DANO|OFENSA|PREJUIZO|MORAL|CIVIL)', 'sentido juridico'),
    ('P234', 'REFORMA (AGRARIA|TRIBUTARIA|ADMINISTRATIVA|PREVIDENCIARIA|DO ENSINO|CURRICULAR|INTIMA|PSIQUIATRICA)', 'sentido institucional'),
    ('P209', 'IRRIGACAO (VESICAL|OCULAR|NASAL|GASTRICA|DA FERIDA|CIRURGICA)', 'procedimento clinico'),
    ('M341', 'DITADO|CONCRETO E ABSTRATO|PENSAMENTO CONCRETO', 'uso pedagogico e psicologico do adjetivo'),
    ('V061', 'SANEAMENTO DO PROCESSO|SANEAMENTO DE DUVIDA|SANEAMENTO PROCESSUAL', 'sentido processual e figurado'),
    ('P254', 'COMPOSTO(S)? ORGANICO(S)? (OU|E) (IN)?ORGANICO|ANALISAR COMPOSTO', 'quimica analitica'),
]

# (TERMO, MOTIVO DO DESCARTE)
# Avaliados e rejeitados por uso majoritariamente nao ambiental no corpus
# brasileiro, sem regra de excecao estavel. Nao reintroduzir sem nova
# rodada de inspecao manual das capturas.
DESCARTADOS = [
    ('INCINERACAO', 'ambivalente: incineracao de residuos e tratamento (verde) e incineracao industrial e emissora (marrom); sem desambiguacao textual confiavel'),
    ('CONTAMINACAO', 'dominado por uso clinico e de seguranca alimentar na CBO'),
    ('CLIMATIC', 'dominado por condicoes meteorologicas de trabalho, sem conteudo de mitigacao'),
    ('ENERGIA', 'termo generico, presente em atividades eletricas sem conteudo ambiental'),
    ('VERDE', 'dominado por cor, area verde e produto agricola em estado verde'),
    ('LIMPEZA', 'higiene predial, sem conteudo ambiental'),
    ('NATURAL', 'generico, presente em gas natural, luz natural, parto natural'),
    ('EFICIENCIA', 'generico, sem qualificador energetico'),
    ('EMISSAO', 'dominado por emissao de documentos e notas fiscais'),
    ('CARBONO', 'dominado por aco carbono, fibra de carbono e papel carbono'),
    ('PRESERVACAO', 'dominado por preservacao de alimentos e de documentos'),
    ('DESCARTE', 'dominado por descarte de material de consumo sem gestao ambiental'),
    ('TOXICO', 'dominado por toxicologia clinica'),
    ('BATERIA', 'ambivalente e dominado por bateria automotiva convencional'),
    ('MOTOR ELETRICO', 'equipamento industrial generico, sem conteudo de transicao'),
]


# --------------------------------------------------------------------------
# Compilacao e varredura
# --------------------------------------------------------------------------

_EXC = {}
for _id, _pat, _just in EXCECOES:
    _EXC.setdefault(_id, []).append(re.compile(_pat))

PADROES = [
    (_id, _classe, _cat, re.compile(_pat), _EXC.get(_id, []))
    for _id, _classe, _cat, _pat, _fonte in TERMOS
]


def casar(texto):
    """IDs dos termos que capturam o enunciado, ja descontadas as excecoes.

    Aceita texto original ou normalizado.
    """
    t = normalizar(texto)
    return [
        _id for _id, _classe, _cat, rx, exc in PADROES
        if rx.search(t) and not any(e.search(t) for e in exc)
    ]


def classes_candidatas(texto):
    """Classes do dicionario sugeridas para o enunciado.

    ATENCAO: sugestao, nao classificacao. A classe final vem da leitura do
    enunciado conforme RUBRICA.md.
    """
    por_id = {_id: _classe for _id, _classe, _cat, _pat, _fonte in TERMOS}
    return sorted({por_id[i] for i in casar(texto)})


if __name__ == '__main__':
    print('termos: %d' % len(TERMOS))
    for c in ('VERDE_ESTRITO', 'VERDE_POTENCIAL', 'MARROM'):
        print('  %-16s %d' % (c, sum(1 for t in TERMOS if t[1] == c)))
    print('excecoes: %d' % len(EXCECOES))
    print('descartados: %d' % len(DESCARTADOS))
    for exemplo in ('Segregar residuos de servicos de saude',
                    'Retirar residuos de areia das pecas',
                    'Operar forno de coque',
                    'Realizar citologia ginecologica'):
        print('%-45s -> %s' % (exemplo, casar(exemplo)))
