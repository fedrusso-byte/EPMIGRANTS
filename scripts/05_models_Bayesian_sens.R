# ==============================================================================
# NOTE (2026-11-17, DV promotion): the keyword-based DV varied by this script
# is now the demoted robustness operationalization (Appendix B;
# 05_models_Bayesian_sens_keyword.R). The keyword-extension check is retained
# unchanged as a further keyword-layer robustness variant.
# ==============================================================================

# ==============================================================================
# # 05_models_Bayesian_sens.R — DV-201 KEYWORD-EXTENSION SENSITIVITY (2026-11-13)
# Sensitivity of the two-estimand Bayesian models (M1_total / M2_direct) to the
# DV-201 validation disposition (FR hand-coding, 2026-11-13): titles anchored in
# non-EU contexts ("extra-EU OUT" category — 22 of 120 precision-sample rows)
# are additionally removed via a keyword extension of the CAP-201 exclusion
# pattern, re-applied at QUESTION level before the (mep_id, leg_year)
# aggregation, and both Bayesian fits are re-run on the resulting sample.
#
# LOCKED RESULTS OF THE DERIVATION (session of 2026-11-13):
#   - extension removes 183 question rows in-window (VII 68 / VIII 64 / IX 51);
#   - keeps 1,136 in-window DV events, i.e. (540 / 418 / 178 per term);
#   - covers 22/22 sheet "extra-EU OUT" rows; residual uncovered: NONE;
#   - ZERO hits on the 29 FR-validated force-keeps, the 7 audit rescue rows
#     and the 63 precision-sheet verified IN rows.
# Three candidate stems were dropped at derivation because they collide with
# protected rows (EU-relevant verdicts must NOT be removed):
#   * bare `macedonia|macedonians?` -> rescue row E-0636/2000 (Macedonian
#     minority in Greece); N-Macedonia coverage is preserved by `fyrom`,
#     `north macedonia`, `republic of macedonia` and the city keys;
#   * bare `ukrain` -> IN row P-000972/2022 (racial profiling at EU-Ukraine
#     borders); replaced by refined phrases;
#   * `\bchechen` -> a precision-sheet verified IN row.
# A bare `russia|russian` stem is deliberately absent (the refined Russia keys
# target "russian authorit"/"in russia"/capital-leader phrases instead).
#
# SAMPLE: rebuilt exactly like 05_models.R (problem indicators join, MIPEX-only
# structural filter, same drop_na list), with the sens pqs overlay applied
# BEFORE listwise deletion. total_questions is asserted identical to the
# primary aggregation (the extension changes DV counts only). Nothing in the
# primary output namespace is overwritten: caches/tables use *_sens names.
# =============================================================================
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
message("   Loading question data and DV-201 decision record...")
epq <- readRDS(here("data_processed", "epq.rds"))
decisions <- read_csv(here("data", "dv201_validation_decisions_FR.csv"), show_col_types = FALSE)
lab <- read_csv(here("data", "dv201_precision_sample_tocode.csv"), show_col_types = FALSE)

# FR-validated force-keeps come from the decisions CSV (single source of truth)
sens_force_keep_ids <- decisions$id[decisions$decision == "IN"]
stopifnot(
  "expected 29 FR-validated IN rows in decisions CSV" = length(sens_force_keep_ids) == 29
)

# Audit rescue allowlist (2026-11-06 CAP-201 dictionary audit — kept in sync
# with cap201_rescue_ids in 01_import_questions.R)
sens_rescue_ids <- c(
  "E-0636/2000", "P-1626/2005", "P-2304/2006", "E-004683/2012",
  "E-003234/2014", "E-005109/2016", "E-006385/2018"
)

# Precision-sheet verified IN rows (63): protection set for the guard
sheetIN_ids <- lab %>%
  filter(toupper(coalesce(trimws(on_scope), "")) == "IN") %>%
  pull(id)
stopifnot("expected 63 sheet-verified IN rows" = length(sheetIN_ids) == 63)

# ==============================================================================
# 1. PATTERNS
# ==============================================================================
# Base CAP-201 exclusion pattern — VERBATIM copy of cap201_exclusion_pattern in
# 01_import_questions.R (keep in sync if the primary changes).
sens_base_pattern <- paste0("(?i)christian|\\bafrica\\b|palestin|Second World War|",
  "\\bhamas\\b|danube|turkey|turkish|istanbul|\\bindia\\b|china|chinese|\\busa\\b|\\basia\\b|israel|\\biran\\b|iranians?|syria|middle east|\\bnative\\b|",
  "pakistan|tibet|uighur|uyghur|vietnam|guatemala|burma|myanmar|rwanda|congo|cambodia|afghan|egypt|iraq|jerusalem|brazil|kashmir|nepal|coptic|ahmadi|\\bkaren\\b|degar|lausanne")

