# 06_responsiveness_data.R — Responsiveness Analysis: Data Preparation
# Author: Marcello Carammia
# Purpose: Build the analysis panel for the Europeanisation of Representation
#          paper. Loads question-level EPQ data, MIP panel, and problem
#          indicators; re-aggregates EPQs to semester level; constructs
#          CAP-MIP crosswalk; decomposes MIP and problem indicators into
#          EU-mean + country deviation.
#
# Input:  data_processed/epq.csv, output/df_merged_3.rds,
#         data_raw/mip/mip_panel.csv, output/problem_indicators.csv
# Output: output/responsiveness_panel.rds, output/responsiveness_panel.csv,
#         output/cap_mip_crosswalk.csv, output/cap_mip_crosswalk.rds,
#         output/mip_decomposed.rds

# 0. Setup ====================================================================
library(tidyverse)
library(here)

source(here("scripts", "R", "utils", "cap_issue_mapping.R"))

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# 1. CAP-MIP Issue Crosswalk
# ============================================================================
message("Step 1: Building CAP-MIP issue crosswalk...")

# Map MIP standardized issues to CAP major topic labels (from 02_df_setup.R)
# "domain" groups issues for the economy vs migration heterogeneity test (H3)
cap_mip_crosswalk <- tribble(
  ~mip_issue,              ~cap_issue_name,        ~domain,
  "unemployment",          "Labor",                "economy",
  "economic_situation",    "Macroeconomics",        "economy",
  "inflation",             "Macroeconomics",        "economy",
  "government_debt",       "Macroeconomics",        "economy",
  "taxation",              "Macroeconomics",        "economy",
  "immigration",           "Immigration",           "migration",
  "environment",           "Environment",           "other",
  "crime",                 "Law and Crime",         "other",
  "health",                "Health",                "other",
  "pensions",              "Social Welfare",        "other",
  "housing",               "Housing",               "other",
  "education",             "Education",             "other",
  "energy",                "Energy",                "other",
  "defence",               "Defense",               "other",
  "security_defence",      "Defense",               "other",
  "terrorism",             "Defense",               "other",
  "public_transport",      "Transportation",        "other",
  "international_situation", "International Affairs", "other",
  "war_ukraine",           "International Affairs",  "other"
)

write_csv(cap_mip_crosswalk, here("output", "cap_mip_crosswalk.csv"))
saveRDS(cap_mip_crosswalk, here("output", "cap_mip_crosswalk.rds"))
message("  Crosswalk: ", nrow(cap_mip_crosswalk), " MIP issues -> ",
        n_distinct(cap_mip_crosswalk$cap_issue_name), " CAP topics")

# ============================================================================
# 2. Load and re-aggregate EPQ data to semesters
# ============================================================================
message("Step 2: Loading and re-aggregating EPQ data to semesters...")

# --- 2a. Load question-level data and assign issue names ---
# Replicates the issue_name mapping from 02_df_setup.R lines 307-334
questions <- read_csv(here("data_processed", "epq.csv"), show_col_types = FALSE) %>%
  dplyr::select(-url, -author_s, -party_s, -subject) %>%
  dplyr::filter(date >= as.Date("1994-07-19"), date <= as.Date("2024-06-08")) %>%
  mutate(issue_name = assign_issue_name(major)) %>%
  dplyr::filter(issue_name != "Other") %>%
  # Assign calendar year and semester
  mutate(
    year = year(date),
    semester = if_else(month(date) <= 6, 1L, 2L)
  ) %>%
  # Filter to 2003+ (MIP constraint)
  dplyr::filter(year >= 2003)

stopifnot(
  "Questions data is empty after filtering" = nrow(questions) > 0,
  "No mep_id in questions" = "mep_id" %in% names(questions)
)

message("  Loaded ", nrow(questions), " questions (2003-2024, excl. Other)")

# --- 2b. Aggregate to MEP x year x semester x issue ---
questions_semester <- questions %>%
  group_by(mep_id, year, semester, issue_name) %>%
  summarise(n_questions = n(), .groups = "drop") %>%
  group_by(mep_id, year, semester) %>%
  mutate(total_questions = sum(n_questions)) %>%
  ungroup()

