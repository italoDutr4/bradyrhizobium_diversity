# Curadoria de dados genômicos de *Bradyrhizobium* — Registro metodológico

Este documento resume as decisões tomadas durante a etapa de obtenção e curadoria
de metadados dos genomas de *Bradyrhizobium* utilizados neste projeto. O objetivo
é registrar critérios e justificativas para consulta futura e para a redação da
seção de Métodos do trabalho.

## 1. Fonte dos dados

Todos os genomas foram obtidos do banco de dados **NCBI Genome**, utilizando a
ferramenta de linha de comando `datasets`/`dataformat` (NCBI Datasets CLI),
filtrando pelo táxon *Bradyrhizobium*.

- Consulta inicial: `datasets summary genome taxon "Bradyrhizobium"`
- Total de registros de assembly brutos retornados: **4047**
- Metadados de hospedeiro, localização geográfica, fonte de isolamento, nível de
  montagem, tipo de pacote BioSample e qualidade genômica (completude/
  contaminação, estimados pelo próprio NCBI) foram extraídos diretamente via
  `dataformat tsv genome`, sem necessidade de consulta separada à base
  BioSample (os campos relevantes já estão disponíveis nos campos
  `assminfo-biosample-*` do próprio `dataformat`).

## 2. Remoção de duplicatas (GenBank × RefSeq)

Constatou-se que o NCBI frequentemente deposita o **mesmo genoma físico** duas
vezes: uma vez na base GenBank (prefixo `GCA_`) e uma vez na base RefSeq
(prefixo `GCF_`), com o mesmo número de acesso após o prefixo.

- **Critério de desduplicação:** para cada par GCA/GCF com o mesmo número base,
  foi mantida apenas uma entrada, com **prioridade para a versão RefSeq (GCF)**
  quando disponível, por esta ter passado por checagem adicional de qualidade
  pela equipe do NCBI. Quando não havia par (apenas GenBank), a entrada única
  foi mantida.
- **Resultado:** de 4047 registros brutos, restaram **2199 genomas únicos**
  (1848 pares GCF/GCA reduzidos a 1 cada + 351 registros sem par).

## 3. Filtro de qualidade genômica

Foi aplicado o mesmo critério de qualidade utilizado por Sobol et al. (2026,
*ISME Communications*) e por Bowers et al. (2017, *Nature Biotechnology*):

- **Completude ≥ 90%**
- **Contaminação < 5%**

(valores estimados pelo próprio NCBI/CheckM, disponíveis no campo
`checkm-completeness`/`checkm-contamination`)

- **Resultado após desduplicação + filtro de qualidade: 1727 genomas.**

Distribuição por nível de montagem (`assminfo-level`) nos 1727 genomas
resultantes desta etapa:

| Nível de montagem | n |
|---|---|
| Contig | 1137 |
| Complete Genome | 329 |
| Scaffold | 240 |
| Chromosome | 21 |

**Decisão:** genomas em nível *Contig* foram mantidos na análise. A justificativa
é que a etapa de filogenia (baseada em genes marcadores de cópia única, não em
genoma completo) tende a não ser sensível à fragmentação da montagem, já que os
genes-alvo normalmente estão contidos inteiramente dentro de um único contig.

## 4. Remoção de MAGs (Metagenome-Assembled Genomes)

Por orientação do supervisor do projeto, genomas montados a partir de
metagenômica (MAGs) foram identificados e removidos do dataset, de modo a
delimitar exclusivamente isolados obtidos em cultura pura (a maioria
associados a plantas hospedeiras via nódulo radicular).

- **Critério de identificação:** o campo `assminfo-biosample-package` do NCBI
  indica o padrão de submissão do BioSample. Pacotes com prefixo **`MIMAG`**
  (Minimum Information about a Metagenome-Assembled Genome — o mesmo padrão
  definido por Bowers et al. 2017, já citado como base do critério de
  qualidade genômica na seção 3) identificam MAGs. Pacotes `Microbe.1.0`,
  `Generic.1.0` e `MIGS.ba.*` (Minimum Information about a Genome Sequence,
  bacterial) correspondem a isolados de cultura pura e foram mantidos.
