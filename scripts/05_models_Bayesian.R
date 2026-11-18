# ==============================================================================
# # 05_models_Bayesian.R — Bayesian ZINB Models: Minority x MIPEX Interaction
# PRIMARY SPECIFICATION (DV-definition promotion, 2026-11-17):
# - DV = LLM-refined (R2) operationalization, built in 05_models.R (overlay
#   § 1b): refined retained-DV 529 (524 refined-rubric kept-DV INs + 5 FR
#   force-keeps) ∪ FR verified-INs 255 = 784 question-level DV events
#   in-window (739 in-sample). Derivation record:
#   scripts/05_models_Bayesian_sens_llm_R2.R.
# - The former keyword-based counts ship as `pqs_discrimination_keyword` in
#   output/df_model_data.rds and define the demoted appendix robustness check
#   (05_models_Bayesian_sens_keyword.R; Appendix B of the manuscript).
#   Pre-promotion keyword-DV artifacts (+md5):
#   output/archive_spec_promotion_2026-11-17/.
# TWO-ESTIMAND STRUCTURE (DV-201 validation disposition, 2026-11-13):
#   M1_total  = model WITHOUT the LIBE committee control — total effect of
#               minority status on DV claim-making, conditional on MIPEX context;
#   M2_direct = model WITH the LIBE committee control — direct effect net of
#               committee assignment.
# Same priors, chains, offsets and random effects as the pre-promotion fit
# (brms zero-inflated negative binomial). A convergence gate is applied to
# BOTH fits: max Rhat <= 1.01, min ESS ratio >= 0.10, zero divergences.
# AS OF THE PROMOTION both fits run at iter = 4000 / warmup = 1500 (the
# keyword-era M1 setting of 2000/1000 is archived with the old artifacts).
# The old caches MUST be removed before the promotion rerun because
# `brm(file = ...)` restores by path otherwise (see § 2b note).
# Uses the 'brms' package; the approach is robust to small numbers of groups
# (countries) and allows the inclusion of time-invariant country
# characteristics (MIPEX) in interactions without the collinearity issues
# found in Fixed Effects models.
#
# MIPEX-only specification (decision 2026-11-12):
# - Sample = shared MIPEX-only estimation sample built in 05_models.R
#   (output/df_model_data.rds): panel structure is UNCHANGED by the DV
#   promotion (total_questions asserted identical); all EU countries covered
#   by MIPEX, i.e. 27 of 28 EU Member States (Malta is not assessed by
#   MIPEX); CMP variables and the hardcoded claim-making feature
#   (discrimination_mean) are not used for sample construction, so HU, SK,
#   LU and RO are retained.
# - Random effects: (1 | mep_id) + (1 | country).
# - Sensitivity runs kept around the demoted keyword measure:
#   05_models_Bayesian_sens.R (keyword extension) and
#   05_models_Bayesian_sens_llm.R (R1: keyword + 255 verified-INs).
# - The CMP-interaction Bayesian model was discarded earlier (2026-11-12) and
#   the pre-disposition single-model Bayesian fit (bayesian_model_mipex.rds)
#   is archived in output/archive_dv201_2026-11-13/.
# ==============================================================================

# free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("tidybayes", quietly = TRUE)) { install.packages("tidybayes") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(tidybayes)
library(broom.mixed)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# Load data ####
# The estimation sample is defined ONCE in 05_models.R (MIPEX-only filtering)
# and shared with the Bayesian specification to avoid sample drift between
# the frequentist and Bayesian pipelines.
message("   Loading shared MIPEX-only estimation sample (output/df_model_data.rds)...")
df_model_data <- readRDS(here("output", "df_model_data.rds"))

stopifnot(
  "df_model_data is empty" = nrow(df_model_data) > 0,
  "Required columns missing" = all(c(
    "pqs_discrimination", "pqs_discrimination_keyword", "total_questions", "gender", "mep_id", "country",
    "party_family", "libe", "minority", "misery_index", "mipex_center"
  ) %in% names(df_model_data))
)

message(paste("✅ N finale for the Bayesian model:", nrow(df_model_data)))
message(paste("   Countries in sample (", length(unique(df_model_data$country)), "):",
              paste(sort(unique(df_model_data$country)), collapse = ", ")))

# ==============================================================================
# 1. PRIOR SPECIFICATIONS
# ==============================================================================
# We use weakly informative priors. 
# Normal(0, 2.5) is standard for coefficients in GLMMs as it covers 
# a wide range of plausible effects without being overly restrictive.
# Random-effect SDs (mep_id, country) use the brms default weakly-informative
# prior, as in the previous specification.
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"), # Robust prior for coefficients
  set_prior("student_t(3, 0, 2.5)", class = "zi") # Robust prior for zero-inflation part
)

