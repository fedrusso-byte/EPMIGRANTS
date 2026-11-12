# ==============================================================================
# explorations/cap_topic_scan/01_topic_scan.R
# Inductive CAP topic scan: which issues do minority-background MEPs emphasize
# beyond the null CAP-201 (discrimination) result?
#
# READS (no pipeline files modified):
#   data_processed/epq.csv, output/df_merged_3.csv, output/problem_indicators.csv
#   scripts/utils/cap_issue_mapping.R  (project CAP major labels; source of truth)
#
# DESIGN MIRRORS scripts/05_models_Bayesian.R:
#   - sample: legislative_term in {7th, 8th, 9th} + drop_na(...)  (ref N = 9,850)
#   - question->MEP-year mapping mirrors 02_df_setup.R L274-297
#     (leg_year windows derived from the panel; validated exactly vs CAP-201)
#   - controlled layer: glmmTMB NB2 GLMM per topic, offset(total_questions),
#     BH-FDR per code family. NOTE: NB2 without zero-inflation (speed/robustness
#     over many sparse DVs); the paper's CAP-201 model is ZINB, reported ns.
#
# OUTPUTS -> explorations/cap_topic_scan/out/ (CSV tables + 3 figures PNG)
# ==============================================================================

rm(list = ls())
set.seed(20260321)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(ggplot2)
  library(glmmTMB)
  library(here)
})

source(here("scripts", "utils", "cap_issue_mapping.R"))

out_dir <- here("explorations", "cap_topic_scan", "out")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Window constants (mirroring 02 / 05) ####
WIN_START_VI   <- as.Date("2004-07-20")
WIN_END        <- as.Date("2024-06-08")
TERMS_MODEL    <- c("7th", "8th", "9th")
N_BOOT         <- 2000L
MIN_N_MIN_EX   <- 25L   # volume threshold: minor-code examples table
MIN_N_MIN_MOD  <- 25L   # volume threshold: model a minor code
MIN_EVENTS_MOD <- 5L    # minimum minority events to attempt a topic model

## 1. Inputs ####
message("   Loading inputs...")
epq <- read_csv(
  here("data_processed", "epq.csv"),
  col_select = c(id, date, subject, mep_id, major, subtopic, pq_discrimination),
  show_col_types = FALSE
) |>
  mutate(date = as.Date(date), major = as.integer(major), subtopic = as.integer(subtopic))

stopifnot("epq.csv is empty" = nrow(epq) > 0)

panel <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE)

ind <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) |>
  mutate(year = as.integer(round(year)))

# MEP-level minority flag: time-invariant in the source; some MEPs are fully
# unflagged (mostly VI mandates), no MEP carries conflicting non-NA flags
mep_lookup <- panel |>
  group_by(mep_id) |>
  summarise(minority = first(minority[!is.na(minority)]), .groups = "drop")
chk_mc <- panel |> filter(!is.na(minority)) |> distinct(mep_id, minority)
stopifnot("conflicting non-NA minority flags for some MEPs" = !any(duplicated(chk_mc$mep_id)))

## Model sample: verbatim mirror of scripts/05_models_Bayesian.R L33-55 ####
sample_df <- panel |>
  mutate(mid_year = as.integer(round(mid_year))) |>
  left_join(ind, by = c("country", "mid_year" = "year")) |>
  mutate(
    discrimination_center = discrimination_mean - mean(discrimination_mean, na.rm = TRUE),
    cmp_center = cmp_mean - mean(cmp_mean, na.rm = TRUE),
    mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE)
  ) |>
  filter(legislative_term %in% TERMS_MODEL) |>
  drop_na(pqs_discrimination, total_questions, gender, mep_id, country,
          party_family, libe, minority, misery_index, cmp_center, mipex_center)

message("   Model sample rows: ", nrow(sample_df), " (reference in 05: 9,850)",
        " | minority MEPs in sample: ",
        n_distinct(sample_df$mep_id[sample_df$minority == 1]))

