# ==============================================================================
# 05_models_Bayesian_TERM.R — ALTERNATIVE Bayesian ZINB Model:
# Legislature-term heterogeneity of the minority effect (MIPEX-only sample)
# ------------------------------------------------------------------------------
# PURPOSE (decision with FR, 2026-11-12 — SEPARATE model, does NOT replace
# the primary MIPEX-only fit in 05_models_Bayesian.R):
#   - Test whether the supported H1 minority effect (2.31x at reference values
#     in the primary MIPEX-only spec) differs across EP terms VII/VIII/IX, as
#     a minimal extension of the primary specification: exactly two added
#     terms — legislative_term (7th = reference) and its interaction with
#     minority. The H3 interaction (minority x mipex_center) is kept
#     untouched, so this fit = the primary spec PLUS term heterogeneity.
#   - One single fit yields:
#       * per-term minority IRRs (7th = reference),
#       * a pooled "crisis era" STEP contrast — the average minority
#         log-effect change for {8th, 9th} vs 7th (exp = geometric-mean IRR).
#     pooled step contrast trades granularity for power; the per-term
#     IRRs are nevertheless reported separately,
#       * pairwise minority-effect contrasts (8 vs 7, 9 vs 7, 9 vs 8),
#       * term main effects (non-minority baseline) as free context.
#   - Interpretation guardrail: legislative_term is a PERIOD (8th/9th terms
#     combine refugee-crisis aftermath, Brexit shock and migration MIP
#     salience), not a causal salience manipulation — results must be
#     framed as "consistent with" the salience account, never as its test.
#   - Estimation sample: the PRIMARY sample, loaded read-only from
#     output/df_model_data.rds (built by 05_models.R; N = 10,955 MEP-years,
#     27 MIPEX-covered countries, 1,707 MEPs). Nothing is rebuilt, rewritten
#     or archived; sample invariants are asserted before fitting.
#   - Feasibility baseline (verified 2026-11-12, read-only diagnostics) and
#     UPDATED for the 2026-11-13 re-run. Two changes landed between the
#     2026-11-12 check and this re-run:
#       (a) upstream data: FR added Swedish MEP 28125 to minority.csv
#           (2026-11-13 10:33; VII term only, AFET, libe = 0, DV events = 0)
#           — minority cells in the 7th term go 122 -> 127 MEP-years,
#           27 -> 28 MEPs, and total minority MEPs 55 -> 56;
#       (b) the DV-201 validation force-keeps (2026-11-13): 29 questions
#           re-classified as on-scope, of which 3 are authored by minority
#           MEPs (2 in the 8th, 1 in the 9th term) — minority events go
#           17/22/8 -> 17/24/9.
#     Post-patch structure: minority cells 127/91/115 MEP-years
#     (28/21/23 MEPs), events 17/24/9 across terms 7/8/9; 12 of 56 minority
#     MEPs span >= 2 terms (8 two-term + 4 three-term, partial within-MEP
#     identification; the effect remains mostly between-MEP); UK minority
#     MEPs vanish in the 9th term (empirical composition feature of the
#     primary sample, NOT a filter).
#   - DV PROMOTION (decision FR, 2026-11-18 — Option A; audit remediation
#     item 1): the fit runs on the refined LLM (R2) DV shipped inside
#     output/df_model_data.rds by the 2026-11-17 promotion (05_models.R §1b;
#     739 in-sample events; former keyword counts kept on the panel as
#     pqs_discrimination_keyword = 1,244 in-sample). DV-dependent invariants
#     recomputed 2026-11-18: minority events by term are 12 / 27 / 11
#     (keyword vintage was 17 / 24 / 9 — now pinned as a keyword-vintage
#     cross-check). All structural invariants (minority cells 127/91/115
#     MEP-years, 28/21/23 MEPs, 12 term-spanning minority MEPs) are unchanged.
#     The keyword-vintage fit of this model is archived in
#     output/archive_keyword_dv_2026-11-18/ and remains a valid appendix
#     reference for the keyword estimand.
#   - All outputs use DISTINCT names (bayesian_model_term.rds,
#     bayesian_term_*.csv): nothing in output/ is overwritten. NOT wired
#     into run_pipeline.R — run standalone under the project renv.
#   - brm(file = ...) caches by path: if the model spec changes, delete
#     output/bayesian_model_term.rds first or the stale fit loads silently.
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
# 1. DATA AND ESTIMATION SAMPLE (the PRIMARY sample, loaded read-only)
# ==============================================================================
message("   Loading the primary MIPEX-only estimation sample (read-only)...")
df_model_data <- readRDS(here("output", "df_model_data.rds")) %>%
  dplyr::mutate(legislative_term = factor(legislative_term,
                                          levels = c("7th", "8th", "9th")))

