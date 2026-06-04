# 08_responsiveness_models.R — Responsiveness Analysis: Model Progression
# Author: Marcello Carammia and Federico Russo (Modified for Misery Index)
# Purpose: Fit a sequence of negative binomial GLMMs testing MEP
#          responsiveness to public priorities (MIP) and real-world problems,
#          with domestic vs EU-wide decomposition.
#
# Input:  output/responsiveness_panel.rds
# Output: output/resp_model_*.rds, output/resp_model_comparison.rds,
#         output/resp_vc_*.rds, output/figures/resp_*.pdf
#
# NOTE: Models are fitted sequentially with aggressive memory cleanup
# between each model. Each model is saved to disk immediately after fitting,
# and summary statistics are extracted before the object is removed.
# This allows the script to run within WSL memory constraints (~2-3 GB).

# 0. Setup ====================================================================
library(tidyverse)
library(glmmTMB)
library(marginaleffects)
library(performance)
library(broom.mixed)
library(emmeans)
library(DHARMa)
library(here)
library(patchwork)

set.seed(20260327)

dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)

# 1. Helper functions ==========================================================

#' Extract exponentiated coefficients (IRRs) from a glmmTMB model
#' @param model A fitted glmmTMB object
#' @param model_name Character label for the model
#' @return Tibble with IRR estimates, CIs, and significance
tidy_irr <- function(model, model_name = "model") {
  broom.mixed::tidy(model, component = "cond", conf.int = TRUE, exponentiate = TRUE) %>%
    mutate(
      model = model_name,
      sig = case_when(
        p.value < 0.001 ~ "***",
        p.value < 0.01  ~ "**",
        p.value < 0.05  ~ "*",
        p.value < 0.1   ~ ".",
        TRUE ~ ""
      )
    )
}

#' Variance decomposition for a glmmTMB model
#' @param model A fitted glmmTMB object
#' @param model_name Character label for the model
#' @return Tibble with columns: model, group, variance
extract_vc <- function(model, model_name = "model") {
  vc_raw <- VarCorr(model)$cond
  if (is.null(vc_raw) || length(vc_raw) == 0) {
    return(tibble(model = model_name, group = character(0), variance = numeric(0)))
  }
  tibble(
    model = model_name,
    group = names(vc_raw),
    variance = map_dbl(vc_raw, ~ attr(.x, "stddev")^2)
  )
}

#' Extract summary stats from a model before removing it
#' @param model A fitted glmmTMB object
#' @param model_name Character label
#' @return List with AIC, BIC, logLik, nobs, irr, vc
extract_summary <- function(model, model_name) {
  list(
    name = model_name,
    AIC = AIC(model),
    BIC = BIC(model),
    logLik = as.numeric(logLik(model)),
    n_obs = nobs(model),
    irr = tidy_irr(model, model_name),
    vc = extract_vc(model, model_name),
    converged = isTRUE(model$sdr$pdHess)
  )
}

#' Run DHARMa diagnostics and save plot
#' @param model A fitted glmmTMB object
#' @param model_name Character label used in filename
#' @param n_sim Number of simulations (reduce for large models)
#' @return Invisible DHARMa simulation object, or NULL on failure
run_dharma <- function(model, model_name, n_sim = 100) {
  tryCatch({
    sim <- simulateResiduals(model, n = n_sim, plot = FALSE)
    pdf(here("output", "figures", paste0("resp_dharma_", model_name, ".pdf")),
        width = 10, height = 5, bg = "transparent")
    plot(sim, main = model_name)
    dev.off()
    invisible(sim)
  }, error = function(e) {
    message("    DHARMa failed for ", model_name, ": ", e$message)
    invisible(NULL)
  })
}