# Keyword extension: non-EU-anchored contexts. 90 keys, each verified (2026-11-13)
# to hit ZERO of the protection set (29 force-keeps / 7 rescues / 63 sheet INs).
sens_extension_keys <- c(
  "bitola", "\\bstruga\\b", "fyrom", "\\bnorth macedonia\\b|north-macedonia", "republic of macedonia",
  "\\bserbia\\b|serbians?", "dimitrovgrad", "gagauzia", "vojvodina",
  "ukrainian citizens|in ukraine|from ukraine|to ukraine|of ukraine|over ukraine|for ukraine",
  "crimea", "sahrawi", "maldives", "mauritania", "tohti", "kalasha", "pontic", "svoboda", "t\u00fcrkiye|turkiye",
  "sarajevo|\\bbutmir\\b",
  "russian authorit|russia's|\\bin russia\\b|\\bfrom russia\\b|\\bto russia\\b|\\bmoscow\\b|\\bkremlin\\b|\\bputin\\b|\\bmedvedev\\b|\\blavrov\\b",
  "yugoslavia|\\bbalkan", "maghreb|\\bmashriq\\b",
  "skopje|ohrid|tetovo|gostivar|kumanovo|presevo|bujanovac",
  "podgorica|montenegro|budva",
  "mostar|trebinje|srebrenica",
  "transnistria|tiraspol",
  "\\btirana\\b|durres|shkodra",
  "belgrade|beograd|novi sad",
  "donbas|donetsk|luhansk|\\blviv\\b|\\bodesa\\b|\\bkharkiv\\b|\\bkyiv\\b|\\bkiev\\b|mariupol",
  "\\btatars?\\b",
  "ossetia|abkhaz|sukhum|tskhinval",
  "nagorno|karabakh|shusha|stepanakert",
  "west bank|\\bgaza\\b|golan|shebaa",
  "\\bsindhi|\\bbaloch",
  "nubian|amazigh|\\bberber",
  "uganda|cameroon",
  "karakalpak|bashkir|kabardino|chuvash",
  "\\bainu",
  "\\bmacau",
  "\\bniger\\b",
  "\\bmitrovica\\b",
  "\\bchad\\b|sahel|\\bmali\\b|burkina",
  "\\bkurds?\\b",
  "\\brohingya\\b",
  "\\bkhmer\\b",
  "albania|albanian|\\bkosovar",
  "kosovo",
  "bosnia|bosnian|herzegovina",
  "moldova|moldovan",
  "belarus",
  "\\bgeorgia\\b|georgian",
  "armenia|armenian",
  "azerbaijan",
  "morocco|moroccan",
  "tunisia|tunis",
  "algeria|algerian",
  "libya|libyan",
  "lebanon|lebanese",
  "jordan|jordanian",
  "somalia|somali",
  "ethiopia|ethiopian",
  "eritrea|eritrean",
  "sudan",
  "nigeria|nigerian",
  "\\bkenya\\b",
  "zimbabwe",
  "south africa",
  "colombi",
  "venezuela",
  "\\bmexico\\b|mexican",
  "\\bchile\\b",
  "\\bperu\\b",
  "philippin",
  "indonesia|indonesian",
  "malaysia|malaysian",
  "thailand|\\bthai\\b",
  "sri lanka|\\btamil\\b",
  "bangladesh",
  "taiwan",
  "hong kong",
  "singapore",
  "kazakhstan",
  "uzbek|\\btajik\\b|turkmen|kyrgyz",
  "\\byemen\\b",
  "saudi",
  "\\bqatar\\b|\\buae\\b|emirates",
  "kuwait",
  "\\boman\\b|bahrain",
  "\\bcuba\\b|haiti|honduras|salvador|nicaragu"
)

# ==============================================================================
# 2. GUARDS (design gate for the extension)
# ==============================================================================
stopifnot(
  "no bare russia|russian stem allowed in the extension keys" =
    !any(sens_extension_keys %in% c("russia|russian", "russa", "russi"))
)
subj_prot_fk  <- epq$subject[match(sens_force_keep_ids, epq$id)]
subj_rescue   <- epq$subject[match(sens_rescue_ids, epq$id)]
subj_sheetIN  <- epq$subject[match(sheetIN_ids, epq$id)]

