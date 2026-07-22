# ==============================================================================
# # 05_models.R — Zero-Inflated NB GLMM + Marginal Effects (MIPEX Updated)
# Fits multilevel ZINB model, computes variance decomposition,
# coefficient tables, effect plots, and marginal predictions.
# ==============================================================================

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

# Helper Corretto per estrarre SOLO gli effetti fissi condizionali
tidy_exp_coefs <- function(model) {
  broom.mixed::tidy(model, component = "cond") %>%
    # CRITICO: Teniamo solo gli effetti fissi, eliminando le stime della varianza casuale
    filter(effect == "fixed") %>%
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
message("   Loading updated MEP-year dataset...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

# CORREZIONE 1: Sanity check aggiornato con la nuova variabile dipendente pqs_discrimination
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("pqs_discrimination", "total_questions", "gender",
                                     "party_family", "libe", "misery_index",
                                     "discrimination_mean", "mipex_antidiscrimination_score", 
                                     "cmp_mean", "mep_id", "country", "minority") %in% names(df_merged_3))
)

# 1. CREAZIONE DELLE VARIABILI CENTRATE
df_merged_3 <- df_merged_3 %>%
  mutate(
    discrimination_center = discrimination_mean - mean(discrimination_mean, na.rm = TRUE),
    cmp_center = cmp_mean - mean(cmp_mean, na.rm = TRUE),
    mipex_center = mipex_antidiscrimination_score - mean(mipex_antidiscrimination_score, na.rm = TRUE)
  )

# ==============================================================================
# 2. PULIZIA STRUTTURALE DEI PAESI E FILTRO CASI (Listwise Deletion) ####
# ==============================================================================
message("   Pulizia preventiva dei paesi strutturalmente privi di dati MIPEX/CMP...")

paesi_da_escludere <- df_merged_3 %>%
  filter(legislative_term %in% c("8th", "9th")) %>%
  group_by(country) %>%
  summarise(
    pct_na_mipex = mean(is.na(mipex_antidiscrimination_score)),
    pct_na_cmp   = mean(is.na(cmp_mean)),
    .groups = "drop"
  ) %>%
  filter(pct_na_mipex == 1 | pct_na_cmp == 1) %>%
  pull(country)

message(paste("🚫 Paesi esclusi strutturalmente (100% dati mancanti):", paste(paesi_da_escludere, collapse = ", ")))

df_model_data <- df_merged_3 %>% 
  filter(legislative_term %in% c("8th", "9th")) %>% 
  filter(!country %in% paesi_da_escludere) %>%
  drop_na(
    pqs_discrimination, total_questions, gender, mep_id, country,
    party_family, libe, minority, cmp_center, 
    misery_index, discrimination_center, mipex_center
  )

message(paste("✅ N finale del dataset purificato per i modelli:", nrow(df_model_data)))
saveRDS(df_model_data, here("output", "df_model_data.rds"))
message("   Dataset for models saved to: output/df_model_data.rds")


# ==============================================================================
# 3. STIMA DEI MODELLI (Risoluzione globale problemi Hessiano / NaN) ####
# ==============================================================================

# Definiamo un blocco di controllo robusto comune a tutti i modelli
controllo_ottimizzatore <- glmmTMBControl(
  optimizer = nlminb,
  optArgs = list(iter.max = 3000, eval.max = 3000)
)