#' Fit a model, extract summaries, run DHARMa, save to disk, then clean up
#' @param formula Model formula
#' @param data Data frame
#' @param model_name Character label (e.g., "m0")
#' @param file_name RDS filename (e.g., "resp_model_0_baseline.rds")
#' @param run_dharma_diag Whether to run DHARMa (skip for very large models)
#' @return List of summary statistics
fit_and_cleanup <- function(formula, data, model_name, file_name,
                            run_dharma_diag = TRUE) {
  fit <- glmmTMB(formula, family = nbinom2, data = data)
  saveRDS(fit, here("output", file_name))
  message("  ", model_name, " fitted and saved")

  summ <- extract_summary(fit, model_name)

  if (run_dharma_diag) {
    run_dharma(fit, model_name)
  }

  # Clean up the large model object
  rm(fit)
  gc()

  summ
}

# 2. Load and prepare data =====================================================
message("Loading responsiveness panel...")
resp_panel <- readRDS(here("output", "responsiveness_panel.rds"))

model_data <- resp_panel %>%
  dplyr::filter(!is.na(mip_share)) %>%
  mutate(
    semester_id = paste0(year, "_S", semester),
    # Rate offset: log(total - focal) to avoid part-whole bias
    log_offset = log(pmax(total_questions - n_questions, 1L))
  ) %>%
  dplyr::filter(total_questions > 0) %>%
  mutate(
    mip_share_z = as.numeric(scale(mip_share)),
    mip_eu_matched_z = as.numeric(scale(mip_eu_mean)),
    mip_deviation_z = as.numeric(scale(mip_deviation))
  )

# AGGIORNAMENTO INTEGRATO:
# Usiamo il Misery Index (Federico) ma con logica Targeted (Marcello)
has_problems <- "misery_index" %in% names(model_data) &&
  "asylum_eu_mean" %in% names(model_data)

if (has_problems) {
  model_data <- model_data %>%
    mutate(
      # Il Misery Index agisce solo sul dominio "economy" [cite: 38, 97]
      misery_eu_matched = if_else(domain == "economy", misery_eu_mean, 0),
      misery_dev_matched = if_else(domain == "economy", misery_deviation, 0),

      # L'asilo agisce solo sul dominio "migration"
      asylum_eu_matched = if_else(domain == "migration", asylum_eu_mean, 0),
      asylum_dev_matched = if_else(domain == "migration", asylum_deviation, 0)
    ) %>%
    mutate(
      # Standardizzazione delle nuove variabili integrate [cite: 39, 97]
      misery_eu_matched_z = as.numeric(scale(misery_eu_matched)),
      misery_dev_matched_z = as.numeric(scale(misery_dev_matched)),
      asylum_eu_matched_z = as.numeric(scale(asylum_eu_matched)),
      asylum_dev_matched_z = as.numeric(scale(asylum_dev_matched))
    )
}

stopifnot(
  "model_data has zero rows after filtering" = nrow(model_data) > 0,
  "mip_share_z has zero variance" = sd(model_data$mip_share_z, na.rm = TRUE) > 0,
  "log_offset contains NA" = !any(is.na(model_data$log_offset)),
  "log_offset contains Inf" = all(is.finite(model_data$log_offset))
)

message("  Model data: ", nrow(model_data), " rows, ",
        n_distinct(model_data$mep_id), " MEPs, ",
        n_distinct(model_data$issue_name), " issues")
message("  Problem indicators available: ", has_problems)

# Free panel before model fitting
rm(resp_panel)
gc()

# Prepare problem-indicator subset (used by m1, m2, m3)
if (has_problems) {
  model_data_problems <- model_data %>%
    dplyr::filter(!is.na(misery_eu_matched_z), !is.na(asylum_eu_matched_z))
}

# Accumulate summaries in a list
summaries <- list()

# ==============================================================================
# --- ALLINEAMENTO CAMPIONE PER COMPARABILITÀ AIC/BIC (STRICT DATASET) ---
# ==============================================================================
message("\n--- Creazione dataset 'strict' per comparabilità modelli ---")

# 1. Elenchiamo le variabili base usate in tutti i modelli
vars_to_check <- c(
  "n_questions", "log_offset",
  "mip_eu_matched_z", "mip_deviation_z",
  "issue_name", "semester_id", "domain",
  "committee_match", "gender", "geographic_region",
  "euro_member", "party_family",
  "mep_id", "country", "group_abbr"
)