- **Resultado após remoção de MAGs: 1634 genomas.**

## 5. Padronização geográfica (país → continente)

O campo de localização geográfica (`assminfo-biosample-geo-loc-name`) foi
processado da seguinte forma:

1. Extração do nome do país a partir do formato `"País: região/cidade"`.
2. Conversão de país para continente usando o pacote R `countrycode`
   (`origin = "country.name"`, `destination = "continent"`).
3. **Valores tratados como ausentes (`NA`)**, por representarem ausência de
   informação e não um país válido: `"missing"`, `"Missing"`,
   `"not applicable"`, `"not provided"`, `"not recorded"`, `"-"`, `"None"`.
4. **Casos especiais não classificáveis como país/continente**, tratados como
   categoria própria ("Não aplicável — fonte ambiental"): `"Arctic Ocean"` e
   `"Antarctica"`.

**Decisão sobre escopo geográfico:** optou-se por realizar a análise inicial em
nível de **continente amplo** (Americas, Africa, Asia, Europe, Oceania), sem
subdivisão inicial por sub-região (ex.: América do Sul separada de América do
Norte). Análises complementares restritas a regiões específicas (ex.: América
do Sul, África) poderão ser conduzidas posteriormente como recortes do dataset
completo, sem necessidade de nova curadoria.

A definição de uma categoria "Sul Global" foi **adiada** deliberadamente, dado
que não existe consenso único sobre quais países a compõem (definições da ONU,
UNCTAD, Banco Mundial e da literatura de Relações Internacionais divergem,
especialmente para casos como China, Rússia, Coreia do Sul e Taiwan). Essa
classificação será definida e aplicada em uma etapa posterior e específica da
análise, com critério explicitado separadamente.

**Resultado, após remoção de MAGs (n = 1634): 1174 genomas com continente
identificado (71,8%).**

**Limitação registrada:** cerca de 28% dos genomas não possuem informação de
país no metadado original. Esses genomas foram mantidos no dataset geral, mas
são necessariamente excluídos de qualquer análise agregada por continente.

## 6. Padronização do hospedeiro

O campo de hospedeiro (`assminfo-biosample-host`) veio em texto livre, com
valores heterogêneos, incluindo nomes científicos (por vezes com autoridade
taxonômica, cultivar ou subespécie anexados), nomes comuns em inglês, erros de
digitação e sinônimos taxonômicos desatualizados.

Etapas de limpeza aplicadas:

1. Remoção de anotações de autoridade taxonômica, cultivar e subespécie (ex.:
   `"(L.) Merr."`, `"cv. AC Glengarry"`, `"subsp."`, `"var."`).
2. Correção de erros de digitação identificados manualmente (ex.: `"Glicyne
   max"` → `"Glycine max"`) e de sinônimo taxonômico desatualizado (`"Glycine
   hispida"` → `"Glycine max"`).
3. Padronização de valores de ausência de informação (`"not applicable"`,
   `"missing"`, `"Not determined"`, `"Plant"`, `"legume"`, entre outros) como
   `NA`.
4. Mapeamento de nomes comuns em inglês para o gênero científico correspondente
   (ex.: `"soybean"` → *Glycine*; `"peanut"`/`"forage peanut"` → *Arachis*;
   `"pigeon pea"` → *Cajanus*; `"rice"` → *Oryza*; `"sweet potato"` →
   *Ipomoea*; `"sugarcane"` → *Saccharum*).
5. Extração automática do gênero a partir de nomes binomiais (primeira palavra
   do nome científico) para os demais casos.

**Resultado, após remoção de MAGs (n = 1634): 722 genomas com gênero de
hospedeiro identificado (44,2%).**

