# ==============================================================================
# # 05_models_Bayesian_LIBE.R — ALTERNATIVE Bayesian ZINB Model:
# Minority x LIBE Interaction (all-country sample, no MIPEX)
# ------------------------------------------------------------------------------
# PURPOSE (decision with FR, 2026-11-12 — SEPARATE model, does NOT replace
# the primary MIPEX-only fit in 05_models_Bayesian.R):
#   - Estimate an alternative specification WITHOUT any MIPEX variable, with a
#     minority x libe interaction, on a sample that includes ALL EU Member
#     States present in the data (28) instead of only MIPEX-covered countries.
#   - Sample rule (confirmed by FR):
#       * structural exclusion based on MIPEX coverage: REMOVED. Malta (the
#         only 100%-MIPEX-NA country) is now retained;
#       * the ONLY programmatic exclusion is the United Kingdom in the 9th EP
#         term (2019-2024, the Brexit-truncated term). VERIFIED in the source
#         data (feasibility check, 2026-11-12): the upstream dataset contains
#         NO UK rows in the 9th term (UK: 367 rows in the 7th, 374 in the 8th,
#         0 in the 9th), so the safeguard filter below is a no-op today and
#         only enforces the approved rule explicitly;
#       * remaining row loss is ordinary listwise deletion on model variables.
#   - Feasibility verified BEFORE fitting (2026-11-12, read-only diagnostics):
#     focal cell minority=1 & libe=1 has 56 MEP-years / 11 MEPs (23 events,
#     25% of rows positive); a glmmTMB ZINB smoke test on this exact sample
#     converged with a clean Hessian (minority:libe = 1.004, SE 0.489).
#   - All outputs use DISTINCT names (df_model_data_libe.rds,
#     bayesian_model_libe, bayesian_libe_*.csv): nothing in output/ is
#     overwritten. NOT wired into run_pipeline.R — run standalone under the
#     project renv.
#   - brm(file = ...) caches by path: if the model spec changes, delete
#     output/bayesian_model_libe.rds first or the stale fit loads silently.
# ==============================================================================

# free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("posterior", quietly = TRUE)) { install.packages("posterior") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(broom.mixed)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. DATA AND ESTIMATION SAMPLE (all countries, MIPEX-free, UK-9th excluded)
# ==============================================================================
# Built exactly like the primary sample in 05_models.R (same joins, same term
# filter, same variable list for drop_na) with two deliberate deviations:
#   (a) no MIPEX coverage filter and no mipex_center (MIPEX is not in this
#       specification at all);
#   (b) explicit UK x 9th-term exclusion (see header).
message("   Loading MEP-year dataset and country problem indicators...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c(
    "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
    "party_family", "libe", "minority", "misery_index", "legislative_term"
  ) %in% names(df_merged_3))
)

# NOTE: no mipex_center here — the alternative specification drops MIPEX
# entirely, so the drop_na list must NOT require MIPEX coverage.
model_variables <- c(
  "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
  "party_family", "libe", "minority", "misery_index"
)

df_libe_model <- df_merged_3 %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  # ONLY programmatic exclusion: United Kingdom in the 9th EP term (the
  # Brexit-truncated term). A no-op on today's data, enforced per the
  # FR-approved alternative-sample rule of 2026-11-12.
  filter(!(country == "UK" & legislative_term == "9th")) %>%
  drop_na(all_of(model_variables))