# 2. Aggiungiamo dinamicamente le variabili dei "problemi" (se disponibili)
if (has_problems) {
  vars_to_check <- c(vars_to_check,
                     "misery_eu_matched_z", "misery_dev_matched_z",
                     "asylum_eu_matched_z", "asylum_dev_matched_z")
}

# 3. Rimuoviamo le righe che hanno NA in *qualsiasi* di queste colonne
model_data_strict <- model_data %>%
  tidyr::drop_na(any_of(vars_to_check))

message(sprintf("  Osservazioni originali: %d", nrow(model_data)))
message(sprintf("  Osservazioni strict:    %d", nrow(model_data_strict)))

# 4. Prepariamo SUBITO le variabili per il Modello 5 (Mundlak) sul campione strict
mundlak_means <- model_data_strict %>%
  group_by(mep_id) %>%
  summarise(mip_share_mean = mean(mip_share, na.rm = TRUE), .groups = "drop")

model_data_strict <- model_data_strict %>%
  left_join(mundlak_means, by = "mep_id") %>%
  mutate(mip_share_mean_z = as.numeric(scale(mip_share_mean)))

rm(mundlak_means)
gc()

# 5. Aggiorniamo la gestione per 'has_problems' (se usato nel tuo script)
if (exists("has_problems") && has_problems) {
  model_data_problems_strict <- model_data_strict
}
# ==============================================================================




# 3. Model fitting (sequential with cleanup) ===================================

# --- Model 0: Baseline MIP responsiveness ---
message("\n--- Model 0: Baseline MIP responsiveness ---")
summaries$m0 <- fit_and_cleanup(
  n_questions ~ mip_share_z +
    issue_name + semester_id +
    committee_match + gender + geographic_region + euro_member + party_family +
    (1 | mep_id) + (1 | country) + (1 | group_abbr) +
    offset(log_offset),
  data = model_data_strict,
  model_name = "m0",
  file_name = "resp_model_0_baseline.rds"
)

# --- Model 1: Add problem indicators ---
# Sostituisci eu_mean_z con eu_matched_z <--- CORREZIONE
if (has_problems) {
  message("\n--- Model 1: Add problem indicators ---")
  summaries$m1 <- fit_and_cleanup(
    n_questions ~ mip_share_z + misery_eu_matched_z + misery_dev_matched_z +
      asylum_eu_matched_z + asylum_dev_matched_z +
      issue_name + semester_id +
      committee_match + gender + geographic_region + euro_member + party_family +
      (1 | mep_id) + (1 | country) + (1 | group_abbr) +
      offset(log_offset),
    data = if (has_problems) model_data_problems_strict else model_data_strict,
    model_name = "m1",
    file_name = "resp_model_1_problems.rds"
  )
} else {
  message("\n--- Model 1: Skipped (no problem indicators) ---")
}

# --- Model 2: Core decomposition (H1/H2) ---
message("\n--- Model 2: MIP decomposition (core H1/H2 test) ---")
m2_formula <- if (has_problems) {
  n_questions ~ mip_eu_matched_z + mip_deviation_z +
    misery_eu_matched_z + misery_dev_matched_z +
    asylum_eu_matched_z + asylum_dev_matched_z +
    issue_name + semester_id +
    committee_match + gender + geographic_region + euro_member + party_family +
    (1 | mep_id) + (1 | country) + (1 | group_abbr) +
    offset(log_offset)
} else {
  n_questions ~ mip_eu_matched_z + mip_deviation_z +
    issue_name + semester_id +
    committee_match + gender + geographic_region + euro_member + party_family +
    (1 | mep_id) + (1 | country) + (1 | group_abbr) +
    offset(log_offset)
}

summaries$m2 <- fit_and_cleanup(
  m2_formula,
  data = if (has_problems) model_data_problems_strict else model_data_strict,
  model_name = "m2",
  file_name = "resp_model_2_decomposition.rds"
)

