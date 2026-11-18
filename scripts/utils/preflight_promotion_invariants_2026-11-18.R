# ONE-OFF read-only preflight for the 2026-11-18 Option-A promotion refits
# (audit remediation item 1). Computes the invariant numbers that re-anchor
# the TERM/CMP/LIBE asserts after the refined-DV promotion.
library(tidyverse)
library(here)

cat("== PART 1: TERM invariants from output/df_model_data.rds (refined vintage) ==\n")
df_model_data <- readRDS(here("output", "df_model_data.rds")) %>%
  dplyr::mutate(legislative_term = factor(legislative_term,
                                          levels = c("7th", "8th", "9th")))
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
cat("N:", nrow(df_model_data),
    "| countries:", dplyr::n_distinct(df_model_data$country),
    "| MEPs:", dplyr::n_distinct(df_model_data$mep_id),
    "| minority MEPs:", dplyr::n_distinct(df_model_data$mep_id[df_model_data$minority == 1]),
    "| DV sum:", sum(df_model_data$pqs_discrimination),
    "| keyword DV sum:",
    if ("pqs_discrimination_keyword" %in% names(df_model_data)) {
      sum(df_model_data$pqs_discrimination_keyword)
    } else { NA_real_ }, "\n")
print(as.data.frame(minority_by_term))
cat("two-term minority MEPs:", sum(mep_terms_minority$n_terms == 2),
    "| three-term:", sum(mep_terms_minority$n_terms == 3), "\n")
stopifnot(sum(df_model_data$pqs_discrimination) == 739)

cat("\n== PART 2: exact 05_models.R section-1b overlay replication ==\n")
epq <- readRDS(here("data_processed", "epq.rds"))
refined_keptdv <- read_csv(here("data", "dv201_llm_refined_keptdv_ids.csv"),
                           show_col_types = FALSE)
verified_in <- read_csv(here("data", "dv201_llm_verified_in_ids.csv"),
                        show_col_types = FALSE)
stopifnot(nrow(refined_keptdv) == 529, nrow(verified_in) == 255)
refined_ids <- refined_keptdv$id
verified_ids <- verified_in$id
stopifnot(
  all(refined_ids %in% epq$id),
  all(verified_ids %in% epq$id),
  !any(refined_ids %in% verified_ids),
  !any(duplicated(c(refined_ids, verified_ids)))
)
dv_r2_ids <- c(refined_ids, verified_ids)
iv_r <- match(refined_ids, epq$id)
iv_v <- match(verified_ids, epq$id)
stopifnot(
  all(epq$pq_discrimination %in% c(0L, 1L)),
  all(epq$pq_discrimination[iv_r] == 1L),
  all(epq$pq_discrimination[iv_v] == 0L),
  all(as.Date(epq$date)[iv_r] >= as.Date("2009-07-14") &
        as.Date(epq$date)[iv_r] <= as.Date("2024-07-15") &
        !is.na(epq$date)[iv_r]),
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
stopifnot(sum(d_win$pq_discrimination) == 1319)
epq <- epq %>% mutate(pq_r2 = as.integer(id %in% dv_r2_ids))
d_win2 <- epq %>%
  filter(!is.na(date), as.Date(date) >= as.Date("2009-07-14"),
         as.Date(date) <= as.Date("2024-07-15")) %>%
  mutate(term_ch = assign_term_sensllmr2(as.Date(date)))
stopifnot(sum(d_win2$pq_r2) == 784,
          sum(d_win2$pq_r2) - sum(d_win$pq_discrimination) == -535)
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
stopifnot(nrow(questions_r2) > 0)
problem_indicators <- read_csv(here("output", "problem_indicators.csv"),
                               show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))
df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))
df_merged_3 <- df_merged_3 %>%
  left_join(questions_r2, by = c("mep_id", "leg_year")) %>%
  mutate(
    pqs_discrimination_r2 = replace_na(pqs_discrimination_r2, 0L),
    total_questions_r2 = replace_na(total_questions_r2, 0L),
    total_questions = replace_na(total_questions, 0L)
  )
stopifnot(all(df_merged_3$total_questions_r2 == df_merged_3$total_questions))
df_merged_3 <- df_merged_3 %>%
  rename(pqs_discrimination_keyword = pqs_discrimination,
         pqs_discrimination = pqs_discrimination_r2) %>%
  select(-total_questions_r2)
cat("overlay OK; panel rows:", nrow(df_merged_3), "\n")

cat("\n== PART 3a: CMP sample (23 CMP countries) ==\n")
model_variables_cmp <- c(
  "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
  "party_family", "libe", "minority", "misery_index", "cmp_mean"
)
df_term <- df_merged_3 %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!(country == "UK" & legislative_term == "9th"))
cmp_missing_countries <- df_term %>%
  group_by(country) %>%
  summarise(pct_na_cmp = mean(is.na(cmp_mean)), .groups = "drop") %>%
  filter(pct_na_cmp == 1) %>%
  pull(country)
stopifnot(setequal(cmp_missing_countries, c("HU", "LU", "MT", "RO", "SK")))
df_cmp_model <- df_term %>%
  filter(!country %in% cmp_missing_countries) %>%
  drop_na(all_of(model_variables_cmp))
