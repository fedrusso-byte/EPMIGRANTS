# ==============================================================================
# # 05_models_Bayesian_CMP.R — ALTERNATIVE Bayesian ZINB Model:
# Minority x CMP Interaction, sample restricted to CMP-coverage countries (23)
# ------------------------------------------------------------------------------
# PURPOSE (decision with FR, 2026-11-12 — SEPARATE model, does NOT replace the
# primary MIPEX-only fit in 05_models_Bayesian.R):
#   - MAIN model (M1): minority (main IV) x cmp (Claim Making Pressure,
#     secondary IV) interaction, with libe kept as a control. CMP is the
#     country-level Claim Making Pressure measure hardcoded in
#     scripts/03_country_level_vars.R (data/claimmakingpressure.csv), NOT the
#     Comparative Manifesto Project.
#   - ROBUSTNESS model (M2): same sample and controls, with LIBE as the ONLY
#     other IV and NO interaction (minority + libe): tests whether the minority
#     main effect holds once the CMP moderator is removed entirely. Per FR,
#     there is NO minority x libe interaction anywhere in this analysis
#     (libe is a control in M1 and a main effect in M2).
#   - SAMPLE RULE (confirmed by FR): countries with CMP coverage only. Verified
#     against the source file (data/claimmakingpressure.csv): HU and SK list
#     CMP = "n.a." (they only carry the Discrimination measure); LU, MT and RO
#     are not present in the file at all. The exclusion below is a
#     data-coverage constraint, not a programmatic choice.
#   - Relation to the DISCARDED archived CMP model
#     (output/archive_cmp_23cty_2026-11-12/): same interaction and same sample
#     size (N = 9,850), but that fit had (1 | country) only and was dropped
#     during the 2026-11-12 MIPEX-only refit. This upgrade restores the CMP
#     idea under the current conventions: random intercepts (1 | mep_id) +
#     (1 | country), seed 20260321, 4 x 2,000 iterations, adapt_delta = 0.95.
#   - Centering: cmp_center is computed WITHIN the estimation sample (mean
#     cmp_mean = 8.8294, sd = 4.0073; verified pre-flight 2026-11-12) so
#     cmp_center = 0 corresponds to the sample mean. The archived fit centered
#     globally on df_merged_3 before filtering: this shifts only the minority
#     baseline, never the interaction, which is invariant to the centering
#     constant.
#   - Sample facts (recomputed 2026-11-18 on the 2026-11-13 panel build,
#     exact assertions below): N = 9,850; 23 countries; 1,543 MEPs;
#     52 minority MEPs / 306 MEP-years (+1 MEP / +5 MEP-years vs the
#     2026-11-12 pre-flight: minority.csv update of 2026-11-13, MEP 28125,
#     SE, VII term); refined LLM DV sum = 599 (4.2% of MEP-years positive;
#     keyword vintage on this same sample: 1,063 events, 7.5%); terms
#     3,445 / 3,444 / 2,961 rows.
#     13 of the 23 countries have ZERO minority MEPs (AT CY CZ DK EE GR HR IE
#     LT LV PL PT SI); minority MEP-years concentrate in 10 countries, led by
#     FR (122), UK (58), DE (36), SE (30), NL (20) — the interaction is
#     identified from between-country contrasts among these minority-hosting
#     countries, whose CMP values sit at the HIGH end of the sample range
#     (minority rows: median cmp_mean 13.03 vs 7.83 for non-minority). This
#     exposure imbalance is a mandatory caveat in the results memo.
#   - DV PROMOTION (decision FR, 2026-11-18 — Option A; audit remediation
#     item 1): the keyword DV shipped in df_merged_3.csv is replaced IN
#     MEMORY by the refined LLM (R2) DV promoted to the primary
#     specification (05_models.R §1b, 2026-11-17) via the overlay in §1b
#     below; the former keyword counts are kept as
#     pqs_discrimination_keyword for vintage cross-checks. The
#     keyword-vintage fit of this model is archived in
#     output/archive_keyword_dv_2026-11-18/.
#   - All outputs use DISTINCT names (df_model_data_cmp.rds,
#     bayesian_model_cmp.rds, bayesian_model_cmp_libeonly.rds,
#     bayesian_cmp_*.csv): nothing in output/ is overwritten. NOT wired into
#     run_pipeline.R — run standalone (see session log for the invocation).
#   - brm(file = ...) caches by path: if a model spec changes, delete the
#     cached .rds first or the stale fit loads silently.
# ==============================================================================

# free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("glmmTMB", quietly = TRUE)) { install.packages("glmmTMB") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("posterior", quietly = TRUE)) { install.packages("posterior") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(glmmTMB)
library(broom.mixed)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. DATA AND ESTIMATION SAMPLE (CMP-coverage countries only)
# ==============================================================================
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
    "party_family", "libe", "minority", "misery_index", "cmp_mean",
    "legislative_term"
  ) %in% names(df_merged_3))
)