model_variables <- c(
  "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
  "party_family", "libe", "minority", "misery_index", "mipex_center",
  "legislative_term"
)

# Per-term minority cell structure (asserted against the feasibility check)
minority_by_term <- df_model_data %>%
  dplyr::group_by(legislative_term) %>%
  dplyr::summarise(
    mep_years = sum(minority == 1),
    meps      = dplyr::n_distinct(mep_id[minority == 1]),
    events    = sum(pqs_discrimination[minority == 1]),
    questions = sum(total_questions[minority == 1]),
    .groups   = "drop"
  )

mep_terms_minority <- df_model_data %>%
  dplyr::filter(minority == 1) %>%
  dplyr::distinct(mep_id, legislative_term) %>%
  dplyr::count(mep_id, name = "n_terms")

stopifnot(
  "Primary sample must not be empty" = nrow(df_model_data) > 0,
  "Model variables must have no NA (sample is listwise-deleted upstream)" =
    !anyNA(df_model_data[model_variables]),
  "N must equal the primary MIPEX-only sample (10,955 MEP-years)" =
    nrow(df_model_data) == 10955,
  "Sample must cover the 27 MIPEX-covered countries" =
    dplyr::n_distinct(df_model_data$country) == 27,
  "Unique MEPs must match the refit check (1,707)" =
    dplyr::n_distinct(df_model_data$mep_id) == 1707,
  "Minority MEPs must match (56; +1 from the upstream minority.csv update of 2026-11-13, MEP 28125)" =
    dplyr::n_distinct(df_model_data$mep_id[df_model_data$minority == 1]) == 56,
  "Minority MEP-years by term must match (127 / 91 / 115)" =
    identical(as.integer(minority_by_term$mep_years), c(127L, 91L, 115L)),
  "Minority MEPs by term must match (28 / 21 / 23)" =
    identical(as.integer(minority_by_term$meps), c(28L, 21L, 23L)),
  "Minority events by term must match the refined DV (12 / 27 / 11; recomputed 2026-11-18 for the Option-A promotion — keyword vintage was 17 / 24 / 9)" =
    identical(as.integer(minority_by_term$events), c(12L, 27L, 11L)),
  "Refined in-sample DV sum must match the promoted panel (739)" =
    sum(df_model_data$pqs_discrimination) == 739,
  "Keyword-vintage in-sample DV sum must match the promoted panel (1,244)" =
    sum(df_model_data$pqs_discrimination_keyword) == 1244,
  "Keyword-vintage minority events by term must match (17 / 24 / 9; cross-check that the panel ships the same keyword column the 2026-11-13 fit used)" =
    identical(as.integer(tapply(df_model_data$pqs_discrimination_keyword[df_model_data$minority == 1],
                                df_model_data$legislative_term[df_model_data$minority == 1], sum)),
              c(17L, 24L, 9L)),
  "Term-spanning minority MEPs must match (8 two-term + 4 three-term)" =
    sum(mep_terms_minority$n_terms == 2) == 8 &&
      sum(mep_terms_minority$n_terms == 3) == 4
)

# Sample report (context for the results memo)
message("")
message("== PRIMARY estimation sample (MIPEX-only, unchanged; loaded read-only) ==")
message("N MEP-years      : ", nrow(df_model_data))
message("Countries        : ", dplyr::n_distinct(df_model_data$country))
message("Unique MEPs      : ", dplyr::n_distinct(df_model_data$mep_id))
message("Minority MEPs    : ",
        dplyr::n_distinct(df_model_data$mep_id[df_model_data$minority == 1]))
message("DV sum           : ", sum(df_model_data$pqs_discrimination))
message("Rows by term     : ",
        paste(names(table(df_model_data$legislative_term)),
              table(df_model_data$legislative_term),
              sep = " = ", collapse = "; "))