## 2. Map questions to MEP-year rows (mirror of 02_df_setup L274-297) ####
# leg_year windows are taken from the panel itself (identical for all MEPs of a
# leg_year); windows are contiguous within parliaments, so findInterval on
# window starts reproduces assign_term() + lubridate interval slicing in 02.
wind <- panel |>
  group_by(legislative_term, leg_year) |>
  summarise(win_start = min(year_start, na.rm = TRUE),
            win_end   = max(year_end, na.rm = TRUE), .groups = "drop") |>
  filter(legislative_term %in% c("6th", TERMS_MODEL)) |>
  arrange(win_start)

stopifnot(nrow(wind) > 0, min(wind$win_start) == WIN_START_VI)

q_raw <- epq |> filter(date >= WIN_START_VI, date <= WIN_END)
message("   EPQ rows in VI-IX window: ", nrow(q_raw),
        " (dropped outside window: ", nrow(epq) - nrow(q_raw), ")")

pos  <- findInterval(as.integer(q_raw$date), as.integer(wind$win_start))
ok_w <- as.integer(q_raw$date) <= as.integer(wind$win_end[pos])
if (any(!ok_w)) message("   Questions between parliaments (dropped): ", sum(!ok_w))

q_map <- q_raw |>
  mutate(leg_year = wind$leg_year[pos],
         legislative_term = wind$legislative_term[pos]) |>
  filter(ok_w) |>
  mutate(
    minority  = mep_lookup$minority[match(mep_id, mep_lookup$mep_id)],
    issue_maj = assign_issue_name(major)
  )
message("   Question rows with unknown minority flag (VI-only / unflagged, excluded): ",
        sum(is.na(q_map$minority)))

q_v79 <- q_map |>
  filter(legislative_term %in% TERMS_MODEL, !is.na(minority)) |>
  mutate(topic_key = ifelse(is.na(major), NA_character_, paste0(major, "_", subtopic)))

message("   VII-IX question rows used in the scan: ", nrow(q_v79),
        " | minority MEPs observed in window: ",
        n_distinct(q_v79$mep_id[q_v79$minority == 1]),
        " | non-minority MEPs: ", n_distinct(q_v79$mep_id[q_v79$minority == 0]))

## 3. Sanity checks vs the pipeline panel ####
disc_map <- q_v79 |>
  group_by(mep_id, leg_year) |>
  summarise(disc_check = sum(pq_discrimination == 1, na.rm = TRUE), .groups = "drop")

chk <- sample_df |>
  left_join(disc_map, by = c("mep_id", "leg_year")) |>
  mutate(disc_check = replace_na(disc_check, 0), diff = pqs_discrimination - disc_check)

stopifnot(
  "question->leg_year mapping disagrees with 02_df_setup (CAP-201 counts differ)" =
    all(chk$diff == 0)
)
message("   Sanity A (CAP-201 per MEP-year, exact match on ", nrow(chk), " rows): OK")

topic_tot <- q_v79 |> count(mep_id, leg_year, name = "n_topic")
chk2 <- sample_df |>
  left_join(topic_tot, by = c("mep_id", "leg_year")) |>
  mutate(n_topic = replace_na(n_topic, 0))
message("   Sanity B: total_questions MINUS summed topic counts over sample = ",
        sum(chk2$total_questions - chk2$n_topic),
        " (should equal NA-coded majors/subtopics only)")

## 4. Descriptive map (question-level shares, VII-IX) ####
iss_vec <- sort(unique(q_v79$issue_maj))

tab_maj <- q_v79 |>
  group_by(minority, issue_maj) |>
  summarise(n = n(), n_mep = n_distinct(mep_id), .groups = "drop") |>
  pivot_wider(names_from = minority, values_from = c(n, n_mep), values_fill = 0,
              names_sort = TRUE) |>
  rename(n_nonmin = n_0, n_min = n_1, n_mep_nonmin = n_mep_0, n_mep_min = n_mep_1) |>
  mutate(
    share_nonmin = n_nonmin / sum(n_nonmin) * 100,
    share_min    = n_min / sum(n_min) * 100,
    ratio        = share_min / share_nonmin,
    diff_pp      = share_min - share_nonmin
  )

# MEP-level bootstrap of share differences (resample MEPs within group)
bmatrix <- q_v79 |>
  filter(!is.na(issue_maj)) |>
  mutate(issue_maj = factor(issue_maj, levels = iss_vec)) |>
  count(mep_id, minority, issue_maj, .drop = FALSE) |>
  pivot_wider(names_from = issue_maj, values_from = n, values_fill = 0)