# ==============================================================================
# 2. MODELS: M1_total (no LIBE control) and M2_direct (with LIBE control)
# ==============================================================================
# Main effects for both 'minority' and 'mipex_center' are included because
# interactions must be interpreted in the context of their main effects.
# Random intercepts for MEPs (repeated observations) and for countries,
# mirroring the manuscript description and the frequentist ZINB specification.
# LIBE is the only difference between the two fits, isolating the direct vs.
# total effect estimands.

message("   Fitting Bayesian M1_total (Minority x MIPEX, no LIBE control)...")
bayesian_model_m1_total <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  # iter 4000 / warmup 1500 (2026-11-17 DV promotion): both fits now use the
  # longer sampling setting that the keyword-era M2_direct already required
  # (NB `shape` slow-mixing geometry; see § 2b note). The archived
  # keyword-era M1 fit (iter 2000 / warmup 1000) lives in
  # output/archive_spec_promotion_2026-11-17/.
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m1_total")
)

message("   Fitting Bayesian M2_direct (+ LIBE committee control)...")
# NOTE (2026-11-13): the first M2_DIRECT fit at the nominal settings
# (chains = 4, iter = 2000, warmup = 1000) FAILED the M4 ESS gate:
# min neff ratio = 0.066, driven by the NB `shape` (dispersion) parameter —
# the classic slow-mixing ZINB geometry — while all coefficients of interest
# were well mixed (b_Intercept 0.38, zi 0.39; max Rhat 1.0066; 0 divergences).
# Deviation documented in the readout memo: M2_direct is (re)fitted at
# iter = 4000 / warmup = 1500 (~x2.5 sampling draws => shape ESS ratio ~0.17).
# IMPORTANT: `brm(file = ...)` caches by path — delete
# output/bayesian_model_m2_direct.rds BEFORE re-running with a changed spec,
# otherwise the cached (gate-failed) fit loads silently.
# (M1_total passed the gate at the archived 2000/1000 keyword-era settings;
# since the 2026-11-17 DV promotion BOTH fits run at 4000/1500, and the
# pre-promotion keyword-DV caches live in the archive directory.)
bayesian_model_m2_direct <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family + libe +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m2_direct")
)

# ==============================================================================
# 2b. CONVERGENCE GATE (M4 gate, DV-201 validation disposition 2026-11-13)
# ==============================================================================
# Applied to BOTH fits: max Rhat <= 1.01 across all parameters, min ESS ratio
# >= 0.10, and zero divergent transitions. The pipeline halts on failure.
convergence_gate <- function(fit, label) {
  rhat_max <- max(rhat(fit), na.rm = TRUE)
  ess_min  <- min(neff_ratio(fit), na.rm = TRUE)
  n_div    <- nuts_params(fit) %>%
    as.data.frame() %>%
    filter(str_detect(Parameter, "divergent__")) %>%
    pull(Value) %>%
    sum()
  message(label, " gate: max Rhat = ", round(rhat_max, 4),
          " | min ESS ratio = ", round(ess_min, 3),
          " | divergences = ", n_div)
  stopifnot(
    "Rhat must be <= 1.01 on all parameters" = rhat_max <= 1.01,
    "ESS ratio must be >= 0.10 on all parameters" = ess_min >= 0.10,
    "zero divergent transitions required" = n_div == 0
  )
  invisible(TRUE)
}
convergence_gate(bayesian_model_m1_total, "M1_total")
convergence_gate(bayesian_model_m2_direct, "M2_direct")

# ==============================================================================
# 3. RESULTS EXTRACTION (both estimands)
# ==============================================================================

extract_bayesian_results <- function(model, model_name) {
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = model_name)
}

final_results <- bind_rows(
  extract_bayesian_results(bayesian_model_m1_total, "M1_total (no LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high),
  extract_bayesian_results(bayesian_model_m2_direct, "M2_direct (+LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
)

write_csv(final_results, here("output", "bayesian_model_results.csv"))
message("🎉 Bayesian results saved to: output/bayesian_model_results.csv")

# Display the interaction effects specifically
interaction_results <- final_results %>%
  filter(grepl(":", term))

print("--- Bayesian Interaction Effects (M1_total / M2_direct) ---")
print(interaction_results)

knitr::kable(interaction_results, format = "markdown",
             caption = "Credible Intervals for the Minority x MIPEX Interaction (M1_total and M2_direct)")