# ------------------------------------------------------------------------------
# §1b. DV PROMOTION OVERLAY (2026-11-18, FR decision "Option A" — audit
# remediation item 1): df_merged_3.csv still ships the KEYWORD DV counts (the
# 2026-11-13 aggregate artifact), but the primary specification was promoted
# to the refined LLM (R2) DV on 2026-11-17 (05_models.R §1b). To stay on the
# primary estimand, this script reconstructs the refined DV exactly as the
# primary script does — question counts re-aggregated from the epq table over
# the promoted kept-DV id lists — and swaps it in in memory:
#   pqs_discrimination         <- refined LLM (R2) counts (PRIMARY estimand)
#   pqs_discrimination_keyword <- former keyword counts (vintage cross-check)
# The overlay changes DV values only (rows/columns untouched); the
# total_questions equality assert below proves the aggregation row-coverage
# is identical to the primary panel.
# ------------------------------------------------------------------------------
refined_keptdv <- read_csv(here("data", "dv201_llm_refined_keptdv_ids.csv"),
                           show_col_types = FALSE)
verified_in <- read_csv(here("data", "dv201_llm_verified_in_ids.csv"),
                        show_col_types = FALSE)
stopifnot(
  "refined retained-DV list must have exactly 529 rows" =
    nrow(refined_keptdv) == 529,
  "verified-IN list must have exactly 255 rows" = nrow(verified_in) == 255
)
refined_ids <- refined_keptdv$id
verified_ids <- verified_in$id
epq <- readRDS(here("data_processed", "epq.rds"))
stopifnot(
  "all 529 refined ids must exist in epq.rds" = all(refined_ids %in% epq$id),
  "all 255 verified-IN ids must exist in epq.rds" = all(verified_ids %in% epq$id),
  "retained-DV and verified-IN lists must not overlap" =
    !any(refined_ids %in% verified_ids),
  "id lists must be unique" = !any(duplicated(c(refined_ids, verified_ids)))
)
dv_r2_ids <- c(refined_ids, verified_ids)
iv_r <- match(refined_ids, epq$id)
iv_v <- match(verified_ids, epq$id)
stopifnot(
  "primary DV flag must be binary" =
    all(epq$pq_discrimination %in% c(0L, 1L)),
  "all 529 refined retained-DV ids must be DV=1 in the primary import" =
    all(epq$pq_discrimination[iv_r] == 1L),
  "none of the 255 verified-INs may already be DV=1 in the primary import" =
    all(epq$pq_discrimination[iv_v] == 0L),
  "all 529 refined ids must be in-window (VII..IX)" =
    all(as.Date(epq$date)[iv_r] >= as.Date("2009-07-14") &
          as.Date(epq$date)[iv_r] <= as.Date("2024-07-15") &
          !is.na(epq$date)[iv_r]),
  "all 255 verified-IN ids must be in-window (VII..IX)" =
    all(as.Date(epq$date)[iv_v] >= as.Date("2009-07-14") &
          as.Date(epq$date)[iv_v] <= as.Date("2024-07-15") &
          !is.na(epq$date)[iv_v])
)
assign_term_sensllmr2 <- function(date_col) {
  case_when(
    date_col >= lubridate::ymd("2004-07-20") & date_col <= lubridate::ymd("2009-07-13") ~ "6th",
    date_col >= lubridate::ymd("2009-07-14") & date_col <= lubridate::ymd("2014-06-30") ~ "7th",
    date_col >= lubridate::ymd("2014-07-01") & date_col <= lubridate::ymd("2019-07-01") ~ "8th",
    date_col >= lubridate::ymd("2019-07-02") & date_col <= lubridate::ymd("2024-07-15") ~ "9th",
    TRUE ~ NA_character_
  )
}
d_win <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot("primary keyword in-window DV events must be 1,319" =
            sum(d_win$pq_discrimination) == 1319)
epq <- epq %>% mutate(pq_r2 = as.integer(id %in% dv_r2_ids))
d_win2 <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot(
  "refined in-window DV events must be 784 (529 retained + 255 verified)" =
    sum(d_win2$pq_r2) == 784,
  "the replacement must drop 535 primary DV events in-window" =
    sum(d_win2$pq_r2) - sum(d_win$pq_discrimination) == -535
)
legislature_starts <- tibble(
  legislative_term = c("6th", "7th", "8th", "9th"),
  term_start = lubridate::ymd(c("2004-07-20", "2009-07-14", "2014-07-01", "2019-07-02")),
  term_end = lubridate::ymd(c("2009-07-13", "2014-06-30", "2019-07-01", "2024-07-15"))
)
questions_r2 <- epq %>%
  mutate(dates = as.Date(date)) %>%
  filter(dates >= as.Date("2004-07-20"), dates <= as.Date("2024-06-08")) %>%
  mutate(legislative_term = assign_term_sensllmr2(dates)) %>%
  left_join(legislature_starts, by = "legislative_term") %>%
  mutate(year_index = (lubridate::interval(term_start, dates) %/% lubridate::years(1)) + 1) %>%
  mutate(leg_year = paste0(legislative_term, year_index)) %>%
  filter(year_index <= 5) %>%
  group_by(mep_id, leg_year) %>%
  summarise(
    pqs_discrimination_r2 = sum(pq_r2 == 1L, na.rm = TRUE),
    total_questions_r2 = n(),
    .groups = "drop"
  )
