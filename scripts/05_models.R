# ==============================================================================
# # 05_models.R — Frequentist mirror of the Bayesian primary estimands (MIPEX-only)
# Fits the two glmmTMB twins of the promoted Bayesian primary (refined LLM DV):
#   M1_total (no LIBE control) and M2_direct (LIBE included as regressor),
# plus the shared MIPEX-only estimation sample (output/df_model_data.rds),
# the performance/LR comparison and the two-estimand coefficient table.
# History: the former 4-step specification ladder (zinb_model1-4) was retired
# on 2026-11-18 (audit finding 2) — only ladder M4 coincided with M2_direct
# and M1-M3 matched no manuscript estimand; the ladder fits + comparison
# table + both stale figures live in output/archive_freq_mirror_2026-11-18/
# (md5 manifest). The legacy country-FE variant is quarantined in
# scripts/archive/.
# ==============================================================================

# free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("glmmTMB", quietly = TRUE)) { install.packages("glmmTMB") }
if (!requireNamespace("patchwork", quietly = TRUE)) { install.packages("patchwork") }
if (!requireNamespace("marginaleffects", quietly = TRUE)) { install.packages("marginaleffects") }
if (!requireNamespace("performance", quietly = TRUE)) { install.packages("performance") }
if (!requireNamespace("see", quietly = TRUE)) { install.packages("see") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }
if (!requireNamespace("kableExtra", quietly = TRUE)) { install.packages("kableExtra") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("emmeans", quietly = TRUE)) { install.packages("emmeans") }
if (!requireNamespace("scales", quietly = TRUE)) { install.packages("scales") }

library(tidyverse)
library(glmmTMB)
library(lme4)
library(patchwork)
library(marginaleffects)
library(performance)
library(see)
library(here)
library(knitr)
library(kableExtra)
library(broom.mixed)
library(emmeans)
library(scales)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)

# Helper Corretto per estrarre SOLO gli effetti fissi condizionali
tidy_exp_coefs <- function(model) {
  broom.mixed::tidy(model, component = "cond") %>%
    # CRITICO: Teniamo solo gli effetti fissi, eliminando le stime della varianza casuale
    filter(effect == "fixed") %>%
    mutate(
      exp_estimate = exp(estimate),
      estimate = round(estimate, 3),
      exp_estimate = round(exp_estimate, 2),
      std.error = round(std.error, 3),
      pval_fmt = sprintf("%.3f", p.value),
      pval_str = case_when(
        p.value < 0.001 ~ paste0(pval_fmt, " ***"),
        p.value < 0.01  ~ paste0(pval_fmt, " **"),
        p.value < 0.05  ~ paste0(pval_fmt, " *"),
        p.value < 0.1   ~ paste0(pval_fmt, " ."),
        TRUE            ~ pval_fmt
      )
    ) %>%
    dplyr::select(term, estimate, exp_estimate, std.error, pval_str)
}

# Load data ####
message("   Loading updated MEP-year dataset...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

# CORREZIONE 1: Sanity check aggiornato con la nuova variabile dipendente pqs_discrimination
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("pqs_discrimination", "total_questions", "gender",
                                     "party_family", "libe", "misery_index",
                                     "mipex_antidiscrimination_score", 
                                     "mep_id", "country", "minority") %in% names(df_merged_3))
)

# 1. CREAZIONE DELLE VARIABILI CENTRATE
df_merged_3 <- df_merged_3 %>%
  mutate(
    mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE)
  )

