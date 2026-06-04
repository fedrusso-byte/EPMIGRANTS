# 07_responsiveness_descriptives.R — Responsiveness Analysis: Descriptives
# Author: Marcello Carammia
# Purpose: Compute Europeanisation indicators (CV), MIP-EPQ congruence
#          measures, and Link 1 analysis (problems -> MIPs).
#
# Input:  output/responsiveness_panel.rds
# Output: output/europeanisation_cv.rds, output/resp_congruence.rds,
#         output/resp_link1_models.rds, figures

# 0. Setup ====================================================================
library(tidyverse)
library(lme4)
library(here)
library(patchwork)
library(scales)

set.seed(20260327)

min_obs_for_model <- 50L  # Minimum observations for mixed-effects model

dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# Load data
# ============================================================================
message("Loading responsiveness panel...")
resp_panel <- readRDS(here("output", "responsiveness_panel.rds"))

# Subset to issues with MIP data (non-NA mip_share)
matched_issues <- resp_panel %>%
  dplyr::filter(!is.na(mip_share)) %>%
  distinct(issue_name) %>%
  pull(issue_name)

message("  Issues with MIP data: ", paste(sort(matched_issues), collapse = ", "))

# ============================================================================
# 1. Europeanisation CV indicator
# ============================================================================
message("Step 1: Computing Europeanisation CV indicator...")

# Already computed in 06 (mip_cv column), but let's extract a clean table
# and add time-series structure
europeanisation_cv <- resp_panel %>%
  dplyr::filter(!is.na(mip_share)) %>%
  distinct(year, semester, issue_name, domain, mip_eu_mean, mip_eu_sd, mip_cv, mip_n_countries) %>%
  arrange(year, semester, issue_name)

stopifnot(
  "CV contains negative values" = all(europeanisation_cv$mip_cv >= 0, na.rm = TRUE),
  "CV contains Inf" = !any(is.infinite(europeanisation_cv$mip_cv))
)
saveRDS(europeanisation_cv, here("output", "europeanisation_cv.rds"))
message("  Saved: ", nrow(europeanisation_cv), " issue-semester CV observations")

# --- Figure: CV over time by domain ---
# Create time variable for plotting
cv_plot_data <- europeanisation_cv %>%
  mutate(time = year + (semester - 1) * 0.5) %>%
  # Aggregate across issues within domain for cleaner plot
  group_by(time, domain) %>%
  summarise(
    mean_cv = mean(mip_cv, na.rm = TRUE),
    .groups = "drop"
  )