message("  Aggregated to ", nrow(questions_semester),
        " MEP-year-semester-issue observations")

# --- 2c. Get MEP attributes from df_merged_3 ---
# df_merged_3 has MEP attributes at parliamentary-year level.
# We map each calendar semester to the parliamentary year it falls in,
# then join attributes.
message("  Loading MEP attributes from df_merged_3...")
df3 <- readRDS(here("output", "df_merged_3.rds"))

# Extract unique MEP-year attributes (one row per MEP per parliamentary year)
mep_attributes <- df3 %>%
  dplyr::select(
    mep_id, legislative_term, leg_year, year_start, year_end,
    country, country_name, group_abbr, party_family, gender,
    birth_year, committee_most_time, committee,
    geographic_region, eu_enlargement_wave, old_new_ms,
    founding_member, euro_member, eu_member, populist_in_gov,
    net_contributor, mid_year, year_parl
  ) %>%
  distinct(mep_id, leg_year, .keep_all = TRUE)

# Map calendar year-semester to the parliamentary year it falls in.
# Parliamentary years start in July, so:
#   Semester 1 (Jan-Jun) of year Y -> parliamentary year that started Jul Y-1
#   Semester 2 (Jul-Dec) of year Y -> parliamentary year that started Jul Y
# We use year_start/year_end from mep_attributes for precise matching.
mep_semester_attrs <- questions_semester %>%
  distinct(mep_id, year, semester) %>%
  # Create approximate date for this semester
  mutate(
    sem_date = if_else(semester == 1L,
                       make_date(year, 3, 15),   # mid-spring
                       make_date(year, 9, 15))    # mid-autumn
  ) %>%
  # Join to mep_attributes where the semester date falls within the parliamentary year
  left_join(
    mep_attributes,
    by = join_by(mep_id, sem_date >= year_start, sem_date <= year_end)
  ) %>%
  dplyr::select(-sem_date)

# Check join quality
n_unmatched <- sum(is.na(mep_semester_attrs$country))
message("  MEP-semester attribute join: ",
        nrow(mep_semester_attrs), " rows, ",
        n_unmatched, " unmatched (", round(100 * n_unmatched / nrow(mep_semester_attrs), 1), "%)")

# Drop unmatched (MEPs who served in periods not covered by df_merged_3)
mep_semester_attrs <- mep_semester_attrs %>%
  dplyr::filter(!is.na(country))

# --- 2d. Build full semester panel with zeros ---
# Cross-join MEP-semesters with all issue names to fill zeros
issue_names <- questions_semester %>% distinct(issue_name)

# Compute total_questions per MEP-semester (independent of issue) so that
# cross-joined zero-count rows still get the correct MEP-semester total.
mep_semester_totals <- questions_semester %>%
  distinct(mep_id, year, semester, total_questions)

epq_semester_panel <- mep_semester_attrs %>%
  cross_join(issue_names) %>%
  left_join(
    questions_semester %>% dplyr::select(mep_id, year, semester, issue_name, n_questions),
    by = c("mep_id", "year", "semester", "issue_name")
  ) %>%
  left_join(mep_semester_totals, by = c("mep_id", "year", "semester")) %>%
  mutate(
    n_questions = replace_na(n_questions, 0L),
    total_questions = replace_na(total_questions, 0L),
    age = year - birth_year
  )

# Add committee-issue match dummy (shared function from utils/cap_issue_mapping.R)
epq_semester_panel <- add_committee_match(epq_semester_panel)

message("  EPQ semester panel: ", nrow(epq_semester_panel), " rows, ",
        n_distinct(epq_semester_panel$mep_id), " MEPs, ",
        n_distinct(epq_semester_panel$issue_name), " issues, ",
        n_distinct(paste(epq_semester_panel$year, epq_semester_panel$semester)), " semesters")

# ============================================================================
# 3. Load and process MIP data
# ============================================================================
message("Step 3: Processing MIP data...")

mip_raw <- read_csv(here("data_raw", "mip", "mip_panel.csv"), show_col_types = FALSE)