# ==============================================================================
# 1b. DV RE-OPERATIONALIZATION — LLM-REFINED PRIMARY DV (2026-11-17) ####
# ==============================================================================
# Promotion of the LLM-refined (R2) DV to the PRIMARY specification (decision
# FR, 2026-11-17; frozen derivation: scripts/05_models_Bayesian_sens_llm_R2.R).
# Question-level rule:
#   pq_R2 = 1  iff  id in (refined retained-DV 529 | FR verified-INs 255)
#   => 784 question-level DV events in-window (VII 378 / VIII 301 / IX 105):
#   the 1,319 keyword kept-DV events MINUS 535 refined/arbitrated-OUT PLUS 255
#   verified-INs. The former keyword counts are retained as
#   `pqs_discrimination_keyword` and define the demoted appendix robustness
#   check (05_models_Bayesian_sens_keyword.R); pre-promotion artifacts live in
#   output/archive_spec_promotion_2026-11-17/. Panel structure untouched:
#   total_questions is asserted identical to the primary aggregation.
# lubridate:: is used explicitly (lubridate ships with tidyverse but is not
# attached here); everything else mirrors the R2 derivation script verbatim.
message("   [DV promotion] Loading the LLM-refined re-operationalization lists...")
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

# Baseline window asserts (primary keyword baseline must replicate 2026-11-13)
d_win <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot("primary in-window DV events must be 1,319" =
            sum(d_win$pq_discrimination) == 1319)

# Question-level REPLACEMENT overlay (DV counts re-defined, ids unchanged)
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
message("   [DV promotion] R2 DV1 in-window = ", sum(d_win2$pq_r2), " (",
        paste(names(dv_per_term_r2), dv_per_term_r2, sep = " "),
        "); expected VII 378 / VIII 301 / IX 105")


# MEP-year re-aggregation of the refined DV (mirrors 02_df_setup.R exactly)
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

# Panel overlay: refined counts in, keyword counts kept under a new name; the
# aggregation row-coverage is asserted identical to the primary panel
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
        "pqs_discrimination_keyword = former keyword counts (appendix).")

# ==============================================================================
# 2. PULIZIA STRUTTURALE DEI PAESI E FILTRO CASI (Listwise Deletion) ####
# ==============================================================================
# MIPEX-only (2026-11-12): structural exclusion is based on MIPEX coverage only
# (Malta is not assessed by MIPEX). CMP and the hardcoded claim-making feature
# no longer drive sample selection: HU, SK, LU and RO are retained.
message("   Pulizia preventiva dei paesi strutturalmente privi di dati MIPEX...")

paesi_da_escludere <- df_merged_3 %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  group_by(country) %>%
  summarise(
    pct_na_mipex = mean(is.na(mipex_antidiscrimination_score)),
    .groups = "drop"
  ) %>%
  filter(pct_na_mipex == 1) %>%
  pull(country)

message(paste("🚫 Paesi esclusi strutturalmente (100% dati mancanti):", paste(paesi_da_escludere, collapse = ", ")))

df_model_data <- df_merged_3 %>% 
  filter(legislative_term %in% c("7th", "8th", "9th")) %>% 
  filter(!country %in% paesi_da_escludere) %>%
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority, 
    misery_index, mipex_center
  )

message(paste("✅ N finale del dataset purificato per i modelli:", nrow(df_model_data)))
saveRDS(df_model_data, here("output", "df_model_data.rds"))
message("   Dataset for models saved to: output/df_model_data.rds")