stopifnot("questions_r2 must not be empty" = nrow(questions_r2) > 0)
df_merged_3 <- df_merged_3 %>%
  left_join(questions_r2, by = c("mep_id", "leg_year")) %>%
  mutate(
    pqs_discrimination_r2 = replace_na(pqs_discrimination_r2, 0L),
    total_questions_r2 = replace_na(total_questions_r2, 0L),
    total_questions = replace_na(total_questions, 0L)
  )
stopifnot(
  "total_questions must be identical between primary and R2 aggregation" =
    all(df_merged_3$total_questions_r2 == df_merged_3$total_questions)
)
df_merged_3 <- df_merged_3 %>%
  rename(
    pqs_discrimination_keyword = pqs_discrimination,
    pqs_discrimination = pqs_discrimination_r2
  ) %>%
  select(-total_questions_r2)
message("   [DV promotion] Panel DVs: pqs_discrimination = refined R2 (primary); ",
        "pqs_discrimination_keyword = former keyword counts (vintage).")
rm(epq, refined_keptdv, verified_in, refined_ids, verified_ids, dv_r2_ids,
   iv_r, iv_v, d_win, d_win2, questions_r2, legislature_starts,
   assign_term_sensllmr2)

# Term filter and the UK x 9th-term exclusion safeguard (verified no-op on
# today's data: the upstream data contain no UK rows in the 9th term).
df_term <- df_merged_3 %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!(country == "UK" & legislative_term == "9th"))

# Structural exclusion: countries with NO CMP values at all. Computed
# programmatically and asserted against the verified pre-flight result, so
# silent upstream drift fails fast.
cmp_missing_countries <- df_term %>%
  group_by(country) %>%
  summarise(pct_na_cmp = mean(is.na(cmp_mean)), .groups = "drop") %>%
  filter(pct_na_cmp == 1) %>%
  pull(country)

stopifnot(
  "Exactly 5 countries must lack CMP data" = length(cmp_missing_countries) == 5,
  "Excluded countries must match verification" =
    setequal(cmp_missing_countries, c("HU", "LU", "MT", "RO", "SK"))
)
message("   CMP coverage: excluding countries with no CMP values: ",
        paste(sort(cmp_missing_countries), collapse = ", "))

# Model variables: NO MIPEX and NO discrimination_mean requirement — the CMP
# specification does not need them; requiring them would only add listwise
# deletion (all 23 CMP countries carry complete MIPEX/Discrimination anyway,
# which is why N coincides with the archived fit).
model_variables <- c(
  "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
  "party_family", "libe", "minority", "misery_index", "cmp_mean"
)

df_cmp_model <- df_term %>%
  filter(!country %in% cmp_missing_countries) %>%
  drop_na(all_of(model_variables))

# Centering WITHIN the estimation sample so cmp_center = 0 is the sample mean
# (the archived fit centered globally before filtering; see header).
df_cmp_model <- df_cmp_model %>%
  mutate(cmp_center = cmp_mean - mean(cmp_mean))

# ------------------------------------------------------------------------------
# Exact sample assertions (verified pre-flight 2026-11-12; same convention as
# explorations/libe_robustness.R and 05_models_Bayesian_LIBE.R: the sample must
# be byte-stable against silent upstream drift).
# ------------------------------------------------------------------------------
cmp_sd_sample <- sd(df_cmp_model$cmp_mean)
stopifnot(
  "Sample must not be empty" = nrow(df_cmp_model) > 0,
  "N must equal the verified value (9,850 MEP-years)" = nrow(df_cmp_model) == 9850,
  "Sample must cover exactly 23 CMP countries" =
    dplyr::n_distinct(df_cmp_model$country) == 23,
  "No CMP-NA country may survive" =
    !any(c("HU", "LU", "MT", "RO", "SK") %in% unique(df_cmp_model$country)),
  "CMP must be complete after drop_na" = !anyNA(df_cmp_model$cmp_mean),
  "Sample CMP sd must match verification (4.0073)" =
    abs(cmp_sd_sample - 4.0073) < 0.0005,
  "MEPs must match verification (1,543)" =
    dplyr::n_distinct(df_cmp_model$mep_id) == 1543,
  "Minority MEPs must match the recomputed sample (52; +1 vs the 2026-11-12 pre-flight — minority.csv update of 2026-11-13, MEP 28125, SE)" =
    dplyr::n_distinct(df_cmp_model$mep_id[df_cmp_model$minority == 1]) == 52,
  "Minority MEP-years must match the recomputed sample (306; +5 from MEP 28125)" =
    sum(df_cmp_model$minority == 1) == 306,
  "Refined DV events must match the promotion recomputation (599)" =
    sum(df_cmp_model$pqs_discrimination) == 599,
  "Keyword-DV vintage cross-check must match on this sample (1,063; +25 DV-201 force-keep events vs the 2026-11-12 fit's 1,038)" =
    sum(df_cmp_model$pqs_discrimination_keyword) == 1063,
  "UK rows in the 9th term must be absent (safeguard rule)" =
    all(!(df_cmp_model$country == "UK" & df_cmp_model$legislative_term == "9th"))
)