**Casos anômalos excluídos da análise de hospedeiro** (mantidos no dataset
geral, mas marcados como `NA` especificamente na variável de hospedeiro):
`Homo sapiens`, `Sus scrofa` (hospedeiros incompatíveis com o papel biológico
esperado de *Bradyrhizobium* como simbionte de leguminosas — prováveis
achados oportunistas em amostra clínica/veterinária), `Subsurface shale`
(substrato geológico, não um hospedeiro biológico), e um registro com dois
hospedeiros simultâneos no mesmo campo (`Glycine max; Pongamia pinnata`).

**Observação biológica registrada, sem exclusão do dado:** alguns hospedeiros
identificados (*Arabidopsis*, *Beta*, *Erigeron*) não são leguminosas
nodulantes. Esses casos provavelmente correspondem a estudos de colonização
endofítica/rizosférica não simbiótica, fenômeno já descrito na literatura para
alguns isolados de *Bradyrhizobium*, e não a erro de anotação.

## 7. Classificação taxonômica fina (delimitação por clado monofilético)

**Abordagem revisada.** A atribuição de cada genoma a um dos grupos
taxonômicos de interesse (*B. japonicum*, *B. elkanii*, *B. iriomotense*)
**não é realizada por limiar estrito de Average Nucleotide Identity (ANI)**.

### 7.1 Justificativa da mudança de critério

Uma primeira tentativa de classificação via FastANI (Jain et al. 2018), usando
o limiar convencional de 95% de ANI contra uma única cepa-tipo de referência
por grupo, mostrou-se **insuficiente para capturar a complexidade evolutiva e
a alta plasticidade genômica inerentes ao gênero** *Bradyrhizobium*. A
distribuição de valores de ANI observada para o grupo *elkanii*, em
particular, apresentou padrão multimodal (múltiplos agrupamentos distintos de
similaridade, não dois grupos bem separados por um único vale), evidenciando
que um corte único de similaridade fragmentaria artificialmente complexos de
espécies que são evolutivamente coesos — um problema já documentado por
Avontuur et al. (2019) para o gênero como um todo, que demonstraram que
métricas de similaridade par a par (ANI/AAI) e MLSA convencional falham em
resolver de forma robusta a estrutura profunda de *Bradyrhizobium*,
recomendando o uso de filogenia baseada em genes compartilhados.

### 7.2 Cepas-tipo âncora

| Espécie-tipo | Cepa | Accession |
|---|---|---|
| *Bradyrhizobium japonicum* | USDA 6 | GCF_000284375.1 |
| *Bradyrhizobium elkanii* | USDA 76 | GCF_023278185.1 |
| *Bradyrhizobium iriomotense* | EK05 (NBRC 102520) | GCF_030160715.1 |

**Nota:** a espécie *B. iriomotense* não consta na lista de cepas-tipo
utilizadas por Avontuur et al. (2019), não havendo, portanto, referência
direta de comparação externa (Critério de validação, seção 7.5) para a
composição do clado *iriomotense* especificamente.

### 7.3 Critério de delimitação (versão final)

O clado associado a cada cepa-tipo âncora é definido como o **maior clado
monofilético que contém a âncora e não contém a ponta de nenhuma outra
cepa-tipo âncora de um grupo-alvo diferente**. A expansão avança da ponta em
direção à raiz (árvore enraizada por ponto médio — *midpoint rooting*, na
ausência de outgroup filogeneticamente apropriado no dataset) até o último
ancestral comum antes de colidir com outra âncora. O valor de suporte SH-like
do nó que define o limite de cada clado é registrado e reportado como métrica
descritiva de confiabilidade da delimitação.