# ==============================================================================
# 2a. PROMOTION EQUIVALENCE ASSERT + SURFACING AUDIT (2026-11-17) ####
# ==============================================================================
# The shipped panel must equal the cached R2 derivation panel, and equal the
# archived (pre-promotion) keyword panel apart from the DV swap. The audit
# messages are informational; the stopifnots fail the pipeline.
stopifnot(
  "shipped panel must have 10,955 rows (promotion equivalence)" =
    nrow(df_model_data) == 10955,
  "refined DV must have 739 in-sample events" =
    sum(df_model_data$pqs_discrimination) == 739,
  "keyword DV must have 1,244 in-sample events" =
    sum(df_model_data$pqs_discrimination_keyword) == 1244
)
ref_r2 <- readRDS(here("output", "df_model_data_sensllm_r2.rds"))
ref_kw <- readRDS(here("output", "archive_spec_promotion_2026-11-17", "df_model_data.rds"))
key_of <- function(d) paste(d$mep_id, d$leg_year)
stopifnot(
  "panel keys must be unique" = !any(duplicated(key_of(df_model_data))),
  "row set must match the R2 derivation panel" =
    setequal(key_of(df_model_data), key_of(ref_r2)),
  "row set must match the archived keyword panel" =
    setequal(key_of(df_model_data), key_of(ref_kw))
)
i_r2 <- match(key_of(df_model_data), key_of(ref_r2))
i_kw <- match(key_of(df_model_data), key_of(ref_kw))
stopifnot(
  "refined DV must equal the R2 derivation panel" =
    all(df_model_data$pqs_discrimination == ref_r2$pqs_discrimination[i_r2]),
  "total_questions must equal the R2 derivation panel" =
    all(df_model_data$total_questions == ref_r2$total_questions[i_r2]),
  "total_questions must equal the archived keyword panel" =
    all(df_model_data$total_questions == ref_kw$total_questions[i_kw]),
  "keyword DV must equal the archived keyword panel" =
    all(df_model_data$pqs_discrimination_keyword == ref_kw$pqs_discrimination[i_kw])
)
message("✅ [DV promotion] Equivalence asserts passed: new panel identical to ",
        "df_model_data_sensllm_r2.rds and to the archived keyword panel ",
        "(DV swap only; 739 refined vs 1,244 keyword in-sample events).")

# Surfacing audit (pre-registered caveat), re-run for the canonical log
panel_key_audit_r2 <- function(ids, label) {
  keys <- epq %>%
    filter(id %in% ids) %>%
    mutate(dates = as.Date(date),
           legislative_term = assign_term_sensllmr2(dates)) %>%
    left_join(legislature_starts, by = "legislative_term") %>%
    mutate(year_index = (lubridate::interval(term_start, dates) %/% lubridate::years(1)) + 1,
           leg_year = paste0(legislative_term, year_index)) %>%
    filter(year_index <= 5) %>%
    distinct(id, mep_id, leg_year)
  surf <- keys %>% semi_join(df_model_data, by = c("mep_id", "leg_year"))
  message("   [DV promotion] Surfacing audit [", label, "]: ", nrow(surf),
          " of ", nrow(keys),
          " questions sit on estimation-sample (mep_id, leg_year) keys (",
          n_distinct(surf$mep_id), " distinct MEPs surfaced)")
}
panel_key_audit_r2(refined_ids, "refined retained-DV")
panel_key_audit_r2(verified_ids, "verified-INs")
n_tail_protocol <- sum(as.Date(epq$date)[match(dv_r2_ids, epq$id)] >
                         as.Date("2024-06-08"), na.rm = TRUE)
message("   [DV promotion] Protocol-tail note: ", n_tail_protocol,
        " DV-defining question(s) dated after the aggregation window end ",
        "(2024-06-08) do not reach the MEP-year panel — same protocol ",
        "treatment as the keyword DV.")

# Housekeeping: release the question-level objects used by the overlay
rm(epq, refined_keptdv, verified_in, refined_ids, verified_ids, dv_r2_ids,
   iv_r, iv_v, d_win, d_win2, dv_per_term_r2, questions_r2,
   legislature_starts, assign_term_sensllmr2, panel_key_audit_r2,
   key_of, ref_r2, ref_kw, i_r2, i_kw, n_tail_protocol)


# ==============================================================================
# 3. STIMA DEI MODELLI — FREQUENTIST MIRROR OF THE BAYESIAN PRIMARY ####
# ==============================================================================
# Remediation of audit finding 2 (FR directive 2026-11-18): the frequentist
# engine is a robustness check on the ESTIMATION PARADIGM, so it re-fits
# exactly the two Bayesian primary estimands (05_models_Bayesian.R, promoted
# refined DV) by maximum likelihood via glmmTMB:
#   M1_total  ~ gender + misery_index + party_family + minority * mipex_center
#               + offset(log(total_questions + 1)) + (1 | mep_id) + (1 | country)
#   M2_direct ~ M1_total + libe
# family nbinom2 with intercept-only zero inflation
# (brms zero_inflated_negbinomial twin). Spec-parity, finite-SE and drift
# gates below halt the pipeline on any mismatch. The retired 4-step ladder
# lives in output/archive_freq_mirror_2026-11-18/ (md5 manifest).