# --- Model 3: Domain interactions (H3) ---
# For m3 we need the model object for emtrends, so we keep it temporarily
message("\n--- Model 3: Domain interactions (H3) ---")
m3_formula <- if (has_problems) {
  n_questions ~ mip_eu_matched_z * domain + mip_deviation_z * domain +
    misery_eu_matched_z + misery_dev_matched_z +
    asylum_eu_matched_z + asylum_dev_matched_z +
    issue_name + semester_id +
    committee_match + gender + geographic_region + euro_member + party_family +
    (1 | mep_id) + (1 | country) + (1 | group_abbr) +
    offset(log_offset)
} else {
  n_questions ~ mip_eu_matched_z * domain + mip_deviation_z * domain +
    issue_name + semester_id +
    committee_match + gender + geographic_region + euro_member + party_family +
    (1 | mep_id) + (1 | country) + (1 | group_abbr) +
    offset(log_offset)
}

m3 <- glmmTMB(m3_formula, family = nbinom2,
              data = if (has_problems) model_data_problems_strict else model_data_strict)
saveRDS(m3, here("output", "resp_model_3_domain.rds"))
message("  m3 fitted and saved")
summaries$m3 <- extract_summary(m3, "m3")
run_dharma(m3, "m3")
gc()

# --- Domain-specific effects (emtrends) ---
message("\n--- Domain-specific effects (emtrends) ---")

tryCatch({
  # Identifichiamo il dataset usato per il modello
  d_per_trends <- if (exists("model_data_problems")) model_data_problems else model_data

  trends_eu <- emtrends(m3, ~ domain, var = "mip_eu_matched_z",
                        data = d_per_trends, # Fondamentale per la stabilità
                        nuisance = c("semester_id", "issue_name"))

  trends_dev <- emtrends(m3, ~ domain, var = "mip_deviation_z",
                         data = d_per_trends,
                         nuisance = c("semester_id", "issue_name"))

  domain_trends <- list(
    eu_mean = trends_eu,
    deviation = trends_dev,
    eu_mean_pairs = pairs(trends_eu),
    deviation_pairs = pairs(trends_dev)
  )

  saveRDS(domain_trends, here("output", "resp_domain_trends.rds"))
  message("  Domain trends saved correctly.")
}, error = function(e) {
  message("  emtrends failed: ", e$message)
})

# Now clean up m3
rm(m3)
gc()

# --- Model 4: Electoral system moderation (H4) ---
message("\n--- Model 4: Electoral system moderation (H4) ---")
if (any(!is.na(model_data$system_type))) {
  m4_data <- model_data %>% dplyr::filter(!is.na(system_type))
  summaries$m4 <- fit_and_cleanup(
    n_questions ~ mip_eu_matched_z * system_type + mip_deviation_z * system_type +
      issue_name + semester_id +
      committee_match + gender + geographic_region + euro_member + party_family +
      (1 | mep_id) + (1 | country) + (1 | group_abbr) +
      offset(log_offset),
    data = m4_data,
    model_name = "m4",
    file_name = "resp_model_4_electoral.rds"
  )
} else {
  message("  Model 4: Skipped (electoral system data not yet available)")
}

# --- Model 5: Full model (HTE + Mundlak) ---
message("\n--- Model 5: Full model (HTE + Mundlak) ---")

# Nota: codice commentato perché mundlak_means e mip_share_mean_z sono già stati creati
# nel blocco 'Strict' all'inizio dello script
#ATTENTION: MISERY AND ASYLUM ARE MISSING HERE
#mundlak_means <- model_data %>%
#  group_by(mep_id) %>%
#  summarise(mip_share_mean = mean(mip_share, na.rm = TRUE), .groups = "drop")

#m5_data <- model_data %>%
#  left_join(mundlak_means, by = "mep_id") %>%
#  mutate(mip_share_mean_z = as.numeric(scale(mip_share_mean)))
#rm(mundlak_means)
#gc()

