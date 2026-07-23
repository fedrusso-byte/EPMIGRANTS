# ==============================================================================
# # 05_models_Bayesian.R — Bayesian ZINB Models for Minority Interactions
# Uses the 'brms' package to fit Zero-Inflated Negative Binomial models.
# This approach is more robust to small numbers of groups (countries)
# and allows for the inclusion of time-invariant country characteristics
# in interactions without the collinearity issues found in Fixed Effects models.
# ==============================================================================

# free memory
rm(list = ls())

# Libraries ####
set.seed(20260321)

if (!requireNamespace("brms", quietly = TRUE)) { install.packages("brms") }
if (!requireNamespace("tidyverse", quietly = TRUE)) { install.packages("tidyverse") }
if (!requireNamespace("here", quietly = TRUE)) { install.packages("here") }
if (!requireNamespace("tidybayes", quietly = TRUE)) { install.packages("tidybayes") }
if (!requireNamespace("broom.mixed", quietly = TRUE)) { install.packages("broom.mixed") }
if (!requireNamespace("knitr", quietly = TRUE)) { install.packages("knitr") }

library(tidyverse)
library(brms)
library(here)
library(tidybayes)
library(broom.mixed)
library(knitr)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# Load data ####
message("   Loading data for Bayesian analysis...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

# Create Centered Variables
df_merged_3 <- df_merged_3 %>%
  mutate(
    discrimination_center = discrimination_mean - mean(discrimination_mean, na.rm = TRUE),
    cmp_center = cmp_mean - mean(cmp_mean, na.rm = TRUE),
    mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE)
  )

# Filter for relevant periods and remove structural NAs
# Note: We keep a broader set of data than the FE version to maximize Bayesian power
df_model_data <- df_merged_3 %>% 
  filter(legislative_term %in% c("8th", "9th")) %>% 
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority, misery_index, cmp_center, mipex_center
  )

message(paste("✅ N finale for Bayesian models:", nrow(df_model_data)))

# ==============================================================================
# 1. PRIOR SPECIFICATIONS
# ==============================================================================
# We use weakly informative priors. 
# Normal(0, 2.5) is standard for coefficients in GLMMs as it covers 
# a wide range of plausible effects without being overly restrictive.
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"), # Robust prior for coefficients
  set_prior("student_t(3, 0, 2.5)", class = "zi") # Robust prior for zero-inflation part
)

# ==============================================================================
# 2. MODEL 1: INTERACTION WITH CMP_CENTER
# ==============================================================================
message("   Fitting Bayesian Model 1 (Minority x CMP)...")
# We include main effects for both 'minority' and 'cmp_center' 
# because interactions must be interpreted in the context of their main effects.
bayesian_model_cmp <- brm(
  formula = pqs_discrimination ~ 
             gender + misery_index + party_family + libe + 
             minority * cmp_center + 
             offset(log(total_questions + 1)) + 
             (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, 
  iter = 2000, 
  warmup = 1000, 
  cores = 4, 
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_cmp")
)

# ==============================================================================
# 3. MODEL 2: INTERACTION WITH MIPEX_CENTER
# ==============================================================================
message("   Fitting Bayesian Model 2 (Minority x MIPEX)...")
bayesian_model_mipex <- brm(
  formula = pqs_discrimination ~ 
             gender + misery_index + party_family + libe + 
             minority * mipex_center + 
             offset(log(total_questions + 1)) + 
             (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, 
  iter = 2000, 
  warmup = 1000, 
  cores = 4, 
  control = list(adapt_delta = 0.95),
  file = here("output", "bayesian_model_mipex")
)

# ==============================================================================
# 4. RESULTS EXTRACTION
# ==============================================================================

extract_bayesian_results <- function(model, model_name) {
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    mutate(model = model_name)
}

res_cmp <- extract_bayesian_results(bayesian_model_cmp, "CMP Interaction")
res_mipex <- extract_bayesian_results(bayesian_model_mipex, "MIPEX Interaction")

final_results <- bind_rows(res_cmp, res_mipex) %>%
  dplyr::select(model, term, estimate, std.error, conf.low, conf.high)

write_csv(final_results, here("output", "bayesian_model_results.csv"))
message("🎉 Bayesian results saved to: output/bayesian_model_results.csv")

# Display the interaction effects specifically
interaction_results <- final_results %>%
  filter(grepl(":", term))

print("--- Bayesian Interaction Effects ---")
print(interaction_results)

knitr::kable(interaction_results, format = "markdown", caption = "Credible Intervals for Minority Interactions")