# Modello 1
message("   Fitting zinb_model1...")
zinb_model1 <- glmmTMB(
   pqs_discrimination ~ 
       gender + misery_index + party_family + libe + cmp_center + discrimination_center + 
       offset(log(total_questions + 1)) + 
       (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data,
   control = controllo_ottimizzatore
)
saveRDS(zinb_model1, here("output", "zinb_model1.rds"))

# Modello 2
message("   Fitting zinb_model2...")
zinb_model2 <- glmmTMB(
   pqs_discrimination ~ 
       gender + misery_index + party_family + libe + cmp_center + discrimination_center + 
       minority +
       offset(log(total_questions + 1)) + 
       (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data,
   control = controllo_ottimizzatore
)
saveRDS(zinb_model2, here("output", "zinb_model2.rds"))

# Modello 3
message("   Fitting zinb_model3 (with MIPEX)...")
zinb_model3 <- glmmTMB(
   pqs_discrimination ~ 
       gender + misery_index + party_family + libe + minority + 
       cmp_center + discrimination_center + mipex_center + 
       offset(log(total_questions + 1)) + 
       (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data,
   control = controllo_ottimizzatore
)
saveRDS(zinb_model3, here("output", "zinb_model3.rds"))

# Modello 4
message("   Stima del Modello 4...")
zinb_model4 <- glmmTMB(
  pqs_discrimination ~ 
    gender + misery_index + party_family + libe + 
    discrimination_center + cmp_center + minority * mipex_center + 
    offset(log(total_questions + 1)) + 
    (1 | mep_id) + (1 | country),
  family = nbinom2,
  ziformula = ~ 1,           
  data = df_model_data,
  control = controllo_ottimizzatore
)
saveRDS(zinb_model4, here("output", "zinb_model4.rds"))


# ==============================================================================
# 4. CONFRONTO PERFORMANCE E ANOVA (VERSIONE BLINDATA) ####
# ==============================================================================
message("   Generazione tabelle di confronto delle performance...")

model_comparison <- performance::compare_performance(
  zinb_model1, zinb_model2, zinb_model3, zinb_model4, 
  metrics = c("RMSE", "AIC", "BIC")
)

essential_comparison <- model_comparison %>%
  as_tibble() %>%
  mutate(
    Model_Label = case_when(
      Name == "zinb_model1" ~ "M1: Baseline Individual Controls",
      Name == "zinb_model2" ~ "M2: Adding Minority Predictor",
      Name == "zinb_model3" ~ "M3: Fully Controlled + MIPEX + Country RE",
      Name == "zinb_model4" ~ "M4: Country RE + MIPEX + Minority*MIPEX Interaction",
      TRUE ~ Name
    ),
    RMSE = round(RMSE, 3),
    AIC = round(AIC, 1),
    BIC = round(BIC, 1)
  ) %>%
  dplyr::select(Model = Model_Label, RMSE, AIC, BIC) %>%
  arrange(AIC)

print("--- Tabella Comparativa delle Performance ---")
print(essential_comparison)

anova_results <- anova(zinb_model1, zinb_model2, zinb_model3, zinb_model4, test = "Chisq")
print("--- Test ANOVA Completo (Tutti i Modelli) ---")
print(anova_results)

# ==============================================================================
# 6. ESTRAZIONE COEFFICIENTI E COSTRUZIONE TABELLA UNIFICATA (CORRETTO) ####
# ==============================================================================
message("   Estrazione e formattazione dei coefficienti per i 4 modelli...")

coef_m1 <- tidy_exp_coefs(zinb_model1) %>% rename_with(~paste0(., "_M1"), -term)
coef_m2 <- tidy_exp_coefs(zinb_model2) %>% rename_with(~paste0(., "_M2"), -term)
coef_m3 <- tidy_exp_coefs(zinb_model3) %>% rename_with(~paste0(., "_M3"), -term)
coef_m4 <- tidy_exp_coefs(zinb_model4) %>% rename_with(~paste0(., "_M4"), -term)

tabella_coefficienti <- coef_m1 %>%
  full_join(coef_m2, by = "term") %>%
  full_join(coef_m3, by = "term") %>%
  full_join(coef_m4, by = "term") %>%
  rename(Predictor = term)

print("--- Anteprima dei Coefficienti Unificati (Componente Condizionale) ---")
print(head(tabella_coefficienti, 10))

write_csv(tabella_coefficienti, here("output", "model_coefficients_comparison.csv"))
message("🎉 Tabella dei coefficienti salvata in: output/model_coefficients_comparison.csv")

# ------------------------------------------------------------------------------
# Versione compatta per il terminale
# ------------------------------------------------------------------------------
tabella_compatta <- tabella_coefficienti %>%
  mutate(
    `M1 (Baseline)`   = if_else(!is.na(estimate_M1), paste0(estimate_M1, " (IRR: ", exp_estimate_M1, ") ", pval_str_M1), "-"),
    `M2 (+ Minority)` = if_else(!is.na(estimate_M2), paste0(estimate_M2, " (IRR: ", exp_estimate_M2, ") ", pval_str_M2), "-"),
    `M3 (+ MIPEX)`    = if_else(!is.na(estimate_M3), paste0(estimate_M3, " (IRR: ", exp_estimate_M3, ") ", pval_str_M3), "-"),
    `M4 (Interaction)` = if_else(!is.na(estimate_M4), paste0(estimate_M4, " (IRR: ", exp_estimate_M4, ") ", pval_str_M4), "-")
  ) %>%
  dplyr::select(Predictor, `M1 (Baseline)`, `M2 (+ Minority)`, `M3 (+ MIPEX)`, `M4 (Interaction)`)

knitr::kable(tabella_compatta, format = "markdown", caption = "Confronto dei Coefficienti e degli Incident Rate Ratios (IRR)")