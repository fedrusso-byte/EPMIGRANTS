# ==============================================================================
# NOTE (2026-11-17, DV promotion): following the promotion of the refined
# (R2) operationalization to the PRIMARY specification
# (scripts/05_models.R § 1b, scripts/05_models_Bayesian.R), the keyword-based
# DV referred to below as "primary" is the DEMOTED robustness
# operationalization (Appendix B: 05_models_Bayesian_sens_keyword.R). R1
# remains documented as the additive variant — keyword kept-DV union the 255
# FR verified-INs — and its numbers are quoted as generated on 2026-11-17.
# ==============================================================================

# ==============================================================================
# # 05_models_Bayesian_sens_llm.R — DV-201 LLM-VERIFIED-IN SENSITIVITY, R1 (2026-11-17)
# Sensitivity of the two-estimand Bayesian models (M1_total / M2_direct) to the
# LLM screening verified-INs (FR adjudication sheet, 2026-11-17): the 621-row
# candidate pool (step4 majority export, dual refined-rubric runs) was fully
# coded by FR => 258 IN / 363 OUT. After the window filter, 255 sheet-INs are
# ADDITIVE DV events on top of the primary kept-DV rule (258 - 3 pre-window
# corpus rows before the VII term start 2009-07-14: E-3845/2009, E-3675/2009,
# E-4252/2009). The 255 verified-INs have zero overlap with the kept-DV
# universe (asserted in the consolidator) and are DV=0 in the primary import,
# so the overlay flips pq_discrimination 0 -> 1 for exactly those ids.
#
# VERIFIED NUMBERS (session 2026-11-17, python consolidator
# explorations/llm_screen/step5_consolidate_fr.py):
#   - 258/258 sheet-INs canon-match data_processed/epq.csv (0 collisions);
#   - 255/258 in-window (VII 115 / VIII 102 / IX 38);
#   - 0 overlap with data/dv201_llm_keptdv_ids.csv (1,309 kept-DV ids);
#   - primary DV1 in-window = 1,319 -> R1 DV = 1,319 + 255 = 1,574
#     (VII 723 / VIII 589 / IX 262 expected under assign_term()).
#
# SAMPLE: rebuilt exactly like 05_models.R / 05_models_Bayesian_sens.R (problem
# indicators join, MIPEX-only structural filter, same drop_na list), with the
# additive overlay applied BEFORE the (mep_id, leg_year) aggregation.
# total_questions is asserted identical to the primary aggregation (the overlay
# changes DV counts only). Caveat reported at run time: because some sheet-IN
# authors sit outside the MIPEX/ESS sample (cf. the 1,136->1,072 keyword-sens
# precedent), the script reports how many of the 255 verified-INs surface in
# the estimation sample panel (mep_id, leg_year) keys.
# Nothing in the primary or keyword-sens output namespace is overwritten:
# caches/tables use *_sensllm names.
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
message("   Loading question data and FR verified-IN record...")
epq <- readRDS(here("data_processed", "epq.rds"))
verified_in <- read_csv(here("data", "dv201_llm_verified_in_ids.csv"),
                        show_col_types = FALSE)
stopifnot(
  "verified-IN list must have exactly 255 rows (window-filtered)" =
    nrow(verified_in) == 255
)
verified_ids <- verified_in$id
stopifnot(
  "all 255 verified-IN ids must exist in epq.rds" =
    all(verified_ids %in% epq$id),
  "verified-IN ids must be unique" = !any(duplicated(verified_ids))
)

# ==============================================================================
# 1. WINDOW ASSERTS (primary baseline = 1,319; overlay target = 1,574)
# ==============================================================================
assign_term_sensllm <- function(date_col) {
  case_when(
    date_col >= ymd("2004-07-20") & date_col <= ymd("2009-07-13") ~ "6th",
    date_col >= ymd("2009-07-14") & date_col <= ymd("2014-06-30") ~ "7th",
    date_col >= ymd("2014-07-01") & date_col <= ymd("2019-07-01") ~ "8th",
    date_col >= ymd("2019-07-02") & date_col <= ymd("2024-07-15") ~ "9th",
    TRUE ~ NA_character_
  )
}

stopifnot(
  "primary DV flag must be binary" =
    all(epq$pq_discrimination %in% c(0L, 1L)),
  "none of the 255 verified-INs may already be DV=1 in the primary import" =
    all(epq$pq_discrimination[match(verified_ids, epq$id)] == 0L)
)

d_win <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllm(as.Date(date)))
stopifnot("primary in-window DV events must be 1,319" =
            sum(d_win$pq_discrimination) == 1319)