summaries$m5 <- tryCatch({
  fit_and_cleanup(
    n_questions ~ mip_eu_matched_z + mip_deviation_z +
      mip_share_mean_z +
      issue_name + semester_id +
      committee_match + gender + geographic_region + euro_member + party_family +
      (1 | mep_id) + (1 | country) + (1 | group_abbr) +
      (0 + mip_eu_matched_z | issue_name) +
      offset(log_offset),
    data = model_data_strict,
    model_name = "m5",
    file_name = "resp_model_5_full.rds",
    run_dharma_diag = FALSE  # Too large for DHARMa simulation in WSL
  )
}, error = function(e) {
  message("  Model 5 failed: ", e$message)
  NULL
})

rm(m5_data)
gc()

# 4. Post-estimation ===========================================================
message("\n--- Post-estimation ---")

# Model comparison table
comparison <- tibble(
  model = map_chr(summaries, "name"),
  AIC = map_dbl(summaries, "AIC"),
  BIC = map_dbl(summaries, "BIC"),
  logLik = map_dbl(summaries, "logLik"),
  n_obs = map_int(summaries, "n_obs"),
  converged = map_lgl(summaries, "converged")
) %>%
  arrange(AIC)

saveRDS(comparison, here("output", "resp_model_comparison.rds"))
message("  Model comparison saved")

# Variance decomposition
vc_all <- map_df(summaries, "vc")
saveRDS(vc_all, here("output", "resp_vc_comparison.rds"))
message("  Variance decomposition saved")

# IRR tables
irr_all <- map_df(summaries, "irr")
saveRDS(irr_all, here("output", "resp_irr_tables.rds"))

# Forest plot: decomposition coefficients (from m2)
message("\n--- Forest plots ---")
irr_m2 <- summaries$m2$irr

key_terms <- c("mip_eu_matched_z", "mip_deviation_z")
if (has_problems) {
  key_terms <- c(key_terms, "misery_eu_matched_z", "misery_dev_matched_z",
                 "asylum_eu_matched_z", "asylum_dev_matched_z")
}

forest_data <- irr_m2 %>%
  dplyr::filter(term %in% key_terms) %>%
  mutate(
    term_label = case_when(
      term == "mip_eu_matched_z"      ~ "MIP: EU-wide",
      term == "mip_deviation_z"    ~ "MIP: Domestic deviation",
      term == "misery_eu_matched_z"   ~ "Misery Index: EU-wide",
      term == "misery_dev_matched_z" ~ "Misery Index: Domestic deviation",
      term == "asylum_eu_matched_z"   ~ "Asylum: EU-wide",
      term == "asylum_dev_matched_z" ~ "Asylum: Domestic deviation",
      TRUE ~ term
    ),
    component = if_else(str_detect(term, "eu_matched"), "EU-wide", "Domestic")
  )

if (nrow(forest_data) > 0) {
  p_forest <- ggplot(forest_data,
                     aes(x = estimate, y = reorder(term_label, estimate),
                         xmin = conf.low, xmax = conf.high, color = component)) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "grey50") +
    geom_pointrange(size = 0.8) +
    scale_color_manual(values = c("EU-wide" = "#0072B2", "Domestic" = "#D55E00")) +
    labs(
      title = "Responsiveness Decomposition (Model 2)",
      subtitle = "Incidence rate ratios with 95% confidence intervals",
      x = "Incidence Rate Ratio (IRR)", y = NULL,
      color = "Component"
    ) +
    theme_minimal(base_size = 14) +
    theme(legend.position = "bottom")

  ggsave(here("output", "figures", "resp_forest_decomposition.pdf"),
         p_forest, width = 8, height = 5, bg = "transparent")
  message("  Forest plot saved")
}

# 5. Summary ===================================================================
message("\n=== 08_responsiveness_models.R complete ===")
message("Models fitted: ", paste(map_chr(summaries, "name"), collapse = ", "))
message("Outputs in output/resp_model_*.rds, output/resp_vc_comparison.rds")

# ============================================================================
# 6. Export Scatter Data for QMD (ULTIMATE FIX)
# ============================================================================
message("\n--- Exporting scatter data for report ---")