# Sample report (context for the results memo)
message("")
message("== CMP estimation sample (CMP-coverage countries only) ==")
message("N MEP-years      : ", nrow(df_cmp_model))
message("Countries        : ", dplyr::n_distinct(df_cmp_model$country),
        " (", paste(sort(unique(df_cmp_model$country)), collapse = " "), ")")
message("Unique MEPs      : ", dplyr::n_distinct(df_cmp_model$mep_id))
message("Minority MEPs    : ", dplyr::n_distinct(df_cmp_model$mep_id[df_cmp_model$minority == 1]))
message("Minority MEP-yrs : ", sum(df_cmp_model$minority == 1))
message("DV sum           : ", sum(df_cmp_model$pqs_discrimination),
        " (", round(100 * mean(df_cmp_model$pqs_discrimination > 0), 1), "% positive)")
message("cmp_mean mean/sd : ", round(mean(df_cmp_model$cmp_mean), 4),
        " / ", round(cmp_sd_sample, 4))
message("Rows by term     : ",
        paste(names(table(df_cmp_model$legislative_term)),
              table(df_cmp_model$legislative_term), sep = " = ", collapse = "; "))

min_by_cty <- df_cmp_model %>%
  dplyr::group_by(country) %>%
  dplyr::summarise(
    minority_meps = dplyr::n_distinct(mep_id[minority == 1]),
    minority_mep_years = sum(minority == 1),
    .groups = "drop"
  ) %>%
  dplyr::filter(minority_mep_years > 0) %>%
  dplyr::arrange(desc(minority_mep_years))
message("Countries hosting minority MEP-years (must be 10): ",
        nrow(min_by_cty), " -> ",
        paste(min_by_cty$country, min_by_cty$minority_mep_years, sep = ":",
              collapse = ", "))
stopifnot(nrow(min_by_cty) == 10)

saveRDS(df_cmp_model, here("output", "df_model_data_cmp.rds"))
message("Sample saved to: output/df_model_data_cmp.rds")

# ==============================================================================
# 2. FEASIBILITY SMOKE TESTS (glmmTMB ZINB on the exact sample, before brms)
# ==============================================================================
# Cheap frequentist smoke tests verify that BOTH formulas are fittable on this
# exact sample before any brms time is spent. Reference anchors: the archived
# (discarded) keyword-vintage CMP fit — (1 | country) only, global centering —
# returned a minority:cmp_center interaction of 0.107 [-0.038, 0.275] (null);
# the glmmTMB pre-flight on 2026-11-12 (keyword-DV vintage of 2026-11-12;
# nbinom2 + ziformula = ~1, same REs) gave
# 0.085 (SE 0.100) for M1 and 0.948 (SE 0.250) for the minority main effect
# in M2. NOTE: glmmTMB 1.1.14 does not export ziNegBin() as a function call
# (first launch 2026-11-12 failed on exactly that); family = nbinom2 with
# ziformula = ~1 is the NB2 + binomial-zero-inflation equivalent brms uses.
message("   glmmTMB smoke test M1 (minority x cmp_center)...")
smoke_m1 <- tryCatch(
  glmmTMB(
    pqs_discrimination ~ gender + misery_index + party_family + libe +
      minority * cmp_center + offset(log(total_questions + 1)) +
      (1 | mep_id) + (1 | country),
    data = df_cmp_model,
    family = nbinom2,
    ziformula = ~1
  ),
  error = function(e) e
)
message("   glmmTMB smoke test M2 (minority + libe, no interaction)...")
smoke_m2 <- tryCatch(
  glmmTMB(
    pqs_discrimination ~ gender + misery_index + party_family + minority +
      libe + offset(log(total_questions + 1)) +
      (1 | mep_id) + (1 | country),
    data = df_cmp_model,
    family = nbinom2,
    ziformula = ~1
  ),
  error = function(e) e
)
if (inherits(smoke_m1, "error")) {
  stop("glmmTMB smoke test M1 failed to fit: ", conditionMessage(smoke_m1))
}
if (inherits(smoke_m2, "error")) {
  stop("glmmTMB smoke test M2 failed to fit: ", conditionMessage(smoke_m2))
}

