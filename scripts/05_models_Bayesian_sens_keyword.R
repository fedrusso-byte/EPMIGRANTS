# ==============================================================================
# # 05_models_Bayesian_sens_keyword.R — APPENDIX B: DEMOTED KEYWORD-DV
# # ROBUSTNESS, two-estimand fits (2026-11-17)
# Reference fits for the demoted keyword-based operationalization, retained
# after the DV-definition promotion of 2026-11-17 (the LLM-refined R2 measure
# became the PRIMARY DV; see scripts/05_models.R § 1b and
# scripts/05_models_Bayesian.R). Input = the pre-promotion keyword panel and
# its two-estimand fits, archived with an md5 manifest in
# output/archive_spec_promotion_2026-11-17/: the panel has 10,955 MEP-year
# rows and 1,244 in-sample DV events. Because formula/data are identical to
# the archived fits, `brm(file = ...)` restores the cached posteriors (no
# refit); on a fresh workspace the same code refits the keyword
# specification from scratch. Outputs: output/bayesian_senskw_model_results.csv
# (M1_keyword / M2_keyword). No primary namespace is touched.
# Manuscript mapping: Appendix B Table B1 quotes M1/M2 on the keyword DV;
# the robustness text cites the minority and LIBE estimates from these fits.
# ==============================================================================
rm(list = ls())
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(broom.mixed)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
archive_dir <- here("output", "archive_spec_promotion_2026-11-17")
stopifnot(
  "keyword archive directory must exist (output/archive_spec_promotion_2026-11-17)" =
    dir.exists(archive_dir)
)

# ==============================================================================
# 0. INPUTS: the archived keyword panel is the fit input
# ==============================================================================
df_model_data_kw <- readRDS(here(archive_dir, "df_model_data.rds"))
stopifnot(
  "archived keyword panel must have 10,955 rows" =
    nrow(df_model_data_kw) == 10955,
  "archived keyword DV must have 1,244 in-sample events" =
    sum(df_model_data_kw$pqs_discrimination) == 1244
)

# Cross-check: the shipped (post-promotion) panel must carry the same rows
# and the same keyword counts under `pqs_discrimination_keyword`.
df_new <- readRDS(here("output", "df_model_data.rds"))
key_of <- function(d) paste(d$mep_id, d$leg_year)
stopifnot(
  "shipped and archived keyword panels must share the panel keys" =
    setequal(key_of(df_new), key_of(df_model_data_kw)),
  "shipped keyword column must match the archived DV" =
    all(df_new$pqs_discrimination_keyword[match(key_of(df_model_data_kw), key_of(df_new))] ==
          df_model_data_kw$pqs_discrimination)
)
rm(df_new, key_of)

message(paste("✅ Keyword (demoted) estimation sample:", nrow(df_model_data_kw),
              "| in-sample DV events:", sum(df_model_data_kw$pqs_discrimination)))
# ==============================================================================
# 1. FITS (same priors and two-estimand structure as the primary fits)
# ==============================================================================
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting/restoring keyword M1_total (no LIBE control)...")
bayesian_model_m1_total_kw <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_kw,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  file = here(archive_dir, "bayesian_model_m1_total")
)

message("   Fitting/restoring keyword M2_direct (+ LIBE committee control)...")
bayesian_model_m2_direct_kw <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family + libe +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_kw,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  file = here(archive_dir, "bayesian_model_m2_direct")
)

# ==============================================================================
# 2. CONVERGENCE GATE (same M4 gate as the primary two-estimand fits)
# ==============================================================================
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
convergence_gate(bayesian_model_m1_total_kw, "M1_keyword")
convergence_gate(bayesian_model_m2_direct_kw, "M2_keyword")

# ==============================================================================
# 3. RESULTS
# ==============================================================================
final_results_senskw <- bind_rows(
  broom.mixed::tidy(bayesian_model_m1_total_kw, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M1_keyword (no LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high),
  broom.mixed::tidy(bayesian_model_m2_direct_kw, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M2_keyword (+LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
)
write_csv(final_results_senskw, here("output", "bayesian_senskw_model_results.csv"))
message("🎉 Keyword-DV robustness results saved to: output/bayesian_senskw_model_results.csv")

interaction_results_senskw <- final_results_senskw %>% filter(grepl(":", term))
print("--- Keyword-DV Robustness: Focal and Interaction Effects (M1/M2) ---")
print(knitr::kable(interaction_results_senskw, format = "markdown",
                   caption = "Appendix B keyword-DV robustness: Minority x MIPEX interaction (M1/M2)"))
