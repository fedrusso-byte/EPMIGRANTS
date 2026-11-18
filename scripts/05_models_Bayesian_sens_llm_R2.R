# ==============================================================================
# *** PROMOTED TO PRIMARY SPECIFICATION (2026-11-17) ***
# The R2 DV defined in this script is now the PRIMARY DV of the paper: the
# overlay was lifted into scripts/05_models.R (§ 1b) and the shipped
# output/df_model_data.rds carries the refined DV as `pqs_discrimination`
# (keyword counts preserved as `pqs_discrimination_keyword`). This script is
# retained as the frozen derivation + verification record of the
# re-operationalization; its cached panel (df_model_data_sensllm_r2.rds) is
# the equivalence reference asserted by 05_models.R after the promotion, and
# its fits are cross-checked against the new primary fits in
# 05_models_Bayesian.R (expected agreement to sampling noise ~0.02). The
# header below is kept as written at derivation time (the "sensitivity"
# framing predates the promotion).
# ==============================================================================

# ==============================================================================
# # 05_models_Bayesian_sens_llm_R2.R — DV-201 REFINED-OPERATIONALIZED SENSITIVITY,
# # R2 (2026-11-17)
# Second LLM-verified-IN sensitivity: the DV is RE-OPERATIONALIZED with the
# refined rubric (FR decision A, 2026-11-17) instead of being extended
# additively on the primary keyword DV (that is R1, 05_models_Bayesian_sens_llm.R).
#
# DV definition (question level, all ids emitted in epq format by the python
# consolidator explorations/llm_screen/step5_consolidate_fr.py):
#   R2 DV = 1  iff  id in ( refined retained-DV 529  |  FR verified-INs 255 )
#   where refined retained-DV 529 = 524 refined-rubric INs on the arbitration-
#   aware kept-DV universe (1,309 ids screened by 08_llm_screen.py --rubric
#   refined, err 0) + 5 FR force-keeps held IN over refined-OUT
#   (E-000782/2013, E-001218/2022, E-002519/2021, E-007949/2017, E-016119/2015).
#
# VERIFIED NUMBERS (session 2026-11-17):
#   - 529/529 retained-DV ids exist in epq.rds with primary DV=1 (all in-window,
#     re-asserted here) [consolidator universe-integrity assert];
#   - 255 verified-INs exist with primary DV=0, in-window;
#   - 0 overlap retained-DV x verified-INs (asserted);
#   - primary DV1 in-window = 1,319 -> R2 DV = 784 question events in-window
#     (expected per term under assign_term(): VII 378 / VIII 301 / IX 105);
#     delta vs primary = -535 refined-OUT and arbitrated-OUT keyword rows drop
#     out of the DV.
#
# SAMPLE: structural filter identical to 05_models.R (total_questions asserted
# identical to the primary aggregation - the overlay changes DV counts only).
# Nothing in the primary/keyword-sens/R1 namespaces is overwritten: caches and
# tables use *_sensllm_r2 names.
# ==============================================================================
rm(list = ls())
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("lubridate", quietly = TRUE)) { install.packages("lubridate") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(broom.mixed)
library(lubridate)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 0. INPUTS
# ==============================================================================
message("   Loading question data and the two DV re-operationalization lists...")
epq <- readRDS(here("data_processed", "epq.rds"))
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
stopifnot(
  "all 529 refined ids must exist in epq.rds" = all(refined_ids %in% epq$id),
  "all 255 verified-IN ids must exist in epq.rds" = all(verified_ids %in% epq$id),
  "retained-DV and verified-IN lists must not overlap" =
    !any(refined_ids %in% verified_ids),
  "id lists must be unique" = !any(duplicated(c(refined_ids, verified_ids)))
)
dv_r2_ids <- c(refined_ids, verified_ids)
# ==============================================================================
# 1. WINDOW + BASELINE ASSERTS (primary baseline = 1,319; R2 target = 784)
# ==============================================================================
assign_term_sensllmr2 <- function(date_col) {
  case_when(
    date_col >= ymd("2004-07-20") & date_col <= ymd("2009-07-13") ~ "6th",
    date_col >= ymd("2009-07-14") & date_col <= ymd("2014-06-30") ~ "7th",
    date_col >= ymd("2014-07-01") & date_col <= ymd("2019-07-01") ~ "8th",
    date_col >= ymd("2019-07-02") & date_col <= ymd("2024-07-15") ~ "9th",
    TRUE ~ NA_character_
  )
}

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

d_win <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot("primary in-window DV events must be 1,319" =
            sum(d_win$pq_discrimination) == 1319)

# ==============================================================================
# 2. QUESTION-LEVEL REPLACEMENT OVERLAY
# ==============================================================================
epq <- epq %>% mutate(pq_r2 = as.integer(id %in% dv_r2_ids))

d_win2 <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot(
  "R2 in-window DV events must be 784 (529 retained + 255 verified)" =
    sum(d_win2$pq_r2) == 784,
  "the replacement must drop 535 primary DV events in-window" =
    sum(d_win2$pq_r2) - sum(d_win$pq_discrimination) == -535
)
dv_per_term_r2 <- table(d_win2$term_ch[d_win2$pq_r2 == 1L])
message("   R2 DV1 in-window = ", sum(d_win2$pq_r2), " (",
        paste(names(dv_per_term_r2), dv_per_term_r2, sep = " "),
        "); expected VII 378 / VIII 301 / IX 105")
# ==============================================================================
# 3. MEP-YEAR RE-AGGREGATION (mirrors 02_df_setup.R exactly)
# ==============================================================================
legislature_starts <- tibble(
  legislative_term = c("6th", "7th", "8th", "9th"),
  term_start = ymd(c("2004-07-20", "2009-07-14", "2014-07-01", "2019-07-02")),
  term_end = ymd(c("2009-07-13", "2014-06-30", "2019-07-01", "2024-07-15"))
)

questions_r2 <- epq %>%
  mutate(dates = as.Date(date)) %>%
  filter(dates >= as.Date("2004-07-20"), dates <= as.Date("2024-06-08")) %>%
  mutate(legislative_term = assign_term_sensllmr2(dates)) %>%
  left_join(legislature_starts, by = "legislative_term") %>%
  mutate(year_index = (interval(term_start, dates) %/% years(1)) + 1) %>%
  mutate(leg_year = paste0(legislative_term, year_index)) %>%
  filter(year_index <= 5) %>%
  group_by(mep_id, leg_year) %>%
  summarise(
    pqs_discrimination_r2 = sum(pq_r2 == 1L, na.rm = TRUE),
    total_questions_r2 = n(),
    .groups = "drop"
  )
stopifnot(
  "questions_r2 must not be empty" = nrow(questions_r2) > 0
)

# ==============================================================================
# 4. ESTIMATION SAMPLE (mirrors 05_models.R: indicators join, MIPEX filter)
# ==============================================================================
problem_indicators <- read_csv(here("output", "problem_indicators.csv"),
                               show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_r2_src <- read_csv(here("output", "df_merged_3.csv"),
                             show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

df_merged_r2_src <- df_merged_r2_src %>%
  mutate(mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE))

# Sensitivity overlay: replace DV counts only; total_questions asserted identical
df_merged_r2_src <- df_merged_r2_src %>%
  left_join(questions_r2, by = c("mep_id", "leg_year")) %>%
  mutate(
    pqs_discrimination_r2 = replace_na(pqs_discrimination_r2, 0L),
    total_questions_r2 = replace_na(total_questions_r2, 0L),
    total_questions = replace_na(total_questions, 0L)
  )
stopifnot(
  "total_questions must be identical between primary and R2 aggregation" =
    all(df_merged_r2_src$total_questions_r2 == df_merged_r2_src$total_questions)
)
df_merged_r2_src <- df_merged_r2_src %>%
  mutate(pqs_discrimination = pqs_discrimination_r2) %>%
  select(-pqs_discrimination_r2, -total_questions_r2)

paesi_da_escludere <- df_merged_r2_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  group_by(country) %>%
  summarise(pct_na_mipex = mean(is.na(mipex_antidiscrimination_score)),
            .groups = "drop") %>%
  filter(pct_na_mipex == 1) %>%
  pull(country)

df_model_data_r2 <- df_merged_r2_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!country %in% paesi_da_escludere) %>%
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority,
    misery_index, mipex_center
  )
