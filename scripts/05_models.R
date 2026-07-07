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
message("   Loading updated MEP-year dataset...")
problem_indicators <- read_csv(here("output", "problem_indicators.csv"), show_col_types = FALSE) %>%
  mutate(year = as.integer(round(year)))

df_merged_3 <- read_csv(here("output", "df_merged_3.csv"), show_col_types = FALSE) %>%
  mutate(mid_year = as.integer(round(mid_year))) %>%
  left_join(problem_indicators, by = c("country", "mid_year" = "year"))

# Sanity check sulle variabili ORIGINALI (Inclusa minority!)
stopifnot(
  "df_merged_3 is empty" = nrow(df_merged_3) > 0,
  "Required columns missing" = all(c("n_subtopic_201", "total_questions", "gender",
                                     "geographic_region", "party_family", "libe", "misery_index",
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
# 2. PULIZIA RIGOROSA (Identico N per tutti i modelli) - VERSIONE CORRETTA
# ==============================================================================
message("   Pulizia rigorosa (Listwise Deletion) sui predittori calcolati...")

df_model_data <- df_merged_3 %>% 
  filter(legislative_term %in% c("8th", "9th")) %>% # Raddrizzato l'operatore %in%
  drop_na(
    n_subtopic_201, total_questions, gender, geographic_region, mep_id, country,
    party_family, libe, minority, cmp_center, 
    misery_index, discrimination_center, mipex_center
  )

# ==============================================================================
# DIAGNOSTICA DELLE PERDITE DEI DATI (ATTRITION ANALYSIS)
# ==============================================================================
message("\n=== Analisi della perdita dei casi per Paese ===")

df_iniziale <- df_merged_3 %>% 
  filter(legislative_term %in% c("8th", "9th"))

Tab_Iniziale <- table(df_iniziale$country) %>% as.data.frame() %>% rename(Paese = Var1, N_Iniziale = Freq)

df_finale <- df_iniziale %>% 
  drop_na(
    n_subtopic_201, total_questions, gender, geographic_region, mep_id, country,
    party_family, libe, minority, cmp_center, 
    misery_index, discrimination_center, mipex_center
  )

Tab_Finale <- table(df_finale$country) %>% as.data.frame() %>% rename(Paese = Var1, N_Finale = Freq)

analisi_perdite <- Tab_Iniziale %>%
  left_join(Tab_Finale, by = "Paese") %>%
  mutate(
    N_Finale = coalesce(N_Finale, 0L),
    Casi_Persi = N_Iniziale - N_Finale,
    Percentuale_Persa = round((Casi_Persi / N_Iniziale) * 100, 1)
  ) %>%
  arrange(desc(Percentuale_Persa))

print(analisi_perdite)

message(paste("\nTotale casi INIZIALI (8th & 9th term):", nrow(df_iniziale)))
message(paste("Totale casi FINALES per i modelli:", nrow(df_finale)))
message(paste("Casi persi totali:", nrow(df_iniziale) - nrow(df_finale), 
              "-(", round(((nrow(df_iniziale) - nrow(df_finale)) / nrow(df_iniziale)) * 100, 1), "%)"))


# ==============================================================================
# 3. STIMA DEI MODELLI ####
# ==============================================================================

# Modello 1: Baseline Individual Controls (Senza geographic_region)
message("   Fitting zinb_model1...")
zinb_model1 <- glmmTMB(
   n_subtopic_201 ~ 
       gender + misery_index + party_family + libe + cmp_center + discrimination_center + 
       offset(log(total_questions + 1)) + 
       (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data 
)
saveRDS(zinb_model1, here("output", "zinb_model1.rds"))

# Modello 2: Adding Minority Predictor
message("   Fitting zinb_model2...")
zinb_model2 <- glmmTMB(
   n_subtopic_201 ~ 
      gender + misery_index + party_family + libe + minority + 
      offset(log(total_questions + 1)) + 
      (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data 
)
saveRDS(zinb_model2, here("output", "zinb_model2.rds"))

# Modello 3: Fully Controlled + MIPEX
message("   Fitting zinb_model3 (with MIPEX)...")
zinb_model3 <- glmmTMB(
   n_subtopic_201 ~ 
      gender + misery_index + party_family + libe + minority + 
      cmp_center + discrimination_center + mipex_center + 
      offset(log(total_questions + 1)) + 
      (1 | mep_id) + (1 | country),   
   family = nbinom2,
   ziformula = ~ 1,            
   data = df_model_data 
)
saveRDS(zinb_model3, here("output", "zinb_model3.rds"))

# Modello 4: Interazione con ottimizzatore corretto (Senza geographic_region)
message("   Stima del Modello 4 (Risoluzione problema Hessiano)...")
zinb_model4 <- glmmTMB(
  n_subtopic_201 ~ 
    gender + misery_index + party_family + libe + 
    discrimination_center + cmp_center + minority * mipex_center + 
    offset(log(total_questions + 1)) + 
    (1 | country) + (1 | mep_id),
  family = nbinom2,
  ziformula = ~ 1,           
  data = df_model_data,
  control = glmmTMBControl(
    optimizer = nlminb,
    optArgs = list(iter.max = 2000, eval.max = 2000)
  )
)
saveRDS(zinb_model4, here("output", "zinb_model4.rds"))


# ==============================================================================
# 4. CONFRONTO PERFORMANCE E ANOVA ####
# ==============================================================================
message("   Generazione tabelle di confronto delle performance...")

model_comparison <- compare_performance(zinb_model1, zinb_model2, zinb_model3, zinb_model4, rank = TRUE)

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
    Model = case_match(
      Model,
      "zinb_model1" ~ "M1: Baseline Individual Controls",
      "zinb_model2" ~ "M2: Adding Minority Predictor",
      "zinb_model3" ~ "M3: Fully Controlled + MIPEX + Country RE",
      "zinb_model4" ~ "M4: Country RE + MIPEX + Minority*MIPEX Interaction" # Corretta etichetta!
    ),
    `AIC Weight` = round(`AIC Weight`, 3),
    `BIC Weight` = round(`BIC Weight`, 3),
    `Overall Score` = paste0(round(`Overall Score` * 100, 1), "%")
  )

print(essential_comparison)

anova_results <- anova(zinb_model1, zinb_model2, zinb_model3, zinb_model4, test = "Chisq")
print(anova_results)