message("   Baseline OK: primary DV1 in-window = ",
        sum(d_win$pq_discrimination), " (",
        paste(names(table(d_win$term_ch[d_win$pq_discrimination == 1L])),
              table(d_win$term_ch[d_win$pq_discrimination == 1L]), sep = " "),
        ")")

# ==============================================================================
# 2. QUESTION-LEVEL ADDITIVE OVERLAY
# ==============================================================================
epq <- epq %>%
  mutate(pq_sensllm = as.integer((id %in% verified_ids) | pq_discrimination == 1L))
# (id %in% verified_ids) is additive: the 3 pre-window sheet-INs (E-3845/2009,
# E-3675/2009, E-4252/2009) are NOT overlay targets and keep their primary flag.

d_win2 <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllm(as.Date(date)))
stopifnot(
  "R1 in-window DV events must be 1,574 (1,319 + 255)" =
    sum(d_win2$pq_sensllm) == 1574,
  "the overlay must add exactly 255 in-window DV events" =
    sum(d_win2$pq_sensllm) - sum(d_win$pq_discrimination) == 255
)
dv_per_term_sensllm <- table(d_win2$term_ch[d_win2$pq_sensllm == 1L])
message("   R1 DV1 in-window = ", sum(d_win2$pq_sensllm), " (",
        paste(names(dv_per_term_sensllm), dv_per_term_sensllm, sep = " "),
        "); expected VII 723 / VIII 589 / IX 262")

# ==============================================================================
# 3. MEP-YEAR RE-AGGREGATION (mirrors 02_df_setup.R exactly)
# ==============================================================================
legislature_starts <- tibble(
  legislative_term = c("6th", "7th", "8th", "9th"),
  term_start = ymd(c("2004-07-20", "2009-07-14", "2014-07-01", "2019-07-02")),
  term_end = ymd(c("2009-07-13", "2014-06-30", "2019-07-01", "2024-07-15"))
)

questions_sensllm <- epq %>%
  mutate(dates = as.Date(date)) %>%
  filter(dates >= as.Date("2004-07-20"), dates <= as.Date("2024-06-08")) %>%
  mutate(legislative_term = assign_term_sensllm(dates)) %>%
  left_join(legislature_starts, by = "legislative_term") %>%
  mutate(year_index = (interval(term_start, dates) %/% years(1)) + 1) %>%
  mutate(leg_year = paste0(legislative_term, year_index)) %>%
  filter(year_index <= 5) %>%
  group_by(mep_id, leg_year) %>%
  summarise(
    pqs_discrimination_sensllm = sum(pq_sensllm == 1L, na.rm = TRUE),
    total_questions_sensllm = n(),
    .groups = "drop"
  )
stopifnot(
  "questions_sensllm must not be empty" = nrow(questions_sensllm) > 0
)
# ==============================================================================
# 4. ESTIMATION SAMPLE (mirrors 05_models.R: indicators join, MIPEX filter)
# ==============================================================================
problem_indicators <- read_csv(here("output", "problem_indicators.csv"),
                               show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_sensllm_src <- read_csv(here("output", "df_merged_3.csv"),
                                  show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

df_merged_sensllm_src <- df_merged_sensllm_src %>%
  mutate(mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE))

# Sensitivity overlay: replace DV counts only; total_questions asserted identical
df_merged_sensllm_src <- df_merged_sensllm_src %>%
  left_join(questions_sensllm, by = c("mep_id", "leg_year")) %>%
  mutate(
    pqs_discrimination_sensllm = replace_na(pqs_discrimination_sensllm, 0L),
    total_questions_sensllm = replace_na(total_questions_sensllm, 0L),
    total_questions = replace_na(total_questions, 0L)
  )
stopifnot(
  "total_questions must be identical between primary and sensllm aggregation" =
    all(df_merged_sensllm_src$total_questions_sensllm ==
          df_merged_sensllm_src$total_questions)
)
df_merged_sensllm_src <- df_merged_sensllm_src %>%
  mutate(pqs_discrimination = pqs_discrimination_sensllm) %>%
  select(-pqs_discrimination_sensllm, -total_questions_sensllm)

paesi_da_escludere <- df_merged_sensllm_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  group_by(country) %>%
  summarise(pct_na_mipex = mean(is.na(mipex_antidiscrimination_score)),
            .groups = "drop") %>%
  filter(pct_na_mipex == 1) %>%
  pull(country)

df_model_data_sensllm <- df_merged_sensllm_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!country %in% paesi_da_escludere) %>%
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority,
    misery_index, mipex_center
  )
message("   N (R1 estimation sample): ", nrow(df_model_data_sensllm),
        " | DV events in sample: ", sum(df_model_data_sensllm$pqs_discrimination))
saveRDS(df_model_data_sensllm, here("output", "df_model_data_sensllm.rds"))

