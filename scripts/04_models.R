# 04_models.R — Negative Binomial GLMM + Marginal Effects
# Fits multilevel NB model, computes variance decomposition,
# coefficient tables, effect plots, and marginal predictions.

# Libraries ####
set.seed(20260321)

if (!requireNamespace("glmmTMB", quietly = TRUE)) {
  install.packages("glmmTMB")
}

if (!requireNamespace("patchwork", quietly = TRUE)) {
  install.packages("patchwork")
}

if (!requireNamespace("marginaleffects", quietly = TRUE)) {
  install.packages("marginaleffects")
}

if (!requireNamespace("performance", quietly = TRUE)) {
  install.packages("performance")
}

if (!requireNamespace("see", quietly = TRUE)) {
  install.packages("see")
}

if (!requireNamespace("knitr", quietly = TRUE)) {
  install.packages("knitr")
}

if (!requireNamespace("kableExtra", quietly = TRUE)) {
  install.packages("kableExtra")
}

if (!requireNamespace("broom.mixed", quietly = TRUE)) {
  install.packages("broom.mixed")
}

if (!requireNamespace("emmeans", quietly = TRUE)) {
  install.packages("emmeans")
}

if (!requireNamespace("scales", quietly = TRUE)) {
  install.packages("scales")
}


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

# Helper: exponentiate and format model coefficients
tidy_exp_coefs <- function(model) {
  broom.mixed::tidy(model, component = "cond") %>%
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

############ VARIABLES MISSING AT THIS STAGE ##########################
# LAG ISSUE ATTENTION
# NET CONTRIBUTOR
# PART OF GOVERNING COALITION (although this is partly captured by party family)
#######################################################################

# Load data ####
message("  Loading data...")
df_merged_3 <- read_csv(here("output", "df_merged_3.csv"))
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("n_questions", "committee", "gender",
    "geographic_region", "euro_member", "party_family", "issue_name",
    "mep_id", "country", "group_abbr") %in% names(df_merged_3))
)

# Fit NB GLMM ####
message("  Fitting negative binomial GLMM (this may take a few minutes)...")

nb_model <- glmmTMB(
  n_questions ~
    committee + gender + geographic_region + euro_member + party_family + issue_name +
    (1 | mep_id) +
    (1 | country) +
    (1 | group_abbr),
  family = nbinom2,
  data = df_merged_3
)

summary(nb_model)
saveRDS(nb_model, here("output", "nb_model.rds"))

# Model performance ####
# Pseudo-R² Measures for GLMMs: Marginal & Conditional R²
# from Nakagawa & Schielzeth (2013)

# model_check <- check_model(nb_model) # intensive (> 4 mins), do later
model_performance <- model_performance(nb_model)
saveRDS(model_performance, here("output", "nb_model_performance.rds"))

print(model_performance)
# R2 for Mixed Models
# Conditional R2: 0.733
# Marginal R2: 0.242

# Model fit table
model_fit <- model_performance
model_fit_selected <- model_fit %>%
  dplyr::select(AIC, BIC, R2_conditional, R2_marginal)

model_fit_long <- model_fit_selected %>%
  pivot_longer(cols = everything(), names_to = "Criterion", values_to = "Value") %>%
  mutate(Value = round(Value, 3))

kable(model_fit_long,
      caption = "Key Model Fit Statistics for Negative Binomial GLMM",
      col.names = c("Criterion", "Value")) %>%
  kable_styling(full_width = FALSE)

# Variance decomposition ####

# Random effects overview
vc_raw <- VarCorr(nb_model)
vc <- tibble(
  grp = names(vc_raw$cond),
  vcov = sapply(vc_raw$cond, function(x) attr(x, "stddev")^2)
)
vc$proportion <- vc$vcov / sum(vc$vcov)
vc

# Table 1: Model-level variance summary
vc_df <- insight::get_variance(nb_model)
saveRDS(vc_df, here("output", "vc_df.rds"))

var_fixed <- vc_df$var.fixed
var_random <- vc_df$var.random
var_resid <- vc_df$var.residual
var_total <- var_fixed + var_random + var_resid

model_variance_summary <- tibble(
  Component = c("Fixed effects", "Random effects", "Residual (overdispersion)"),
  Variance = c(var_fixed, var_random, var_resid),
  Proportion = c(var_fixed, var_random, var_resid) / var_total
)

model_variance_summary %>%
  mutate(
    Variance = round(Variance, 3),
    Proportion = percent(Proportion, accuracy = 1)
  ) %>%
  kable(
    caption = "Variance Decomposition of the Negative Binomial Model",
    col.names = c("Component", "Variance", "Proportion"),
    format = "html"
  ) %>%
  kable_styling(full_width = FALSE)