bmat0 <- as.matrix(bmatrix |> filter(minority == 0) |> select(-mep_id, -minority))
bmat1 <- as.matrix(bmatrix |> filter(minority == 1) |> select(-mep_id, -minority))
tot0 <- rowSums(bmat0); tot1 <- rowSums(bmat1)
boot_diff <- matrix(NA_real_, nrow = N_BOOT, ncol = ncol(bmat0))
for (b in seq_len(N_BOOT)) {
  s0 <- sample.int(nrow(bmat0), nrow(bmat0), replace = TRUE)
  s1 <- sample.int(nrow(bmat1), nrow(bmat1), replace = TRUE)
  p0 <- colSums(bmat0[s0, , drop = FALSE]) / sum(tot0[s0])
  p1 <- colSums(bmat1[s1, , drop = FALSE]) / sum(tot1[s1])
  boot_diff[b, ] <- 100 * (p1 - p0)
}
colnames(boot_diff) <- colnames(bmat0)
ci_maj <- t(apply(boot_diff, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE))
tab_maj <- tab_maj |>
  mutate(boot_lo = ci_maj[as.character(factor(issue_maj, levels = iss_vec)), 1],
         boot_hi = ci_maj[as.character(factor(issue_maj, levels = iss_vec)), 2]) |>
  mutate(issue_maj = ifelse(issue_maj == "Other",
                            "Other (incl. CAP-23 Culture/Media/Sport)", issue_maj))

## Minor-code table (same frame; no CIs on thin cells) ####
tab_min <- q_v79 |>
  filter(!is.na(subtopic)) |>
  group_by(topic_key, minority) |>
  summarise(n = n(), n_mep = n_distinct(mep_id), .groups = "drop") |>
  pivot_wider(names_from = minority, values_from = c(n, n_mep), values_fill = 0,
              names_sort = TRUE) |>
  rename(n_nonmin = n_0, n_min = n_1, n_mep_nonmin = n_mep_0, n_mep_min = n_mep_1) |>
  mutate(
    major_id = as.integer(sub("_.*$", "", topic_key)),
    sub_code = as.integer(sub("^[0-9]+_", "", topic_key)),
    issue_maj = assign_issue_name(major_id),
    share_nonmin = n_nonmin / sum(n_nonmin) * 100,
    share_min = n_min / sum(n_min) * 100,
    ratio = share_min / share_nonmin,
    diff_pp = share_min - share_nonmin
  ) |>
  arrange(desc(n_min))

## Example subjects for volume-relevant minor codes (inductive labels) ####
ex_keys <- tab_min |> filter(n_min >= MIN_N_MIN_EX) |> pull(topic_key)
ex_top <- q_v79 |>
  filter(topic_key %in% ex_keys) |>
  count(topic_key, subject, sort = TRUE) |>
  group_by(topic_key) |>
  slice_max(n, n = 5, with_ties = FALSE) |>
  ungroup() |>
  left_join(
    tab_min |> select(topic_key, sub_code, issue_maj, n_min, n_nonmin, ratio),
    by = "topic_key"
  ) |>
  mutate(subject = as.character(str_trunc(str_squish(subject), 95))) |>
  relocate(topic_key, sub_code, issue_maj, n_min, n_nonmin, ratio, subject, n)

## Full-window (VI-IX) major-code sensitivity table ####
tab_maj_all <- q_map |>
  filter(!is.na(minority)) |>
  group_by(minority, issue_maj) |>
  summarise(n = n(), n_mep = n_distinct(mep_id), .groups = "drop") |>
  pivot_wider(names_from = minority, values_from = c(n, n_mep), values_fill = 0,
              names_sort = TRUE) |>
  rename(n_nonmin = n_0, n_min = n_1) |>
  mutate(share_nonmin = n_nonmin / sum(n_nonmin) * 100,
         share_min = n_min / sum(n_min) * 100,
         ratio = share_min / share_nonmin,
         diff_pp = share_min - share_nonmin)