# ------------------------------------------------------------------------------
# Validation: the sample must match the values verified in the 2026-11-12
# feasibility check. Exact assertions protect against silent drift of the
# upstream CSVs (same convention as explorations/libe_robustness.R).
# ------------------------------------------------------------------------------
is_libe_cell <- df_libe_model$minority == 1 & df_libe_model$libe == 1
stopifnot(
  "Sample must not be empty" = nrow(df_libe_model) > 0,
  "N must equal the feasibility-check value (11,042 MEP-years)" =
    nrow(df_libe_model) == 11042,
  "Sample must cover all 28 countries present in the source data" =
    dplyr::n_distinct(df_libe_model$country) == 28,
  "UK rows in the 9th term must be absent (safeguard rule)" =
    all(!(df_libe_model$country == "UK" & df_libe_model$legislative_term == "9th")),
  "Focal cell must match feasibility check (56 MEP-years, 11 MEPs)" =
    sum(is_libe_cell) == 56 &&
      dplyr::n_distinct(df_libe_model$mep_id[is_libe_cell]) == 11
)

# Sample report (context for the results memo)
message("")
message("== ALTERNATIVE estimation sample (all countries, MIPEX-free, UK-9th excluded) ==")
message("N MEP-years      : ", nrow(df_libe_model))
message("Countries        : ", dplyr::n_distinct(df_libe_model$country))
message("Unique MEPs      : ", dplyr::n_distinct(df_libe_model$mep_id))
message("Minority MEPs    : ", dplyr::n_distinct(df_libe_model$mep_id[df_libe_model$minority == 1]))
message("Minority MEP-yrs : ", sum(df_libe_model$minority == 1))
message("DV sum           : ", sum(df_libe_model$pqs_discrimination))
message("Rows by term     : ",
        paste(names(table(df_libe_model$legislative_term)),
              table(df_libe_model$legislative_term), sep = " = ", collapse = "; "))
cell_sizes <- df_libe_model %>%
  dplyr::count(minority, libe, name = "mep_years") %>%
  dplyr::left_join(
    df_libe_model %>%
      dplyr::distinct(mep_id, minority, libe) %>%
      dplyr::count(minority, libe, name = "meps"),
    by = c("minority", "libe")
  ) %>%
  dplyr::left_join(
    df_libe_model %>%
      dplyr::group_by(minority, libe) %>%
      dplyr::summarise(events = sum(pqs_discrimination), .groups = "drop"),
    by = c("minority", "libe")
  ) %>%
  dplyr::mutate(pct_rows_positive = round(events / mep_years, 3))
message("Minority x LIBE cell structure (MEP-years / MEPs / events / share>0):")
print(as.data.frame(cell_sizes))

saveRDS(df_libe_model, here("output", "df_model_data_libe.rds"))
message("Sample saved to: output/df_model_data_libe.rds")

# ==============================================================================
# 2. PRIORS AND MODEL: minority x libe INTERACTION ON THE ALTERNATIVE SAMPLE
# ==============================================================================
# Priors and sampling settings are IDENTICAL to 05_models_Bayesian.R so the
# alternative fit is directly comparable to the primary MIPEX-only fit:
#   - student_t(3, 0, 2.5) on all population-level coefficients (class "b")
#     and on the zero-inflation intercept (class "zi");
#   - brms default weakly-informative prior on the random-effect SDs;
#   - 4 chains x 2,000 iterations (1,000 warmup), adapt_delta = 0.95.
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting ALTERNATIVE Bayesian ZINB (Minority x LIBE, no MIPEX)...")
t_fit <- Sys.time()
# The interaction must be interpreted against its main effects, which are
# therefore both included; RE structure mirrors the primary model
# ((1 | mep_id) + (1 | country)) to keep runs comparable.
bayesian_model_libe <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family +
    minority * libe +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  data = df_libe_model,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_libe")
)
message("Done: minority x libe fit (",
        round(as.numeric(difftime(Sys.time(), t_fit, units = "mins")), 1), " min)")
print(summary(bayesian_model_libe))