# Surfacing audit (pre-registered caveat): how many of the 255 verified-INs
# reach the estimation-sample panel? Sheet-IN authors outside the MIPEX/ESS
# sample cannot surface (cf. the 1,136 -> 1,072 keyword-sens precedent).
verified_panel_keys <- epq %>%
  filter(id %in% verified_ids) %>%
  mutate(dates = as.Date(date),
         legislative_term = assign_term_sensllm(dates)) %>%
  left_join(legislature_starts, by = "legislative_term") %>%
  mutate(year_index = (interval(term_start, dates) %/% years(1)) + 1,
         leg_year = paste0(legislative_term, year_index)) %>%
  filter(year_index <= 5) %>%
  distinct(id, mep_id, leg_year, dates)
surfaced <- verified_panel_keys %>%
  semi_join(df_model_data_sensllm, by = c("mep_id", "leg_year"))
message("   Surfacing audit: ", nrow(surfaced), " of ", nrow(verified_panel_keys),
        " verified-IN questions sit on estimation-sample (mep_id, leg_year) keys",
        " (", n_distinct(surfaced$mep_id), " distinct MEPs surfaced)")
n_tail_protocol <- sum(as.Date(epq$date)[match(verified_ids, epq$id)] >
                         as.Date("2024-06-08"), na.rm = TRUE)
message("   Protocol-tail note: ", n_tail_protocol,
        " verified-IN(s) dated after the 05_models.R aggregation window end",
        " (2024-06-08) do not reach the MEP-year panel — same protocol",
        " treatment as the primary DV.")
# ==============================================================================
# 5. FITS: M1_sensllm (no LIBE) and M2_sensllm (+LIBE), same priors/settings
#    as the primary two-estimand fits (05_models_Bayesian.R)
# ==============================================================================
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting Bayesian M1_sensllm (Minority x MIPEX, no LIBE control)...")
# iter 4000 / warmup 1500 from the start: the keyword-sens and M2_direct
# precedent showed the NB `shape` parameter needs ~2.5x sampling draws to pass
# the M4 ESS gate in this ZINB geometry. `brm(file = ...)` caches by path:
# delete output/bayesian_model_m1_sensllm.rds / ..._m2_sensllm.rds before
# re-running with a changed spec (fresh dv201_sensllm_* names, no stale cache).
bayesian_model_m1_sensllm <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_sensllm,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 4000, warmup = 1500, cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m1_sensllm")
)

message("   Fitting Bayesian M2_sensllm (+ LIBE committee control)...")
bayesian_model_m2_sensllm <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family + libe +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_sensllm,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 4000, warmup = 1500, cores = 4,
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_m2_sensllm")
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
convergence_gate(bayesian_model_m1_sensllm, "M1_sensllm")
convergence_gate(bayesian_model_m2_sensllm, "M2_sensllm")

# ==============================================================================
# 7. RESULTS + COMPARISON AGAINST THE PRIMARY TWO-ESTIMAND FITS
# ==============================================================================
final_results_sensllm <- bind_rows(
  broom.mixed::tidy(bayesian_model_m1_sensllm, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M1_sensllm R1 (no LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high),
  broom.mixed::tidy(bayesian_model_m2_sensllm, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M2_sensllm R1 (+LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
)
write_csv(final_results_sensllm, here("output", "bayesian_sensllm_model_results.csv"))
message("R1 sensitivity results saved to: output/bayesian_sensllm_model_results.csv")

interaction_results_sensllm <- final_results_sensllm %>% filter(grepl(":", term))
print("--- R1 Interaction Effects (M1_sensllm / M2_sensllm): Minority x MIPEX ---")
print(knitr::kable(interaction_results_sensllm, format = "markdown"))

# Focal-coefficient comparison vs primary (M1_total / M2_direct) and the
# keyword-extension sensitivity (M1_sens / M2_sens), same estimand pairs.
comparison_sensllm <- tryCatch({
  primary <- read_csv(here("output", "bayesian_model_results.csv"), show_col_types = FALSE)
  key_terms <- c("minority", "mipex_center", "minority:mipex_center", "libe")
  bind_rows(
    primary %>% filter(model %in% c("M1_total (no LIBE control)",
                                    "M2_direct (+LIBE control)"),
                       term %in% key_terms),
    final_results_sensllm %>% filter(term %in% key_terms)
  )
}, error = function(e) final_results_sensllm %>% filter(grepl("minority|mipex|libe", term)))
write_csv(comparison_sensllm, here("output", "bayesian_sensllm_vs_primary.csv"))
print("--- Focal coefficients: primary vs keyword-sens vs R1 LLM verified-INs ---")
print(knitr::kable(comparison_sensllm, format = "markdown"))