**Nota sobre a formalização do critério de suporte estatístico:** em uma
versão inicial do método, cogitou-se interromper a expansão também quando o
suporte SH-like do nó ficasse abaixo de 0,80, e usar um limiar de comprimento
de ramo para tratar como exceção os nós de suporte artificialmente baixo por
ausência de divergência genética mensurável (ramos quase-zero, comuns entre
genomas quase idênticos). Essa regra foi **testada e descartada**: a
distribuição de comprimentos de ramo desta árvore mostrou que mais de 25% dos
ramos internos têm comprimento próximo de zero (mediana geral = 2,9×10⁻⁴; 1º
quartil = 5×10⁻⁹), inviabilizando a definição de um limiar de "ramo trivial"
que não capturasse também estrutura filogenética genuína. Por esse motivo, a
monofilia em relação às âncoras foi adotada como critério de parada único e
suficiente, e o suporte estatístico passou a ser reportado apenas de forma
descritiva.

### 7.4 Resultado da delimitação

| Grupo | n genomas | Suporte SH-like no nó-limite |
|---|---|---|
| elkanii | 674 | 1,000 |
| japonicum | 355 | 0,934 |
| iriomotense | 14 | 1,000 |
| Other_Bradyrhizobium | 591 | — |

Para comparação, a classificação anterior por ANI (limiar de 95%) havia
atribuído apenas 191 genomas a *japonicum*, 119 a *elkanii* e 1 a
*iriomotense* — a delimitação por clado recupera de forma substancialmente
mais ampla os complexos de espécies relacionadas, consistente com o
comportamento esperado a partir da estrutura de supergrupos descrita por
Avontuur et al. (2019).

### 7.5 Validação externa (Critério de comparação com Avontuur et al. 2019)

A composição de cada clado foi comparada com genomas do dataset cujo
`organism-name` corresponde a outras cepas-tipo dos supergrupos *japonicum* e
*elkanii* listadas por Avontuur et al. (2019) — não apenas as três cepas-tipo
âncora, mas as demais espécies validamente descritas dentro de cada
supergrupo (ex.: *B. arachidis*, *B. centrolobii*, *B. diazoefficiens*,
*B. forestalis*, *B. ottawaense*, *B. sacchari*, *B. shewense*,
*B. stylosanthis*, *B. yuanmingense* para o supergrupo *japonicum*; e
*B. brasilense*, *B. embrapense*, *B. macuxiense*, *B. manausense*,
*B. mercentei*, *B. pachyrhizi*, *B. tropiciagri*, *B. viridifuturi* para o
supergrupo *elkanii*).

| Supergrupo esperado | Concordância com o clado delimitado |
|---|---|
| elkanii | 124/131 (94,7%) |
| japonicum | 112/386 (29,0%) |

A validação do supergrupo *elkanii* é forte e confirma a adequação do
critério. A validação do supergrupo *japonicum* revelou um problema
específico, detalhado a seguir.

### 7.6 Problema identificado: não-recuperação da monofilia entre *B. japonicum* e *B. diazoefficiens*

Investigação detalhada mostrou que a baixa concordância do supergrupo
*japonicum* é quase inteiramente explicada por um único caso: dos 223
genomas identificados no dataset como *B. diazoefficiens*, apenas 8 caíram
dentro do clado delimitado a partir da âncora *B. japonicum* USDA 6; os
demais 215 foram classificados como `Other_Bradyrhizobium`.

**Diagnóstico da causa:** o ancestral comum mais recente (MRCA) entre a
âncora USDA 6 e um genoma representativo de *B. diazoefficiens*
(GCF_000261765.1) mostrou-se um nó extremamente basal — contendo 1568 dos
1634 genomas do dataset (praticamente a raiz da árvore) — e com comprimento
de ramo desprezível (5×10⁻⁹). Ou seja, **a árvore construída a partir dos
genes marcadores de cópia única do GToTree não possui resolução filogenética
suficiente na base (backbone) para separar de forma robusta as divisões
profundas entre supergrupos inteiros**, ainda que a resolução *dentro* de
cada supergrupo (evidenciada pela boa validação do clado *elkanii*) seja
adequada. Esse é um problema reconhecido na literatura: Avontuur et al.
(2019) demonstram explicitamente que datasets com poucos genes (ex. MLSA de
3-6 genes) falham em resolver o backbone da filogenia de *Bradyrhizobium*,
recomendando datasets de 128 a 400 genes compartilhados para esse fim — o
conjunto de SCGs utilizado pelo GToTree pode estar mais próximo, em poder de
resolução, do primeiro cenário do que do segundo.