# ==============================================================================
# 3. CONVERGENCE DIAGNOSTICS
# ==============================================================================
# Population-level parameters + shape; divergences from the NUTS sampler.
# Same function as explorations/libe_robustness.R.
diagnostics_summary <- function(model, model_name) {
  s <- posterior::summarise_draws(posterior::as_draws_df(model)) %>%
    dplyr::filter(grepl("^b_|^zi_|^shape", variable))
  np <- tryCatch(nuts_params(model), error = function(e) NULL)
  divergent <- if (is.null(np)) {
    NA_integer_
  } else {
    par_col <- intersect(c("Parameter", "parameter"), names(np))[1]
    val_col <- intersect(c("Value", "value"), names(np))[1]
    sum(np[[par_col]] == "divergent__" & np[[val_col]] == 1)
  }
  tibble(
    model = model_name,
    max_rhat = max(s$rhat, na.rm = TRUE),
    min_ess_bulk = min(s$ess_bulk, na.rm = TRUE),
    min_ess_tail = min(s$ess_tail, na.rm = TRUE),
    divergent_transitions = divergent
  )
}

diag_table <- diagnostics_summary(bayesian_model_libe, "LIBE interaction (no MIPEX)")
message("Convergence diagnostics (population-level parameters):")
print(as.data.frame(diag_table))
write_csv(diag_table, here("output", "bayesian_libe_diagnostics.csv"))

# ==============================================================================
# 4. RESULTS EXTRACTION
# ==============================================================================
model_name <- "LIBE Interaction"

# Fixed effects: same tidy() call as the primary script for comparability.
fixed_results <- tidy(bayesian_model_libe, conf.int = TRUE, conf.level = 0.95) %>%
  mutate(model = model_name)

# Random-effect SDs: extract via posterior_summary() with a regex so each SD
# keeps its group in the variable name. broom's tidy() collapses both SD rows
# to sd__(Intercept), which is ambiguous with two RE groups (MEP vs country) —
# see the MIPEX-only-refit session notes (carry-over caveat).
sds <- posterior_summary(bayesian_model_libe, variable = "sd_|shape", regex = TRUE)
sd_results <- tibble(
  term = rownames(sds),
  estimate = sds[, "Estimate"],
  std.error = sds[, "Est.Error"],
  conf.low = sds[, "Q2.5"],
  conf.high = sds[, "Q97.5"],
  model = model_name
)

final_results <- bind_rows(fixed_results, sd_results) %>%
  dplyr::select(model, term, estimate, std.error, conf.low, conf.high)

write_csv(final_results, here("output", "bayesian_libe_model_results.csv"))
message("Results saved to: output/bayesian_libe_model_results.csv")

interaction_results <- final_results %>% filter(grepl(":", term))
print("--- Bayesian Interaction Effects (minority x libe) ---")
print(interaction_results)
knitr::kable(interaction_results, format = "markdown",
             caption = "Credible Intervals for the Minority x LIBE Interaction")

# Focal parameters, draws-based: posterior median [95% CrI], P(draw > 0)
focal_draws <- posterior::as_draws_df(bayesian_model_libe)
focal_pars <- tribble(
  ~parameter,             ~label,
  "b_minority",           "minority (main effect, off LIBE reference)",
  "b_libe",               "libe (main effect, non-minority MEPs)",
  "b_minority:libe",      "minority x libe (extra LIBE boost for minority MEPs)"
)
focal_table <- purrr::pmap_dfr(focal_pars, function(parameter, label) {
  d <- focal_draws[[parameter]]
  if (is.null(d) || length(d) == 0) {
    return(tibble(parameter = parameter, label = label, model = model_name,
                  estimate = NA_real_, conf.low = NA_real_,
                  conf.high = NA_real_, p_positive = NA_real_))
  }
  tibble(
    parameter = parameter,
    label = label,
    model = model_name,
    estimate = median(d),
    conf.low = quantile(d, 0.025, names = FALSE),
    conf.high = quantile(d, 0.975, names = FALSE),
    p_positive = mean(d > 0)
  )
})
write_csv(focal_table, here("output", "bayesian_libe_focal_coefficients.csv"))
message("Focal parameters saved to: output/bayesian_libe_focal_coefficients.csv")
message("")
message("=== FOCAL COEFFICIENTS (posterior median [95% CrI], P(draw>0)) ===")
focal_print <- focal_table %>%
  mutate(cell = sprintf("%.3f [%.3f, %.3f]  P(+)=%.3f",
                        estimate, conf.low, conf.high, p_positive)) %>%
  dplyr::select(label, cell)
