# 04_models.R — Zero-Inflated NB GLMM + Marginal Effects
# Fits multilevel ZINB model, computes variance decomposition,
# coefficient tables, effect plots, and marginal predictions.

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

#######################################################################

# Load data ####
message("  Loading updated MEP-year dataset...")
df_merged_3 <- read_csv(here("output", "df_merged_3.csv"))

# Sanity check per verificare la presenza delle nuove variabili time-invariant e del conteggio subtopic
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("n_subtopic_201_941", "total_questions", "gender",
                                     "geographic_region", "euro_member", "party_family",
                                     "discrimination_mean", "cmp_mean",
                                     "mep_id", "country", "group_abbr") %in% names(df_merged_3))
)

# Centratura dei predittori continui per facilitare la convergenza
df_merged_3 <- df_merged_3 %>%
  mutate(
    discrimination_center = discrimination_mean - mean(discrimination_mean, na.rm = TRUE),
    cmp_center = cmp_mean - mean(cmp_mean, na.rm = TRUE)
  )

# Fit Zero-Inflated NB GLMM ####
message("  Fitting Zero-Inflated negative binomial GLMM with structural offsets...")

zinb_model <- glmmTMB(
   n_subtopic_201 ~ 
     gender + geographic_region + party_family + deve + minority * cmp_center + 
     offset(log(total_questions + 1)) + 
     (1 | mep_id),            
   family = nbinom2,
   ziformula = ~ 1,           
   data = df_merged_3 |> filter(legislative_term %in% c("8th", "9th")) 
)

summary(zinb_model)
saveRDS(zinb_model, here("output", "zinb_model.rds"))

# Model performance ####
message("  Evaluating model performance...")
model_performance <- model_performance(zinb_model)
saveRDS(model_performance, here("output", "zinb_model_performance.rds"))

print(model_performance)

# Model fit table
model_fit <- model_performance
model_fit_selected <- model_fit %>%
  dplyr::select(AIC, BIC, R2_conditional, R2_marginal)

model_fit_long <- model_fit_selected %>%
  pivot_longer(cols = everything(), names_to = "Criterion", values_to = "Value") %>%
  mutate(Value = round(Value, 3))

kable(model_fit_long,
      caption = "Key Model Fit Statistics for Zero-Inflated Negative Binomial GLMM",
      col.names = c("Criterion", "Value")) %>%
  kable_styling(full_width = FALSE)


# Variance decomposition ####
message("  Decomposing variance...")
vc_raw <- VarCorr(zinb_model)

# Estrazione robusta della varianza condizionale indipendente dalla struttura di glmmTMB
vc_cond <- if ("cond" %in% names(vc_raw)) vc_raw$cond else vc_raw

vc <- tibble(
  grp = names(vc_cond),
  vcov = sapply(vc_cond, function(x) attr(x, "stddev")^2)
)
vc$proportion <- vc$vcov / sum(vc$vcov)
print(vc)

# Table 1: Model-level variance summary
vc_df <- insight::get_variance(zinb_model)
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
    caption = "Variance Decomposition of the Zero-Inflated Model (Conditional Component)",
    col.names = c("Component", "Variance", "Proportion"),
    format = "html"
  ) %>%
  kable_styling(full_width = FALSE)

# Table 2: Random effects breakdown
var_mep <- attr(vc_cond$mep_id, "stddev")^2
var_country <- attr(vc_cond$country, "stddev")^2
var_group <- attr(vc_cond$group_abbr, "stddev")^2
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
ranef_cond <- if ("cond" %in% names(ranef(zinb_model))) ranef(zinb_model)$cond else ranef(zinb_model)

country_random_intercepts <- ranef_cond$country %>%
  as.data.frame() %>%
  rename(effect = `(Intercept)`) %>%
  mutate(country = rownames(ranef_cond$country))
saveRDS(country_random_intercepts, here("output", "country_random_intercepts.rds"))

group_random_intercepts <- ranef_cond$group_abbr %>%
  as.data.frame() %>%
  rename(effect = `(Intercept)`) %>%
  mutate(group_abbr = rownames(ranef_cond$group_abbr))
saveRDS(group_random_intercepts, here("output", "group_random_intercepts.rds"))


# Prediction grid (Focalizzazione su CMP e Modello Lineare) ####
grid <- tibble(
  cmp_center = seq(min(df_merged_3$cmp_center, na.rm = TRUE), 
                   max(df_merged_3$cmp_center, na.rm = TRUE), 
                   length.out = 100),
  discrimination_center = 0, 
  gender = "F",
  geographic_region = "Western",
  euro_member = 1,
  party_family = "Social democrats",
  total_questions = mean(df_merged_3$total_questions, na.rm = TRUE)
)

grid$pred <- predict(zinb_model, newdata = grid, type = "response", re.form = NA)

ggplot(grid, aes(x = cmp_center, y = pred)) +
  geom_line(color = "darkblue", size = 1) +
  labs(y = "Predicted Subtopic Questions per MEP-Year", 
       x = "Claim-making Pressure (Centered)",
       title = "Predicted Activity by Country Claim-making Pressure") +
  theme_minimal()