message("   N (R2 estimation sample): ", nrow(df_model_data_r2),
        " | DV events in sample: ", sum(df_model_data_r2$pqs_discrimination))
saveRDS(df_model_data_r2, here("output", "df_model_data_sensllm_r2.rds"))

# Surfacing audit by sub-source (pre-registered caveat): authors outside the
# MIPEX/ESS sample cannot surface (cf. 1,136 -> 1,072 keyword-sens precedent).
panel_key_audit <- function(ids, label) {
  keys <- epq %>%
    filter(id %in% ids) %>%
    mutate(dates = as.Date(date),
           legislative_term = assign_term_sensllmr2(dates)) %>%
    left_join(legislature_starts, by = "legislative_term") %>%
    mutate(year_index = (interval(term_start, dates) %/% years(1)) + 1,
           leg_year = paste0(legislative_term, year_index)) %>%
    filter(year_index <= 5) %>%
    distinct(id, mep_id, leg_year)
  surf <- keys %>% semi_join(df_model_data_r2, by = c("mep_id", "leg_year"))
  message("   Surfacing audit [", label, "]: ", nrow(surf), " of ", nrow(keys),
          " questions sit on estimation-sample (mep_id, leg_year) keys",
          " (", n_distinct(surf$mep_id), " distinct MEPs surfaced)")
}
panel_key_audit(refined_ids, "refined retained-DV")
panel_key_audit(verified_ids, "verified-INs")
n_tail_protocol <- sum(as.Date(epq$date)[match(dv_r2_ids, epq$id)] >
                         as.Date("2024-06-08"), na.rm = TRUE)