# Definiamo un blocco di controllo robusto comune ai due modelli
controllo_ottimizzatore <- glmmTMBControl(
  optimizer = nlminb,
  optArgs = list(iter.max = 3000, eval.max = 3000)
)

# --- Analogo frequentista di M1_total Bayesian (senza il regressore LIBE) -----
message("   Fitting zinb_model_m1_total (mirror of Bayesian M1_total)...")
zinb_model_m1_total <- glmmTMB(
  pqs_discrimination ~
    gender + misery_index + party_family +
    minority * mipex_center +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  family = nbinom2,
  ziformula = ~ 1,
  data = df_model_data,
  control = controllo_ottimizzatore
)
saveRDS(zinb_model_m1_total, here("output", "zinb_model_m1_total.rds"))

# --- Analogo frequentista di M2_direct Bayesian (aggiunge LIBE) --------------
message("   Fitting zinb_model_m2_direct (mirror of Bayesian M2_direct)...")
zinb_model_m2_direct <- glmmTMB(
  pqs_discrimination ~
    gender + misery_index + party_family + libe +
    minority * mipex_center +
    offset(log(total_questions + 1)) +
    (1 | mep_id) + (1 | country),
  family = nbinom2,
  ziformula = ~ 1,
  data = df_model_data,
  control = controllo_ottimizzatore
)
saveRDS(zinb_model_m2_direct, here("output", "zinb_model_m2_direct.rds"))

# --- Spec-parity and convergence gates (halt the pipeline on any failure) ----
stopifnot(
  "M1_total must carry the minority x mipex_center interaction" =
    "minority:mipex_center" %in% names(fixef(zinb_model_m1_total)$cond),
  "M1_total must NOT carry libe (total-effect estimand)" =
    !"libe" %in% names(fixef(zinb_model_m1_total)$cond),
  "M2_direct must carry libe (direct-effect estimand)" =
    "libe" %in% names(fixef(zinb_model_m2_direct)$cond),
  "M1_total must be nested in M2_direct (identical terms + libe)" =
    setequal(names(fixef(zinb_model_m1_total)$cond),
             setdiff(names(fixef(zinb_model_m2_direct)$cond), "libe")),
  "M1_total conditional fixed-effect SEs must all be finite" =
    all(is.finite(sqrt(diag(vcov(zinb_model_m1_total)$cond)))),
  "M2_direct conditional fixed-effect SEs must all be finite" =
    all(is.finite(sqrt(diag(vcov(zinb_model_m2_direct)$cond))))
)
message("   [mirror] Spec-parity + finite-SE gates passed on both fits.")

# --- Drift gate vs the archived ladder M4 (pre-existing M2_direct twin) -------
# zinb_model4 (archived before the rebuild, 2026-11-18) was fit under exactly
# the M2_direct formula on the same promoted panel: the refreshed fit must
# reproduce its estimates to numerical precision. Halts on silent
# specification or sample drift.
arch_m4 <- readRDS(here("output", "archive_freq_mirror_2026-11-18", "zinb_model4.rds"))
fe_new <- fixef(zinb_model_m2_direct)
fe_old <- fixef(arch_m4)
stopifnot(
  "new M2_direct terms must match the archived ladder M4 terms" =
    setequal(names(fe_new$cond), names(fe_old$cond)),
  "new M2_direct must reproduce the archived ladder M4 fixed effects" =
    isTRUE(all.equal(unname(fe_new$cond), unname(fe_old$cond), tolerance = 1e-6)),
  "new M2_direct must reproduce the archived ladder M4 zero-inflation intercept" =
    isTRUE(all.equal(unname(fe_new$zi), unname(fe_old$zi), tolerance = 1e-6))
)
message(sprintf(
  "   [mirror] Drift gate vs archived ladder M4 passed (max |dcoef| = %.2e).",
  max(abs(fe_new$cond - fe_old$cond))
))
rm(arch_m4, fe_new, fe_old)