# Exponentiated coefficients table ####
exp_table <- tidy_exp_coefs(zinb_model)

label_lookup <- c(
  "genderM" = "Gender: Male",
  "geographic_regionNorthern" = "Region: Northern",
  "geographic_regionSouthern" = "Region: Southern",
  "geographic_regionWestern" = "Region: Western",
  "euro_member" = "Euro area member",
  "discrimination_center" = "Country Discrimination (Centered)",
  "cmp_center" = "Claim-making Pressure (Centered)",
  "party_familyCommunists and socialists" = "Party Family: Communists/Socialists",
  "party_familyEurosceptic conservatives" = "Party Family: Eurosceptic Conservatives",
  "party_familyEurosceptics" = "Party Family: Eurosceptics",
  "party_familyGreens/EFA" = "Party Family: Greens/EFA",
  "party_familyLiberals" = "Party Family: Liberals",
  "party_familyNI" = "Party Family: Non-affiliated",
  "party_familyRight-wing nationalists" = "Party Family: Right-wing Nationalists",
  "party_familySocial democrats" = "Party Family: Social Democrats"
)

exp_table <- exp_table %>%
  mutate(
    label = recode(term, !!!label_lookup),
    label = ifelse(is.na(label), term, label),
    category = case_when(
      term == "genderM" ~ "1_Gender",
      grepl("^geographic_region", term) ~ "2_Region",
      term == "euro_member" ~ "3_Euro member",
      term %in% c("discrimination_center", "cmp_center") ~ "4_Country Levels (Macro)",
      grepl("^party_family", term) ~ "5_Party family",
      TRUE ~ "6_Other"
    )
  ) %>%
  arrange(category, label) %>%
  dplyr::select(label, estimate, exp_estimate, std.error, pval_str)

saveRDS(exp_table, here("output", "exp_table.rds"))

kable(exp_table,
      caption = "Exponentiated Coefficients (Count Component) - Zero-Inflated Model",
      col.names = c("Variable", "Log Coef", "Exp(Coef)", "SE", "p-value")) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover")) %>%
  footnote(
    general = "p < 0.001 ***; p < 0.01 **; p < 0.05 *; p < 0.1 .",
    general_title = "",
    footnote_as_chunk = TRUE
  )


# Effect plots ####
effects_df <- broom.mixed::tidy(zinb_model, component = "cond") %>%
  dplyr::filter(term != "(Intercept)") %>%
  mutate(
    exp_estimate = exp(estimate),
    conf.low = exp(estimate - 1.96 * std.error),
    conf.high = exp(estimate + 1.96 * std.error),
    term_clean = case_when(
      term == "genderM" ~ "Gender: Male",
      term == "euro_member" ~ "Euro member",
      term == "discrimination_center" ~ "Country Discrimination",
      term == "cmp_center" ~ "Claim-making Pressure",
      grepl("^geographic_region", term) ~ gsub("geographic_region", "Region: ", term),
      grepl("^party_family", term) ~ gsub("party_family", "Party: ", term),
      TRUE ~ term
    ),
    category = case_when(
      term == "genderM" ~ "Gender",
      grepl("^geographic_region", term) ~ "Region",
      term == "euro_member" ~ "Euro member",
      term %in% c("discrimination_center", "cmp_center") ~ "Country Levels (Macro)",
      grepl("^party_family", term) ~ "Party family",
      TRUE ~ "Other"
    )
  )
saveRDS(effects_df, here("output", "effects_df.rds"))

# Individual plots
effects_df %>%
  dplyr::filter(category == "Country Levels (Macro)") %>%
  ggplot(aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
  geom_point(color = "darkred", size = 2) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "darkred") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
  labs(title = "Effect of Country Macro Variables on Subtopic Activity",
       x = "Multiplicative Effect (exp(B))", y = "") +
  theme_minimal()

effects_df %>%
  dplyr::filter(category == "Party family") %>%
  ggplot(aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
  geom_point(color = "steelblue") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "steelblue") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
  labs(title = "Effect of Party Family", x = "Multiplicative Effect (exp(B))", y = "") +
  theme_minimal()


# Combined facet plot with patchwork (proportional heights) ####

# DEFINIZIONE DELLA FUNZIONE - Messa prima del suo utilizzo
make_plot <- function(df, title) {
  ggplot(df, aes(x = exp_estimate, y = reorder(term_clean, exp_estimate))) +
    geom_point(color = "black", size = 1.5) +
    geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "black") +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray") +
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(size = 10, face = "bold"),
      plot.margin = margin(5, 5, 5, 5),
      axis.title.x = element_blank()
    )
}

# Generazione della lista di grafici tramite lapply
plots <- effects_df %>%
  dplyr::filter(category != "Other") %>%
  group_split(category) %>%
  setNames(unique(effects_df$category[effects_df$category != "Other"])) %>%
  lapply(function(df) make_plot(df, unique(df$category)))