message("   Protocol-tail note: ", n_tail_protocol,
        " DV-defining question(s) dated after the 05_models.R aggregation",
        " window end (2024-06-08) do not reach the MEP-year panel — same",
        " protocol treatment as the primary DV.")
# ==============================================================================
# 5. FITS: M1_sensllm_r2 (no LIBE) and M2_sensllm_r2 (+LIBE), same priors
#    and sampler settings as the primary two-estimand fits
# ==============================================================================
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting Bayesian M1_sensllm_r2 (Minority x MIPEX, no LIBE control)...")
# iter 4000 / warmup 1500 from the start (see R1 header note about the NB
# shape parameter and the M4 ESS gate). Fresh *_r2 cache names: delete
# output/bayesian_model_m1_sensllm_r2.rds / ..._m2_sensllm_r2.rds before
# re-running with a changed spec.
bayesian_model_m1_sensllm_r2 <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_r2,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 4000, warmup = 1500, cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m1_sensllm_r2")
)

message("   Fitting Bayesian M2_sensllm_r2 (+ LIBE committee control)...")
bayesian_model_m2_sensllm_r2 <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family + libe +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_r2,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 4000, warmup = 1500, cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m2_sensllm_r2")
)

# ==============================================================================
# 6. CONVERGENCE GATE (same M4 gate as the primary two-estimand fits)
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
convergence_gate(bayesian_model_m1_sensllm_r2, "M1_sensllm_r2")
convergence_gate(bayesian_model_m2_sensllm_r2, "M2_sensllm_r2")

# ==============================================================================
# 7. RESULTS + COMPARISON AGAINST THE PRIMARY TWO-ESTIMAND FITS
# ==============================================================================
final_results_r2 <- bind_rows(
  broom.mixed::tidy(bayesian_model_m1_sensllm_r2, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M1_sensllm R2 (no LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high),
  broom.mixed::tidy(bayesian_model_m2_sensllm_r2, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M2_sensllm R2 (+LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
)
write_csv(final_results_r2, here("output", "bayesian_sensllm_r2_model_results.csv"))
message("R2 sensitivity results saved to: output/bayesian_sensllm_r2_model_results.csv")

interaction_results_r2 <- final_results_r2 %>% filter(grepl(":", term))
print("--- R2 Interaction Effects (M1/M2_sensllm_r2): Minority x MIPEX ---")
print(knitr::kable(interaction_results_r2, format = "markdown"))

# Focal-coefficient comparison: primary estimands vs the R2 re-operationalized DV.
comparison_r2 <- tryCatch({
  primary <- read_csv(here("output", "bayesian_model_results.csv"), show_col_types = FALSE)
  key_terms <- c("minority", "mipex_center", "minority:mipex_center", "libe")
  bind_rows(
    primary %>% filter(model %in% c("M1_total (no LIBE control)",
                                    "M2_direct (+LIBE control)"),
                       term %in% key_terms),
    final_results_r2 %>% filter(term %in% key_terms)
  )
}, error = function(e) final_results_r2 %>% filter(grepl("minority|mipex|libe", term)))
write_csv(comparison_r2, here("output", "bayesian_sensllm_r2_vs_primary.csv"))
print("--- Focal coefficients: primary vs R2 refined-operationalized DV ---")
print(knitr::kable(comparison_r2, format = "markdown"))