if (!exists("model_data")) {
  model_data <- readRDS(here("output", "responsiveness_panel.rds"))
}

scatter_data <- model_data %>%
  group_by(country, issue_name, domain) %>%
  summarise(
    epq_share = mean(n_questions / total_questions, na.rm = TRUE),
    mip_share = mean(mip_share, na.rm = TRUE),             # <-- Serve per un grafico
    mip_share_norm = mean(mip_share / 100, na.rm = TRUE),  # <-- Serve per l'altro
    .groups = "drop"
  )

saveRDS(scatter_data, here("output", "resp_scatter_data.rds"))
message("  Saved: output/resp_scatter_data.rds with ALL required columns")

# ============================================================================
# 7. Export Temporal Data for QMD (WITH PERIOD & ALL NAMES)
# ============================================================================
message("\n--- Exporting temporal data for report ---")

if (!exists("model_data")) {
  model_data <- readRDS(here("output", "responsiveness_panel.rds"))
}

temporal_data <- model_data %>%
  mutate(
    time = year + (semester - 1) * 0.5,
    # Creiamo la variabile 'period' che Marcello usa per i colori!
    period = case_when(
      year <= 2014 ~ "7th Term (2009-14)",
      year <= 2019 ~ "8th Term (2014-19)",
      TRUE ~ "9th Term (2019-24)"
    )
  ) %>%
  group_by(time, year, semester, period, country, issue_name, domain) %>%
  summarise(
    # Le versioni "_share" e "_mean" per sicurezza assoluta
    epq_share = mean(n_questions / total_questions, na.rm = TRUE),
    epq_mean  = mean(n_questions / total_questions, na.rm = TRUE),
    mip_share = mean(mip_share, na.rm = TRUE),
    mip_mean  = mean(mip_share, na.rm = TRUE),
    mip_share_norm = mean(mip_share / 100, na.rm = TRUE),
    .groups = "drop"
  )

saveRDS(temporal_data, here("output", "resp_temporal_data.rds"))
message("  Saved: output/resp_temporal_data.rds (Ora con la colonna 'period'!)")

# ============================================================================
# 8. Estrazione REALE delle Random Slopes dal Modello 5
# ============================================================================
library(dplyr)
library(broom.mixed)
library(here)

message("\n--- Estrazione delle vere Random Slopes dal Modello 5 ---")

# 1. Carichiamo modello e dati base
m5 <- readRDS(here("output", "resp_model_5_full.rds"))
panel <- readRDS(here("output", "responsiveness_panel.rds"))

# 2. Estraiamo il Fixed Effect (l'effetto medio europeo)
fixed_slope <- tidy(m5, effects = "fixed") %>%
  filter(term == "mip_eu_matched_z") %>%
  pull(estimate)

# 3. Estraiamo i Random Effects (le deviazioni per ogni singola issue)
random_slopes <- tidy(m5, effects = "ran_vals") %>%
  filter(group == "issue_name", term == "mip_eu_matched_z") %>%
  select(issue_name = level, random_slope = estimate)

# 4. Calcoliamo lo slope totale e uniamo i domini
slopes_df <- random_slopes %>%
  mutate(
    total_slope = random_slope + fixed_slope,
    irr = exp(total_slope)
  ) %>%
  left_join(
    panel %>% distinct(issue_name, domain),
    by = "issue_name"
  ) %>%
  filter(!is.na(domain))

# 5. Salviamo il file definitivo
saveRDS(slopes_df, here("output", "resp_m5_issue_slopes.rds"))
message("  Saved: output/resp_m5_issue_slopes.rds (Dati REALI estratti con successo!)")

# Genera e salva i trend per i grafici
library(emmeans)
eu_trends <- emtrends(m5, ~ domain, var = "mip_eu_mean_z") # o il nome esatto che usi
dev_trends <- emtrends(m5, ~ domain, var = "mip_dev_matched_z")
domain_trends <- list(eu_mean = eu_trends, deviation = dev_trends)

saveRDS(domain_trends, here("output", "domain_trends.rds"))