# Table 2: Random effects breakdown
vc_raw2 <- VarCorr(nb_model)
var_mep <- attr(vc_raw2$cond$mep_id, "stddev")^2
var_country <- attr(vc_raw2$cond$country, "stddev")^2
var_group <- attr(vc_raw2$cond$group_abbr, "stddev")^2
total_random <- var_mep + var_country + var_group

random_effects_breakdown <- tibble(
  `Random Effect Group` = c("mep_id", "country", "group_abbr"),
  Variance = c(var_mep, var_country, var_group),
  `Proportion of Random` = c(var_mep, var_country, var_group) / total_random
)
saveRDS(random_effects_breakdown, here("output", "random_effects_breakdown.rds"))

random_effects_breakdown %>%
  mutate(
    Variance = round(Variance, 3),
    `Proportion of Random` = percent(`Proportion of Random`, accuracy = 1)
  ) %>%
  kable(
    caption = "Random Effects Breakdown: Contribution by Grouping Factor",
    col.names = c("Random Effect Group", "Variance", "Proportion of Random"),
    format = "html"
  ) %>%
  kable_styling(full_width = FALSE)

# Random intercepts for presentation ####

country_random_intercepts <- ranef(nb_model)$cond$country %>%
  as.data.frame() %>%
  rename(effect = `(Intercept)`) %>%
  mutate(country = rownames(ranef(nb_model)$cond$country))
saveRDS(country_random_intercepts, here("output", "country_random_intercepts.rds"))

group_random_intercepts <- ranef(nb_model)$cond$group_abbr %>%
  as.data.frame() %>%
  rename(effect = `(Intercept)`) %>%
  mutate(group_abbr = rownames(ranef(nb_model)$cond$group_abbr))
saveRDS(group_random_intercepts, here("output", "group_random_intercepts.rds"))

# Prediction grid ####

grid <- df_merged_3 %>%
  distinct(issue_name) %>%
  mutate(
    gender = "F",
    geographic_region = "Western",
    euro_member = 1,
    party_family = "Social democrats",
    committee = 1
  )

grid$pred <- predict(nb_model, newdata = grid, type = "response", re.form = NA)

ggplot(grid, aes(x = reorder(issue_name, pred), y = pred)) +
  geom_col() +
  coord_flip() +
  labs(y = "Predicted Questions per Year-Issue-MEP", x = "Issue Area")

# Exponentiated coefficients table ####

exp_table <- tidy_exp_coefs(nb_model)

# Variable labels
label_lookup <- c(
  "committee" = "Committee match",
  "genderM" = "Gender: Male",
  "geographic_regionNorthern" = "Region: Northern",
  "geographic_regionSouthern" = "Region: Southern",
  "geographic_regionWestern" = "Region: Western",
  "euro_member" = "Euro area member",
  "party_familyCommunists and socialists" = "Party Family: Communists/Socialists",
  "party_familyEurosceptic conservatives" = "Party Family: Eurosceptic Conservatives",
  "party_familyEurosceptics" = "Party Family: Eurosceptics",
  "party_familyGreens/EFA" = "Party Family: Greens/EFA",
  "party_familyLiberals" = "Party Family: Liberals",
  "party_familyNI" = "Party Family: Non-affiliated",
  "party_familyRight-wing nationalists" = "Party Family: Right-wing Nationalists",
  "party_familySocial democrats" = "Party Family: Social Democrats"
)

issue_labels <- unique(grep("^issue_name", exp_table$term, value = TRUE))
issue_label_map <- setNames(
  gsub("^issue_name", "Issue: ", issue_labels),
  issue_labels
)
full_labels <- c(label_lookup, issue_label_map)

exp_table <- exp_table %>%
  mutate(
    label = recode(term, !!!full_labels),
    label = ifelse(is.na(label), term, label),
    category = case_when(
      term == "committee" ~ "0_Committee",
      term == "genderM" ~ "1_Gender",
      grepl("^geographic_region", term) ~ "2_Region",
      term == "euro_member" ~ "3_Euro member",
      grepl("^party_family", term) ~ "4_Party family",
      grepl("^issue_name", term) ~ "5_Issue area",
      TRUE ~ "6_Other"
    )
  ) %>%
  arrange(category, label) %>%
  dplyr::select(label, estimate, exp_estimate, std.error, pval_str)
saveRDS(exp_table, here("output", "exp_table.rds"))