sens_keys_collisions <- map_dfr(sens_extension_keys, function(k) {
  re <- regex(k, ignore_case = TRUE)
  tibble(
    key = k,
    fk      = sum(str_detect(subj_prot_fk, re), na.rm = TRUE),
    rescue  = sum(str_detect(coalesce(subj_rescue, ""), re), na.rm = TRUE),
    sheetin = sum(str_detect(coalesce(subj_sheetIN, ""), re), na.rm = TRUE)
  )
})
stopifnot(
  "extension keys must have ZERO hits among force-keeps" =
    all(sens_keys_collisions$fk == 0),
  "extension keys must have ZERO hits among rescue rows" =
    all(sens_keys_collisions$rescue == 0),
  "extension keys must have ZERO hits among sheet-verified INs" =
    all(sens_keys_collisions$sheetin == 0)
)
message("   Guard OK: 0 collisions of ", length(sens_extension_keys),
        " extension keys with 29 INs / 7 rescues / 63 verified INs")

# Combined sensitivity pattern = base CAP-201 pattern | extension keys
sens_pattern_full <- paste0(sens_base_pattern, "|", paste(sens_extension_keys, collapse = "|"))

# ==============================================================================
# 3. QUESTION-LEVEL RE-CODING + REMOVAL AUDIT
# ==============================================================================
epq <- epq %>%
  mutate(
    pq_sens = if_else(
      id %in% sens_force_keep_ids |
        (!is.na(subtopic) & subtopic == "201" &
           (id %in% sens_rescue_ids |
              (!is.na(subject) & !str_detect(subject, sens_pattern_full)))),
      1L, 0L
    ),
    # Primary rule (01_import_questions.R, 2026-11-13) for the audit diff
    pq_primary = if_else(
      id %in% sens_force_keep_ids |
        (!is.na(subtopic) & subtopic == "201" &
           (id %in% sens_rescue_ids |
              (!is.na(subject) & !str_detect(subject, sens_base_pattern)))),
      1L, 0L
    )
  )

d_win_sens <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-06-15")) %>%
  mutate(term_check = if_else(as.Date(date) <= as.Date("2014-06-30"), "VII",
                       if_else(as.Date(date) <= as.Date("2019-06-30"), "VIII", "IX")))

stopifnot(
  "all 29 force-keeps must remain kept under the sensitivity rule" =
    all(d_win_sens$pq_sens[d_win_sens$id %in% sens_force_keep_ids] == 1L),
  "in-window DV events under the sensitivity rule must be 1,136" =
    sum(d_win_sens$pq_sens, na.rm = TRUE) == 1136,
  "sens events per term must be 540 / 418 / 178 (VII / VIII / IX)" =
    identical(as.integer(table(d_win_sens$term_check[d_win_sens$pq_sens == 1L])[c("VII", "VIII", "IX")]),
              c(540L, 418L, 178L)),
  "extension must remove exactly 183 additional rows" =
    sum(d_win_sens$pq_primary == 1L & d_win_sens$pq_sens == 0L, na.rm = TRUE) == 183
)

sens_removed <- d_win_sens %>%
  filter(pq_primary == 1L, pq_sens == 0L) %>%
  transmute(id, date = as.character(date), term = term_check, subject) %>%
  arrange(term, date, id)
write_csv(sens_removed, here("data", "dv201_sens_removed_ids.csv"))
message("   Sensitivity removal audit: ", nrow(sens_removed),
        " rows written to data/dv201_sens_removed_ids.csv")
print(table(d_win_sens$term_check[d_win_sens$pq_primary == 1L & d_win_sens$pq_sens == 0L]))

# ==============================================================================
# 4. MEP-YEAR RE-AGGREGATION (mirrors 02_df_setup.R exactly)
# ==============================================================================
legislature_starts <- tibble(
  legislative_term = c("6th", "7th", "8th", "9th"),
  term_start = ymd(c("2004-07-20", "2009-07-14", "2014-07-01", "2019-07-02")),
  term_end = ymd(c("2009-07-13", "2014-06-30", "2019-07-01", "2024-07-15"))
)
assign_term_sens <- function(date_col) {
  case_when(
    date_col >= ymd("2004-07-20") & date_col <= ymd("2009-07-13") ~ "6th",
    date_col >= ymd("2009-07-14") & date_col <= ymd("2014-06-30") ~ "7th",
    date_col >= ymd("2014-07-01") & date_col <= ymd("2019-07-01") ~ "8th",
    date_col >= ymd("2019-07-02") & date_col <= ymd("2024-07-15") ~ "9th",
    TRUE ~ NA_character_
  )
}

questions_sens <- epq %>%
  mutate(dates = as.Date(date)) %>%
  filter(dates >= as.Date("2004-07-20"), dates <= as.Date("2024-06-08")) %>%
  mutate(legislative_term = assign_term_sens(dates)) %>%
  left_join(legislature_starts, by = "legislative_term") %>%
  mutate(year_index = (interval(term_start, dates) %/% years(1)) + 1) %>%
  mutate(leg_year = paste0(legislative_term, year_index)) %>%
  filter(year_index <= 5) %>%
  group_by(mep_id, leg_year) %>%
  summarise(
    pqs_discrimination_sens = sum(pq_sens == 1L, na.rm = TRUE),
    total_questions_sens = n(),
    .groups = "drop"
  )