cell_sizes <- df_model_data %>%
  dplyr::count(legislative_term, minority, name = "mep_years") %>%
  dplyr::left_join(
    df_model_data %>%
      dplyr::distinct(mep_id, legislative_term, minority) %>%
      dplyr::count(legislative_term, minority, name = "meps"),
    by = c("legislative_term", "minority")
  ) %>%
  dplyr::left_join(
    df_model_data %>%
      dplyr::group_by(legislative_term, minority) %>%
      dplyr::summarise(events = sum(pqs_discrimination), .groups = "drop"),
    by = c("legislative_term", "minority")
  ) %>%
  dplyr::mutate(pct_rows_positive = round(events / mep_years, 3))
message("Term x Minority cell structure (MEP-years / MEPs / events / share>0):")
print(as.data.frame(cell_sizes))
message("Minority cell detail by term (MEP-years / MEPs / events / intensity per 1k questions):")
print(as.data.frame(minority_by_term %>%
  dplyr::mutate(intensity_per_1k = round(events / questions * 1000, 2))))
raw_intensity <- df_model_data %>%
  dplyr::group_by(legislative_term, minority) %>%
  dplyr::summarise(
    events    = sum(pqs_discrimination),
    questions = sum(total_questions),
    .groups   = "drop"
  ) %>%
  dplyr::mutate(intensity_per_1k = round(events / questions * 1000, 2)) %>%
  dplyr::select(legislative_term, minority, intensity_per_1k) %>%
  tidyr::pivot_wider(names_from = minority, values_from = intensity_per_1k,
                     names_prefix = "min") %>%
  dplyr::mutate(ratio = round(min1 / min0, 2))
message("Unadjusted minority/non-minority intensity ratio by term (preview):")
print(as.data.frame(raw_intensity))
minority_country_term <- df_model_data %>%
  dplyr::filter(minority == 1) %>%
  dplyr::count(country, legislative_term) %>%
  tidyr::pivot_wider(names_from = legislative_term, values_from = n,
                     values_fill = 0) %>%
  dplyr::mutate(total = `7th` + `8th` + `9th`) %>%
  dplyr::arrange(dplyr::desc(total))
message("Minority MEP-years by country x term (composition check):")
print(as.data.frame(minority_country_term))
message("Mean total_questions by term (9th-term DV completeness flag):")
print(as.data.frame(df_model_data %>%
  dplyr::group_by(legislative_term) %>%
  dplyr::summarise(mean_total_questions = round(mean(total_questions), 1),
                   .groups = "drop")))

# ==============================================================================
# 2. PRIORS AND MODEL: legislature-term heterogeneity on the primary spec
# ==============================================================================
# Priors and sampling settings replicate the primary specification AS OF
# CREATION (pre-promotion, keyword-DV vintage): student_t(3, 0, 2.5) on all
# population-level coefficients (class "b") and on the zero-inflation
# intercept (class "zi"); brms default weakly-informative prior on the
# random-effect SDs; 4 chains x 2,000 iterations (1,000 warmup),
# adapt_delta = 0.95, so the alternative fit remains comparable to the
# primary MIPEX-only fit at the level of model structure and priors.
# NOTE (audit fix 2026-11-18): the earlier "IDENTICAL to 05_models_Bayesian.R"
# claim is no longer true — the primary moved to 4 chains x 4,000 iterations
# (1,500 warmup) at the 2026-11-17 promotion, and this variant was NOT
# re-aligned. The variant was refitted on the refined DV (remediation 1,
# 2026-11-18 'Option A') under these settings; no further rerun is planned.
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting ALTERNATIVE Bayesian ZINB (Minority x Term, primary spec + term)...")
t_fit <- Sys.time()
# The primary specification is kept EXACTLY (controls, offset, REs, H3
# interaction); legislative_term and its interaction with minority are the
# only additions, entering the conditional mean only (the zero-inflation
# part stays intercept-only, mirroring the primary model). 7th term = ref.
bayesian_model_term <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family + libe +
    minority * mipex_center +
    legislative_term + minority:legislative_term +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_term")
)
message("Done: minority x term fit (",
        round(as.numeric(difftime(Sys.time(), t_fit, units = "mins")), 1),
        " min)")

# ==============================================================================
# 3. CONVERGENCE DIAGNOSTICS
# ==============================================================================
# Population-level parameters + shape; divergences from the NUTS sampler.
# Same function as explorations/libe_robustness.R / 05_models_Bayesian_LIBE.R.
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

diag_table <- diagnostics_summary(bayesian_model_term,
                                  "Term interaction (MIPEX-only)")
