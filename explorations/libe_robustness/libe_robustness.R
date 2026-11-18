# ==============================================================================
# explorations/libe_robustness/libe_robustness.R
# LIBE-OMISSION ROBUSTNESS: DIRECT vs TOTAL EFFECT OF MINORITY BACKGROUND
# ------------------------------------------------------------------------------
# Why this exists (decision with FR, 2026-11-12):
#   Minority background plausibly CAUSES LIBE assignment (self-selection into
#   the civil-liberties committee and/or party channeling of minority MEPs).
#   Under that theoretical view, `libe` is a POST-TREATMENT variable
#   (mediator), and the two framings imply different estimands:
#     - PRIMARY models (scripts/05_models_Bayesian.R), which control for
#       `libe`, estimate the DIRECT effect of biography (net of committee);
#     - the NO-LIBE models fitted here estimate the TOTAL effect (including
#       whatever operates through committee assignment);
#     - the minority * libe model asks whether the committee boost itself
#       differs by minority background (descriptively: mean DV 0.451 vs
#       0.145 for minority MEPs on vs off LIBE -> committee boost ~3x larger).
#
# Comparability guarantees (verified 2026-11-12):
#   - exact same estimation sample as the primary models:
#     output/df_model_data.rds (N = 9,850 MEP-years, 1,543 MEPs, DV sum 1,038)
#     is byte-identical to the in-script reconstruction in
#     scripts/05_models_Bayesian.R (drop_na on model variables, terms 7th-9th);
#   - same family (ZINB), priors, chains/iter/warmup/cores, adapt_delta;
#   - fits are CACHED in output/libe_robustness/ -> the primary fits in
#     output/ are never touched or overwritten.
#   NOTE: brm(file = ...) caches by path; if you change a model formula,
#   delete the cached .rds first or the stale fit will be loaded silently.
# ==============================================================================

rm(list = ls())

# Libraries ####
library(tidyverse)
library(brms)
library(here)
library(broom.mixed)
library(knitr)

dir_out <- here("output", "libe_robustness")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. DATA - exact primary estimation sample
# ==============================================================================
df_model_data <- readRDS(here("output", "df_model_data.rds"))

stopifnot(
  nrow(df_model_data) == 9850,
  dplyr::n_distinct(df_model_data$mep_id) == 1543,
  all(c("pqs_discrimination", "total_questions", "gender", "mep_id",
        "country", "party_family", "libe", "minority", "misery_index",
        "cmp_center", "mipex_center") %in% names(df_model_data))
)
message("Sample check: ", nrow(df_model_data), " MEP-years, ",
        dplyr::n_distinct(df_model_data$mep_id), " MEPs (identical to primary models)")

# Cell structure of the minority x libe design (context for the memo)
cell_sizes <- df_model_data %>%
  dplyr::count(minority, libe, name = "mep_years") %>%
  dplyr::left_join(
    df_model_data %>%
      dplyr::distinct(mep_id, minority, libe) %>%
      dplyr::count(minority, libe, name = "meps"),
    by = c("minority", "libe")
  )
message("Minority x LIBE cell structure (MEP-years / unique MEPs):")
print(as.data.frame(cell_sizes))