**Consistência histórica:** vale notar que este achado, embora represente uma
limitação técnica da árvore atual, também é consistente com o histórico
taxonômico da própria *B. diazoefficiens*, originalmente descrita como um
subgrupo distinto de *B. japonicum* ("Group Ia") antes de ser elevada a
espécie por Delamuta et al. (2013) com base em evidência poligênica — ou
seja, a separação entre as duas já era reconhecida como filogeneticamente não
trivial antes mesmo da era genômica.

### 7.7 Soluções possíveis (a decidir com orientação do supervisor)

1. **Manter a delimitação atual e documentar a limitação.** Os resultados
   reportados nas seções 7.4–7.6 são usados como estão, com a ressalva
   explícita de que o clado *japonicum*, tal como delimitado, não recupera a
   monofilia completa com *B. diazoefficiens* devido à resolução insuficiente
   do backbone da árvore. Opção de menor esforço, adequada se a limitação for
   aceitável para os objetivos do trabalho.

2. **Reconstruir a filogenia com um conjunto maior de genes marcadores.**
   Aumentar o número de SCGs utilizados pelo GToTree (ou adotar um conjunto de
   marcadores mais amplo, seguindo a recomendação de Avontuur et al. de
   128–400 genes) poderia melhorar a resolução do backbone. Opção de maior
   custo computacional, exigindo reprocessamento completo da etapa de
   filogenia.

3. **Tratar *B. diazoefficiens* como grupo próprio na análise**, em vez de
   fundido ao clado de *B. japonicum*. Essa opção reconhece que, na topologia
   obtida, *diazoefficiens* forma um agrupamento monofilético coeso por conta
   própria (apenas não aninhado dentro do clado de USDA 6), e é compatível
   com o próprio histórico taxonômico da espécie mencionado acima. Opção de
   esforço intermediário: não exige nova filogenia, apenas uma nova rodada de
   delimitação usando *diazoefficiens* como uma quarta âncora independente.

**Status:** decisão pendente de orientação do supervisor do projeto.

## 8. Convenção de nomenclatura (português → inglês)

A partir da etapa de classificação taxonômica, nomes de objetos e colunas
**derivados pela curadoria** (não os campos que já vêm prontos do NCBI) foram
padronizados para o inglês, visando facilitar o compartilhamento do
repositório. Tabela de correspondência com a nomenclatura usada nas etapas
anteriores deste documento:

| Nome original (curadoria inicial) | Nome atual (inglês) |
|---|---|
| `diag` | `genomes_raw` |
| `diag_dedup` | `genomes_dedup` |
| `diag_qc` | `genomes_curated` |
| `pais` | `country` |
| `pais_corrigido` | `country_clean` |
| `continente` | `continent` |
| `host_limpo` | `host_clean` |
| `genero_hospedeiro` | `host_genus` |
| `genero_hospedeiro_final` | `host_genus_final` |
| `numero_base` | `accession_number` |
| `prefixo` | `db_prefix` |

## 9. Resumo do funil de seleção

| Etapa | n genomas |
|---|---|
| Total de registros brutos (NCBI, táxon *Bradyrhizobium*) | 4047 |
| Após remoção de duplicatas GCF/GCA | 2199 |
| Após filtro de qualidade (completude ≥90%, contaminação <5%) | 1727 |
| Após remoção de MAGs | **1634** |
| — dos quais com continente identificado | 1174 (71,8%) |
| — dos quais com gênero de hospedeiro identificado | 722 (44,2%) |

