## =============================================================================
## Bradyrhizobium metadata curation
## Version 3 - column/object naming standardized to English
##
## Naming convention: fields that come directly from NCBI's `dataformat`
## output (already in English, e.g. assembly_accession, check_m_completeness)
## are kept as-is. Fields we derive ourselves (country, continent, host
## genus, etc.) are named in English from this version onward.
##
## Mapping from the original Portuguese-named objects (previous version):
##   diag              -> genomes_raw
##   diag_dedup        -> genomes_dedup
##   diag_qc           -> genomes_curated
##   pais              -> country
##   pais_corrigido    -> country_clean
##   continente        -> continent
##   host_limpo        -> host_clean
##   genero_hospedeiro -> host_genus
##   genero_hospedeiro_final -> host_genus_final
##   numero_base       -> accession_number
##   prefixo           -> db_prefix
##
## Prerequisite (generated in terminal):
##   dataformat tsv genome --inputfile bradyrhizobium_genomes.jsonl \
##     --fields accession,assminfo-level,assminfo-atypicalis-atypical,\
##   source_database,checkm-completeness,checkm-contamination,\
##   assminfo-biosample-host,assminfo-biosample-geo-loc-name,\
##   assminfo-biosample-isolation-source,assminfo-biosample-lat-lon,\
##   organism-name \
##     > bradyrhizobium_diagnostico.tsv
## =============================================================================

library(tidyverse)
library(countrycode)
library(janitor)
library(writexl)
library(readxl)

## ---- 1. Read raw diagnostic table -----------------------------------------

genomes_raw <- read_tsv("bradyrhizobium_diagnostico.tsv", show_col_types = FALSE) |>
  clean_names()

names(genomes_raw)

## ---- 2. Remove duplicates (GenBank/RefSeq pairs of the same genome) ------

genomes_raw <- genomes_raw |>
  mutate(
    accession_number = str_remove(assembly_accession, "^GC[AF]_"),
    db_prefix        = str_sub(assembly_accession, 1, 3)
  )

genomes_dedup <- genomes_raw |>
  group_by(accession_number) |>
  arrange(desc(db_prefix == "GCF"), .by_group = TRUE) |>
  slice(1) |>
  ungroup()

nrow(genomes_raw)
nrow(genomes_dedup)

## ---- 3. Quality filter (Bowers et al. 2017 / Sobol et al. 2026 criterion) -

genomes_curated <- genomes_dedup |>
  filter(check_m_completeness >= 90, check_m_contamination < 5)

nrow(genomes_curated)

genomes_curated |> count(assembly_level, sort = TRUE)

## ---- 4. Geographic standardization (country -> continent) ----------------

genomes_curated <- genomes_curated |>
  mutate(
    country = str_trim(str_extract(assembly_bio_sample_geographic_location, "^[^:]+")),
    country_clean = case_when(
      country %in% c("missing", "Missing", "not applicable", "not provided",
                      "not recorded", "-", "None") ~ NA_character_,
      TRUE ~ country
    ),
    continent = countrycode(country_clean, origin = "country.name", destination = "continent"),
    continent = case_when(
      country_clean %in% c("Arctic Ocean", "Antarctica") ~ "Not applicable (environmental source)",
      TRUE ~ continent
    )
  )

genomes_curated |> count(continent, sort = TRUE)

## Note: countries not automatically matched by countrycode() should always
## be inspected manually before proceeding:
unmatched_countries <- genomes_curated |>
  filter(!is.na(country_clean) & is.na(continent)) |>
  count(country_clean, sort = TRUE)

print(unmatched_countries)

## Decision: geographic scope kept at broad continent level for the initial
## analysis (Americas, Africa, Asia, Europe, Oceania). Sub-regional cuts
## (e.g. South America, Africa specifically) or a "Global South" grouping
## are deferred to a later, separately-justified analysis.

## ---- 5. Host standardization -----------------------------------------------

hosts_unique <- genomes_curated |> count(assembly_bio_sample_host, sort = TRUE)

