# ==============================================================================
# 07_extract_all_coefficients.R — Unified Coefficient Table Extraction
# Extracts coefficients from the frequentist mirror (glmmTMB twins of the two
# Bayesian estimands, M1_total/M2_direct) and the Bayesian primary fits, and
# creates comprehensive comparison tables with engine-aware uncertainty.
# (Legacy 4-step ladder tables retired 2026-11-18 — audit item 2.)
# ==============================================================================

# Free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("glmmTMB", quietly = TRUE)) { install.packages("glmmTMB") }
if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }
if (!requireNamespace("kableExtra", quietly = TRUE)) { install.packages("kableExtra") }

library(tidyverse)
library(glmmTMB)
library(brms)
library(broom.mixed)
library(here)
library(knitr)
library(kableExtra)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. LOAD ALL MODELS
# ==============================================================================
message("📥 Loading all fitted models...")

# Frequentist mirror models (glmmTMB twins of the Bayesian estimands;
# the legacy zinb_model1-4 ladder is archived in
# output/archive_freq_mirror_2026-11-18/)
zinb_model_m1_total <- readRDS(here("output", "zinb_model_m1_total.rds"))
zinb_model_m2_direct <- readRDS(here("output", "zinb_model_m2_direct.rds"))

# Bayesian models (two-estimand structure, DV-201 validation 2026-11-13;
# the pre-disposition single-model fit is archived in
# output/archive_dv201_2026-11-13/)
bayesian_model_m1_total <- readRDS(here("output", "bayesian_model_m1_total.rds"))
bayesian_model_m2_direct <- readRDS(here("output", "bayesian_model_m2_direct.rds"))

message("✅ All models loaded successfully")

# ==============================================================================
# 2. EXTRACTION FUNCTIONS
# ==============================================================================

# Frequentist model extraction (glmmTMB)
tidy_freq_coefs <- function(model, model_label) {
  broom.mixed::tidy(model, component = "cond") %>%
    filter(effect == "fixed") %>%
    mutate(
      model = model_label,
      estimate = round(estimate, 4),
      std.error = round(std.error, 4),
      statistic = round(statistic, 3),
      p.value = round(p.value, 4),
      exp_estimate = round(exp(estimate), 4),
      conf.low = exp(estimate - 1.96 * std.error),
      conf.high = exp(estimate + 1.96 * std.error)
    ) %>%
    select(model, term, estimate, std.error, exp_estimate, conf.low, conf.high, p.value)
}

# Bayesian model extraction (brms)
tidy_bayes_coefs <- function(model, model_label) {
  broom.mixed::tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(
      model = model_label,
      estimate = round(estimate, 4),
      std.error = round(std.error, 4),
      conf.low = round(conf.low, 4),
      conf.high = round(conf.high, 4),
      exp_estimate = round(exp(estimate), 4),
      exp_conf.low = round(exp(conf.low), 4),
      exp_conf.high = round(exp(conf.high), 4)
    ) %>%
    select(model, term, estimate, std.error, exp_estimate, conf.low, conf.high, 
           exp_conf.low, exp_conf.high)
}

# ==============================================================================
# 3. EXTRACT COEFFICIENTS FROM ALL MODELS
# ==============================================================================
message("📊 Extracting coefficients from all models...")

# Frequentist models
coef_m1_total <- tidy_freq_coefs(zinb_model_m1_total,
                                 "M1_total: minority x MIPEX, no LIBE (glmmTMB mirror)")
coef_m2_direct <- tidy_freq_coefs(zinb_model_m2_direct,
                                  "M2_direct: minority x MIPEX, + LIBE (glmmTMB mirror)")

# Bayesian models (two-estimand structure, DV-201 validation 2026-11-13)
coef_bayes_m1 <- tidy_bayes_coefs(bayesian_model_m1_total, "M1_total: Minority × MIPEX (no LIBE)")
coef_bayes_m2 <- tidy_bayes_coefs(bayesian_model_m2_direct, "M2_direct: Minority × MIPEX (+LIBE)")
coef_bayes <- bind_rows(coef_bayes_m1, coef_bayes_m2)

# ==============================================================================
# 4. CREATE COMPREHENSIVE TABLE
# ==============================================================================
message("📋 Creating comprehensive comparison table...")

# Bind all frequentist results
freq_results <- bind_rows(coef_m1_total, coef_m2_direct)

# Add Bayesian results (with compatible columns)
bayes_results_combined <- coef_bayes %>%
  mutate(
    p.value = NA_real_  # Bayesian models don't have p-values
  ) %>%
  select(model, term, estimate, std.error, exp_estimate, conf.low, conf.high, p.value)

# Full comprehensive table
all_coefficients <- bind_rows(freq_results, bayes_results_combined)

# Save comprehensive table
write_csv(all_coefficients, here("output", "all_model_coefficients_comprehensive.csv"))
message("✅ Comprehensive table saved: output/all_model_coefficients_comprehensive.csv")

# ==============================================================================
# 5. CREATE WIDE-FORMAT COMPARISON TABLE (FREQUENTIST ONLY)
# ==============================================================================
message("📋 Creating wide-format comparison table...")

