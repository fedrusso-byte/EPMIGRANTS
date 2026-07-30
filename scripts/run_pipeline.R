# scripts/run_pipeline.R
# run_pipeline.R — EPMigrants Data Pipeline Orchestrator
# Runs all pipeline stages in separate R processes to manage memory.
# Usage: Rscript scripts/run_pipeline.R

# 1. Configuration and Dependencies
# Using a simple config list to avoid commenting/uncommenting code for different model versions
pipeline_config <- list(
  model_version = "Bayesian", # Options: "Standard", "FE", "Bayesian"
  comparison_version = "Bayesian" # Options: "Standard", "Bayesian"
)

# Load required libraries
# Note: It is assumed that the environment is managed via renv (see .clinerules)
libs <- c("here", "dplyr", "tidyr", "readr", "writexl", "tidyverse")
lapply(libs, library, character.only = TRUE)

# 2. Definition of scripts to run
# We define the core pipeline and then dynamically add the selected model version
core_scripts <- c(
  "01_import_questions.R", 
  "02_df_setup.R", 
  "03_country_level_vars.R", 
  "04_download_problem_indicators.R"
)

model_map <- list(
  "Standard" = "05_models.R",
  "FE"       = "05_models_FE.R",
  "Bayesian" = "05_models_Bayesian.R"
)

comparison_map <- list(
  "Standard"  = "06_model_comparison.R",
  "Bayesian" = "06_model_comparison_Bayesian.R"
)

# Resolve the specific scripts based on config
selected_model <- model_map[[pipeline_config$model_version]]
selected_comp   <- comparison_map[[pipeline_config$comparison_version]]

scripts_to_run <- c(core_scripts, selected_model, selected_comp)

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

# 6. Execution of the Pipeline
cat("=== EUQuest Data Pipeline ===\n\n")

# Execute core steps
for (i in seq_along(core_scripts)) {
  run_step(i, paste("Core step", i), core_scripts[i])
}

# Execute Model step
run_step(5, sprintf("Fitting models (%s)", pipeline_config$model_version), selected_model)

# Execute Comparison step
run_step(6, sprintf("Comparing models (%s)", pipeline_config$comparison_version), selected_comp)


cat("=== Pipeline complete ===\n")