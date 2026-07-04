# ==============================================================================
# UNIFIED VISUALIZATION PANEL: EXPECTED COUNT VALUES (OMITTING PLOT 2)
# ==============================================================================
library(marginaleffects)
library(ggplot2)
library(patchwork)
library(here)

message("  Generating streamlined expected count panel for Model 3...")

# ------------------------------------------------------------------------------
# PANEL A: Expected Counts for Minority Status (Discrete Categories)
# ------------------------------------------------------------------------------
pred_minority <- predictions(
  zinb_model3, 
  variables = "minority",
  by = "minority",
  re.form = NA
)

panel_a_discrete <- ggplot(pred_minority, aes(x = factor(minority, labels = c("Non-Minority", "Minority")), 
                                             y = estimate, fill = factor(minority))) +
  geom_col(width = 0.4, alpha = 0.85, color = "black", linewidth = 0.6) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.1, linewidth = 0.9, color = "#2c3e50") +
  scale_fill_manual(values = c("#5a738e", "#e74c3c"), guide = "none") +
  labs(
    title = "A: Impact of MP Identity Status",
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
# PANEL B: Expected Counts for Claim-Making Pressure (Continuous Spectrum)
# ------------------------------------------------------------------------------
pred_cmp_clean <- predictions(
  zinb_model3,
  newdata = datagrid(
    cmp_center = seq(min(df_model_data$cmp_center, na.rm = TRUE), 
                     max(df_model_data$cmp_center, na.rm = TRUE), 
                     length.out = 100),
    grid_type = "mean_or_mode"
  ),
  re.form = NA
)

panel_b_continuous <- ggplot(pred_cmp_clean, aes(x = cmp_center, y = estimate)) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, fill = "#16a085") +
  geom_line(linewidth = 1.2, color = "#16a085") +
  labs(
    title = "B: Impact of Claim Making Pressure (CMP Score)", 
    x = " CMP Score (Less -> More)", 
    y = "Expected Mean Question Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )


# ------------------------------------------------------------------------------
# COMBINE INTO A STACKED BIPANEL (PATCHWORK)
# ------------------------------------------------------------------------------

# Assuming panel_a_discrete and panel_b_continuous are already defined

stacked_panel <- panel_a_discrete / panel_b_continuous +
  plot_annotation(
    title = "Magnitude of Predictors on  Expected Activity",
    subtitle = "Model 3 Marginal Predictions (Covariates fixed at sample mean/mode)",
    theme = theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 13),
      plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d", size = 9.5)
    )
  )

# Print the stacked panel
print(stacked_panel)

# Export publication-ready graphic file
ggsave(
  filename = here("output", "figures", "m3_stacked_magnitude_panel.png"), 
  plot = stacked_panel, 
  width = 7, height = 7, dpi = 300
)

message("  -> Streamlined comparative graphic successfully written to output folder.")