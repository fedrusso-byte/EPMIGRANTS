# 05_descriptives.R — Descriptive Analyses for Paper and Slides
# Computes aggregate statistics used by both QMDs:
# issue frequency table, longitudinal shares, Shannon diversity,
# Sigelman-Buell party and country congruence matrices.

library(tidyverse)
library(here)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# Load data ####
message("  Loading data...")
df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE)
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("issue_name", "n_questions", "mid_year",
    "party_family", "country") %in% names(df_merged_3))
)

# Issue frequency table ####

issue_totals <- df_merged_3 %>%
  group_by(issue_name) %>%
  summarise(total_questions = sum(n_questions, na.rm = TRUE), .groups = "drop") %>%
  mutate(percent = round(total_questions / sum(total_questions) * 100, 1)) %>%
  arrange(desc(total_questions))

# Add total row
total_row <- tibble(
  issue_name = "TOTAL",
  total_questions = sum(issue_totals$total_questions),
  percent = sum(issue_totals$percent)
)
issue_totals <- bind_rows(issue_totals, total_row)
saveRDS(issue_totals, here("output", "issue_totals.rds"))

# Issue shares by year (longitudinal) ####

issue_year_totals <- df_merged_3 %>%
  group_by(mid_year, issue_name) %>%
  summarise(total_questions = sum(n_questions, na.rm = TRUE), .groups = "drop")

issue_shares <- issue_year_totals %>%
  group_by(mid_year) %>%
  mutate(
    total_year = sum(total_questions),
    share = total_questions / total_year
  ) %>%
  ungroup()
saveRDS(issue_shares, here("output", "issue_shares_by_year.rds"))

# Top-8 issues by average share ####

top_issues <- issue_shares %>%
  group_by(issue_name) %>%
  summarise(avg_share = mean(share), .groups = "drop") %>%
  slice_max(avg_share, n = 8) %>%
  pull(issue_name)

issue_shares_top <- issue_shares %>%
  filter(issue_name %in% top_issues)
saveRDS(issue_shares_top, here("output", "issue_shares_top.rds"))

# Shannon diversity index by year ####

shannon_by_year <- issue_shares %>%
  mutate(p_i = total_questions / total_year) %>%
  group_by(mid_year) %>%
  summarise(
    H = -sum(ifelse(p_i > 0, p_i * log(p_i), 0)),
    k = n_distinct(issue_name),
    H_norm = H / log(k),
    .groups = "drop"
  )
saveRDS(shannon_by_year, here("output", "shannon_by_year.rds"))

# Sigelman-Buell similarity ####
message("  Computing Sigelman-Buell congruence matrices...")

sigelman_index <- function(x, y) {
  1 - 0.5 * sum(abs(x - y))
}

compute_similarity_matrix <- function(profile_matrix) {
  groups <- profile_matrix[[1]]
  mat <- as.matrix(profile_matrix[, -1])
  rownames(mat) <- groups

  sim <- outer(
    1:nrow(mat), 1:nrow(mat),
    Vectorize(function(i, j) sigelman_index(mat[i, ], mat[j, ]))
  )

  rownames(sim) <- groups
  colnames(sim) <- groups
  as.data.frame(sim)
}

# Party family congruence
party_issue_share <- df_merged_3 %>%
  group_by(party_family, issue_name) %>%
  summarise(n = sum(n_questions, na.rm = TRUE), .groups = "drop") %>%
  group_by(party_family) %>%
  mutate(share = n / sum(n)) %>%
  select(party_family, issue_name, share) %>%
  pivot_wider(names_from = issue_name, values_from = share, values_fill = 0)

party_sim <- compute_similarity_matrix(party_issue_share)
saveRDS(party_sim, here("output", "party_similarity_matrix.rds"))

# Country congruence
country_issue_share <- df_merged_3 %>%
  group_by(country, issue_name) %>%
  summarise(n = sum(n_questions, na.rm = TRUE), .groups = "drop") %>%
  group_by(country) %>%
  mutate(share = n / sum(n)) %>%
  select(country, issue_name, share) %>%
  pivot_wider(names_from = issue_name, values_from = share, values_fill = 0)

country_sim <- compute_similarity_matrix(country_issue_share)
saveRDS(country_sim, here("output", "country_similarity_matrix.rds"))
