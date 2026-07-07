# ==============================================================================
# download_problem_indicators.R — Versione Semplificata e Corretta
# ==============================================================================

if (!requireNamespace("eurostat", quietly = TRUE)) install.packages("eurostat")
if (!requireNamespace("WDI", quietly = TRUE)) install.packages("WDI")
if (!requireNamespace("countrycode", quietly = TRUE)) install.packages("countrycode")
if (!requireNamespace("janitor", quietly = TRUE)) install.packages("janitor")
if (!requireNamespace("zoo", quietly = TRUE)) install.packages("zoo")
if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")

library(here)
library(tidyverse)
library(eurostat)
library(WDI)
library(countrycode)
library(janitor)
library(zoo)
library(readr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("data_processed"), showWarnings = FALSE, recursive = TRUE)

message("\n=== Downloading real-world problem indicators ===")

eu_countries <- c(
  "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES",
  "FI", "FR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT",
  "NL", "PL", "PT", "RO", "SE", "SI", "SK", "UK"
)

FORCE_REDOWNLOAD <- TRUE
cache_path <- here("data_processed", "covariates_cache.rds")

if (!FORCE_REDOWNLOAD && file.exists(cache_path)) {
  message("   Loading cached covariates from ", cache_path)
  covariates <- readRDS(cache_path)
} else {
  message("   Downloading covariates from Eurostat/WDI APIs...")
  
  # ----------------------------------------------------------------------------
  # 1. UNEMPLOYMENT
  # ----------------------------------------------------------------------------
  message("   -> Processing Unemployment...")
  unemp_raw <- get_eurostat("une_rt_m", time_format = "date")
  unemp_lavoro <- unemp_raw
  colnames(unemp_lavoro) <- tolower(colnames(unemp_lavoro))
  
  unemp <- unemp_lavoro %>%
    filter(
      s_adj == "SA", 
      sex == "T", 
      age == "TOTAL", 
      unit == "PC_ACT", 
      geo %in% eu_countries
    ) %>%
    # APPLICATA STRATEGIA SICURA PER L'ANNO
    mutate(year = as.numeric(substr(as.character(time_period), 1, 4))) %>%
    group_by(geo, year) %>%
    summarise(unemployment = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)
  
  # ----------------------------------------------------------------------------
  # 2. GDP PER CAPITA & GROWTH
  # ----------------------------------------------------------------------------
  message("   -> Processing GDP...")
  gdp_raw <- get_eurostat("nama_10_pc", time_format = "num")
  gdp_lavoro <- gdp_raw
  colnames(gdp_lavoro) <- tolower(colnames(gdp_lavoro))
  
  gdp <- gdp_lavoro %>%
    filter(
      na_item == "B1GQ", 
      unit == "CLV10_EUR_HAB", 
      geo %in% eu_countries
    ) %>%
    mutate(year = floor(time_period)) %>%
    group_by(geo, year) %>%
    summarise(gdp_per_capita = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)
  
  gdp_growth_calc <- gdp %>%
    arrange(country, year) %>%
    group_by(country) %>%
    mutate(gdp_growth = 100 * (gdp_per_capita / dplyr::lag(gdp_per_capita) - 1)) %>%
    ungroup()
  
message("   -> Injecting historical UK GDP growth data missing from Eurostat...")

uk_gdp_history <- tibble(
  country = "UK",
  year = 2005:2020,
  # Dati ufficiali della crescita del PIL % del Regno Unito (https://www.ons.gov.uk/economy/grossdomesticproductgdp/timeseries/ihyp/qna)
  gdp_growth = c(2.8, 2.8, 2.4, -0.2, -4.2, 2.4, 1.5, 1.5, 2.1, 2.6, 2.4, 2.2, 2.1, 1.7, 1.7, -10.4)
)

# Uniamo i dati Eurostat esistenti con la serie storica dello UK
gdp_growth_calc <- gdp_growth_calc %>%
  filter(country != "UK") %>% # Rimuove eventuali righe vuote residue
  bind_rows(uk_gdp_history)


  # ----------------------------------------------------------------------------
  # 3. BOND YIELDS
  # ----------------------------------------------------------------------------
  message("   -> Processing Bond Yields...")
  bond_raw <- get_eurostat("irt_lt_mcby_m", time_format = "date")
  bond_lavoro <- bond_raw
  colnames(bond_lavoro) <- tolower(colnames(bond_lavoro))
  
  bond <- bond_lavoro %>%
    filter(geo %in% eu_countries) %>%
    mutate(year = as.numeric(substr(as.character(time_period), 1, 4))) %>%
    group_by(geo, year) %>%
    summarise(bond_yield = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)
  
  # ----------------------------------------------------------------------------
  # 4. POPULATION
  # ----------------------------------------------------------------------------
  message("   -> Processing Population...")
  pop_raw <- get_eurostat("demo_pjan", time_format = "date")
  pop_lavoro <- pop_raw
  colnames(pop_lavoro) <- tolower(colnames(pop_lavoro))
  
  pop <- pop_lavoro %>%
    filter(
      geo %in% eu_countries, 
      age == "TOTAL", 
      sex == "T"
    ) %>%
    mutate(year = as.numeric(substr(as.character(time_period), 1, 4))) %>%
    group_by(geo, year) %>%
    summarise(population = sum(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)
  
  # ----------------------------------------------------------------------------
  # 5. ASYLUM APPLICATIONS
  # ----------------------------------------------------------------------------
  message("   -> Processing Asylum...")
  asylum_raw <- get_eurostat("migr_asyappctza", time_format = "date")
  
  asylum <- asylum_raw %>%
    filter(geo %in% eu_countries) %>%
    mutate(year = as.numeric(substr(as.character(TIME_PERIOD), 1, 4))) %>%
    group_by(geo, year) %>%
    summarise(asylum_applications = sum(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo) %>%
    left_join(pop, by = c("country", "year")) %>%
    mutate(asylum_per_1000 = 1000 * asylum_applications / population)
  

 
# ----------------------------------------------------------------------------
  # 6. INCLUSIONE MIPEX (CORREZIONE DEFINITIVA PER DF_MERGED_3)
  # ----------------------------------------------------------------------------
  message("   -> Processing MIPEX Antidiscrimination Score...")
  
  mipex_data <- read_csv(here("data", "mipex_long2.csv"), show_col_types = FALSE) %>%
    select(cntry, mipex_year, mipex_antidiscrimination_score) %>%
    # Adeguamento ai codici esatti che leggi in df_merged_3 (GR e UK)
    mutate(cntry = case_when(
      cntry == "EL" ~ "GR", # Se per caso MIPEX aveva EL, portalo a GR
      cntry == "GB" ~ "UK", # GB deve tassativamente diventare UK
      TRUE ~ cntry
    )) %>%
    rename(country = cntry, year = mipex_year)

# ----------------------------------------------------------------------------
  # 7. UNIONE DEI DATI (JOIN)
  # ----------------------------------------------------------------------------
  message("   -> Merging indicators into covariates...")
  
  covariates <- unemp %>%
    mutate(country = if_else(country == "EL", "GR", country)) %>%
    left_join(gdp_growth_calc %>% mutate(country = if_else(country == "EL", "GR", country)), by = c("country", "year")) %>%
    left_join(bond %>% mutate(country = if_else(country == "EL", "GR", country)), by = c("country", "year")) %>%
    left_join(asylum %>% mutate(country = if_else(country == "EL", "GR", country)) %>% 
                select(country, year, asylum_applications, asylum_per_1000), by = c("country", "year")) %>%
    left_join(pop %>% mutate(country = if_else(country == "EL", "GR", country)), by = c("country", "year")) %>% 
    # Uniamo MIPEX qui, prima di fare la pulizia dei NA
    left_join(mipex_data, by = c("country", "year"))
  
  # ----------------------------------------------------------------------------
  # 8. INTERPOLAZIONE E MISERY INDEX (COPRE ANCHE MIPEX)
  # ----------------------------------------------------------------------------
  message("   -> Computing Misery Index and interpolating...")
  
  covariates <- covariates %>%
    group_by(country) %>%
    arrange(year) %>%
    # Escludiamo MT e LU dall'interpolazione per evitare il crash totale, dato che sono tutte NA
    filter(!country %in% c("MT", "LU")) %>% 
    # Riuniamo i buchi degli anni sia per Eurostat che per MIPEX
    mutate(across(where(is.numeric) & !any_of("year"), ~ zoo::na.approx(., year, na.rm = FALSE))) %>%
    mutate(across(where(is.numeric) & !any_of("year"), ~ zoo::na.locf(., na.rm = FALSE))) %>%
    mutate(across(where(is.numeric) & !any_of("year"), ~ zoo::na.locf(., fromLast = TRUE, na.rm = FALSE))) %>% # Copre all'indietro se serve
    ungroup() %>%
    mutate(misery_index = unemployment + bond_yield - gdp_growth)
  
  saveRDS(covariates, cache_path)
}

# Scrittura finale del file CSV
write_csv(covariates, here("output", "problem_indicators.csv"))
message("\n=== Completato con successo senza Gini! File salvato in output/ ===")