## 5. Controlled scan: NB2 GLMM per topic on the mirrored 05 sample ####
fit_topic <- function(dv_long, label, family_tag) {
  dat <- sample_df |>
    left_join(dv_long, by = c("mep_id", "leg_year")) |>
    mutate(.y = replace_na(.y, 0))
  n1_ev  <- sum(dat$.y[dat$minority == 1])
  n0_ev  <- sum(dat$.y[dat$minority == 0])
  n1_row <- sum(dat$.y[dat$minority == 1] > 0)
  if (n1_ev < MIN_EVENTS_MOD) {
    return(tibble(family = family_tag, label = label, est = NA_real_, se = NA_real_,
                  p = NA_real_, irr = NA_real_, lo = NA_real_, hi = NA_real_,
                  n_events_min = n1_ev, n_rows_min_pos = n1_row, n_events_nonmin = n0_ev,
                  status = "skipped_sparse"))
  }
  fit <- tryCatch(
    glmmTMB(
      .y ~ minority + gender + misery_index + party_family + libe +
        offset(log(total_questions + 1)) + (1 | country),
      family = nbinom2, data = dat
    ),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(tibble(family = family_tag, label = label, est = NA_real_, se = NA_real_,
                  p = NA_real_, irr = NA_real_, lo = NA_real_, hi = NA_real_,
                  n_events_min = n1_ev, n_rows_min_pos = n1_row, n_events_nonmin = n0_ev,
                  status = paste("error:", conditionMessage(fit))))
  }
  cf <- summary(fit)$coefficients$cond
  est  <- cf["minority", "Estimate"]
  se   <- cf["minority", "Std. Error"]
  pval <- cf["minority", "Pr(>|z|)"]
  tibble(family = family_tag, label = label, est = est, se = se, p = pval,
         irr = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se),
         n_events_min = n1_ev, n_rows_min_pos = n1_row, n_events_nonmin = n0_ev,
         status = "ok")
}

maj_dv <- q_v79 |>
  semi_join(sample_df, by = c("mep_id", "leg_year")) |>
  count(mep_id, leg_year, issue_maj)

res_maj <- map_dfr(sort(unique(maj_dv$issue_maj)), function(lab) {
  dv <- maj_dv |> filter(issue_maj == lab) |> select(mep_id, leg_year, .y = n)
  fit_topic(dv, lab, "major")
}) |>
  mutate(pBH = p.adjust(p, method = "BH"))

min_dv <- q_v79 |>
  semi_join(sample_df, by = c("mep_id", "leg_year")) |>
  count(mep_id, leg_year, topic_key, minority)

min_keys <- min_dv |>
  filter(minority == 1, !is.na(topic_key)) |>
  count(topic_key, wt = n, name = "n_min_sample") |>
  filter(n_min_sample >= MIN_N_MIN_MOD) |>
  pull(topic_key)

res_min <- map_dfr(min_keys, function(k) {
  dv <- min_dv |> filter(topic_key == k) |> select(mep_id, leg_year, .y = n)
  fit_topic(dv, k, "minor")
}) |>
  mutate(pBH = p.adjust(p, method = "BH"))

## 6. Figures ####
f1 <- tab_maj |>
  arrange(diff_pp) |>
  mutate(lab = factor(paste0(issue_maj, "  [", n_min, " vs ", n_nonmin, "]"),
                      levels = paste0(issue_maj, "  [", n_min, " vs ", n_nonmin, "]"))) |>
  ggplot(aes(diff_pp, lab)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey35") +
  geom_pointrange(aes(xmin = boot_lo, xmax = boot_hi),
                  colour = "#205072", linewidth = 0.45, size = 0.55) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Topic emphasis: minority vs non-minority MEPs (VII-IX)",
    subtitle = "Difference in question shares (pp); MEP-level bootstrap 95% CI (2,000 draws)",
    x = "Share difference (pp, minority - non-minority)", y = NULL
  )
ggsave(file.path(out_dir, "fig_share_diff_majors.png"), f1, width = 9, height = 7.5, dpi = 200)