cat("CMP N:", nrow(df_cmp_model),
    "| countries:", dplyr::n_distinct(df_cmp_model$country),
    "| MEPs:", dplyr::n_distinct(df_cmp_model$mep_id),
    "| minority MEP-years:", sum(df_cmp_model$minority == 1),
    "| minority MEPs:", dplyr::n_distinct(df_cmp_model$mep_id[df_cmp_model$minority == 1]),
    "| cmp sd:", round(sd(df_cmp_model$cmp_mean), 4),
    "| DV sum:", sum(df_cmp_model$pqs_discrimination),
    "| pct positive:", round(mean(df_cmp_model$pqs_discrimination > 0), 3), "\n")
stopifnot(
  nrow(df_cmp_model) == 9850,
  dplyr::n_distinct(df_cmp_model$country) == 23,
  dplyr::n_distinct(df_cmp_model$mep_id) == 1543,
  sum(df_cmp_model$minority == 1) == 306,
  dplyr::n_distinct(df_cmp_model$mep_id[df_cmp_model$minority == 1]) == 52,
  abs(sd(df_cmp_model$cmp_mean) - 4.0073) < 0.0005
)
cat("CMP refined minority events by term:",
    paste(df_cmp_model %>%
            dplyr::group_by(legislative_term) %>%
            dplyr::summarise(e = sum(pqs_discrimination[minority == 1])) %>%
            dplyr::pull(e), collapse = " / "), "\n")
min_by_cty2 <- df_cmp_model %>%
  dplyr::group_by(country) %>%
  dplyr::summarise(meps = dplyr::n_distinct(mep_id[minority == 1]),
                   my = sum(minority == 1), .groups = "drop") %>%
  dplyr::filter(my > 0) %>%
  dplyr::arrange(dplyr::desc(my))
cat("CMP minority-hosting countries:", nrow(min_by_cty2), "->",
    paste(min_by_cty2$country, min_by_cty2$meps, min_by_cty2$my,
          sep = "/", collapse = " "), "\n")
cat("CMP median cmp_mean: minority",
    round(median(df_cmp_model$cmp_mean[df_cmp_model$minority == 1]), 2),
    "| non-minority",
    round(median(df_cmp_model$cmp_mean[df_cmp_model$minority == 0]), 2), "\n")
cat("CMP keyword rows positive:",
    round(mean(df_cmp_model$pqs_discrimination_keyword > 0), 3),
    "| refined rows positive:",
    round(mean(df_cmp_model$pqs_discrimination > 0), 3), "\n")
cat("CMP keyword DV sum (must stay 1,038):",
    sum(df_cmp_model$pqs_discrimination_keyword), "\n")
print(as.data.frame(df_cmp_model %>%
  dplyr::group_by(legislative_term) %>%
  dplyr::summarise(minority_events = sum(pqs_discrimination[minority == 1]),
                   all_events = sum(pqs_discrimination),
                   rows = dplyr::n(), .groups = "drop")))

cat("\n== PART 3b: LIBE sample (28 countries, UK-9th excluded) ==\n")
model_variables_libe <- c(
  "pqs_discrimination", "total_questions", "gender", "mep_id", "country",
  "party_family", "libe", "minority", "misery_index"
)
df_libe_model <- df_merged_3 %>%
  filter(legislative_term %in% c("7th", "8th", "9th")) %>%
  filter(!(country == "UK" & legislative_term == "9th")) %>%
  drop_na(all_of(model_variables_libe))
is_libe_cell <- df_libe_model$minority == 1 & df_libe_model$libe == 1
cat("LIBE N:", nrow(df_libe_model),
    "| countries:", dplyr::n_distinct(df_libe_model$country),
    "| MEPs:", dplyr::n_distinct(df_libe_model$mep_id),
    "| minority MEP-years:", sum(df_libe_model$minority == 1),
    "| DV sum:", sum(df_libe_model$pqs_discrimination),
    "| pct positive:", round(mean(df_libe_model$pqs_discrimination > 0), 3), "\n")
cat("Focal cell (minority=1 & libe=1): rows:", sum(is_libe_cell),
    "| MEPs:", dplyr::n_distinct(df_libe_model$mep_id[is_libe_cell]),
    "| events:", sum(df_libe_model$pqs_discrimination[is_libe_cell]),
    "| pct rows positive:", round(mean(df_libe_model$pqs_discrimination[is_libe_cell] > 0), 3), "\n")
stopifnot(
  nrow(df_libe_model) == 11042,
  dplyr::n_distinct(df_libe_model$country) == 28,
  sum(is_libe_cell) == 56,
  dplyr::n_distinct(df_libe_model$mep_id[is_libe_cell]) == 11
)
print(as.data.frame(df_libe_model %>%
  dplyr::group_by(minority, libe) %>%
  dplyr::summarise(rows = dplyr::n(), meps = dplyr::n_distinct(mep_id),
                   events = sum(pqs_discrimination), .groups = "drop")))
cat("LIBE keyword DV sum:", sum(df_libe_model$pqs_discrimination_keyword), "\n")
print(as.data.frame(df_libe_model %>%
  dplyr::group_by(legislative_term) %>%
  dplyr::summarise(minority_events = sum(pqs_discrimination[minority == 1]),
                   all_events = sum(pqs_discrimination), .groups = "drop")))
cat("\n== PREFLIGHT DONE ==\n")