kable(exp_table,
      caption = "Exponentiated Coefficients - Negative Binomial Model",
      col.names = c("Variable", "Log Coef", "Exp(Coef)", "SE", "p-value")) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover")) %>%
  footnote(
    general = "p < 0.001 ***; p < 0.01 **; p < 0.05 *; p < 0.1 .",
    general_title = "",
    footnote_as_chunk = TRUE
  )

# Effect plots ####

# Prepare effect data
effects_df <- broom.mixed::tidy(nb_model, component = "cond") %>%
  mutate(
    exp_estimate = exp(estimate),
    conf.low = exp(estimate - 1.96 * std.error),
    conf.high = exp(estimate + 1.96 * std.error),
    term_clean = case_when(
      term == "committee" ~ "Committee match",
      term == "genderM" ~ "Gender: Male",
      term == "euro_member" ~ "Euro member",
      grepl("^geographic_region", term) ~ gsub("geographic_region", "Region: ", term),
      grepl("^party_family", term) ~ gsub("party_family", "Party: ", term),
      grepl("^issue_name", term) ~ gsub("issue_name", "Issue: ", term),
      TRUE ~ term
    ),
    category = case_when(
      term == "committee" ~ "Committee",
      term == "genderM" ~ "Gender",
      grepl("^geographic_region", term) ~ "Region",
      term == "euro_member" ~ "Euro member",
      grepl("^party_family", term) ~ "Party family",
      grepl("^issue_name", term) ~ "Issue area",
      TRUE ~ "Other"
    )
  )
saveRDS(effects_df, here("output", "effects_df.rds"))

# Individual effect plots

effects_df %>%
  dplyr::filter(category == "Issue area") %>%
  ggplot(aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
  geom_point() +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
  labs(title = "Effect of Issue Area on Question Count",
       x = "Multiplicative Effect (exp(B))", y = "Issue Area") +
  theme_minimal()

# A. Party Family (default: EPP)
effects_df %>%
  dplyr::filter(category == "Party family") %>%
  ggplot(aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
  geom_point(color = "steelblue") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "steelblue") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
  labs(title = "Effect of Party Family", x = "Multiplicative Effect", y = "") +
  theme_minimal()

# B. Region and Gender (default: Eastern, Female)
effects_df %>%
  dplyr::filter(category %in% c("Region", "Gender")) %>%
  ggplot(aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
  geom_point(color = "darkgreen") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "darkgreen") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
  labs(title = "Effect of Region and Gender", x = "Multiplicative Effect", y = "") +
  theme_minimal()

# Combined facet plot with patchwork (proportional heights)

make_plot <- function(df, title) {
  ggplot(df, aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
    geom_point() +
    geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(size = 10, face = "bold"),
      plot.margin = margin(5, 5, 5, 5),
      axis.title.x = element_blank()
    )
}

plots <- effects_df %>%
  dplyr::filter(category != "Other") %>%
  group_split(category) %>%
  setNames(unique(effects_df$category[effects_df$category != "Other"])) %>%
  lapply(function(df) make_plot(df, unique(df$category)))

heights <- sapply(plots, function(p) length(ggplot_build(p)$data[[1]]$y))

final_plot <- wrap_plots(plots, ncol = 1, heights = heights) +
  plot_annotation(
    title = NULL,
    theme = theme(
      plot.margin = margin(5, 10, 5, 10),
      axis.title.x = element_text(size = 12)
    )
  ) &
  theme(plot.margin = margin(5, 10, 5, 10))

final_plot <- final_plot & labs(x = "Multiplicative Effect (exp(B))")
final_plot

# ggsave("output/figures/effects_plot.png", final_plot, width = 8, height = 12)

# Bar chart effect plots ####

exp_tab <- tidy_exp_coefs(nb_model)

# A. Party Family
party_effects <- exp_tab %>%
  dplyr::filter(grepl("^party_family", term)) %>%
  mutate(term = gsub("party_family", "", term))

ggplot(party_effects, aes(x = reorder(term, exp_estimate), y = exp_estimate)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(x = "Party Family", y = "Multiplicative Effect (exp(B))",
       title = "Effect of Party Family on Number of Questions")

# B. Gender and Geography
demographic_effects <- exp_tab %>%
  dplyr::filter(term %in% c("genderM", "geographic_regionNorthern",
                      "geographic_regionSouthern", "geographic_regionWestern"))

ggplot(demographic_effects, aes(x = reorder(term, exp_estimate), y = exp_estimate)) +
  geom_col(fill = "darkgreen") +
  coord_flip() +
  labs(x = "Demographic Group", y = "Multiplicative Effect (exp(B))",
       title = "Effect of Gender and Region")

# C. Issue Area
issue_effects <- exp_tab %>%
  dplyr::filter(grepl("^issue_name", term)) %>%
  mutate(issue = gsub("issue_name", "", term))

ggplot(issue_effects, aes(x = reorder(issue, exp_estimate), y = exp_estimate)) +
  geom_col(fill = "darkred") +
  coord_flip() +
  labs(x = "Issue Area", y = "Multiplicative Effect (exp(B))",
       title = "Baseline Question Intensity by Issue")

# Marginal effects ####
message("  Computing marginal predictions...")
# NOTE: avg_predictions on the full dataset (415K rows) requires >8GB RAM.
# We use a 10% subsample for computation; results are stable at this size.

df_sample <- df_merged_3 %>% sample_frac(0.10)

# Average predictions by issue (fixed effects only)
if (file.exists(here("output", "average_predictions_marginal_no_randomeffects.rds"))) {
  avg_preds <- readRDS(here("output", "average_predictions_marginal_no_randomeffects.rds"))
} else {
  avg_preds <- avg_predictions(
    model = nb_model,
    variables = "issue_name",
    newdata = df_sample,
    re.form = NA
  )
  saveRDS(avg_preds, file = here("output", "average_predictions_marginal_no_randomeffects.rds"))
}

ggplot(avg_preds, aes(x = estimate, y = reorder(issue_name, estimate))) +
  geom_point() +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2) +
  labs(x = "Predicted Questions per MEP-Year (Averaged over all MEPs)",
       y = "Issue Area",
       title = "Average Predicted Question Count by Issue") +
  theme_minimal()

# Average predictions including random effects
if (file.exists(here("output", "average_predictions_marginal_randomeffects.rds"))) {
  avg_preds_random <- readRDS(here("output", "average_predictions_marginal_randomeffects.rds"))
} else {
  avg_preds_random <- avg_predictions(
    model = nb_model,
    variables = "issue_name",
    newdata = df_sample,
    re.form = NULL
  )
  saveRDS(avg_preds_random, file = here("output", "average_predictions_marginal_randomeffects.rds"))
}

ggplot(avg_preds_random, aes(x = estimate, y = reorder(issue_name, estimate))) +
  geom_point() +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2) +
  labs(x = "Predicted Questions per MEP-Year (Averaged over all MEPs)",
       y = "Issue Area",
       title = "Average Predicted Question Count by Issue (with random effects)") +
  theme_minimal()

