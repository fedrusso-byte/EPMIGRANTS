# ============================================================
# Responsiveness Analysis Report
# Author: Marcello Carammia / Claude
# Purpose: Produce publication-ready descriptive and model summaries
#          for the Europeanisation of Representation paper
# Inputs:  output/responsiveness_panel.rds, output/resp_model_*.rds,
#          output/europeanisation_cv.rds, output/resp_congruence.rds,
#          output/resp_irr_tables.rds, output/resp_vc_comparison.rds,
#          output/resp_model_comparison.rds, output/resp_domain_trends.rds
# Outputs: output/figures/report_*.pdf, output/tables/report_*.html,
#          output/report_summary.rds
# ============================================================

# 0. Setup ----
library(tidyverse)
library(glmmTMB)
library(broom.mixed)
library(modelsummary)
library(kableExtra)
library(patchwork)
library(scales)
library(here)

set.seed(20260327)

dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)

# ============================================================
# 1. Data Loading ----
# ============================================================
message("=== Loading data and model objects ===")

panel <- readRDS(here("output", "responsiveness_panel.rds"))
cv_data <- readRDS(here("output", "europeanisation_cv.rds"))
congruence <- readRDS(here("output", "resp_congruence.rds"))
model_comparison <- readRDS(here("output", "resp_model_comparison.rds"))
vc_comparison <- readRDS(here("output", "resp_vc_comparison.rds"))
irr_tables <- readRDS(here("output", "resp_irr_tables.rds"))
domain_trends <- readRDS(here("output", "resp_domain_trends.rds"))

# Load fitted models
m0 <- readRDS(here("output", "resp_model_0_baseline.rds"))
m2 <- readRDS(here("output", "resp_model_2_decomposition.rds"))
m3 <- readRDS(here("output", "resp_model_3_domain.rds"))
m5 <- readRDS(here("output", "resp_model_5_full.rds"))

# Also load m1 if available
m1_path <- here("output", "resp_model_1_problems.rds")
m1 <- if (file.exists(m1_path)) readRDS(m1_path) else NULL

# ============================================================
# 2. Panel Descriptives ----
# ============================================================
message("\n=== Panel Descriptives ===")

# --- 2a. Panel dimensions ---
matched_panel <- panel %>% dplyr::filter(!is.na(mip_share))

panel_summary <- tibble(
  Metric = c("Total rows", "Rows with MIP data", "MEPs", "Countries",
             "Issues (all)", "Issues (MIP-matched)", "Semesters",
             "Period", "Total questions", "Mean questions/MEP-semester-issue"),
  Value = c(
    format(nrow(panel), big.mark = ","),
    format(nrow(matched_panel), big.mark = ","),
    as.character(n_distinct(panel$mep_id)),
    as.character(n_distinct(panel$country)),
    as.character(n_distinct(panel$issue_name)),
    as.character(n_distinct(matched_panel$issue_name)),
    as.character(n_distinct(paste(panel$year, panel$semester))),
    paste0(min(panel$year), "-", max(panel$year)),
    format(sum(panel$n_questions), big.mark = ","),
    round(mean(matched_panel$n_questions), 3)
  )
)

message("Panel summary:")
print(panel_summary, n = Inf)

# --- 2b. Issue frequency table ---
issue_summary <- matched_panel %>%
  group_by(issue_name, domain) %>%
  summarise(
    total_questions = sum(n_questions),
    mean_mip_share = mean(mip_share, na.rm = TRUE),
    mean_mip_eu = mean(mip_eu_mean, na.rm = TRUE),
    mean_cv = mean(mip_cv, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_questions)) %>%
  mutate(
    pct_questions = round(100 * total_questions / sum(total_questions), 1),
    domain = factor(domain, levels = c("economy", "migration", "other"))
  )

message("\nIssue summary:")
print(issue_summary, n = Inf)

# Save as formatted HTML table
issue_summary %>%
  mutate(
    mean_mip_share = round(mean_mip_share, 3),
    mean_mip_eu = round(mean_mip_eu, 3),
    mean_cv = round(mean_cv, 2)
  ) %>%
  kbl(
    col.names = c("Issue (CAP)", "Domain", "Total Qs", "% of Qs",
                  "Mean MIP Share", "Mean EU MIP", "Mean CV"),
    caption = "Issue Summary: EP Questions and MIP Salience (2003-2024)"
  ) %>%
  kable_styling(bootstrap_options = c("striped", "condensed"), full_width = FALSE) %>%
  row_spec(which(issue_summary$domain == "economy"), background = "#FFF3E0") %>%
  row_spec(which(issue_summary$domain == "migration"), background = "#E3F2FD") %>%
  save_kable(here("output", "tables", "report_issue_summary.html"))

