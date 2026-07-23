# scripts/run_pipeline.R
# run_pipeline.R — EPMigrants Data Pipeline Orchestrator
# Runs all pipeline stages in separate R processes to manage memory.
# Usage: Rscript scripts/run_pipeline.R

# 1. Caricamento librerie e controllo installazione
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)

if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}
library(dplyr)

if (!requireNamespace("tidyr", quietly = TRUE)) {
  install.packages("tidyr")
}
library(tidyr)

if (!requireNamespace("readr", quietly = TRUE)) {
  install.packages("readr")
}
library(readr)

if (!requireNamespace("writexl", quietly = TRUE)) {
  install.packages("writexl")
}
library(writexl)

if (!requireNamespace("tidyverse", quietly = TRUE)) {
  install.packages("tidyverse")
}
library(tidyverse)

# 2. Definizione dei file da eseguire
# Include all versions of model scripts for verification
scripts_to_run <- c("01_import_questions.R", "02_df_setup.R", "03_country_level_vars.R",
                    "04_download_problem_indicators.R", "05_models.R", "05_models_FE.r", 
                    "05_models_Bayesian.R", "06_model_comparison.r")

# 3. Verifica preventiva dell'esistenza dei file
for (s in scripts_to_run) {
  if (!file.exists(here("scripts", s))) {
    stop(paste("ERRORE: Lo script", s, "non esiste nella cartella scripts/!"))
  }
}

# 4. Creazione cartelle di output
dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("data_processed"), showWarnings = FALSE, recursive = TRUE)

# 5. Funzione per eseguire ogni step in una sessione pulita
run_step <- function(step_num, description, script_name) {
  cat(sprintf("Step %d/%d: %s...\n", step_num, length(scripts_to_run), description))

  script_path <- shQuote(here("scripts", script_name))

  # Eseguiamo Rscript passando il percorso virgolettato
  result <- system2("Rscript", args = script_path,
                    stdout = TRUE, stderr = TRUE)

  if (!is.null(attr(result, "status")) && attr(result, "status") != 0) {
    cat("  FAILED!\n")
    # Stampiamo le ultime 20 righe dell'errore REALE dello script per debug
    cat(tail(result, 20), sep = "\n")
    stop(sprintf("Pipeline failed at step %d: %s", step_num, script_name))
  }
  cat(sprintf("  -> %s complete\n\n", script_name))
}

# 6. Esecuzione della Pipeline
cat("=== EUQuest Data Pipeline ===\n\n")

run_step(1, "Importing and coding questions", "01_import_questions.R")
run_step(2, "Constructing MEP-year-issue panel", "02_df_setup.R")
run_step(3, "Adding country-level variables", "03_country_level_vars.R")
run_step(4, "Downloading problem indicators", "04_download_problem_indicators.R")

# STEP 5: Choose WHICH model version to run (Uncomment only ONE)
# run_step(5, "Fitting models (Standard)", "05_models.R")
# run_step(5, "Fitting models (Fixed Effects)", "05_models_FE.r")
run_step(5, "Fitting models (Bayesian)", "05_models_Bayesian.R")

# STEP 6: Choose WHICH model version to compare (Uncomment only ONE)
#run_step(6, "Comparing models", "06_model_comparison.R")
run_step(6, "Comparing models", "06_model_comparison_Bayesian.R")


cat("=== Pipeline complete ===\n")