# Priors - identical to 05_models_Bayesian.R
priors_common <- c(
  set_prior("student_t(3, 0, 2.5)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "zi")
)

# ==============================================================================
# 2. FITS WITHOUT `libe` - TOTAL effect of minority background
# ==============================================================================
t_fit <- Sys.time()
message("Fitting MIPEX model WITHOUT libe (total effect)...")
bayesian_model_mipex_nolibe <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family +
    minority * mipex_center +
    offset(log(total_questions + 1)) +
    (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 2000, warmup = 1000, cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = file.path(dir_out, "bayesian_model_mipex_nolibe")
)
message("Done: MIPEX no-libe (",
        round(as.numeric(difftime(Sys.time(), t_fit, units = "mins")), 1), " min)")

t_fit <- Sys.time()
message("Fitting CMP model WITHOUT libe (total effect)...")
bayesian_model_cmp_nolibe <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family +
    minority * cmp_center +
    offset(log(total_questions + 1)) +
    (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 2000, warmup = 1000, cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = file.path(dir_out, "bayesian_model_cmp_nolibe")
)
message("Done: CMP no-libe (",
        round(as.numeric(difftime(Sys.time(), t_fit, units = "mins")), 1), " min)")

# ==============================================================================
# 3. FIT WITH minority * libe - does the committee boost differ by background?
# ==============================================================================
t_fit <- Sys.time()
message("Fitting MIPEX model with minority * libe + minority * mipex_center...")
bayesian_model_mipex_minoritylibe <- brm(
  formula = pqs_discrimination ~
    gender + misery_index + party_family +
    minority * libe + minority * mipex_center +
    offset(log(total_questions + 1)) +
    (1 | country),
  data = df_model_data,
  family = zero_inflated_negbinomial(),
  prior = priors_common,
  chains = 4, iter = 2000, warmup = 1000, cores = 4,
  control = list(adapt_delta = 0.95),
  seed = 20260321,
  file = file.path(dir_out, "bayesian_model_mipex_minoritylibe")
)
message("Done: minority x libe model (",
        round(as.numeric(difftime(Sys.time(), t_fit, units = "mins")), 1), " min)")

# ==============================================================================
# 4. CONVERGENCE DIAGNOSTICS (new fits, population-level parameters)
# ==============================================================================
diagnostics_summary <- function(model, model_name) {
  s <- posterior::summarise_draws(posterior::as_draws_df(model)) %>%
    dplyr::filter(grepl("^b_|^zi_|^shape", variable))
  np <- tryCatch(nuts_params(model), error = function(e) NULL)
  divergent <- if (is.null(np)) {
    NA_integer_
  } else {
    par_col <- intersect(c("Parameter", "parameter"), names(np))[1]
    val_col <- intersect(c("Value", "value"), names(np))[1]
    sum(np[[par_col]] == "divergent__" & np[[val_col]] == 1)
  }
  tibble(
    model = model_name,
    max_rhat = max(s$rhat, na.rm = TRUE),
    min_ess_bulk = min(s$ess_bulk, na.rm = TRUE),
    min_ess_tail = min(s$ess_tail, na.rm = TRUE),
    divergent_transitions = divergent
  )
}

diag_table <- bind_rows(
  diagnostics_summary(bayesian_model_mipex_nolibe, "MIPEX no libe"),
  diagnostics_summary(bayesian_model_cmp_nolibe, "CMP no libe"),
  diagnostics_summary(bayesian_model_mipex_minoritylibe, "MIPEX minority x libe")
)
message("Convergence diagnostics (population-level parameters):")
print(as.data.frame(diag_table))
write_csv(diag_table, file.path(dir_out, "libe_robustness_diagnostics.csv"))

# ==============================================================================
# 5. COEFFICIENT COMPARISON - primary (with libe) vs robustness fits
# ==============================================================================
message("Loading primary fits for side-by-side comparison...")
bayesian_model_cmp <- readRDS(here("output", "bayesian_model_cmp.rds"))
bayesian_model_mipex <- readRDS(here("output", "bayesian_model_mipex.rds"))

extract_bayesian_results <- function(model, model_name) {
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    dplyr::mutate(model = model_name)
}

final_results <- bind_rows(
  extract_bayesian_results(bayesian_model_cmp, "CMP primary (with libe)"),
  extract_bayesian_results(bayesian_model_mipex, "MIPEX primary (with libe)"),
  extract_bayesian_results(bayesian_model_cmp_nolibe, "CMP no libe (total effect)"),
  extract_bayesian_results(bayesian_model_mipex_nolibe, "MIPEX no libe (total effect)"),
  extract_bayesian_results(bayesian_model_mipex_minoritylibe, "MIPEX minority x libe")
) %>%
  dplyr::select(model, term, estimate, std.error, conf.low, conf.high)

write_csv(final_results, file.path(dir_out, "libe_robustness_results.csv"))
message("Saved full coefficient table: output/libe_robustness/libe_robustness_results.csv")

# Focal parameters, draws-based: median [95% CrI], P(draw > 0)
focal_pars <- tribble(
  ~parameter, ~label,
  "b_minority", "minority (main effect)",
  "b_libe", "libe (main effect)",
  "b_mipex_center", "mipex_center (main effect)",
  "b_minority:mipex_center", "minority x mipex_center (H3)",
  "b_cmp_center", "cmp_center (main effect)",
  "b_minority:cmp_center", "minority x cmp_center (H2)",
  "b_minority:libe", "minority x libe (committee boost)"
)

models_focal <- list(
  "MIPEX primary (with libe)" = bayesian_model_mipex,
  "MIPEX no libe (total)" = bayesian_model_mipex_nolibe,
  "MIPEX minority x libe" = bayesian_model_mipex_minoritylibe,
  "CMP primary (with libe)" = bayesian_model_cmp,
  "CMP no libe (total)" = bayesian_model_cmp_nolibe
)

focal_table <- purrr::map_dfr(names(models_focal), function(mn) {
  dr <- posterior::as_draws_df(models_focal[[mn]])
  purrr::map_dfr(seq_len(nrow(focal_pars)), function(i) {
    d <- dr[[focal_pars$parameter[i]]]
    if (is.null(d) || length(d) == 0) {
      return(tibble(label = focal_pars$label[i], model = mn,
                    estimate = NA_real_, conf.low = NA_real_,
                    conf.high = NA_real_, p_positive = NA_real_))
    }
    tibble(
      label = focal_pars$label[i],
      model = mn,
      estimate = median(d),
      conf.low = quantile(d, 0.025, names = FALSE),
      conf.high = quantile(d, 0.975, names = FALSE),
      p_positive = mean(d > 0)
    )
  })
})

write_csv(focal_table,
          file.path(dir_out, "libe_robustness_focal_coefficients.csv"))

focal_wide <- focal_table %>%
  dplyr::mutate(cell = sprintf("%.3f [%.3f, %.3f]  P(+)=%.3f",
                               estimate, conf.low, conf.high, p_positive)) %>%
  dplyr::select(label, model, cell) %>%
  tidyr::pivot_wider(names_from = model, values_from = cell)

message("")
message("=== FOCAL COEFFICIENT COMPARISON (median [95% CrI], P(draw>0)) ===")
print(knitr::kable(focal_wide, format = "markdown"))

# ==============================================================================
# 6. EXPECTED COUNTS & MINORITY CONTRASTS (IRR) - direct vs total effect
#    Grid conventions mirror 06_model_comparison_Bayesian.R:
#    gender = "M", party_family = reference, offset at mean, country averaged
#    out (re.form = NA), MIPEX at observed min / median / max.
# ==============================================================================
mipex_levels <- df_model_data %>%
  dplyr::summarise(
    min = min(mipex_center, na.rm = TRUE),
    median = median(mipex_center, na.rm = TRUE),
    max = max(mipex_center, na.rm = TRUE)
  ) %>%
  tidyr::pivot_longer(dplyr::everything(),
                      names_to = "mipex_level", values_to = "mipex_center")

make_grid <- function(with_libe) {
  g <- mipex_levels %>% tidyr::crossing(minority = c(0, 1))
  if (with_libe) g <- g %>% tidyr::crossing(libe = c(0, 1))
  g %>%
    dplyr::mutate(
      gender = "M",
      party_family = "Christian democrats and conservatives",
      misery_index = mean(df_model_data$misery_index, na.rm = TRUE),
      total_questions = mean(df_model_data$total_questions, na.rm = TRUE),
      country = "Reference"
    )
}

expected_counts <- function(model, model_name, grid) {
  ep <- posterior_epred(model, newdata = grid,
                        re.form = NA, allow_new_levels = TRUE)
  grid %>%
    dplyr::mutate(
      model = model_name,
      estimate = colMeans(ep),
      conf.low = apply(ep, 2, quantile, probs = 0.025),
      conf.high = apply(ep, 2, quantile, probs = 0.975)
    )
}

minority_irr <- function(model, model_name, grid) {
  ep <- posterior_epred(model, newdata = grid,
                        re.form = NA, allow_new_levels = TRUE)
  has_libe <- "libe" %in% names(grid)
  if (has_libe) {
    strata <- grid %>% dplyr::distinct(mipex_level, mipex_center, libe)
  } else {
    strata <- grid %>% dplyr::distinct(mipex_level, mipex_center)
  }
  purrr::map_dfr(seq_len(nrow(strata)), function(i) {
    cond <- grid$mipex_center == strata$mipex_center[i]
    if (has_libe) cond <- cond & grid$libe == strata$libe[i]
    i1 <- which(cond & grid$minority == 1)
    i0 <- which(cond & grid$minority == 0)
    ratio <- ep[, i1] / ep[, i0]
    strata[i, ] %>%
      dplyr::mutate(
        model = model_name,
        irr = median(ratio),
        conf.low = quantile(ratio, 0.025, names = FALSE),
        conf.high = quantile(ratio, 0.975, names = FALSE),
        p_irr_above_1 = mean(ratio > 1)
      )
  })
}

grid_libe <- make_grid(with_libe = TRUE)
grid_nolibe <- make_grid(with_libe = FALSE)

counts_all <- bind_rows(
  expected_counts(bayesian_model_mipex, "MIPEX primary (with libe)", grid_libe),
  expected_counts(bayesian_model_mipex_nolibe, "MIPEX no libe (total)", grid_nolibe),
  expected_counts(bayesian_model_mipex_minoritylibe, "MIPEX minority x libe", grid_libe)
)
irr_all <- bind_rows(
  minority_irr(bayesian_model_mipex, "MIPEX primary (with libe)", grid_libe),
  minority_irr(bayesian_model_mipex_nolibe, "MIPEX no libe (total)", grid_nolibe),
  minority_irr(bayesian_model_mipex_minoritylibe, "MIPEX minority x libe", grid_libe)
)
write_csv(counts_all, file.path(dir_out, "libe_robustness_expected_counts.csv"))
write_csv(irr_all, file.path(dir_out, "libe_robustness_minority_contrasts.csv"))

message("")
message("=== MINORITY vs NON-MINORITY IRR AT MEDIAN MIPEX ===")
irr_median <- irr_all %>%
  dplyr::filter(mipex_level == "median") %>%
  dplyr::mutate(
    libe_lab = ifelse(is.na(libe), "omitted (avg. out)", paste0("libe=", libe)),
    irr_cell = sprintf("%.2f [%.2f, %.2f]  P(>1)=%.2f",
                       irr, conf.low, conf.high, p_irr_above_1)
  ) %>%
  dplyr::select(model, libe_lab, irr_cell)
print(knitr::kable(irr_median, format = "markdown"))

# ==============================================================================
# 7. SUMMARY OF OUTPUTS
# ==============================================================================
message("")
message("All fits and results written to output/libe_robustness/:")
message("  - bayesian_model_mipex_nolibe.rds (brms cache)")
message("  - bayesian_model_cmp_nolibe.rds (brms cache)")
message("  - bayesian_model_mipex_minoritylibe.rds (brms cache)")
message("  - libe_robustness_results.csv (full coefficient table, 5 models)")
message("  - libe_robustness_focal_coefficients.csv (focal parameters)")
message("  - libe_robustness_diagnostics.csv (Rhat / ESS / divergences)")
message("  - libe_robustness_expected_counts.csv (grid expected counts)")
message("  - libe_robustness_minority_contrasts.csv (IRR minority vs non-minority)")
message("Primary fits in output/ were NOT modified.")