f2 <- tab_min |>
  filter(n_min >= MIN_N_MIN_EX) |>
  mutate(lab = paste0(sub_code, " (", issue_maj, ")  [", n_min, " vs ", n_nonmin, "]")) |>
  arrange(ratio) |>
  mutate(lab = factor(lab, levels = lab)) |>
  ggplot(aes(ratio, lab)) +
  geom_point(aes(size = n_min), colour = "#D95F02") +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey35") +
  scale_x_continuous(trans = "log2", breaks = c(0.25, 0.5, 1, 2, 4, 8)) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Minor CAP codes: question-share ratio, minority / non-minority (VII-IX)",
    subtitle = "Codes with >= 25 minority-MEP questions; point size = minority volume",
    x = "Share ratio (log2 scale; 1 = parity)", y = NULL
  )
ggsave(file.path(out_dir, "fig_share_ratio_minors.png"), f2, width = 9, height = 7.5, dpi = 200)

f3 <- bind_rows(
  res_maj |>
    mutate(code_label = label, fam = "CAP major codes"),
  res_min |>
    left_join(tab_min |> select(topic_key, sub_code, issue_maj), by = c("label" = "topic_key")) |>
    mutate(code_label = paste0(sub_code, " (", issue_maj, ")"),
           fam = "CAP minor codes (>= 25 minority Qs)")
) |>
  filter(status == "ok") |>
  mutate(code_label = paste0(code_label, "  [", n_events_min, "]")) |>
  arrange(fam, desc(irr)) |>
  mutate(
    code_label = factor(code_label, levels = unique(code_label)),
    fam = factor(fam, levels = c("CAP major codes", "CAP minor codes (>= 25 minority Qs)"))
  ) |>
  ggplot(aes(irr, code_label)) +
  facet_grid(fam ~ ., scales = "free_y", space = "free_y") +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey35") +
  geom_pointrange(aes(xmin = lo, xmax = hi, colour = pBH < 0.05), linewidth = 0.4) +
  scale_colour_manual(values = c("grey55", "#D95F02"), name = "FDR-corrected p < 0.05") +
  scale_x_continuous(trans = "log2", breaks = c(0.25, 0.5, 0.75, 1, 1.5, 2, 4)) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Controlled scan: minority topic emphasis (NB2 GLMM IRRs)",
    subtitle = "Sample & controls as 05 (9,850 MEP-years); offset log(total_questions+1); (1|country)",
    x = "Incidence rate ratio (log2 scale; 1 = parity)", y = NULL
  )
ggsave(file.path(out_dir, "fig_model_irr.png"), f3, width = 9.5, height = 11, dpi = 200)

## 7. Write outputs ####
write_csv(tab_maj, file.path(out_dir, "descriptives_major_vii_ix.csv"))
write_csv(tab_min, file.path(out_dir, "descriptives_minor_vii_ix.csv"))
write_csv(tab_maj_all, file.path(out_dir, "descriptives_major_fullwindow.csv"))
write_csv(ex_top, file.path(out_dir, "examples_minor_top.csv"))
write_csv(res_maj, file.path(out_dir, "models_major.csv"))
write_csv(res_min, file.path(out_dir, "models_minor.csv"))

## 8. Console summary ####
message("\n=== TOPIC SCAN SUMMARY (VII-IX, minority-background MEPs) ===")
print(q_v79 |> count(minority, name = "questions"))
message("\nTotal minority questions: ", sum(tab_maj$n_min),
        " | non-minority: ", sum(tab_maj$n_nonmin))

message("\nMajor codes by share difference (pp):")
print(
  tab_maj |>
    select(issue_maj, n_min, n_nonmin, share_min, share_nonmin, ratio,
           diff_pp, boot_lo, boot_hi) |>
    arrange(desc(diff_pp)),
  row.names = FALSE
)

message("\nTop minor codes by minority volume:")
print(
  tab_min |>
    select(topic_key, issue_maj, n_min, n_nonmin, share_min, share_nonmin, ratio) |>
    head(15),
  row.names = FALSE
)

message("\nMajor-code models (sorted by p):")
print(
  res_maj |>
    select(label, irr, lo, hi, p, pBH, n_events_min, status) |>
    arrange(p),
  row.names = FALSE
)

message("\nMinor-code models (sorted by p):")
print(
  res_min |>
    select(label, irr, lo, hi, p, pBH, n_events_min, status) |>
    arrange(p),
  row.names = FALSE
)

message("\nScan complete. Outputs in: ", out_dir)

invisible(TRUE)