p_cv_time <- ggplot(cv_plot_data, aes(x = time, y = mean_cv, color = domain)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_color_manual(
    values = c("economy" = "#E69F00", "migration" = "#0072B2", "other" = "#999999"),
    labels = c("Economy", "Migration", "Other")
  ) +
  labs(
    title = "Europeanisation of Public Priorities (MIP)",
    subtitle = "Cross-country coefficient of variation of MIP salience\n(lower CV = more Europeanised)",
    x = NULL, y = "Mean CV across issues",
    color = "Domain"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(here("output", "figures", "resp_europeanisation_cv_time.pdf"),
       p_cv_time, width = 10, height = 6, bg = "transparent")
message("  Saved figure: resp_europeanisation_cv_time.pdf")

# --- Figure: CV heatmap by issue x semester ---
cv_heatmap_data <- europeanisation_cv %>%
  mutate(time_label = paste0(year, "-S", semester))

p_cv_heatmap <- ggplot(cv_heatmap_data,
                        aes(x = time_label, y = reorder(issue_name, -mip_cv, FUN = mean), fill = mip_cv)) +
  geom_tile() +
  scale_fill_viridis_c(option = "plasma", direction = -1, name = "CV") +
  labs(
    title = "Europeanisation of Issue Attention (MIP)",
    subtitle = "Darker = more Europeanised (lower cross-country variation)",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6))

ggsave(here("output", "figures", "resp_europeanisation_cv_heatmap.pdf"),
       p_cv_heatmap, width = 14, height = 6, bg = "transparent")
message("  Saved figure: resp_europeanisation_cv_heatmap.pdf")

# ============================================================================
# 2. MIP-EPQ Congruence (Sigelman-Buell)
# ============================================================================
message("Step 2: Computing MIP-EPQ congruence...")

# Sigelman-Buell index: 1 - 0.5 * sum(|p_mip - p_epq|)
# Computed per country-semester, comparing MIP and EPQ issue distributions

# EPQ issue shares per country-semester (normalized to sum to 1)
epq_shares <- resp_panel %>%
  dplyr::filter(issue_name %in% matched_issues) %>%
  group_by(country, year, semester, issue_name) %>%
  summarise(n_q = sum(n_questions), .groups = "drop") %>%
  group_by(country, year, semester) %>%
  mutate(epq_share = n_q / sum(n_q)) %>%
  ungroup() %>%
  dplyr::select(country, year, semester, issue_name, epq_share)

# MIP shares per country-semester (normalized to sum to 1)
# MIP shares can sum to >1 because respondents name multiple issues.
# Normalize within each country-semester to get a proper distribution.
mip_shares <- resp_panel %>%
  dplyr::filter(!is.na(mip_share)) %>%
  distinct(country, year, semester, issue_name, mip_share) %>%
  group_by(country, year, semester) %>%
  mutate(mip_share_norm = mip_share / sum(mip_share)) %>%
  ungroup() %>%
  dplyr::select(country, year, semester, issue_name, mip_share_norm)

# Join and compute congruence
congruence <- epq_shares %>%
  full_join(mip_shares, by = c("country", "year", "semester", "issue_name")) %>%
  mutate(
    epq_share = replace_na(epq_share, 0),
    mip_share_norm = replace_na(mip_share_norm, 0)
  ) %>%
  group_by(country, year, semester) %>%
  summarise(
    sigelman_buell = 1 - 0.5 * sum(abs(mip_share_norm - epq_share)),
    n_issues = n(),
    .groups = "drop"
  )

stopifnot(
  "Sigelman-Buell outside [0,1]" =
    all(congruence$sigelman_buell >= 0 & congruence$sigelman_buell <= 1, na.rm = TRUE)
)
saveRDS(congruence, here("output", "resp_congruence.rds"))
message("  Congruence computed: ", nrow(congruence), " country-semester observations")
message("  Mean Sigelman-Buell: ", round(mean(congruence$sigelman_buell, na.rm = TRUE), 3))

# --- Figure: Congruence over time ---
congruence_time <- congruence %>%
  mutate(time = year + (semester - 1) * 0.5) %>%
  group_by(time) %>%
  summarise(
    mean_sb = mean(sigelman_buell, na.rm = TRUE),
    sd_sb = if_else(n() > 1, sd(sigelman_buell, na.rm = TRUE), 0),
    .groups = "drop"
  )

p_congruence <- ggplot(congruence_time, aes(x = time, y = mean_sb)) +
  geom_ribbon(aes(ymin = mean_sb - sd_sb, ymax = mean_sb + sd_sb), alpha = 0.2) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "MIP-EPQ Congruence Over Time",
    subtitle = "Sigelman-Buell index (1 = perfect agreement, 0 = no overlap)\nMean ± 1 SD across countries",
    x = NULL, y = "Sigelman-Buell Index"
  ) +
  theme_minimal(base_size = 12)

ggsave(here("output", "figures", "resp_congruence_time.pdf"),
       p_congruence, width = 10, height = 6, bg = "transparent")
message("  Saved figure: resp_congruence_time.pdf")

# ============================================================================
# 3. Link 1 Analysis: Problems -> MIPs (Updated with Misery Index)
# ============================================================================
message("Step 3: Link 1 analysis (problems -> MIPs)...")