## 10. Arquivos gerados nesta etapa

- `bradyrhizobium_genomes.jsonl` — resumo bruto de todos os assemblies (NCBI)
- `bradyrhizobium_diagnostico.tsv` — tabela com metadados de qualidade,
  hospedeiro, localização e nível de montagem
- `pacotes_biosample.tsv` — tabela com o tipo de pacote BioSample de cada
  genoma, utilizada para identificação e remoção de MAGs
- `bradyrhizobium_metadados_dedup_bruto.csv` — checkpoint intermediário, após
  desduplicação GCF/GCA, antes do filtro de qualidade completo e da
  padronização de continente/hospedeiro
- `bradyrhizobium_metadados_curados_final.xlsx` — tabela curada (1727
  genomas, antes da remoção de MAGs)
- `bradyrhizobium_metadados_curados_sem_mags.xlsx` — tabela final curada
  (1634 genomas, após remoção de MAGs) — **versão oficial usada nas análises**
- `accessions_finais.txt` — lista de accessions selecionados, utilizada
  para o download dos arquivos genômicos (FASTA de nucleotídeos e proteínas)
- `Aligned_SCGs.tre` — árvore filogenômica (FastTree/GToTree), utilizada como
  base para a delimitação de clados monofiléticos (seção 7)
- `bradyrhizobium_classificacao_clados.xlsx` — resultado da delimitação por
  clado (`taxonomic_group` por `assembly_accession`), versão oficial da
  classificação taxonômica fina
- `01_curadoria_metadados.R` — script R documentando a curadoria de metadados
- `01_obtencao_dados.sh` — script bash documentando a obtenção de dados brutos
- `bradyrhizobium_analise.Rmd` — documento R Markdown consolidando texto,
  código bash/R e resultados de todas as etapas descritas neste README

## Referências citadas

- Avontuur JR, Palmer M, Beukes CW, et al. (2019). Genome-informed
  *Bradyrhizobium* taxonomy: where to from here? *Systematic and Applied
  Microbiology* (preprint/submitted version).
- Bowers RM, Kyrpides NC, Stepanauskas R, et al. (2017). Minimum information
  about a single amplified genome (MISAG) and a metagenome-assembled genome
  (MIMAG) of bacteria and archaea. *Nature Biotechnology*, 35, 725–731.
- Delamuta JRM, Ribeiro RA, Ormeño-Orrillo E, Melo IS, Martínez-Romero E,
  Hungria M (2013). Polyphasic evidence supporting the reclassification of
  *Bradyrhizobium japonicum* group Ia strains as *Bradyrhizobium
  diazoefficiens* sp. nov. *International Journal of Systematic and
  Evolutionary Microbiology*, 63, 3342–3351.
- Goris J, Konstantinidis KT, Klappenbach JA, et al. (2007). DNA-DNA
  hybridization values and their relationship to whole-genome sequence
  similarities. *International Journal of Systematic and Evolutionary
  Microbiology*, 57, 81–91.
- Jain C, Rodriguez-R LM, Phillippy AM, Konstantinidis KT, Aluru S (2018).
  High throughput ANI analysis of 90K prokaryotic genomes reveals clear
  species boundaries. *Nature Communications*, 9, 5114.
- Richter M, Rosselló-Móra R (2009). Shifting the genomic gold standard for
  the prokaryotic species definition. *PNAS*, 106(45), 19126–19131.
- Sobol MS, Klos AS, Ané C, McMahon KD, Kaçar B (2026). Ecological
  constraints and evolutionary trade-offs shape nitrogen fixation across
  habitats. *ISME Communications*, 6(1), ycag007.

---
*Documento gerado como registro do processo de curadoria — atualizar conforme
o projeto avançar para a delimitação final dos clados monofiléticos e para a
análise estatística.*
