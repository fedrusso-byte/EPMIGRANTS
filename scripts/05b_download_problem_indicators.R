# ==============================================================================
# download_problem_indicators.R — Versione Semplificata (Senza Gini)
# ==============================================================================

library(here)
library(tidyverse)
library(eurostat)
library(WDI)
library(countrycode)
library(janitor)
library(zoo)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("data_processed"), showWarnings = FALSE, recursive = TRUE)

message("\n=== Downloading real-world problem indicators ===")

eu_countries <- c(
  "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES",
  "FI", "FR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT",
  "NL", "PL", "PT", "RO", "SE", "SI", "SK", "UK"
)

# Forza il ricaricamento visto che l'ultima volta è fallito
FORCE_REDOWNLOAD <- TRUE
cache_path <- here("data_processed", "covariates_cache.rds")

if (!FORCE_REDOWNLOAD && file.exists(cache_path)) {
  message("  Loading cached covariates from ", cache_path)
  covariates <- readRDS(cache_path)
} else {
  message("  Downloading covariates from Eurostat/WDI APIs...")

  # --- Unemployment ---
  unemp_raw <- get_eurostat("une_rt_m", time_format = "date")
  unemp <- unemp_raw %>%
    clean_names() %>%
    filter(s_adj == "SA", sex == "T", age == "TOTAL", unit == "PC_ACT", geo %in% eu_countries) %>%
    mutate(year = lubridate::year(time_period)) %>%
    group_by(geo, year) %>%
    summarise(unemployment = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)

  # --- GDP per capita ---
  gdp_raw <- get_eurostat("nama_10_pc", time_format = "num")
  gdp <- gdp_raw %>%
    clean_names() %>%
    filter(na_item == "B1GQ", unit == "CLV10_EUR_HAB", geo %in% eu_countries) %>%
    mutate(year = floor(time_period)) %>%
    group_by(geo, year) %>%
    summarise(gdp_per_capita = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)

  # --- GDP Growth ---
  gdp_growth_calc <- gdp %>%
    arrange(country, year) %>%
    group_by(country) %>%
    mutate(gdp_growth = 100 * (gdp_per_capita / dplyr::lag(gdp_per_capita) - 1)) %>%
    ungroup()

  # --- Bond Yields ---
  message("    Downloading Bond Yields data...")
  bond_raw <- get_eurostat("irt_lt_mcby_m", time_format = "date")
  bond <- bond_raw %>%
    clean_names() %>%
    filter(geo %in% eu_countries) %>%
    mutate(year = lubridate::year(time_period)) %>%
    group_by(geo, year) %>%
    summarise(bond_yield = mean(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)

  # --- Population ---
  pop_raw <- get_eurostat("demo_pjan", time_format = "date")
  pop <- pop_raw %>%
    clean_names() %>%
    filter(geo %in% eu_countries, age == "TOTAL", sex == "T") %>%
    mutate(year = lubridate::year(time_period)) %>%
    group_by(geo, year) %>%
    summarise(population = sum(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo)

  # --- Asylum ---
  asylum_raw <- get_eurostat("migr_asyappctza", time_format = "date")
  asylum <- asylum_raw %>%
    clean_names() %>%
    filter(geo %in% eu_countries) %>%
    mutate(year = lubridate::year(time_period)) %>%
    group_by(geo, year) %>%
    summarise(asylum_applications = sum(values, na.rm = TRUE), .groups = "drop") %>%
    rename(country = geo) %>%
    left_join(pop, by = c("country", "year")) %>%
    mutate(asylum_per_1000 = 1000 * asylum_applications / population)

  # --- UNIONE DEI DATI ---
  covariates <- unemp %>%
    left_join(gdp_growth_calc %>% select(country, year, gdp_growth), by = c("country", "year")) %>%
    left_join(bond, by = c("country", "year")) %>%
    left_join(asylum %>% select(country, year, asylum_applications, asylum_per_1000), by = c("country", "year")) %>%
    left_join(pop, by = c("country", "year"))

  # --- Interpolazione e Misery Index ---
  covariates <- covariates %>%
    group_by(country) %>%
    arrange(year) %>%
    mutate(across(where(is.numeric) & !any_of("year"), ~ zoo::na.approx(., year, na.rm = FALSE))) %>%
    mutate(across(where(is.numeric) & !any_of("year"), ~ zoo::na.locf(., na.rm = FALSE))) %>%
    ungroup() %>%
    mutate(misery_index = unemployment + bond_yield - gdp_growth)

  # Aggiunta riga EU (media)
  eu_rows <- covariates %>%
    group_by(year) %>%
    summarise(across(where(is.numeric) & !any_of("year"), \(x) mean(x, na.rm = TRUE)), .groups = "drop") %>%
    mutate(country = "EU")

  covariates <- bind_rows(covariates, eu_rows) %>%
    mutate(country = case_match(country, "EL" ~ "GR", .default = country))

  saveRDS(covariates, cache_path)
}

write_csv(covariates, here("output", "problem_indicators.csv"))
message("=== Completato con successo senza Gini ===")