# Calcolo proporzionale delle altezze degli assi Y
heights <- sapply(plots, function(p) length(ggplot_build(p)$data[[1]]$y))

# Unione dei grafici con patchwork
final_plot <- wrap_plots(plots, ncol = 1, heights = heights) +
  plot_annotation(
    title = "Multiplicative Effects on Subtopic Question Activity",
    theme = theme(plot.margin = margin(5, 10, 5, 10), axis.title.x = element_text(size = 12))
  ) & theme(plot.margin = margin(5, 10, 5, 10))

final_plot <- final_plot & labs(x = "Multiplicative Effect (exp(B))")
final_plot

ggsave("output/figures/effects_plot.png", final_plot, width = 8, height = 10)

# Bar chart effect plots ####
exp_tab <- tidy_exp_coefs(zinb_model)

macro_effects <- exp_tab %>% dplyr::filter(term %in% c("discrimination_center", "cmp_center"))
ggplot(macro_effects, aes(x = reorder(label, exp_estimate), y = exp_estimate)) +
  geom_col(fill = "darkred", width = 0.5) + coord_flip() +
  labs(x = "Macro Indicator", y = "Multiplicative Effect (exp(B))", title = "Effect of Country-Level Characteristics") +
  theme_minimal()

party_effects <- exp_tab %>% dplyr::filter(grepl("^party_family", term)) %>% mutate(term = gsub("party_family", "", term))
ggplot(party_effects, aes(x = reorder(term, exp_estimate), y = exp_estimate)) +
  geom_col(fill = "steelblue") + coord_flip() +
  labs(x = "Party Family", y = "Multiplicative Effect (exp(B))", title = "Effect of Party Family on Subtopic Questions") +
  theme_minimal()


# Marginal effects ####
message("  Computing marginal predictions...")
df_sample <- df_merged_3 %>% sample_frac(0.10)

# 1. Predizioni medie al variare della Claim-making Pressure (CMP)
if (file.exists(here("output", "predictions_marginal_cmp.rds"))) {
  avg_preds_cmp <- readRDS(here("output", "predictions_marginal_cmp.rds"))
} else {
  avg_preds_cmp <- predictions(
    model = zinb_model,
    newdata = datagrid(cmp_center = seq(min(df_sample$cmp_center, na.rm=TRUE), 
                                        max(df_sample$cmp_center, na.rm=TRUE), 
                                        length.out = 50)),
    re.form = NA
  )
  saveRDS(avg_preds_cmp, file = here("output", "predictions_marginal_cmp.rds"))
}

ggplot(avg_preds_cmp, aes(x = cmp_center, y = estimate)) +
  geom_line(color = "darkblue", size = 1) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, fill = "darkblue") +
  labs(x = "Claim-making Pressure (Centered)", y = "Predicted Questions per MEP-Year", title = "Marginal Effect of Claim-making Pressure") +
  theme_minimal()

# 2. Predizioni medie per Famiglia Politica
if (file.exists(here("output", "predictions_marginal_parties.rds"))) {
  avg_preds_parties <- readRDS(here("output", "predictions_marginal_parties.rds"))
} else {
  avg_preds_parties <- avg_predictions(
    model = zinb_model,
    variables = "party_family",
    newdata = df_sample,
    re.form = NA
  )
  saveRDS(avg_preds_parties, file = here("output", "predictions_marginal_parties.rds"))
}

ggplot(avg_preds_parties, aes(x = estimate, y = reorder(party_family, estimate))) +
  geom_point(color = "steelblue", size = 2) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2, color = "steelblue") +
  labs(x = "Predicted Questions per MEP-Year", y = "Party Family", title = "Average Predicted Question Count by Party Family") +
  theme_minimal()

# 3. Predizioni condizionate incrociate (CMP Paese x Famiglia Politica) - FIX CRITICO
if (file.exists(here("output", "grouped_predictions_cmp_parties.rds"))) {
  grouped_preds <- readRDS(here("output", "grouped_predictions_cmp_parties.rds"))
} else {
  # Usiamo predictions() accoppiato a datagrid() per generare correttamente le linee divise per partito
  grouped_preds <- predictions(
    model = zinb_model,
    newdata = datagrid(
      cmp_center = seq(min(df_sample$cmp_center, na.rm=TRUE), max(df_sample$cmp_center, na.rm=TRUE), length.out = 20),
      party_family = unique(df_sample$party_family)
    ),
    re.form = NA
  )
  saveRDS(grouped_preds, file = here("output", "grouped_predictions_cmp_parties.rds"))
}

ggplot(grouped_preds, aes(x = cmp_center, y = estimate, color = party_family, fill = party_family)) +
  geom_line(size = 1) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.08, color = NA) +
  labs(title = "How Country Pressure Affects Party Families Differently",
       x = "Claim-making Pressure (Centered)",
       y = "Predicted Questions per MEP-Year", 
       color = "Party Family", fill = "Party Family") +
  theme_minimal() +
  theme(legend.position = "bottom")