# ==============================================================================
# BAYESIAN VISUALIZATION PANEL: MODEL MIPEX MARGINAL EFFECTS & INTERACTION
# Adapted from 06_model_comparison.r for brms models
# ==============================================================================
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(here)
library(brms)

message("   Loading Bayesian model and data for visualization...")
df_model_data <- readRDS(here("output", "df_model_data.rds"))
# brms models saved with the 'file' argument create .rds files
bayesian_model_mipex <- readRDS(here("output", "bayesian_model_mipex.rds"))

message("   Generating Bayesian expected count panel (Marginal Effects)...")

# Create base grid with covariates fixed at means/reference levels
base_grid <- df_model_data %>%
  summarise(
    gender = "M",                                           # Reference/most common
    party_family = "Christian democrats and conservatives", # Reference/most common
    libe = 0,                                               # Binary/fixed
    misery_index = mean(misery_index, na.rm = TRUE),
    discrimination_center = 0,                              # Centered (0 = mean)
    cmp_center = 0,                                         # Centered (0 = mean)
    country = "Reference",                                  # Dummy value to satisfy brms grouping
    total_questions = mean(total_questions, na.rm = TRUE)   # Offset fixed at mean
  )

# ------------------------------------------------------------------------------
# PANEL A: Expected Counts for Minority Status
# ------------------------------------------------------------------------------
grid_a <- base_grid %>%
  slice(rep(1, 2)) %>%
  mutate(
    minority = c(0, 1),
    mipex_center = 0 # Fixed at mean
  )

# Bayesian prediction: use posterior_predict to get simulated counts
# This automatically handles the ZINB combination (count + zero-inflation)
# re.form = NA ensures we get population-level predictions
# allow_new_levels = TRUE lets us use a dummy country name for the grid
pred_a <- posterior_predict(bayesian_model_mipex, newdata = grid_a, re.form = NA, allow_new_levels = TRUE)

# Calculate mean and 95% Credible Intervals (CI) from the posterior samples
# pred_a is [n_samples, n_obs], so we take means/quantiles across rows (samples)
pred_minority_bayesian <- grid_a %>%
  mutate(
    estimate = colMeans(pred_a),
    conf.low = apply(pred_a, 2, quantile, probs = 0.025),
    conf.high = apply(pred_a, 2, quantile, probs = 0.975)
  )

panel_a_discrete <- ggplot(pred_minority_bayesian, aes(x = factor(minority, labels = c("Non-Minority", "Minority")), 
                                                     y = estimate, fill = factor(minority))) +
  geom_col(width = 0.4, alpha = 0.85, color = "black", linewidth = 0.6) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.1, linewidth = 0.9, color = "#2c3e50") +
  scale_fill_manual(values = c("#5a738e", "#e74c3c"), guide = "none") +
  labs(
    title = "A: Main Impact of MP Identity Status (Bayesian)",
    x = "Identity Grouping",
    y = "Expected Mean Question Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.x = element_blank(), 
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )


# ------------------------------------------------------------------------------
# PANEL B: Cross-Level Interaction (Minority * MIPEX Score)
# ------------------------------------------------------------------------------
mipex_seq <- seq(min(df_model_data$mipex_center, na.rm = TRUE), 
                 max(df_model_data$mipex_center, na.rm = TRUE), 
                 length.out = 100)

grid_b <- base_grid %>%
  dplyr::select(-total_questions) %>% 
  crossing(
    mipex_center = mipex_seq,
    minority = c(0, 1)
  ) %>%
  mutate(
    total_questions = mean(df_model_data$total_questions, na.rm = TRUE)
  )

# Bayesian prediction for the interaction grid
# use posterior_predict to get simulated counts
# re.form = NA ensures we get population-level predictions
# allow_new_levels = TRUE lets us use a dummy country name for the grid
pred_b <- posterior_predict(bayesian_model_mipex, newdata = grid_b, re.form = NA, allow_new_levels = TRUE)

# Calculate mean and 95% CI from the posterior samples
# pred_b is [n_samples, n_obs], so we take means/quantiles across rows (samples)
pred_interaction_bayesian <- grid_b %>%
  mutate(
    estimate = colMeans(pred_b),
    conf.low = apply(pred_b, 2, quantile, probs = 0.025),
    conf.high = apply(pred_b, 2, quantile, probs = 0.975)
  )

panel_b_interaction <- ggplot(pred_interaction_bayesian, aes(x = mipex_center, y = estimate, 
                                                            color = factor(minority, labels = c("Non-Minority", "Minority")), 
                                                            fill = factor(minority, labels = c("Non-Minority", "Minority")))) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = c("#5a738e", "#e74c3c"), name = "MP Group") +
  scale_fill_manual(values = c("#5a738e", "#e74c3c"), name = "MP Group") +
  labs(
    title = "B: Contextual Moderation (Identity × MIPEX Score)", 
    x = "MIPEX Anti-discrimination Score (Centered)", 
    y = "Expected Mean Question Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )


# ------------------------------------------------------------------------------
# 3. COMBINE INTO A STACKED BIPANEL WITH PATCHWORK
# ------------------------------------------------------------------------------
stacked_panel <- panel_a_discrete / panel_b_interaction +
  plot_layout(heights = c(1, 1.2)) + 
  plot_annotation(
    title = "Identity and Institutional Context (Bayesian Estimation)",
    subtitle = "Marginal Effects from Zero-Inflated NB Bayesian Model (Covariates at means)",
    theme = theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 13),
      plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d", size = 9.5)
    )
  )

# Display plot
print(stacked_panel)

# Save the figure
ggsave(
  filename = here("output", "figures", "bayesian_interaction_magnitude_panel.png"), 
  plot = stacked_panel, 
  width = 7, height = 8.5, dpi = 300
)

message("   -> Bayesian interaction graphic successfully written to output/figures/bayesian_interaction_magnitude_panel.png")