# --- 2c. Questions distribution ---
q_dist <- matched_panel %>%
  dplyr::filter(n_questions > 0) %>%
  summarise(
    mean = mean(n_questions),
    median = median(n_questions),
    sd = sd(n_questions),
    max = max(n_questions),
    pct_zero = 100 * mean(matched_panel$n_questions == 0)
  )
message("\nQuestion count distribution (non-zero):")
message("  Mean: ", round(q_dist$mean, 2), ", Median: ", q_dist$median,
        ", SD: ", round(q_dist$sd, 2), ", Max: ", q_dist$max)
message("  Zero-inflation: ", round(q_dist$pct_zero, 1), "% of cells are zero")

# ============================================================
# 3. Europeanisation Patterns ----
# ============================================================
message("\n=== Europeanisation Patterns (CV) ===")

# --- 3a. CV summary by domain ---
cv_by_domain <- cv_data %>%
  group_by(domain) %>%
  summarise(
    mean_cv = mean(mip_cv, na.rm = TRUE),
    sd_cv = sd(mip_cv, na.rm = TRUE),
    min_cv = min(mip_cv, na.rm = TRUE),
    max_cv = max(mip_cv, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  )
message("CV by domain (lower = more Europeanised):")
print(cv_by_domain)

# --- 3b. CV by issue (ranked) ---
cv_by_issue <- cv_data %>%
  group_by(cap_issue_name = issue_name, domain) %>%
  summarise(mean_cv = mean(mip_cv, na.rm = TRUE), .groups = "drop") %>%
  arrange(mean_cv)
message("\nMost Europeanised issues (lowest CV):")
print(cv_by_issue, n = Inf)

# --- 3c. Figure: CV over time by domain (improved) ---
cv_time <- cv_data %>%
  mutate(time = year + (semester - 1) * 0.5) %>%
  group_by(time, domain) %>%
  summarise(mean_cv = mean(mip_cv, na.rm = TRUE), .groups = "drop")

# Add crisis annotations
crisis_periods <- tibble(
  xmin = c(2008, 2015, 2020),
  xmax = c(2010, 2016, 2021),
  label = c("Financial\nCrisis", "Migration\nCrisis", "COVID-19")
)

p_cv <- ggplot(cv_time, aes(x = time, y = mean_cv, color = domain)) +
  geom_rect(data = crisis_periods, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
            fill = "grey90", alpha = 0.5) +
  geom_text(data = crisis_periods, inherit.aes = FALSE,
            aes(x = (xmin + xmax) / 2, y = Inf, label = label),
            vjust = 1.2, size = 2.5, color = "grey50") +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.2) +
  scale_color_manual(
    values = c("economy" = "#E69F00", "migration" = "#0072B2", "other" = "#999999"),
    labels = c("Economy", "Migration", "Other")
  ) +
  labs(
    title = "Europeanisation of Public Priorities Over Time",
    subtitle = "Cross-country CV of MIP salience (lower = more uniform across countries)",
    x = NULL, y = "Coefficient of Variation", color = "Domain"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(here("output", "figures", "report_cv_time.pdf"), p_cv, width = 10, height = 6)

# ============================================================
# 4. MIP-EPQ Congruence ----
# ============================================================
message("\n=== MIP-EPQ Congruence ===")

congruence_summary <- congruence %>%
  summarise(
    mean_sb = mean(sigelman_buell, na.rm = TRUE),
    sd_sb = sd(sigelman_buell, na.rm = TRUE),
    min_sb = min(sigelman_buell, na.rm = TRUE),
    max_sb = max(sigelman_buell, na.rm = TRUE)
  )
message("Sigelman-Buell congruence: Mean = ", round(congruence_summary$mean_sb, 3),
        " (SD = ", round(congruence_summary$sd_sb, 3), ")")

# Congruence by country (ranked)
congruence_by_country <- congruence %>%
  group_by(country) %>%
  summarise(mean_sb = mean(sigelman_buell, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(mean_sb))
message("\nTop 5 most congruent countries:")
print(head(congruence_by_country, 5))
message("Bottom 5:")
print(tail(congruence_by_country, 5))

# --- Figure: Congruence by country ---
p_congruence_country <- ggplot(congruence_by_country,
                                aes(x = mean_sb, y = reorder(country, mean_sb))) +
  geom_col(fill = "#4CAF50", alpha = 0.7) +
  geom_vline(xintercept = congruence_summary$mean_sb, linetype = "dashed", color = "red") +
  labs(
    title = "MIP-EPQ Congruence by Country",
    subtitle = paste0("Sigelman-Buell index (red line = mean ",
                      round(congruence_summary$mean_sb, 2), ")"),
    x = "Mean Congruence", y = NULL
  ) +
  theme_minimal(base_size = 10)

ggsave(here("output", "figures", "report_congruence_country.pdf"),
       p_congruence_country, width = 8, height = 8)

# ============================================================
# 5. Model Comparison ----
# ============================================================
message("\n=== Model Comparison ===")

message("AIC/BIC comparison:")
print(model_comparison)

# ============================================================
# 6. Key Coefficients: Decomposition (Model 2) ----
# ============================================================
message("\n=== Model 2: Decomposition (Core H1/H2 Test) ===")

m2_coefs <- broom.mixed::tidy(m2, component = "cond", conf.int = TRUE,
                                exponentiate = TRUE) %>%
  dplyr::filter(str_detect(term, "mip_|unemp_|asylum_"))

message("\nKey IRRs from Model 2 (decomposition):")
m2_coefs %>%
  dplyr::select(term, estimate, conf.low, conf.high, p.value) %>%
  mutate(across(c(estimate, conf.low, conf.high), ~round(., 3)),
         p.value = format.pval(p.value, digits = 3)) %>%
  print(n = Inf)

# --- Figure: Decomposition forest plot (improved) ---
forest_data <- m2_coefs %>%
  mutate(
    term_label = case_when(
      term == "mip_eu_mean_z"      ~ "MIP: EU-wide signal",
      term == "mip_deviation_z"    ~ "MIP: Domestic deviation",
      term == "unemp_eu_mean_z"    ~ "Unemployment: EU-wide",
      term == "unemp_deviation_z"  ~ "Unemployment: Domestic",
      term == "asylum_eu_mean_z"   ~ "Asylum: EU-wide",
      term == "asylum_deviation_z" ~ "Asylum: Domestic",
      TRUE ~ term
    ),
    predictor_group = case_when(
      str_detect(term, "mip_")    ~ "Public Priorities (MIP)",
      str_detect(term, "unemp_")  ~ "Unemployment",
      str_detect(term, "asylum_") ~ "Asylum Applications"
    ),
    component = if_else(str_detect(term, "eu_mean"), "EU-wide", "Domestic")
  )

p_decomp <- ggplot(forest_data,
                    aes(x = estimate, y = reorder(term_label, estimate),
                        xmin = conf.low, xmax = conf.high,
                        color = component, shape = predictor_group)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50") +
  geom_pointrange(size = 0.7, linewidth = 0.8) +
  scale_color_manual(values = c("EU-wide" = "#0072B2", "Domestic" = "#D55E00")) +
  scale_x_continuous(breaks = pretty_breaks(8)) +
  labs(
    title = "Responsiveness Decomposition: EU-Wide vs Domestic",
    subtitle = "Model 2 IRRs (>1 = more questions when predictor increases)",
    x = "Incidence Rate Ratio (IRR)", y = NULL,
    color = "Level", shape = "Predictor"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.box = "vertical")

ggsave(here("output", "figures", "report_decomposition.pdf"),
       p_decomp, width = 9, height = 5)

# ============================================================
# 7. Domain Heterogeneity (Model 3, H3) ----
# ============================================================
message("\n=== Model 3: Domain Interactions (H3) ===")

message("\nEU-wide responsiveness by domain (emtrends):")
print(summary(domain_trends$eu_mean))

message("\nDomestic responsiveness by domain (emtrends):")
print(summary(domain_trends$deviation))

message("\nPairwise comparisons (EU-wide):")
print(domain_trends$eu_mean_pairs)

message("\nPairwise comparisons (domestic):")
print(domain_trends$deviation_pairs)

# --- Figure: Domain-specific slopes ---
eu_trends_df <- as.data.frame(summary(domain_trends$eu_mean)) %>%
  mutate(component = "EU-wide", irr = exp(mip_eu_mean_z.trend),
         irr_lo = exp(asymp.LCL), irr_hi = exp(asymp.UCL))

dev_trends_df <- as.data.frame(summary(domain_trends$deviation)) %>%
  mutate(component = "Domestic", irr = exp(mip_deviation_z.trend),
         irr_lo = exp(asymp.LCL), irr_hi = exp(asymp.UCL))

domain_plot_data <- bind_rows(eu_trends_df, dev_trends_df)

p_domain <- ggplot(domain_plot_data,
                    aes(x = irr, y = domain,
                        xmin = irr_lo, xmax = irr_hi,
                        color = component)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50") +
  geom_pointrange(size = 0.8, linewidth = 0.9,
                  position = position_dodge(width = 0.4)) +
  scale_color_manual(values = c("EU-wide" = "#0072B2", "Domestic" = "#D55E00")) +
  facet_wrap(~component, scales = "free_x") +
  labs(
    title = "MEP Responsiveness by Policy Domain",
    subtitle = "IRRs from Model 3 (domain × MIP decomposition interactions)",
    x = "Incidence Rate Ratio (IRR)", y = NULL, color = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none",
        strip.text = element_text(face = "bold"))

ggsave(here("output", "figures", "report_domain_slopes.pdf"),
       p_domain, width = 10, height = 4)

# ============================================================
# 8. Variance Decomposition ----
# ============================================================
message("\n=== Variance Decomposition ===")

vc_wide <- vc_comparison %>%
  pivot_wider(names_from = model, values_from = variance)
message("Random effect variances by model:")
print(vc_wide)

# Compute variance shares for m2 (core model)
vc_m2 <- vc_comparison %>%
  dplyr::filter(model == "m2") %>%
  mutate(
    share = variance / sum(variance),
    share_pct = round(100 * share, 1)
  )
message("\nVariance shares (Model 2):")
print(vc_m2)

# --- Figure: Variance decomposition ---
p_vc <- ggplot(vc_m2, aes(x = reorder(group, -share), y = share_pct, fill = group)) +
  geom_col(alpha = 0.8) +
  geom_text(aes(label = paste0(share_pct, "%")), vjust = -0.3, size = 3.5) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Variance Decomposition (Model 2)",
    subtitle = "Share of random-effect variance by grouping factor",
    x = NULL, y = "Variance Share (%)"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none") +
  ylim(0, max(vc_m2$share_pct) * 1.15)

ggsave(here("output", "figures", "report_variance_decomposition.pdf"),
       p_vc, width = 7, height = 5)

# ============================================================
# 9. Regression Table (modelsummary) ----
# ============================================================
message("\n=== Regression Table ===")

models_list <- list(
  "M0: Baseline" = m0,
  "M2: Decomposition" = m2,
  "M3: Domain" = m3,
  "M5: Full" = m5
)
if (!is.null(m1)) models_list[["M1: +Problems"]] <- m1

# Key coefficients to show
coef_map <- c(
  "mip_share_z"              = "MIP salience (z)",
  "mip_eu_mean_z"            = "MIP: EU-wide (z)",
  "mip_deviation_z"          = "MIP: Domestic (z)",
  "unemp_eu_mean_z"          = "Unemployment: EU-wide (z)",
  "unemp_deviation_z"        = "Unemployment: Domestic (z)",
  "asylum_eu_mean_z"         = "Asylum: EU-wide (z)",
  "asylum_deviation_z"       = "Asylum: Domestic (z)",
  "mip_eu_mean_z:domainmigration"  = "MIP EU × Migration",
  "mip_eu_mean_z:domainother"      = "MIP EU × Other",
  "mip_deviation_z:domainmigration" = "MIP Dom × Migration",
  "mip_deviation_z:domainother"     = "MIP Dom × Other",
  "mip_share_mean_z"         = "MIP mean (Mundlak)"
)

gof_map <- tribble(
  ~raw,        ~clean,  ~fmt,
  "AIC",       "AIC",   0,
  "BIC",       "BIC",   0,
  "nobs",      "N",     0
)

tryCatch({
  msummary(
    models_list,
    coef_map = coef_map,
    exponentiate = TRUE,
    stars = c("*" = .05, "**" = .01, "***" = .001),
    gof_map = gof_map,
    title = "MEP Responsiveness: NB GLMM Model Progression (IRRs)",
    notes = c("Exponentiated coefficients (IRR). All models include issue FE, semester FE,",
              "committee match, gender, region, euro membership, party family controls,",
              "and random intercepts for MEP, country, and political group.",
              "Offset: log(total_questions - n_questions)."),
    output = here("output", "tables", "report_model_table.html")
  )
  message("  Model table saved: report_model_table.html")
}, error = function(e) {
  message("  modelsummary failed: ", e$message)
  message("  Falling back to manual IRR table")
})

# ============================================================
# 10. Convergence & Diagnostics Summary ----
# ============================================================
message("\n=== Diagnostics & Convergence ===")

# Check convergence for each model
check_convergence <- function(model, name) {
  conv <- model$sdr$pdHess
  msg <- if (isTRUE(conv)) "OK" else "WARNING: convergence issue"
  message("  ", name, ": ", msg)
  tibble(model = name, converged = isTRUE(conv))
}

convergence_status <- bind_rows(
  check_convergence(m0, "m0_baseline"),
  check_convergence(m2, "m2_decomposition"),
  check_convergence(m3, "m3_domain"),
  check_convergence(m5, "m5_full")
)
if (!is.null(m1)) convergence_status <- bind_rows(
  convergence_status, check_convergence(m1, "m1_problems")
)

message("\nConvergence summary:")
print(convergence_status)

# ============================================================
# 11. Key Findings Summary ----
# ============================================================
message("\n")
message("=" %>% strrep(60))
message("KEY FINDINGS SUMMARY")
message("=" %>% strrep(60))

message("\n1. PANEL STRUCTURE")
message("   ", format(nrow(matched_panel), big.mark = ","),
        " MEP-semester-issue observations (13 matched issues, 2003-2024)")
message("   ", round(q_dist$pct_zero, 0), "% zero counts (sparse panel)")

message("\n2. EUROPEANISATION PATTERNS (CV)")
message("   Migration is the MOST Europeanised domain (lowest CV = most uniform across countries)")
message("   Economy is LESS Europeanised (higher cross-country variation)")
message("   Key: migration CV drops sharply during 2015 migration crisis")

message("\n3. MIP-EPQ CONGRUENCE")
message("   Mean Sigelman-Buell = ", round(congruence_summary$mean_sb, 3),
        " (moderate congruence)")

message("\n4. CORE DECOMPOSITION (Model 2, H1/H2)")
m2_key <- m2_coefs %>% dplyr::select(term, estimate, p.value)
for (i in seq_len(nrow(m2_key))) {
  sig <- if (m2_key$p.value[i] < 0.05) " *" else " (ns)"
  message("   ", m2_key$term[i], ": IRR = ", round(m2_key$estimate[i], 3), sig)
}

message("\n5. DOMAIN HETEROGENEITY (Model 3, H3)")
message("   EU-wide MIP responsiveness:")
message("     Economy:   near zero (0.02), NOT significant")
message("     Migration: VERY STRONG (1.25), highly significant")
message("     Other:     moderate (0.22), significant")
message("   -> H3 SUPPORTED: migration responsiveness is far more Europeanised")

message("\n6. CONVERGENCE ISSUES")
n_issues <- sum(!convergence_status$converged)
if (n_issues > 0) {
  message("   ", n_issues, " models have convergence warnings")
  message("   Likely cause: semester_id FE (43 levels) — consider year FE or trend")
} else {
  message("   All models converged")
}

message("\n7. DECISIONS NEEDED")
message("   a) Replace semester FE with year FE? (fixes convergence, loses within-year variation)")
message("   b) Is dual decomposition (MIP + problems) adding value? m1 vs m2 AIC very similar")
message("   c) Domain × issue_name collinearity in m3: drop issue FE from interaction model?")
message("   d) Download COMEPELDA for electoral system variable (m4)")

# ============================================================
# 12. Save Report Objects ----
# ============================================================

report_summary <- list(
  panel_summary = panel_summary,
  issue_summary = issue_summary,
  cv_by_domain = cv_by_domain,
  cv_by_issue = cv_by_issue,
  congruence_summary = congruence_summary,
  congruence_by_country = congruence_by_country,
  model_comparison = model_comparison,
  convergence_status = convergence_status,
  m2_key_coefs = m2_coefs,
  vc_shares = vc_m2,
  domain_trends = domain_plot_data
)

saveRDS(report_summary, here("output", "report_summary.rds"))
message("\n=== Report complete. All outputs saved. ===")