stopifnot(
  "questions_sens must not be empty" = nrow(questions_sens) > 0
)

# ==============================================================================
# 5. ESTIMATION SAMPLE (mirrors 05_models.R: indicators join, MIPEX filter)
# ==============================================================================
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_sens_src <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

df_merged_sens_src <- df_merged_sens_src %>%
  mutate(mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE))

# Sensitivity overlay: replace DV counts only; total_questions asserted identical
df_merged_sens_src <- df_merged_sens_src %>%
  left_join(questions_sens, by = c("mep_id", "leg_year")) %>%
  mutate(
    pqs_discrimination_sens = replace_na(pqs_discrimination_sens, 0L),
    total_questions_sens = replace_na(total_questions_sens, 0L),
    total_questions = replace_na(total_questions, 0L)
  )
stopifnot(
  "total_questions must be identical between primary and sens aggregation" =
    all(df_merged_sens_src$total_questions_sens == df_merged_sens_src$total_questions)
)
df_merged_sens_src <- df_merged_sens_src %>%
  mutate(pqs_discrimination = pqs_discrimination_sens) %>%
  select(-pqs_discrimination_sens, -total_questions_sens)

paesi_da_escludere <- df_merged_sens_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  group_by(country) %>%
  summarise(pct_na_mipex = mean(is.na(mipex_antidiscrimination_score)), .groups = "drop") %>%
  filter(pct_na_mipex == 1) %>%
  pull(country)

df_model_data_sens <- df_merged_sens_src %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!country %in% paesi_da_escludere) %>%
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority,
    misery_index, mipex_center
  )
message("   N (sens estimation sample): ", nrow(df_model_data_sens),
        " | DV events in sample: ", sum(df_model_data_sens$pqs_discrimination))
saveRDS(df_model_data_sens, here("output", "df_model_data_sens.rds"))

# ==============================================================================
# 6. FITS: M1_sens (no LIBE) and M2_sens (+LIBE), same priors as primary
# ==============================================================================
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

message("   Fitting Bayesian M1_sens (Minority x MIPEX, no LIBE control)...")
# NOTE (2026-11-13): the first attempt at iter = 2000 / warmup = 1000 FAILED
# the M4 ESS gate (M1_sens min neff ratio = 0.094 — the NB `shape` dispersion
# parameter mixes slowly in this ZINB geometry; all b/zi parameters were well
# mixed, max Rhat 1.0064, 0 divergences). Both sens fits therefore use
# iter = 4000 / warmup = 1500 (~x2.5 sampling draws => shape ESS ratio ~0.24),
# mirroring the M2_direct deviation documented in the primary script.
# `brm(file = ...)` caches by path: delete output/bayesian_model_m1_sens.rds
# and output/bayesian_model_m2_sens.rds before re-running with changed spec.
bayesian_model_m1_sens <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_sens,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_m1_sens")
)

message("   Fitting Bayesian M2_sens (+ LIBE committee control)...")
bayesian_model_m2_sens <- brm(
  formula = pqs_discrimination ~
             gender + misery_index + party_family + libe +
             minority * mipex_center +
             offset(log(total_questions + 1)) +
             (1 | mep_id) + (1 | country),
  data = df_model_data_sens,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4,
  iter = 4000,
  warmup = 1500,
  cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = here("output", "bayesian_model_m2_sens")
)

# ==============================================================================
# 7. CONVERGENCE GATE (same M4 gate as the primary two-estimand fits)
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
convergence_gate(bayesian_model_m1_sens, "M1_sens")
convergence_gate(bayesian_model_m2_sens, "M2_sens")

# ==============================================================================
# 8. RESULTS
# ==============================================================================
final_results_sens <- bind_rows(
  broom.mixed::tidy(bayesian_model_m1_sens, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M1_sens (no LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high),
  broom.mixed::tidy(bayesian_model_m2_sens, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = "M2_sens (+LIBE control)") %>%
    dplyr::select(model, term, estimate, std.error, conf.low, conf.high)
)
write_csv(final_results_sens, here("output", "bayesian_sens_model_results.csv"))
message("🎉 Sensitivity results saved to: output/bayesian_sens_model_results.csv")

interaction_results_sens <- final_results_sens %>% filter(grepl(":", term))
print("--- Sensitivity Interaction Effects (M1_sens / M2_sens) ---")
print(knitr::kable(interaction_results_sens, format = "markdown",
                   caption = "DV-201 keyword-extension sensitivity: Minority x MIPEX interaction"))