print(knitr::kable(focal_print, format = "markdown"))

# ==============================================================================
# 5. MARGINAL IRR CONTRASTS (expected-count ratios)
# ==============================================================================
# Grid conventions mirror 06_model_comparison_Bayesian.R / libe_robustness.R:
# gender = "M", party_family = reference, misery_index at sample mean, offset
# at mean total_questions, country averaged out (re.form = NA).
grid_irr <- tidyr::crossing(minority = c(0, 1), libe = c(0, 1)) %>%
  dplyr::mutate(
    gender = "M",
    party_family = "Christian democrats and conservatives",
    misery_index = mean(df_libe_model$misery_index, na.rm = TRUE),
    total_questions = mean(df_libe_model$total_questions, na.rm = TRUE),
    country = "Reference"
  )

# Row-order-robust cell indexing
cell_idx <- function(m, l) which(grid_irr$minority == m & grid_irr$libe == l)

ep_redraws <- posterior_epred(
  bayesian_model_libe,
  newdata = grid_irr,
  re.form = NA,
  allow_new_levels = TRUE
)

irr_specs <- tribble(
  ~contrast,                                                    ~i_num,    ~i_den,
  "Minority IRR | ON the LIBE committee (libe = 1)",              cell_idx(1, 1), cell_idx(0, 1),
  "Minority IRR | OFF the LIBE committee (libe = 0)",             cell_idx(1, 0), cell_idx(0, 0),
  "LIBE boost | minority MEPs (libe 0 -> 1)",                     cell_idx(1, 1), cell_idx(1, 0),
  "LIBE boost | non-minority MEPs (libe 0 -> 1)",                 cell_idx(0, 1), cell_idx(0, 0)
)

irr_contrasts <- purrr::pmap_dfr(irr_specs, function(contrast, i_num, i_den) {
  ratio <- ep_redraws[, i_num] / ep_redraws[, i_den]
  tibble(
    contrast = contrast,
    irr = median(ratio),
    conf.low = quantile(ratio, 0.025, names = FALSE),
    conf.high = quantile(ratio, 0.975, names = FALSE),
    p_irr_above_1 = mean(ratio > 1)
  )
})
write_csv(irr_contrasts, here("output", "bayesian_libe_irr_contrasts.csv"))
message("IRR contrasts saved to: output/bayesian_libe_irr_contrasts.csv")
message("")
message("=== MARGINAL IRR CONTRASTS (expected counts, median [95% CrI], P(IRR>1)) ===")
irr_print <- irr_contrasts %>%
  mutate(cell = sprintf("%.2f [%.2f, %.2f]  P(>1)=%.3f",
                        irr, conf.low, conf.high, p_irr_above_1)) %>%
  dplyr::select(contrast, cell)
print(knitr::kable(irr_print, format = "markdown"))

# ==============================================================================
# 6. SUMMARY OF OUTPUTS
# ==============================================================================
message("")
message("ALTERNATIVE model outputs (all distinctly named, nothing overwritten):")
message("  - output/df_model_data_libe.rds            (estimation sample)")
message("  - output/bayesian_model_libe.rds           (brms fit cache)")
message("  - output/bayesian_libe_model_results.csv   (full coefficient table)")
message("  - output/bayesian_libe_diagnostics.csv     (Rhat / ESS / divergences)")
message("  - output/bayesian_libe_focal_coefficients.csv (focal draws-based table)")
message("  - output/bayesian_libe_irr_contrasts.csv   (marginal IRR contrasts)")
message("Primary MIPEX-only fits and outputs in output/ were NOT modified.")