# Grouped predictions: Issue x Party Family
if (file.exists(here("output", "grouped_predictions_parties.rds"))) {
  grouped_preds_parties <- readRDS(here("output", "grouped_predictions_parties.rds"))
} else {
  grouped_preds_parties <- avg_predictions(
    model = nb_model,
    variables = "issue_name",
    by = "party_family",
    newdata = df_sample,
    re.form = NA
  )
  saveRDS(grouped_preds_parties, file = here("output", "grouped_predictions_parties.rds"))
}

if ("party_family" %in% names(grouped_preds_parties)) {
  print(ggplot(grouped_preds_parties,
               aes(x = estimate, y = reorder(party_family, estimate), color = party_family)) +
    geom_point(position = position_dodge(width = 0.7)) +
    geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                   height = 0.2, position = position_dodge(width = 0.7)) +
    labs(title = "Predicted Number of Questions by Issue and Party Family",
         x = "Predicted Questions per MEP-Issue-Year",
         y = "Issue Area", color = "Party Family") +
    theme_minimal())
} else {
  message("Skipping party family plot: pre-computed data lacks party_family column. Recompute to generate.")
}

# Grouped predictions: Issue x Country
if (file.exists(here("output", "grouped_predictions_country.rds"))) {
  grouped_preds_country <- readRDS(here("output", "grouped_predictions_country.rds"))
} else {
  grouped_preds_country <- avg_predictions(
    model = nb_model,
    variables = "issue_name",
    by = "country",
    newdata = df_sample,
    re.form = NA
  )
  saveRDS(grouped_preds_country, file = here("output", "grouped_predictions_country.rds"))
}

if ("country" %in% names(grouped_preds_country)) {
  print(ggplot(grouped_preds_country,
               aes(x = estimate, y = reorder(country, estimate), color = country)) +
    geom_point(position = position_dodge(width = 0.7)) +
    geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                   height = 0.2, position = position_dodge(width = 0.7)) +
    labs(title = "Predicted Number of Questions by Issue and Country",
         x = "Predicted Questions per MEP-Issue-Year",
         y = "Country", color = "Country") +
    theme_minimal())
} else {
  message("Skipping country plot: pre-computed data lacks country column. Recompute to generate.")
}