# Filter to national MIP, 2003+, and apply crosswalk
mip_national <- mip_raw %>%
  dplyr::filter(mip_level == "national", year >= 2003) %>%
  # Join crosswalk to map MIP issues to CAP topics
  inner_join(cap_mip_crosswalk, by = c("issue" = "mip_issue")) %>%
  # Aggregate MIP shares within same CAP topic (e.g., inflation + economic_situation -> Macroeconomics)
  group_by(country, year, semester, cap_issue_name, domain) %>%
  summarise(
    mip_share = sum(share, na.rm = TRUE),
    .groups = "drop"
  )

# Report coverage
n_mip_matched <- mip_raw %>%
  dplyr::filter(mip_level == "national", year >= 2003) %>%
  inner_join(cap_mip_crosswalk, by = c("issue" = "mip_issue")) %>%
  pull(count) %>% sum(na.rm = TRUE)
n_mip_total <- mip_raw %>%
  dplyr::filter(mip_level == "national", year >= 2003) %>%
  pull(count) %>% sum(na.rm = TRUE)
message("  MIP coverage: ", round(100 * n_mip_matched / n_mip_total, 1),
        "% of mentions matched via crosswalk")
message("  MIP panel: ", nrow(mip_national), " country-semester-issue observations, ",
        n_distinct(mip_national$country), " countries, ",
        n_distinct(paste(mip_national$year, mip_national$semester)), " semesters")

# ============================================================================
# 4. Decompose MIP into EU-mean + country deviation
# ============================================================================
message("Step 4: Decomposing MIP into EU-mean + country deviation...")

# EU-mean salience per issue-semester
mip_eu_mean <- mip_national %>%
  group_by(year, semester, cap_issue_name, domain) %>%
  summarise(
    mip_eu_mean = mean(mip_share, na.rm = TRUE),
    mip_eu_sd   = if_else(n() >= 2, sd(mip_share, na.rm = TRUE), NA_real_),
    mip_n_countries = n(),
    .groups = "drop"
  ) %>%
  mutate(
    # Europeanisation indicator: coefficient of variation (low CV = more Europeanised)
    mip_cv = if_else(mip_eu_mean > 0, mip_eu_sd / mip_eu_mean, NA_real_)
  )

# Join back to get country deviations
mip_decomposed <- mip_national %>%
  left_join(mip_eu_mean, by = c("year", "semester", "cap_issue_name", "domain")) %>%
  mutate(
    mip_deviation = mip_share - mip_eu_mean
  )

# Sanity: deviations should sum to ~0 within each issue-semester
dev_check <- mip_decomposed %>%
  group_by(year, semester, cap_issue_name) %>%
  summarise(dev_sum = sum(mip_deviation, na.rm = TRUE), .groups = "drop")
stopifnot("MIP deviations do not sum to ~0" = all(abs(dev_check$dev_sum) < 0.01))

saveRDS(mip_decomposed, here("output", "mip_decomposed.rds"))
message("  MIP decomposed: ", nrow(mip_decomposed), " rows")


# ============================================================================
# 5. Load and decompose problem indicators
# ============================================================================
message("Step 5: Processing problem indicators...")

problem_file <- here("output", "problem_indicators.csv")
if (!file.exists(problem_file)) {
  warning("problem_indicators.csv not found. Run download_problem_indicators.R first.")
  problems_decomposed <- NULL
} else {
  # Carichiamo i dati assicurandoci di prendere le nuove colonne
  problems_raw <- read_csv(problem_file, show_col_types = FALSE) %>%
    # Filtriamo l'aggregato EU perché lo ricalcoliamo qui per coerenza con Marcello
    dplyr::filter(year >= 2003, country != "EU") %>%
    # SELEZIONE COLONNE: Assicurati che misery_index sia presente
    dplyr::select(country, year, misery_index, asylum_per_1000)

  # Calcolo della Media EU annuale (Benchmark)
  problems_eu_mean <- problems_raw %>%
    group_by(year) %>%
    summarise(
      misery_eu_mean  = mean(misery_index, na.rm = TRUE),
      asylum_eu_mean = mean(asylum_per_1000, na.rm = TRUE),
      .groups = "drop"
    )

  # Decomposizione: Calcolo della deviazione del paese rispetto alla media UE
  # Questo serve a Marcello per distinguere tra "problemi comuni a tutti"
  # e "problemi specifici di quel paese".
  problems_decomposed <- problems_raw %>%
    left_join(problems_eu_mean, by = "year") %>%
    mutate(
      misery_deviation  = misery_index - misery_eu_mean,
      asylum_deviation = asylum_per_1000 - asylum_eu_mean
    )

  message("  Problem indicators decomposed: ", nrow(problems_decomposed), " country-year rows")
}