smoke_report <- function(m, label, focal_row) {
  coefs <- summary(m)$coefficients$cond
  vc <- tryCatch(vcov(m)$cond, error = function(e) NULL)
  message(sprintf(
    "   %s: %s = %.4f (SE %.4f); conv_code = %s; finite VCV = %s",
    label, focal_row,
    coefs[focal_row, "Estimate"], coefs[focal_row, "Std. Error"],
    m$fit$convergence, if (is.null(vc)) "NA" else all(is.finite(diag(vc)))
  ))
  invisible(TRUE)
}
smoke_report(smoke_m1, "M1 smoke", "minority:cmp_center")
smoke_report(smoke_m2, "M2 smoke", "minority")

# ==============================================================================
# 3. PRIORS AND MODEL M1: minority x cmp CENTER INTERACTION
# ==============================================================================
# Priors and sampling settings replicate the primary specification AS OF
# CREATION (pre-promotion, keyword-DV vintage): student_t(3, 0, 2.5) on all
# population-level coefficients (class "b") and on the zero-inflation
# intercept (class "zi"); brms default weakly-informative prior on the
# random-effect SDs; 4 chains x 2,000 iterations (1,000 warmup),
# adapt_delta = 0.95.
# NOTE (audit fix 2026-11-18): the earlier "IDENTICAL to 05_models_Bayesian.R
# and 05_models_Bayesian_LIBE.R" claim is no longer true — the primary moved
# to 4 chains x 4,000 iterations (1,500 warmup) at the 2026-11-17 promotion,
# and this variant was NOT re-aligned (both CMP fit blocks run 2,000/1,000).
# Comparability holds at the level of model structure and priors; the variant
# was refitted on the refined DV (remediation 1, 2026-11-18 'Option A') under
# these settings; no further rerun is planned.
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting M1 Bayesian ZINB (Minority x CMP, libe as control)...")
t_fit1 <- Sys.time()
# The interaction must be interpreted against its main effects, which are
# therefore both included; libe stays as a control precisely because it is a
# plausible confounder/mediator of minority status (see memo framing); RE
# structure matches the current convention ((1 | mep_id) + (1 | country)).
bayesian_model_cmp <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family + libe +
    minority * cmp_center +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  data = df_cmp_model,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_cmp")
)
message("Done: minority x cmp fit (",
        round(as.numeric(difftime(Sys.time(), t_fit1, units = "mins")), 1),
        " min)")
print(summary(bayesian_model_cmp))

# ==============================================================================
# 4. CONVERGENCE DIAGNOSTICS (M1)
# ==============================================================================
# Population-level parameters + shape; divergences from the NUTS sampler.
# Same function as explorations/libe_robustness.R and 05_models_Bayesian_LIBE.R.
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

diag_cmp <- diagnostics_summary(bayesian_model_cmp, "CMP interaction (23 countries)")
message("Convergence diagnostics M1 (population-level parameters):")
print(as.data.frame(diag_cmp))
write_csv(diag_cmp, here("output", "bayesian_cmp_diagnostics.csv"))

# ==============================================================================
# 5. RESULTS EXTRACTION (M1)
# ==============================================================================
model_name <- "CMP Interaction"

# Fixed effects: same tidy() call as the primary script for comparability.
fixed_results_cmp <- tidy(bayesian_model_cmp, conf.int = TRUE, conf.level = 0.95) %>%
  mutate(model = model_name)

# Random-effect SDs: extract via posterior_summary() with a regex so each SD
# keeps its group in the variable name. broom's tidy() collapses both SD rows
# to sd__(Intercept), which is ambiguous with two RE groups (MEP vs country) —
# see the MIPEX-only-refit session notes (carry-over caveat).
sds_cmp <- posterior_summary(bayesian_model_cmp, variable = "sd_|shape", regex = TRUE)
sd_results_cmp <- tibble(
  term = rownames(sds_cmp),
  estimate = sds_cmp[, "Estimate"],
  std.error = sds_cmp[, "Est.Error"],
  conf.low = sds_cmp[, "Q2.5"],
  conf.high = sds_cmp[, "Q97.5"],
  model = model_name
)

final_results_cmp <- bind_rows(fixed_results_cmp, sd_results_cmp) %>%
  dplyr::select(model, term, estimate, std.error, conf.low, conf.high)

write_csv(final_results_cmp, here("output", "bayesian_cmp_model_results.csv"))
message("Results saved to: output/bayesian_cmp_model_results.csv")

interaction_results_cmp <- final_results_cmp %>% filter(grepl(":", term))
print("--- Bayesian Interaction Effects (minority x cmp_center) ---")
print(interaction_results_cmp)
knitr::kable(interaction_results_cmp, format = "markdown",
             caption = "Credible Intervals for the Minority x CMP Interaction")

