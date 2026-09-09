# ==============================================================================
# 07_extract_all_coefficients.R — Unified Coefficient Table Extraction
# Extracts coefficients from ALL fitted models (Frequentist + Bayesian)
# and creates comprehensive comparison tables
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

# Frequentist models (glmmTMB)
zinb_model1 <- readRDS(here("output", "zinb_model1.rds"))
zinb_model2 <- readRDS(here("output", "zinb_model2.rds"))
zinb_model3 <- readRDS(here("output", "zinb_model3.rds"))
zinb_model4 <- readRDS(here("output", "zinb_model4.rds"))

# Bayesian models (brms)
bayesian_model_cmp <- readRDS(here("output", "bayesian_model_cmp.rds"))
bayesian_model_mipex <- readRDS(here("output", "bayesian_model_mipex.rds"))

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
coef_m1 <- tidy_freq_coefs(zinb_model1, "M1: Baseline (Individual Controls)")
coef_m2 <- tidy_freq_coefs(zinb_model2, "M2: + Minority Predictor")
coef_m3 <- tidy_freq_coefs(zinb_model3, "M3: + CMP Interaction")
coef_m4 <- tidy_freq_coefs(zinb_model4, "M4: + MIPEX Interaction")

# Bayesian models
coef_bayes_cmp <- tidy_bayes_coefs(bayesian_model_cmp, "Bayesian: Minority × CMP")
coef_bayes_mipex <- tidy_bayes_coefs(bayesian_model_mipex, "Bayesian: Minority × MIPEX")

# ==============================================================================
# 4. CREATE COMPREHENSIVE TABLE
# ==============================================================================
message("📋 Creating comprehensive comparison table...")

# Bind all frequentist results
freq_results <- bind_rows(coef_m1, coef_m2, coef_m3, coef_m4)

# Add Bayesian results (with compatible columns)
# Note: For Bayesian, we'll use the conf.low/conf.high as placeholders for p.value
bayes_results_combined <- bind_rows(coef_bayes_cmp, coef_bayes_mipex) %>%
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

coef_m1_w <- prepare_wide(coef_m1) %>% rename_with(~paste0(., "_M1"), -term)
coef_m2_w <- prepare_wide(coef_m2) %>% rename_with(~paste0(., "_M2"), -term)
coef_m3_w <- prepare_wide(coef_m3) %>% rename_with(~paste0(., "_M3"), -term)
coef_m4_w <- prepare_wide(coef_m4) %>% rename_with(~paste0(., "_M4"), -term)

wide_comparison <- coef_m1_w %>%
  full_join(coef_m2_w, by = "term") %>%
  full_join(coef_m3_w, by = "term") %>%
  full_join(coef_m4_w, by = "term") %>%
  rename(Predictor = term) %>%
  select(
    Predictor,
    estimate_M1, pval_star_M1, irr_M1 = irr_fmt_M1,
    estimate_M2, pval_star_M2, irr_M2 = irr_fmt_M2,
    estimate_M3, pval_star_M3, irr_M3 = irr_fmt_M3,
    estimate_M4, pval_star_M4, irr_M4 = irr_fmt_M4
  )

write_csv(wide_comparison, here("output", "model_coefficients_wide_comparison.csv"))
message("✅ Wide-format table saved: output/model_coefficients_wide_comparison.csv")

# ==============================================================================
# 6. CREATE BAYESIAN-SPECIFIC TABLE
# ==============================================================================
message("📋 Creating Bayesian-specific table...")

bayes_comparison <- bind_rows(coef_bayes_cmp, coef_bayes_mipex) %>%
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
print(kable(wide_comparison %>% select(Predictor, estimate_M1, estimate_M2, estimate_M3, estimate_M4),
            format = "markdown",
            caption = "Coefficient Estimates Across 4 Frequentist ZINB Models",
            align = c("l", rep("r", 4)),
            digits = 3))

message("\n📊 === BAYESIAN MODELS: INTERACTION EFFECTS ===")
bayes_interactions <- bayes_comparison %>%
  filter(str_detect(Predictor, "×|:"))

print(kable(bayes_interactions,
            format = "markdown",
            caption = "Bayesian Interaction Effects (Credible Intervals)",
            align = c("l", "l", rep("r", 7)),
            digits = 4))

message("\n📊 === KEY INTERACTION EFFECTS SUMMARY ===")
interaction_summary <- all_coefficients %>%
  filter(str_detect(term, "minority.*:|minority.*\\*")) %>%
  select(model, term, estimate, exp_estimate, conf.low, conf.high, p.value) %>%
  mutate(
    interpretation = case_when(
      estimate > 0 & p.value < 0.05 ~ "Positive & Significant",
      estimate < 0 & p.value < 0.05 ~ "Negative & Significant",
      estimate > 0 ~ "Positive (ns)",
      estimate < 0 ~ "Negative (ns)",
      TRUE ~ "Null"
    )
  )

print(kable(interaction_summary,
            format = "markdown",
            caption = "Interaction Effects: Minority Status × Context",
            align = c("l", "l", "r", "r", "r", "r", "r", "l"),
            digits = 4))

# ==============================================================================
# 8. SAVE SUMMARY REPORT
# ==============================================================================
message("\n📝 Generating summary report...")

write_csv(interaction_summary, here("output", "interaction_effects_summary.csv"))

message("\n✅ === EXTRACTION COMPLETE ===")
message("📁 All coefficient tables saved to output/ directory")
message("📊 Review the CSV files for detailed coefficient comparisons")