# ============================================================================
# 6. Merge into responsiveness panel
# ============================================================================
message("Step 6: Constructing responsiveness panel...")

# Join EPQ semester panel with MIP decomposition
# Match on country + year + semester + issue_name (CAP topic)
resp_panel <- epq_semester_panel %>%
  left_join(
    mip_decomposed %>%
      dplyr::select(country, year, semester, cap_issue_name, domain,
                    mip_share, mip_eu_mean, mip_deviation,
                    mip_eu_sd, mip_cv, mip_n_countries),
    by = c("country", "year", "semester", "issue_name" = "cap_issue_name")
  )

# Join problem indicators (annual, joined by country + year).
# DESIGN NOTE: Both semesters of the same country-year get identical values.
# Downstream models should account for this (e.g., cluster SEs at country-year).
if (!is.null(problems_decomposed)) {
  resp_panel <- resp_panel %>%
    left_join(
      problems_decomposed,
      by = c("country", "year")
    )
}

# ============================================================================
# 7. Electoral system stub (placeholder for Hix classification)
# ============================================================================
message("Step 7: Adding electoral system stub...")

# Placeholder — to be replaced when Hix et al. classification is provided
resp_panel <- resp_panel %>%
  mutate(system_type = NA_character_)

# ============================================================================
# 8. Sanity checks and save
# ============================================================================
message("Step 8: Sanity checks...")

# Panel dimensions
n_rows <- nrow(resp_panel)
n_meps <- n_distinct(resp_panel$mep_id)
n_issues <- n_distinct(resp_panel$issue_name)
n_semesters <- n_distinct(paste(resp_panel$year, resp_panel$semester))
n_countries <- n_distinct(resp_panel$country)

message("  Panel: ", n_rows, " rows")
message("  MEPs: ", n_meps)
message("  Issues: ", n_issues)
message("  Semesters: ", n_semesters)
message("  Countries: ", n_countries)

# MIP coverage in the merged panel
mip_na_pct <- 100 * mean(is.na(resp_panel$mip_share))
message("  MIP NA rate: ", round(mip_na_pct, 1), "% (expected: some NAs for 2004 gap and unmatched issues)")

# EPQ coverage: what fraction of total EPQ questions are in the panel?
total_q_panel <- sum(resp_panel$n_questions)
total_q_raw <- nrow(questions)
message("  EPQ questions in panel: ", total_q_panel, " / ", total_q_raw,
        " (", round(100 * total_q_panel / total_q_raw, 1), "%)")

# Country code check
epq_countries <- sort(unique(resp_panel$country))
mip_countries <- sort(unique(mip_decomposed$country))
common <- intersect(epq_countries, mip_countries)
epq_only <- setdiff(epq_countries, mip_countries)
mip_only <- setdiff(mip_countries, epq_countries)
message("  Country overlap: ", length(common), " shared, ",
        length(epq_only), " EPQ-only, ", length(mip_only), " MIP-only")
if (length(epq_only) > 0) message("    EPQ-only: ", paste(epq_only, collapse = ", "))
if (length(mip_only) > 0) message("    MIP-only: ", paste(mip_only, collapse = ", "))

stopifnot(
  "Responsiveness panel is empty" = n_rows > 0,
  "No MEPs in panel" = n_meps > 100,
  "MIP NA rate unexpectedly high (>80%)" = mip_na_pct < 80
)

# Save
message("  Saving responsiveness panel...")
saveRDS(resp_panel, here("output", "responsiveness_panel.rds"))
write_csv(resp_panel, here("output", "responsiveness_panel.csv"))

message("Step 8 complete. Panel saved to output/responsiveness_panel.rds")
message("=== 06_responsiveness_data.R complete ===")