message("Convergence diagnostics (population-level parameters):")
print(as.data.frame(diag_table))
write_csv(diag_table, here("output", "bayesian_term_diagnostics.csv"))

# ==============================================================================
# 4. RESULTS EXTRACTION
# ==============================================================================
model_name <- "Term Interaction"

# Fixed effects: same tidy() call as the primary script for comparability.
fixed_results <- tidy(bayesian_model_term, conf.int = TRUE, conf.level = 0.95) %>%
  mutate(model = model_name)

# Random-effect SDs: extract via posterior_summary() with a regex so each SD
# keeps its group in the variable name (see 05_models_Bayesian_LIBE.R).
sds <- posterior_summary(bayesian_model_term, variable = "sd_|shape", regex = TRUE)
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

write_csv(final_results, here("output", "bayesian_term_model_results.csv"))
message("Results saved to: output/bayesian_term_model_results.csv")

interaction_results <- final_results %>%
  filter(grepl("term", term, ignore.case = TRUE))
print("--- Bayesian interaction effects (minority x legislative_term) ---")
print(interaction_results)
knitr::kable(interaction_results, format = "markdown",
             caption = "Credible Intervals for the Minority x Legislative Term Interaction")

# Focal parameters, draws-based: posterior median [95% CrI], P(draw > 0)
# (log-IRR scale; exp() of all rows = multiplicative IRR / IRR change).
focal_draws <- posterior::as_draws_df(bayesian_model_term)
d_mint8 <- focal_draws[["b_minority:legislative_term8th"]]
d_mint9 <- focal_draws[["b_minority:legislative_term9th"]]
focal_stat <- function(parameter, label, d) {
  if (is.null(d) || length(d) == 0) {
    return(tibble(parameter = parameter, label = label, model = model_name,
                  estimate = NA_real_, conf.low = NA_real_,
                  conf.high = NA_real_, p_positive = NA_real_))
  }
  tibble(
    parameter  = parameter,
    label      = label,
    model      = model_name,
    estimate   = median(d),
    conf.low   = quantile(d, 0.025, names = FALSE),
    conf.high  = quantile(d, 0.975, names = FALSE),
    p_positive = mean(d > 0)
  )
}
focal_table <- bind_rows(
  focal_stat("b_minority", "minority (main effect; 7th term, mean MIPEX)",
             focal_draws[["b_minority"]]),
  focal_stat("b_mipex_center", "mipex_center (policy-inclusiveness main effect)",
             focal_draws[["b_mipex_center"]]),
  focal_stat("b_minority:mipex_center",
             "H3 re-check: minority x mipex_center (spec identical to primary)",
             focal_draws[["b_minority:mipex_center"]]),
  focal_stat("b_legislative_term8th",
             "term main effect: 8th vs 7th (non-minority baseline)",
             focal_draws[["b_legislative_term8th"]]),
  focal_stat("b_legislative_term9th",
             "term main effect: 9th vs 7th (non-minority baseline)",
             focal_draws[["b_legislative_term9th"]]),
  focal_stat("b_minority:legislative_term8th",
             "minority x 8th term: change in minority log-effect vs 7th", d_mint8),
  focal_stat("b_minority:legislative_term9th",
             "minority x 9th term: change in minority log-effect vs 7th", d_mint9),
  focal_stat("b_step_{8th,9th} vs 7th",
             "STEP contrast: average minority log-effect change, {8th,9th} vs 7th (exp = geometric-mean IRR)",
             (d_mint8 + d_mint9) / 2),
  focal_stat("b_minority:term 9th vs 8th",
             "Pairwise: minority log-effect change, 9th vs 8th",
             d_mint9 - d_mint8)
)
write_csv(focal_table, here("output", "bayesian_term_focal_coefficients.csv"))
message("Focal parameters saved to: output/bayesian_term_focal_coefficients.csv")
message("")
message("=== FOCAL COEFFICIENTS (posterior median [95% CrI], P(draw>0), log scale) ===")
focal_print <- focal_table %>%
  mutate(cell = sprintf("%.3f [%.3f, %.3f]  P(+)=%.3f",
                        estimate, conf.low, conf.high, p_positive)) %>%
  dplyr::select(label, cell)
print(knitr::kable(focal_print, format = "markdown"))