# ==============================================================================
# 4. CONFRONTO PERFORMANCE E TEST LR SU LIBE (M1_total vs M2_direct) ####
# ==============================================================================
message("   Generazione tabelle di confronto delle performance (2 estimands)...")

model_comparison <- performance::compare_performance(
  zinb_model_m1_total, zinb_model_m2_direct,
  metrics = c("RMSE", "AIC", "BIC")
)

essential_comparison <- model_comparison %>%
  as_tibble() %>%
  mutate(
    Model_Label = case_when(
      Name == "zinb_model_m1_total"  ~ "M1_total: minority x MIPEX (no LIBE)",
      Name == "zinb_model_m2_direct" ~ "M2_direct: minority x MIPEX (+ LIBE)",
      TRUE ~ Name
    ),
    RMSE = round(RMSE, 3),
    AIC = round(AIC, 1),
    BIC = round(BIC, 1)
  ) %>%
  dplyr::select(Model = Model_Label, RMSE, AIC, BIC) %>%
  arrange(AIC)

print("--- Tabella Comparativa delle Performance ---")
print(essential_comparison)

# LR test on the only difference between the two estimands: the LIBE coefficient
anova_results <- anova(zinb_model_m1_total, zinb_model_m2_direct, test = "Chisq")
print("--- Likelihood-ratio test: aggiunta di libe (M1_total -> M2_direct) ---")
print(anova_results)

# ==============================================================================
# 6. ESTRAZIONE COEFFICIENTI (DUE ESTIMANDS, TABELLA MIRROR) ####
# ==============================================================================
message("   Estrazione e formattazione dei coefficienti per i 2 estimands...")

coef_m1_total <- tidy_exp_coefs(zinb_model_m1_total) %>%
  rename_with(~paste0(., "_M1_total"), -term)
coef_m2_direct <- tidy_exp_coefs(zinb_model_m2_direct) %>%
  rename_with(~paste0(., "_M2_direct"), -term)

tabella_coefficienti <- coef_m1_total %>%
  full_join(coef_m2_direct, by = "term") %>%
  rename(Predictor = term)

print("--- Anteprima dei Coefficienti (Componente Condizionale) ---")
print(head(tabella_coefficienti, 10))

write_csv(tabella_coefficienti, here("output", "model_coefficients_comparison.csv"))
message("🎉 Tabella dei coefficienti salvata in: output/model_coefficients_comparison.csv")

# ------------------------------------------------------------------------------
# Versione compatta per il terminale
# ------------------------------------------------------------------------------
tabella_compatta <- tabella_coefficienti %>%
  mutate(
    `M1_total (no LIBE)`  = if_else(!is.na(estimate_M1_total),
                                    paste0(estimate_M1_total, " (IRR: ",
                                           exp_estimate_M1_total, ") ",
                                           pval_str_M1_total), "-"),
    `M2_direct (+ LIBE)` = if_else(!is.na(estimate_M2_direct),
                                   paste0(estimate_M2_direct, " (IRR: ",
                                          exp_estimate_M2_direct, ") ",
                                          pval_str_M2_direct), "-")
  ) %>%
  dplyr::select(Predictor, `M1_total (no LIBE)`, `M2_direct (+ LIBE)`)

cat("\n--- Coefficienti frequentist mirror: M1_total vs M2_direct ---\n")
print(tabella_compatta, width = Inf)
message("✅ Frequentist mirror complete: 2/2 estimand twins fit, gates passed.")

knitr::kable(tabella_compatta, format = "markdown", caption = "Confronto dei Coefficienti e degli Incident Rate Ratios (IRR)")