# Verifichiamo se il Misery Index è presente nel panel
if ("misery_index" %in% names(resp_panel)) {

  # Aggregazione a livello paese-semestre-issue per il Link 1
  link1_data <- resp_panel %>%
    dplyr::filter(!is.na(mip_share), !is.na(misery_index)) %>%
    distinct(country, year, semester, issue_name, domain,
             mip_share, mip_eu_mean, mip_deviation,
             misery_index, misery_eu_mean, misery_deviation,
             asylum_per_1000, asylum_eu_mean, asylum_deviation)

  if (nrow(link1_data) > 0) {

    # --- MODEL ECONOMY: Misery Index -> MIP Economy ---
    # Testiamo se la salienza dell'economia nel MIP risponde al Misery Index
    link1_econ <- link1_data %>%
      dplyr::filter(domain == "economy") %>%
      dplyr::filter(!is.na(misery_eu_mean), !is.na(misery_deviation))

    # --- MODEL MIGRATION: Asylum -> MIP Migration ---
    link1_migr <- link1_data %>%
      dplyr::filter(domain == "migration") %>%
      dplyr::filter(!is.na(asylum_eu_mean), !is.na(asylum_deviation))

    # Stima dei modelli Mixed-Effects
    if (nrow(link1_econ) > min_obs_for_model) {
      # Usiamo il Misery Index (decomposto in media UE e deviazione nazionale)
      # per spiegare la salienza dell'economia
      m_link1_econ <- lmer(
        mip_share ~ misery_eu_mean + misery_deviation +
          (1 | country) + (1 | issue_name),
        data = link1_econ
      )
      message("  Link 1 economy (Misery Index) model fitted: ", nrow(link1_econ), " obs")
    } else {
      m_link1_econ <- NULL
      message("  Link 1 economy: insufficient data (", nrow(link1_econ), " obs)")
    }

    if (nrow(link1_migr) > min_obs_for_model) {
      m_link1_migr <- lmer(
        mip_share ~ asylum_eu_mean + asylum_deviation +
          (1 | country),
        data = link1_migr
      )
      message("  Link 1 migration model fitted: ", nrow(link1_migr), " obs")
    } else {
      m_link1_migr <- NULL
      message("  Link 1 migration: insufficient data (", nrow(link1_migr), " obs)")
    }

    # Salvataggio risultati
    link1_results <- list(
      economy = m_link1_econ,
      migration = m_link1_migr,
      data_econ = link1_econ,
      data_migr = link1_migr
    )
    saveRDS(link1_results, here("output", "resp_link1_models.rds"))
    message("  Link 1 models (with Misery Index) saved")

  } else {
    message("  Skipping Link 1 models: No rows in link1_data after filtering")
  }
} else {
  message("  CRITICAL: misery_index not found in panel. Check script 06.")
}

# ============================================================================
# 4. Export Time Series for Circuit Plots (used in QMD)
# ============================================================================
message("Step 4: Exporting time-series data for report...")

resp_timeseries <- resp_panel %>%
  # Creiamo prima il totale per riga se non esiste,
  # o usiamo una logica basata sul raggruppamento
  group_by(year, semester, domain) %>%
  summarise(
    # Calcoliamo la media della ratio n_questions / totale del semestre
    # Se n_questions_total non esiste, sommiamo n_questions nel gruppo
    q_share = sum(n_questions, na.rm = TRUE),
    mip_share = mean(mip_share / 100, na.rm = TRUE),
    misery = mean(misery_index, na.rm = TRUE),
    asylum = mean(asylum_per_1000, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  # Ora normalizziamo q_share rispetto al totale di tutte le domande nel semestre
  group_by(year, semester) %>%
  mutate(
    q_share = q_share / sum(q_share, na.rm = TRUE),
    time = year + (semester - 1) * 0.5
  ) %>%
  ungroup()

saveRDS(resp_timeseries, here("output", "resp_timeseries_data.rds"))
message("  Saved: output/resp_timeseries_data.rds")
# ============================================================================
# Summary
# ============================================================================
message("\n=== 07_responsiveness_descriptives.R complete ===")
message("Outputs:")
message("  output/europeanisation_cv.rds")
message("  output/resp_congruence.rds")
if (exists("link1_results")) message("  output/resp_link1_models.rds")
message("  output/figures/resp_europeanisation_cv_time.pdf")
message("  output/figures/resp_europeanisation_cv_heatmap.pdf")
message("  output/figures/resp_congruence_time.pdf")