# ==============================================================================
# 5. MARGINAL IRR CONTRASTS (expected-count ratios)
# ==============================================================================
# Grid conventions mirror 06_model_comparison_Bayesian.R / the LIBE model:
# gender = "M", party_family = reference, misery_index at sample mean,
# mipex_center = 0 (mean MIPEX context), libe = 0, offset at mean
# total_questions, country/MEP averaged out (re.form = NA).
grid_irr <- tidyr::crossing(
  minority = c(0, 1),
  legislative_term = factor(c("7th", "8th", "9th"),
                            levels = levels(df_model_data$legislative_term))
) %>%
  dplyr::mutate(
    gender = "M",
    party_family = "Christian democrats and conservatives",
    misery_index = mean(df_model_data$misery_index, na.rm = TRUE),
    mipex_center = 0,
    libe = 0,
    total_questions = mean(df_model_data$total_questions, na.rm = TRUE),
    mep_id = "Reference",
    country = "Reference"
  )

cell_idx <- function(m, t) which(grid_irr$minority == m & grid_irr$legislative_term == t)

ep_term <- posterior_epred(
  bayesian_model_term,
  newdata = grid_irr,
  re.form = NA,
  allow_new_levels = TRUE
)

irr_epred <- tibble(
  contrast = c("Minority IRR | 7th term (reference)",
               "Minority IRR | 8th term",
               "Minority IRR | 9th term"),
  method = "posterior_epred (covariates at reference, offset at mean)",
  draws = list(
    ep_term[, cell_idx(1, "7th")] / ep_term[, cell_idx(0, "7th")],
    ep_term[, cell_idx(1, "8th")] / ep_term[, cell_idx(0, "8th")],
    ep_term[, cell_idx(1, "9th")] / ep_term[, cell_idx(0, "9th")]
  )
)
irr_coef <- tibble(
  contrast = c(
    "Minority effect change | 8th vs 7th (exp)",
    "Minority effect change | 9th vs 7th (exp)",
    "Minority effect change | 9th vs 8th (exp)",
    "STEP contrast (minority) | average {8th,9th} vs 7th (exp)",
    "Term main effect (non-minority) | 8th vs 7th (exp)",
    "Term main effect (non-minority) | 9th vs 7th (exp)"
  ),
  method = "coefficient draws (exp of log-effect contrasts)",
  draws = list(
    exp(d_mint8),
    exp(d_mint9),
    exp(d_mint9 - d_mint8),
    exp((d_mint8 + d_mint9) / 2),
    exp(focal_draws[["b_legislative_term8th"]]),
    exp(focal_draws[["b_legislative_term9th"]])
  )
)
irr_contrasts <- bind_rows(irr_epred, irr_coef) %>%
  dplyr::mutate(
    irr           = purrr::map_dbl(draws, median),
    conf.low      = purrr::map_dbl(draws, ~ quantile(.x, 0.025, names = FALSE)),
    conf.high     = purrr::map_dbl(draws, ~ quantile(.x, 0.975, names = FALSE)),
    p_irr_above_1 = purrr::map_dbl(draws, ~ mean(.x > 1))
  ) %>%
  dplyr::select(-draws)
write_csv(irr_contrasts, here("output", "bayesian_term_irr_contrasts.csv"))
message("IRR contrasts saved to: output/bayesian_term_irr_contrasts.csv")
message("")
message("=== MARGINAL IRR CONTRASTS (expected counts, median [95% CrI], P(IRR>1)) ===")
irr_print <- irr_contrasts %>%
  mutate(cell = sprintf("%.2f [%.2f, %.2f]  P(>1)=%.3f",
                        irr, conf.low, conf.high, p_irr_above_1)) %>%
  dplyr::select(contrast, method, cell)
print(knitr::kable(irr_print, format = "markdown"))

# ==============================================================================
# 6. SUMMARY OF OUTPUTS
# ==============================================================================
message("")
message("ALTERNATIVE model outputs (all distinctly named, nothing overwritten):")
message("  - output/bayesian_model_term.rds             (brms fit cache)")
message("  - output/bayesian_term_model_results.csv     (full coefficient table)")
message("  - output/bayesian_term_diagnostics.csv       (Rhat / ESS / divergences)")
message("  - output/bayesian_term_focal_coefficients.csv (focal draws-based table)")
message("  - output/bayesian_term_irr_contrasts.csv     (marginal IRR contrasts)")
message("  (sample = output/df_model_data.rds, loaded READ-ONLY; no sample copy written)")
message("Primary MIPEX-only fits and outputs in output/ were NOT modified.")
