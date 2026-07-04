# 05_models.R — Zero-Inflated NB GLMM + Marginal Effects
# Fits multilevel ZINB model, computes variance decomposition,
# coefficient tables, effect plots, and marginal predictions.


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

# Load data ####
message("  Loading updated MEP-year dataset...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"))
df_merged_3 <- read_csv(here("output", "df_merged_3.csv")) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

# Sanity check aggiornato con tutte le variabili incluse nel modello
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("n_subtopic_201", "total_questions", "gender",
                                     "geographic_region", "party_family", "libe", "misery_index",
                                     "discrimination_mean", "cmp_mean", "mep_id", "country") %in% names(df_merged_3))
)

# Centratura dei predittori continui per facilitare la convergenza
df_merged_3 <- df_merged_3 %>%
  mutate(
    discrimination_center = discrimination_mean - mean(discrimination_mean, na.rm = TRUE),
    cmp_center = cmp_mean - mean(cmp_mean, na.rm = TRUE)
  )

# ==============================================================================
# NUOVO APPROCCIO: Pulizia mirata per salvare i Paesi Europei
# ==============================================================================

message("  Pulizia ottimizzata dei dati per preservare la copertura geografica...")

df_model_data <- df_merged_3 %>% 
  filter(legislative_term %in% c("8th", "9th")) %>%
  # Rimuoviamo dalla pulizia stringente misery_index e discrimination_center
  # per salvare Grecia, Romania, Estonia, Lussemburgo e Malta.
  drop_na(n_subtopic_201, total_questions, gender, geographic_region, 
          party_family, libe, cmp_center, minority, mep_id)

# Controlliamo il nuovo numero di righe e la presenza dei paesi
message(paste("  Nuovo numero di osservazioni per i modelli:", nrow(df_model_data)))
message("  Nuovo controllo della distribuzione per paese:")
print(table(df_model_data$country))



# 2. Stima dei Modelli usando il dataset pulito 'df_model_data' ####

# Modello 1
message("  Fitting zinb_model1...")
zinb_model1 <- glmmTMB(
   n_subtopic_201 ~ 
     gender + geographic_region + misery_index + party_family + libe + cmp_center + discrimination_center +
     offset(log(total_questions + 1)) + 
     (1 | mep_id) + (1 | country),   # Aggiunta di un secondo livello di random intercept per paese
   family = nbinom2,
   ziformula = ~ 1,           
   data = df_model_data # <-- Usiamo il dataset pulito
)

summary(zinb_model1)
saveRDS(zinb_model1, here("output", "zinb_model1.rds"))



# Modello 2
message("  Fitting zinb_model2...")
zinb_model2 <- glmmTMB(
   n_subtopic_201 ~ 
     gender + geographic_region + misery_index + party_family + libe + minority +
     offset(log(total_questions + 1)) + 
     (1 | mep_id) + (1 | country),   # Aggiunta di un secondo livello di random intercept per paese
   family = nbinom2,
   ziformula = ~ 1,           
   data = df_model_data # <-- Usiamo il dataset pulito
)
saveRDS(zinb_model2, here("output", "zinb_model2.rds"))
summary(zinb_model2)

# Modello 3
message("  Fitting zinb_model3...")
zinb_model3 <- glmmTMB(
   n_subtopic_201 ~ 
     gender + geographic_region + misery_index + party_family + libe + minority + cmp_center + discrimination_center +
     offset(log(total_questions + 1)) + 
     (1 | mep_id) + (1 | country),   # Aggiunta di un secondo livello di random intercept per paese
   family = nbinom2,
   ziformula = ~ 1,           
   data = df_model_data # <-- Usiamo il dataset pulito
)
saveRDS(zinb_model3, here("output", "zinb_model3.rds"))
summary(zinb_model3)

#modello 4 (interazione principale)
message("  Stima del Modello 4: Interazione + Doppio Random Effect...")

zinb_model4 <- glmmTMB(
   n_subtopic_201 ~ 
     gender + geographic_region + misery_index + party_family + libe + 
     discrimination_center + minority * cmp_center + # <-- Interazione inclusa
     offset(log(total_questions + 1)) + 
     (1 | country) + (1 | mep_id),
   family = nbinom2,
   ziformula = ~ 1,           
   data = df_model_data
)

# Visualizza la sintesi in console per controllare p-value e stime
summary(zinb_model4)
saveRDS(zinb_model4, here("output", "zinb_model4.rds"))


# ==============================================================================
# NUOVO CONFRONTO PERFORMANCE E ANOVA
# ==============================================================================

model_comparison <- compare_performance(zinb_model1, zinb_model2, zinb_model3, zinb_model4, rank = TRUE)
print(model_comparison)

# Filter down to the absolute essentials and format for presentation
essential_comparison <- model_comparison %>%
  as_tibble() %>%
  select(
    Model = Name, 
    RMSE, 
    `AIC Weight` = AIC_wt, 
    `BIC Weight` = BIC_wt, 
    `Overall Score` = Performance_Score
  ) %>%
  mutate(
    # Clean up model names for the final reader
    Model = case_match(
      Model,
      "zinb_model1" ~ "M1: Baseline Individual Controls",
      "zinb_model2" ~ "M2: Adding Minority Predictor",
      "zinb_model3" ~ "M3: Fully Controlled + Country RE (Winner)",
      "zinb_model4" ~ "M4: Country RE + Minority*CMP Interaction"
    ),
    # Format weights and scores to clean decimals/percentages
    `AIC Weight` = round(`AIC Weight`, 3),
    `BIC Weight` = round(`BIC Weight`, 3),
    `Overall Score` = paste0(round(`Overall Score` * 100, 1), "%")
  )

# Display the clean table in the console
print(essential_comparison)


###Il controllo del contesto (Modello 3 - Il Vincitore Globale): Mostri che inserendo i controlli macro-nazionali (discrimination_center, misery_index) e la struttura multilivello, il fit del modello tocca il suo picco massimo (Performance-Score del 69.31%). Questo è il tuo modello di riferimento per spiegare gli effetti principali.

anova_results <- anova(zinb_model1, zinb_model2, zinb_model3, zinb_model4, test = "Chisq")
print(anova_results)

###conferma del modello vincente: zinb_model3 è il modello con il miglior fit e significatività statistica rispetto agli altri modelli. Questo modello sarà utilizzato per ulteriori analisi e interpretazioni.