# Focal parameters, draws-based: posterior median [95% CrI], P(draw > 0)
focal_draws_cmp <- posterior::as_draws_df(bayesian_model_cmp)
focal_pars_cmp <- tribble(
  ~parameter,             ~label,
  "b_minority",           "minority (main effect, at sample-mean CMP)",
  "b_cmp_center",         "cmp_center (gradient, non-minority MEPs)",
  "b_minority:cmp_center", "minority x cmp_center (extra CMP gradient for minority MEPs)"
)
focal_table_cmp <- purrr::pmap_dfr(focal_pars_cmp, function(parameter, label) {
  d <- focal_draws_cmp[[parameter]]
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
write_csv(focal_table_cmp, here("output", "bayesian_cmp_focal_coefficients.csv"))
message("Focal parameters saved to: output/bayesian_cmp_focal_coefficients.csv")
message("=== FOCAL COEFFICIENTS — CMP model (posterior median [95% CrI], P(draw>0)) ===")
print(as.data.frame(
  focal_table_cmp %>%
    dplyr::mutate(cell = sprintf("%.3f [%.3f, %.3f]  P(+)= %.3f",
                                 estimate, conf.low, conf.high, p_positive)) %>%
    dplyr::select(label, cell)
))

# ------------------------------------------------------------------------------
# Marginal IRR contrasts: expected-count ratios under posterior_epred
# (row-order-robust cell indexing, per 06_model_comparison_Bayesian.R).
# Profile: gender = M, party_family = Christian democrats and conservatives,
# misery_index / total_questions at estimation-sample means, country = Reference
# (random effects integrated out via re.form = NA).
# ------------------------------------------------------------------------------
cmp_mean_s <- mean(df_cmp_model$cmp_mean)
# NOTE: newdata must contain ALL population-level variables of the M1 formula,
# including the libe control. libe is held at 0 (off-LIBE profile); every IRR
# below is a ratio computed at the SAME libe level, so the constant libe factor
# cancels within each contrast. First launch 2026-11-12 crashed here on the
# missing-libe brms validate_data() check — fixed by adding the column.
grid_cmp <- tidyr::crossing(minority = c(0, 1), k = -1:1) %>%
  dplyr::mutate(
    cmp_center = k * cmp_sd_sample,
    k_label = dplyr::case_when(
      k == -1 ~ paste0("CMP mean -1 SD (= ", round(cmp_mean_s - cmp_sd_sample, 2), ")"),
      k == 0  ~ paste0("CMP mean (= ", round(cmp_mean_s, 2), ")"),
      k == 1  ~ paste0("CMP mean +1 SD (= ", round(cmp_mean_s + cmp_sd_sample, 2), ")")
    ),
    libe = 0,
    gender = "M",
    party_family = "Christian democrats and conservatives",
    misery_index = mean(df_cmp_model$misery_index, na.rm = TRUE),
    total_questions = mean(df_cmp_model$total_questions, na.rm = TRUE),
    country = "Reference"
  )
cell_idx <- function(m, k) which(grid_cmp$minority == m & grid_cmp$k == k)

epred_cmp <- posterior_epred(bayesian_model_cmp, newdata = grid_cmp,
                             re.form = NA, allow_new_levels = TRUE)

irr_specs_cmp <- tribble(
  ~contrast,                                   ~i_num,        ~i_den,
  "Minority IRR | CMP at sample mean",         cell_idx(1, 0), cell_idx(0, 0),
  "Minority IRR | CMP at mean - 1 SD",         cell_idx(1, -1), cell_idx(0, -1),
  "Minority IRR | CMP at mean + 1 SD",         cell_idx(1, 1),  cell_idx(0, 1),
  "CMP +1 SD gradient | minority MEPs",        cell_idx(1, 1),  cell_idx(1, 0),
  "CMP +1 SD gradient | non-minority MEPs",    cell_idx(0, 1),  cell_idx(0, 0)
)
irr_table_cmp <- irr_specs_cmp %>%
  dplyr::mutate(
    draws = purrr::pmap(list(i_num, i_den), function(n, d) {
      # posterior_epred returns a draws x cells MATRIX (4000 x 6, verified
      # empirically on brms 2.23); index by column, not 3-D slicing.
      # pmap maps n <- i_num, d <- i_den: the IRR is num/den (minority vs
      # non-minority; +1SD vs mean). First launch inverted this ratio — fixed.
      z <- epred_cmp[, n] / epred_cmp[, d]
      c(estimate = median(z),
        conf.low = quantile(z, 0.025, names = FALSE),
        conf.high = quantile(z, 0.975, names = FALSE),
        p_gt_1 = mean(z > 1))
    })
  ) %>%
  dplyr::mutate(
    cell      = purrr::map_chr(draws, ~ sprintf("%.2f [%.2f, %.2f]", .x[1], .x[2], .x[3])),
    p_gt_1    = purrr::map_dbl(draws, ~ .x[4]),
    model     = model_name,
    cell_profile = "libe = 0; gender = M; party_family = CDU/conservatives; misery_index & total_questions at sample means; country RE integrated out"
  ) %>%
  dplyr::select(model, contrast, cell, p_gt_1, cell_profile)

write_csv(irr_table_cmp, here("output", "bayesian_cmp_irr_contrasts.csv"))
message("IRR contrasts saved to: output/bayesian_cmp_irr_contrasts.csv")
message("=== MARGINAL IRR CONTRASTS — CMP model (expected counts, median [95% CrI], P(IRR>1)) ===")
print(knitr::kable(
  irr_table_cmp %>% dplyr::select(contrast, cell, p_gt_1),
  format = "markdown"
))

# ==============================================================================
# 6. MODEL M2 — LIBE ONLY (ROBUSTNESS, nested in M1)
# ==============================================================================
# Same sample and controls as M1, with CMP removed entirely and NO interaction
# (per FR): gender + misery_index + party_family + minority + libe. M2 is
# nested in M1 (M1 minus the two cmp terms), so the nested-model logic applies:
# does the minority estimate move once the CMP moderator is dropped?
message("   Fitting M2 Bayesian ZINB (minority + libe, no interaction)...")
t_fit2 <- Sys.time()
bayesian_model_cmp_libeonly <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family + minority + libe +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  data = df_cmp_model,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_cmp_libeonly")
)
message("Done: minority + libe fit (",
        round(as.numeric(difftime(Sys.time(), t_fit2, units = "mins")), 1),
        " min)")
print(summary(bayesian_model_cmp_libeonly))

# Diagnostics (M2)
diag_libeonly <- diagnostics_summary(bayesian_model_cmp_libeonly,
                                     "LIBE-only robustness (23 countries)")
message("Convergence diagnostics M2 (population-level parameters):")
print(as.data.frame(diag_libeonly))
write_csv(diag_libeonly, here("output", "bayesian_cmp_libeonly_diagnostics.csv"))

# Extraction (M2)
model_name2 <- "LIBE-only Robustness"
fixed_results2 <- tidy(bayesian_model_cmp_libeonly, conf.int = TRUE, conf.level = 0.95) %>%
  mutate(model = model_name2)
sds2 <- posterior_summary(bayesian_model_cmp_libeonly, variable = "sd_|shape", regex = TRUE)
sd_results2 <- tibble(
  term = rownames(sds2),
  estimate = sds2[, "Estimate"],
  std.error = sds2[, "Est.Error"],
  conf.low = sds2[, "Q2.5"],
  conf.high = sds2[, "Q97.5"],
  model = model_name2
)
final_results2 <- bind_rows(fixed_results2, sd_results2) %>%
  dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
write_csv(final_results2, here("output", "bayesian_cmp_libeonly_model_results.csv"))
message("Results saved to: output/bayesian_cmp_libeonly_model_results.csv")

# Focal parameters (M2): minority + libe main effects only
focal_draws2 <- posterior::as_draws_df(bayesian_model_cmp_libeonly)
focal_pars2 <- tribble(
  ~parameter, ~label,
  "b_minority", "minority (main effect, CMP removed)",
  "b_libe",     "libe (main effect, CMP removed)"
)
focal_table2 <- purrr::pmap_dfr(focal_pars2, function(parameter, label) {
  d <- focal_draws2[[parameter]]
  if (is.null(d) || length(d) == 0) {
    return(tibble(parameter = parameter, label = label, model = model_name2,
                  estimate = NA_real_, conf.low = NA_real_,
                  conf.high = NA_real_, p_positive = NA_real_))
  }
  tibble(
    parameter = parameter, label = label, model = model_name2,
    estimate = median(d),
    conf.low = quantile(d, 0.025, names = FALSE),
    conf.high = quantile(d, 0.975, names = FALSE),
    p_positive = mean(d > 0)
  )
})
write_csv(focal_table2, here("output", "bayesian_cmp_libeonly_focal_coefficients.csv"))
message("Focal parameters saved to: output/bayesian_cmp_libeonly_focal_coefficients.csv")
message("=== FOCAL COEFFICIENTS — LIBE-only robustness (posterior median [95% CrI], P(draw>0)) ===")
print(as.data.frame(
  focal_table2 %>%
    dplyr::mutate(cell = sprintf("%.3f [%.3f, %.3f]  P(+)= %.3f",
                                 estimate, conf.low, conf.high, p_positive)) %>%
    dplyr::select(label, cell)
))

# ------------------------------------------------------------------------------
# Marginal IRR contrasts (M2). With NO interaction, the minority IRR is by
# construction the same on and off the LIBE committee; the four rows below make
# that equality (up to MCMC noise) directly checkable in the output CSV.
# ------------------------------------------------------------------------------
grid2 <- tidyr::crossing(minority = c(0, 1), libe = c(0, 1)) %>%
  dplyr::mutate(
    gender = "M",
    party_family = "Christian democrats and conservatives",
    misery_index = mean(df_cmp_model$misery_index, na.rm = TRUE),
    total_questions = mean(df_cmp_model$total_questions, na.rm = TRUE),
    country = "Reference"
  )
cell_idx2 <- function(m, l) which(grid2$minority == m & grid2$libe == l)
epred2 <- posterior_epred(bayesian_model_cmp_libeonly, newdata = grid2,
                          re.form = NA, allow_new_levels = TRUE)
irr_specs2 <- tribble(
  ~contrast,                                         ~i_num,          ~i_den,
  "Minority IRR | ON the LIBE committee (libe = 1)",  cell_idx2(1, 1), cell_idx2(0, 1),
  "Minority IRR | OFF the LIBE committee (libe = 0)", cell_idx2(1, 0), cell_idx2(0, 0),
  "LIBE boost | minority MEPs (libe 0 -> 1)",         cell_idx2(1, 1), cell_idx2(1, 0),
  "LIBE boost | non-minority MEPs (libe 0 -> 1)",     cell_idx2(0, 1), cell_idx2(0, 0)
)
irr_table2 <- irr_specs2 %>%
  dplyr::mutate(
    draws = purrr::pmap(list(i_num, i_den), function(n, d) {
      # draws x cells matrix (see the M1 note); pmap maps n <- i_num,
      # d <- i_den: the IRR is num/den (first launch inverted the ratio).
      z <- epred2[, n] / epred2[, d]
      c(estimate = median(z),
        conf.low = quantile(z, 0.025, names = FALSE),
        conf.high = quantile(z, 0.975, names = FALSE),
        p_gt_1 = mean(z > 1))
    })
  ) %>%
  dplyr::mutate(
    cell      = purrr::map_chr(draws, ~ sprintf("%.2f [%.2f, %.2f]", .x[1], .x[2], .x[3])),
    p_gt_1    = purrr::map_dbl(draws, ~ .x[4]),
    model     = model_name2,
    cell_profile = "gender = M; party_family = CDU/conservatives; misery_index & total_questions at sample means; country RE integrated out"
  ) %>%
  dplyr::select(model, contrast, cell, p_gt_1, cell_profile)
write_csv(irr_table2, here("output", "bayesian_cmp_libeonly_irr_contrasts.csv"))
message("IRR contrasts saved to: output/bayesian_cmp_libeonly_irr_contrasts.csv")
message("=== MARGINAL IRR CONTRASTS — LIBE-only robustness (expected counts, median [95% CrI], P(IRR>1)) ===")
print(knitr::kable(
  irr_table2 %>% dplyr::select(contrast, cell, p_gt_1),
  format = "markdown"
))

# ==============================================================================
# 7. CROSS-MODEL COMPARISON (informational printout)
# ==============================================================================
# M2 is nested in M1 (M1 minus the two cmp terms). The printout below lines up
# the minority / moderator / interaction terms across M1, M2 and, when
# present, the primary MIPEX-only model's CSV. Nested-model anchors for the
# memo: (a) compare b_minority across M1 and M2; (b) compare the M1 interaction
# with the archived (discarded) CMP fit (0.107 [-0.038, 0.275], (1|country)
# only) and with the primary MIPEX interaction in
# output/bayesian_model_results.csv (refined-DV vintage). The keyword-vintage
# M1/M2 columns live in output/archive_keyword_dv_2026-11-18/.
key_terms <- c("minority", "libe", "cmp_center", "minority:cmp_center",
               "minority:libe", "mipex_center", "minority:mipex_center")
comparison_cmp <- bind_rows(final_results_cmp, final_results2)
primary_csv <- here("output", "bayesian_model_results.csv")
if (file.exists(primary_csv)) {
  primary_results <- read_csv(primary_csv, show_col_types = FALSE) %>%
    dplyr::filter(term %in% key_terms)
  comparison_cmp <- bind_rows(comparison_cmp, primary_results)
}
message("=== CROSS-MODEL COMPARISON (log-scale coefficients, 95% CrI) ===")
print(as.data.frame(
  comparison_cmp %>%
    dplyr::filter(term %in% key_terms) %>%
    dplyr::mutate(cell = sprintf("%.3f [%.3f, %.3f]",
                                 estimate, conf.low, conf.high)) %>%
    dplyr::select(model, term, cell)
))

message("")
message("== Files written by this script ==")
message("  output/df_model_data_cmp.rds")
message("  output/bayesian_model_cmp.rds (brm cache)")
message("  output/bayesian_cmp_diagnostics.csv")
message("  output/bayesian_cmp_model_results.csv")
message("  output/bayesian_cmp_focal_coefficients.csv")
message("  output/bayesian_cmp_irr_contrasts.csv")
message("  output/bayesian_model_cmp_libeonly.rds (brm cache)")
message("  output/bayesian_cmp_libeonly_diagnostics.csv")
message("  output/bayesian_cmp_libeonly_model_results.csv")
message("  output/bayesian_cmp_libeonly_focal_coefficients.csv")
message("  output/bayesian_cmp_libeonly_irr_contrasts.csv")
message("Done: CMP alternative models (M1 interaction, M2 robustness).")






