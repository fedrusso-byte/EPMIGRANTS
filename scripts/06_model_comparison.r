# ==========================================
# #06 MODEL COMPARISON: Tables and Plots (Fixed)
# ==========================================
# ==============================================================================
# TABELLA COMPARATIVA DEI COEFFICIENTI (IRR) PER I 4 MODELLI
# ==============================================================================
library(broom.mixed)
library(tidyverse)
library(here)

message("  Estrazione e formattazione dei coefficienti in corso...")

# Funzione helper interna per estrarre l'IRR e formattare i p-value
extract_irr <- function(model, model_label) {
  tidy(model, effects = "fixed", component = "cond") %>%
    mutate(
      IRR = exp(estimate),
      conf.low_IRR = exp(estimate - 1.96 * std.error),
      conf.high_IRR = exp(estimate + 1.96 * std.error),
      # Formattazione delle stelline di significatività
      stars = case_when(
        p.value < 0.001 ~ "***",
        p.value < 0.01  ~ "**",
        p.value < 0.05  ~ "*",
        p.value < 0.1   ~ ".",
        TRUE            ~ ""
      ),
      # Stringa compatta da mostrare in tabella: IRR (CI_low - CI_high) stars
      Inquadramento = sprintf("%.3f [%.2f, %.2f]%s", IRR, conf.low_IRR, conf.high_IRR, stars)
    ) %>%
    select(term, !!sym(paste0("IRR_", model_label)) := Inquadramento)
}

# Estrazione dai 4 modelli stimati
t_m1 <- extract_irr(zinb_model1, "M1_Base")
t_m2 <- extract_irr(zinb_model2, "M2_Minority")
t_m3 <- extract_irr(zinb_model3, "M3_MacroControlli")
t_m4 <- extract_irr(zinb_model4, "M4_Interazione")

# Unione di tutte le tabelle in un'unica matrice comparativa
tabella_comparativa_irr <- t_m1 %>%
  full_join(t_m2, by = "term") %>%
  full_join(t_m3, by = "term") %>%
  full_join(t_m4, by = "term") %>%
  # Ordiniamo l'intercetta per prima per pulizia grafica
  arrange(desc(term == "(Intercept)"))

# Mostra il risultato in console
print(tabella_comparativa_irr, n = Inf)

# Esportazione in CSV pronta per Excel o per essere incollata su Word/LaTeX
write_csv(tabella_comparativa_irr, here("output", "tabella_comparativa_irr_definitiva.csv"))
message("  -> Tabella salvata con successo in 'output/tabella_comparativa_irr_definitiva.csv'")


# ==============================================================================
# VISUALIZZAZIONE MAGNITUDINE DEGLI EFFETTI — SOLO MODELLO 3
# ==============================================================================
library(marginaleffects)
library(ggplot2)
# Use the 'by' argument to force R to compute a single average per group
pred_minority_aggregated <- predictions(
  zinb_model3, 
  variables = "minority",
  by = "minority",        # Crucial: collapses individual rows into 2 group means
  re.form = NA
)

# Print a verification check in the console
message("--- NEW AGGREGATED DATA CHECK (Should be exactly 2 rows!) ---")
print(pred_minority_aggregated)
message("-------------------------------------------------------------------------")

# Build the final clean plot with exactly two bars
plot_minority_final <- ggplot(pred_minority_aggregated, 
                               aes(x = factor(minority, labels = c("Non-Minority", "Minority")), 
                                   y = estimate, 
                                   fill = factor(minority))) +
  # Draw two crisp bars
  geom_col(width = 0.4, alpha = 0.85, color = "black", linewidth = 0.6) +
  # Draw a single, clear error bar (Confidence Interval) per column
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), 
                width = 0.1, linewidth = 0.9, color = "#2c3e50") +
  # Academic color palette (Muted Blue/Slate vs Academic Red)
  scale_fill_manual(values = c("#5a738e", "#e74c3c"), guide = "none") +
  labs(
    title = "Expected Number of Parliamentary Questions (Model 3)",
    subtitle = "Average Marginal Population Predictions (95% Confidence Intervals)",
    x = "MP Identity Status",
    y = "Predicted Mean Number of Questions"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

# Display the final clean plot
print(plot_minority_final)

# Save the plot in high resolution
ggsave(
  filename = here("output", "figures", "m3_final_minority_magnitude_en.png"),
  plot = plot_minority_final,
  width = 7, height = 5, dpi = 300
)
message("  -> Plot successfully saved to 'output/figures/m3_final_minority_magnitude_en.png'")

# 2. PLOT 2: Confronto altri predittori individuali (Gender e LIBE) ####
# Calcoliamo le pendenze medie (effetti marginali) per fare un grafico a punti
# 1. Extract structural coefficients and exponentiate to get IRRs
model_coefficients <- tidy(zinb_model3, effects = "fixed", component = "cond") %>%
  filter(term %in% c("genderM", "libe")) %>%
  mutate(
    irr = exp(estimate),
    conf.low_irr = exp(estimate - 1.96 * std.error),
    conf.high_irr = exp(estimate + 1.96 * std.error),
    term_clean = case_when(
      term == "genderM" ~ "Gender (Male vs. Female)",
      term == "libe"    ~ "LIBE Committee Member (Yes vs. No)"
    )
  )

# 2. Build the Forest Plot (Where 1 is the baseline of no effect)
plot_irr_fixed <- ggplot(model_coefficients, aes(y = term_clean, x = irr)) +
  # Crucial: The null hypothesis line for an IRR is 1, not 0!
  geom_vline(xintercept = 1, linetype = "dashed", color = "#c0392b", linewidth = 0.8) +
  # Plot the point estimates (IRRs)
  geom_point(size = 4, color = "#2c3e50") +
  # Plot the exact horizontal confidence intervals
  geom_errorbarh(aes(xmin = conf.low_irr, xmax = conf.high_irr), height = 0.15, linewidth = 0.9, color = "#2c3e50") +
  labs(
    title = "Incidence Rate Ratios (IRR): Individual Factors",
    subtitle = "Relative multiplicative effect on question counts (Model 3)",
    x = "Incidence Rate Ratio (Values > 1 indicate an increase)",
    y = ""
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d"),
    panel.grid.minor = element_blank()
  )

# Render plot to screen
print(plot_irr_fixed)

# Save the plot in high resolution
ggsave(
  filename = here("output", "figures", "m3_final_irr_individual_en.png"),
  plot = plot_irr_fixed,
  width = 7, height = 5, dpi = 300
)
message("  -> Plot successfully saved to 'output/figures/m3_final_irr_individual_en.png'")



### CMP

message("  Generating high-efficiency prediction profiles for Model 3...")
# 1. Prediction Grid for CMP (Claim-Making Pressure) ####
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

plot_line_cmp <- ggplot(pred_cmp_clean, aes(x = cmp_center, y = estimate)) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, fill = "#16a085") +
  geom_line(linewidth = 1.2, color = "#16a085") +
  labs(
    title = "Claim-Making Pressure (CMP)", 
    x = "Centered CMP Score", 
    y = "Expected Question Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank()
)

print(plot_line_cmp)

# Save the polished output
ggsave(
  filename = here("output", "figures", "m3_CMP_magnitude_en.png"), 
  plot = plot_line_cmp, 
  width = 10, height = 5, dpi = 300
)

message("  -> Continuous effects plot successfully saved to 'output/figures/m3_continuous_magnitude_en.png'")