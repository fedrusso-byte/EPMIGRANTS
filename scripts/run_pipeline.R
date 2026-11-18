# scripts/run_pipeline.R
# run_pipeline.R — EPMigrants Data Pipeline Orchestrator
# Runs all pipeline stages in separate R processes to manage memory.
# Usage: Rscript scripts/run_pipeline.R
# Reproducibility (audit item 7, 2026-11-18): pin the CRAN mirror so the
# on-demand install fallback in load_packages() targets a stable default
# HTTPS mirror on any machine. With renv.lock (created 2026-11-18) in place
# this fallback should remain a no-op in day-to-day runs.
options(repos = c(CRAN = "https://cloud.r-project.org"))

# =============================================================================
# 1. Configuration and Dependencies
# =============================================================================

# Pipeline configuration - select which model versions to run
# (the legacy "FE" variant was quarantined in scripts/archive/ on 2026-11-18)
pipeline_config <- list(
  model_version = "Bayesian",     # Options: "Standard", "Bayesian"
  comparison_version = "Bayesian" # Options: "Standard", "Bayesian"
)

# Helper function to load required packages
load_packages <- function(pkgs) {
  missing_pkgs <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  
  if (length(missing_pkgs) > 0) {
    warning(sprintf(
      "The following packages are missing and will be installed: %s\n",
      paste(missing_pkgs, collapse = ", ")
    ))
    install.packages(missing_pkgs)
  }
  
  invisible(lapply(pkgs, library, character.only = TRUE))
}

# Load only the packages actually needed by the orchestrator
libs_orchestrator <- c("here")
load_packages(libs_orchestrator)

# =============================================================================
# 2. Definition of Scripts to Run
# =============================================================================

core_scripts <- c(
  "01_import_questions.R", 
  "02_df_setup.R", 
  "03_country_level_vars.R", 
  "04_download_problem_indicators.R"
)

# 05_models.R (2026-11-18) is the frequentist mirror of the two Bayesian
# estimands; the legacy country-FE variant (05_models_FE.R, keyword-DV vintage)
# is quarantined in scripts/archive/ and no longer selectable.
model_map <- list(
  "Standard" = "05_models.R",
  "Bayesian" = "05_models_Bayesian.R"
)

comparison_map <- list(
  "Standard"  = "06_model_comparison.R",
  "Bayesian"  = "06_model_comparison_Bayesian.R"
)

selected_model <- model_map[[pipeline_config$model_version]]
selected_comp   <- comparison_map[[pipeline_config$comparison_version]]

# 05_models.R ALWAYS runs first: it defines the shared MIPEX-only estimation
# sample (output/df_model_data.rds) consumed by 05_models_Bayesian.R
# (decision 2026-11-12). The coefficient extraction (07) requires fits from
# BOTH engines and is therefore appended only for the Bayesian variant.
# Only matched-engine combinations are valid: 05_models.R always runs (shared
# MIPEX-only sample), while 06/07 consume the fits of the selected engine —
# mixing engines across the two selectors would compare mismatched artifacts.
stopifnot(
  "model_version and comparison_version must use the same engine ('Standard' or 'Bayesian')" =
    identical(pipeline_config$model_version, pipeline_config$comparison_version),
  "unknown model_version" =
    pipeline_config$model_version %in% names(model_map),
  "unknown comparison_version" =
    pipeline_config$comparison_version %in% names(comparison_map)
)

scripts_to_run <- unique(c(core_scripts, "05_models.R", selected_model, selected_comp))
if (pipeline_config$model_version == "Bayesian") {
  scripts_to_run <- c(scripts_to_run, "07_extract_all_coefficients.R")
}

# =============================================================================
# 3. Pre-flight Checks
# =============================================================================

for (s in scripts_to_run) {
  script_path <- here("scripts", s)
  if (!file.exists(script_path)) {
    stop(sprintf("ERRORE: Lo script '%s' non esiste nella cartella scripts/!", s))
  }
}

# =============================================================================
# 4. Create Output Directories
# =============================================================================

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("data_processed"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 5. Pipeline Execution Function
# =============================================================================

run_step <- function(step_num, total_steps, description, script_name) {
  cat(sprintf("Step %d/%d: %s...\n", step_num, total_steps, description))
  
  script_path <- here("scripts", script_name)
  
  # Execute Rscript - REMOVED shQuote() for the args parameter in system2
  # as system2 handles arguments separately and shQuote can lead to 
  # double-quoting in some R versions/OS combinations.
  result <- system2(
    "Rscript", 
    args = script_path,
    stdout = TRUE, 
    stderr = TRUE
  )
  
  execution_failed <- FALSE
  error_message <- ""
  
  status_attr <- attr(result, "status")
  if (!is.null(status_attr) && status_attr != 0) {
    execution_failed <- TRUE
    error_message <- paste("Exit status:", status_attr)
  }
  
  if (!execution_failed && length(result) > 0) {
    error_patterns <- c("^Error:", "^ERROR", "fatal error", "non-zero exit status")
    has_error <- any(vapply(error_patterns, function(p) any(grepl(p, result, ignore.case = TRUE)), logical(1)))
    
    if (has_error) {
      execution_failed <- TRUE
      error_message <- "R error detected in output"
    }
  }
  
  if (execution_failed) {
    cat("  FAILED!\n")
    cat("  ", error_message, "\n\n")
    cat("  Last 30 lines of output:\n")
    cat("  ", paste(tail(result, 30), collapse = "\n  "), "\n\n")
    stop(sprintf("Pipeline failed at step %d/%d: %s", step_num, total_steps, script_name))
  }
  
  cat(sprintf("  -> %s complete\n\n", script_name))
  invisible(result)
}

# =============================================================================
# 6. Execute the Pipeline
# =============================================================================

cat("=== EUQuest Data Pipeline ===\n")
cat(sprintf("Model version: %s\n", pipeline_config$model_version))
cat(sprintf("Comparison version: %s\n\n", pipeline_config$comparison_version))

total_steps <- length(scripts_to_run)

for (i in seq_along(scripts_to_run)) {
  script_name <- scripts_to_run[i]
  
  if (i <= length(core_scripts)) {
    description <- sprintf("Core step %d", i)
  } else if (script_name == "05_models.R") {
    description <- "Fitting frequentist mirror (M1_total/M2_direct) + shared MIPEX-only sample"
  } else if (script_name == selected_model) {
    description <- sprintf("Fitting models (%s)", pipeline_config$model_version)
  } else if (script_name == "07_extract_all_coefficients.R") {
    description <- "Extracting unified coefficient tables"
  } else {
    description <- sprintf("Comparing models (%s)", pipeline_config$comparison_version)
  }
  
  run_step(i, total_steps, description, script_name)
}

cat("=== Pipeline complete ===\n")