genomes_curated <- genomes_curated |>
  mutate(
    host_clean = assembly_bio_sample_host,
    host_clean = str_remove(host_clean, "\\(L\\.\\)\\s*Merr(ill)?\\.?"),
    host_clean = str_remove(host_clean, "\\(Sw\\.\\)\\s*Willd\\.?"),
    host_clean = str_remove(host_clean, "\\bcv\\.\\s*[A-Za-z ]+"),
    host_clean = str_remove(host_clean, "\\bcultivar\\s+[A-Za-z0-9]+"),
    host_clean = str_remove(host_clean, "\\bsubsp\\.\\s*[A-Za-z]+"),
    host_clean = str_remove(host_clean, "\\bvar\\.\\s*[A-Za-z]+"),
    host_clean = str_remove(host_clean, "\\bBenth\\.?"),
    host_clean = str_remove(host_clean, "\\bCol-0\\b"),
    host_clean = str_remove(host_clean, "Golden Promise"),
    host_clean = str_remove(host_clean, "\\(pigeon pea\\)"),
    host_clean = str_remove(host_clean, "\\s+[A-Z][0-9]+$"),
    host_clean = str_trim(host_clean),
    host_clean = str_replace(host_clean, "^Glicyne", "Glycine"),
    host_clean = str_replace(host_clean, "^Desmonium", "Desmodium"),
    host_clean = str_replace(host_clean, "^Glycine hispida$", "Glycine max"),
    host_clean = if_else(
      host_clean %in% c("not applicable", "missing", "-", "None", "not provided",
                         "not recorded", "Not determined", "Plant", "legume",
                         "forest legume species") | is.na(host_clean),
      NA_character_, host_clean
    )
  )

genomes_curated <- genomes_curated |>
  mutate(
    host_genus = case_when(
      is.na(host_clean) ~ NA_character_,
      host_clean == "Homo sapiens" ~ "ANOMALY_review",
      host_clean == "Sus scrofa" ~ "ANOMALY_review",
      host_clean == "Subsurface shale" ~ "Non_plant_source",
      str_detect(host_clean, ";") ~ "MULTIPLE_review",
      str_detect(host_clean, regex("^soybean", ignore_case = TRUE)) ~ "Glycine",
      str_detect(host_clean, regex("^(forage )?peanut", ignore_case = TRUE)) ~ "Arachis",
      str_detect(host_clean, regex("pigeon\\s*pea", ignore_case = TRUE)) ~ "Cajanus",
      str_detect(host_clean, regex("^rice$", ignore_case = TRUE)) ~ "Oryza",
      str_detect(host_clean, regex("sweet potato", ignore_case = TRUE)) ~ "Ipomoea",
      str_detect(host_clean, regex("sugarcane", ignore_case = TRUE)) ~ "Saccharum",
      TRUE ~ word(host_clean, 1)
    ),
    host_genus_final = if_else(
      host_genus %in% c("ANOMALY_review", "MULTIPLE_review", "Non_plant_source"),
      NA_character_, host_genus
    )
  )

genomes_curated |> count(host_genus_final, sort = TRUE) |> print(n = 70)

## Cases excluded from the host variable (kept in the overall dataset):
## Homo sapiens (n=2), Sus scrofa (n=1), Subsurface shale (n=1),
## multiple-host field (n=1). See README for justification of each.

## ---- 6. Selection funnel summary ------------------------------------------

selection_funnel <- tibble(
  step = c(
    "Total genomes in NCBI (raw)",
    "After removing GCF/GCA duplicates",
    "After quality filter (completeness >=90%, contamination <5%)",
    "With country identified",
    "With continent assigned",
    "With host genus identified"
  ),
  n_genomes = c(
    nrow(genomes_raw),
    nrow(genomes_dedup),
    nrow(genomes_curated),
    sum(!is.na(genomes_curated$country_clean)),
    sum(!is.na(genomes_curated$continent) & genomes_curated$continent != "Not applicable (environmental source)"),
    sum(!is.na(genomes_curated$host_genus_final))
  )
)

selection_funnel

## ---- 7. Export -------------------------------------------------------------

write_xlsx(genomes_curated, "bradyrhizobium_metadados_curados.xlsx")
write_xlsx(selection_funnel, "selection_funnel.xlsx")

genomes_curated |>
  pull(assembly_accession) |>
  write_lines("accessions_finais.txt")

message("Curation (v3, English naming) complete.")
message("Curated genomes: ", nrow(genomes_curated))