# Function to prepare for wide format
prepare_wide <- function(coef_df) {
  coef_df %>%
    mutate(
      estimate_fmt = sprintf("%.3f", estimate),
      pval_fmt = sprintf("%.3f", p.value),
      pval_star = case_when(
        p.value < 0.001 ~ paste0(pval_fmt, " ***"),
        p.value < 0.01  ~ paste0(pval_fmt, " **"),
        p.value < 0.05  ~ paste0(pval_fmt, " *"),
        p.value < 0.1   ~ paste0(pval_fmt, " ."),
        TRUE            ~ pval_fmt
      ),
      irr_fmt = sprintf("%.2f", exp_estimate)
    )
}

coef_m1_total_w <- prepare_wide(coef_m1_total) %>%
  rename_with(~paste0(., "_M1_total"), -term)
coef_m2_direct_w <- prepare_wide(coef_m2_direct) %>%
  rename_with(~paste0(., "_M2_direct"), -term)

wide_comparison <- coef_m1_total_w %>%
  full_join(coef_m2_direct_w, by = "term") %>%
  rename(Predictor = term) %>%
  select(
    Predictor,
    estimate_M1_total, pval_star_M1_total, irr_M1_total = irr_fmt_M1_total,
    estimate_M2_direct, pval_star_M2_direct, irr_M2_direct = irr_fmt_M2_direct
  )

write_csv(wide_comparison, here("output", "model_coefficients_wide_comparison.csv"))
message("✅ Wide-format table saved: output/model_coefficients_wide_comparison.csv")

# ==============================================================================
# 6. CREATE BAYESIAN-SPECIFIC TABLE
# ==============================================================================
message("📋 Creating Bayesian-specific table...")

bayes_comparison <- coef_bayes %>%
  mutate(
    term_clean = str_replace_all(term, ":", " × "),
    term_clean = str_replace_all(term_clean, "_center", "")
  ) %>%
  select(
    model, term_clean, estimate, std.error, 
    exp_estimate, exp_conf.low, exp_conf.high,
    conf.low, conf.high
  ) %>%
  rename(
    Predictor = term_clean,
    Model = model,
    `Estimate` = estimate,
    `Std.Error` = std.error,
    `Exp(Est)` = exp_estimate,
    `Exp(CI Low)` = exp_conf.low,
    `Exp(CI High)` = exp_conf.high,
    `CI Low` = conf.low,
    `CI High` = conf.high
  )

write_csv(bayes_comparison, here("output", "bayesian_coefficients_comparison.csv"))
message("✅ Bayesian table saved: output/bayesian_coefficients_comparison.csv")

# ==============================================================================
# 7. DISPLAY TABLES
# ==============================================================================
message("\n📊 === FREQUENTIST MODELS: WIDE FORMAT ===")
print(kable(wide_comparison %>% select(Predictor, estimate_M1_total, estimate_M2_direct),
            format = "markdown",
            caption = "Coefficient Estimates Across the 2 Frequentist Mirror Models",
            align = c("l", "r", "r"),
            digits = 3))

message("\n📊 === BAYESIAN MODELS: INTERACTION EFFECTS ===")
bayes_interactions <- bayes_comparison %>%
  filter(str_detect(Predictor, "×|:"))

print(kable(bayes_interactions,
            format = "markdown",
            caption = "Bayesian Interaction Effects (Credible Intervals)",
            align = c("l", "l", rep("r", 7)),
            digits = 4))

message("\n📊 === KEY INTERACTION EFFECTS SUMMARY (ENGINE-AWARE) ===")
# Audit fix (2026-11-18): the former interpretation labels relied on
# 'p.value', which is NA for every Bayesian row (brms reports no p-values),
# silently stamping all Bayesian interactions as 'Null'. Uncertainty is now
# assessed per engine: Wald p-values for glmmTMB, 95% CrI coverage of 0 for
# brms (conf.low/conf.high are on the log scale for both engines).
interaction_summary <- all_coefficients %>%
  filter(str_detect(term, "minority.*:|minority.*\\*")) %>%
  select(model, term, estimate, exp_estimate, conf.low, conf.high, p.value) %>%
  mutate(
    engine = if_else(str_detect(model, "glmmTMB"),
                     "GLM (glmmTMB)", "Bayes (brms)"),
    interpretation = case_when(
      engine == "GLM (glmmTMB)" & p.value < 0.05 & estimate > 0 ~
        "Positive & Significant (Wald p < .05)",
      engine == "GLM (glmmTMB)" & p.value < 0.05 & estimate < 0 ~
        "Negative & Significant (Wald p < .05)",
      engine == "GLM (glmmTMB)" ~
        "Not Significant (Wald p >= .05)",
      engine == "Bayes (brms)" & estimate > 0 & conf.low > 0 ~
        "Positive (95% CrI excludes 0)",
      engine == "Bayes (brms)" & estimate < 0 & conf.high < 0 ~
        "Negative (95% CrI excludes 0)",
      TRUE ~ "Not credible (95% CrI includes 0)"
    )
  )

print(kable(interaction_summary,
            format = "markdown",
            caption = "Interaction Effects: Minority Status × Context (engine-aware)",
            align = c("l", "l", "r", "r", "r", "r", "r", "l", "l"),
            digits = 4))

# ==============================================================================
# 8. SAVE SUMMARY REPORT
# ==============================================================================
message("\n📝 Generating summary report...")

write_csv(interaction_summary, here("output", "interaction_effects_summary.csv"))

message("\n✅ === EXTRACTION COMPLETE ===")
message("📁 All coefficient tables saved to output/ directory")
message("📊 Review the CSV files for detailed coefficient comparisons")
