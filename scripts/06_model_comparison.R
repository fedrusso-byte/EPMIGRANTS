# ==============================================================================
# UNIFIED VISUALIZATION PANEL: MODEL 4 MARGINAL EFFECTS & INTERACTION (FIXED)
# ==============================================================================
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(here)

message("   Loading model and data for visualization...")
df_model_data <- readRDS(here("output", "df_model_data.rds"))
zinb_model4 <- readRDS(here("output", "zinb_model4.rds"))

message("   Generating updated expected count panel for Model 4 (Native glmmTMB engine)...")

# Creiamo un dataset di base con i valori medi/regolati delle altre variabili
base_grid <- df_model_data %>%
  summarise(
    gender = "M",                                           # Categoria di riferimento/più comune
    party_family = "Christian democrats and conservatives", # Categoria di riferimento/più comune
    libe = 0,                                               # Tipicamente binaria o fissa
    misery_index = mean(misery_index, na.rm = TRUE),
    discrimination_center = 0,                              # Centrata (0 = media)
    cmp_center = 0,                                         # Centrata (0 = media)
    total_questions = mean(total_questions, na.rm = TRUE)   # Fissiamo l'offset alla media dei dati originali
  )

# ------------------------------------------------------------------------------
# PANEL A: Expected Counts for Minority Status (From Model 4)
# ------------------------------------------------------------------------------
grid_a <- base_grid %>%
  slice(rep(1, 2)) %>%
  mutate(
    minority = c(0, 1),
    mipex_center = 0 # Fissato alla media
  )

# Predizione nativa glmmTMB (in link space, poi trasformata in response)
pred_a_raw <- predict(zinb_model4, newdata = grid_a, se.fit = TRUE, re.form = NA, type = "link")

pred_minority_m4 <- grid_a %>%
  mutate(
    estimate = exp(pred_a_raw$fit),
    conf.low = exp(pred_a_raw$fit - 1.96 * pred_a_raw$se.fit),
    conf.high = exp(pred_a_raw$fit + 1.96 * pred_a_raw$se.fit)
  )

panel_a_discrete <- ggplot(pred_minority_m4, aes(x = factor(minority, labels = c("Non-Minority", "Minority")), 
                                                 y = estimate, fill = factor(minority))) +
  geom_col(width = 0.4, alpha = 0.85, color = "black", linewidth = 0.6) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.1, linewidth = 0.9, color = "#2c3e50") +
  scale_fill_manual(values = c("#5a738e", "#e74c3c"), guide = "none") +
  labs(
    title = "A: Main Impact of MP Identity Status",
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

# CORREZIONE: Usiamo crossing() per evitare disallineamenti nell'accoppiamento dei vettori
grid_b <- base_grid %>%
  dplyr::select(-total_questions) %>% # Rimuoviamo temporaneamente per espandere le altre
  crossing(
    mipex_center = mipex_seq,
    minority = c(0, 1)
  ) %>%
  mutate(
    total_questions = mean(df_model_data$total_questions, na.rm = TRUE) # Ripristiniamo l'offset corretto per ogni riga
  )

# Predizione nativa glmmTMB
pred_b_raw <- predict(zinb_model4, newdata = grid_b, se.fit = TRUE, re.form = NA, type = "link")

pred_interaction <- grid_b %>%
  mutate(
    estimate = exp(pred_b_raw$fit),
    conf.low = exp(pred_b_raw$fit - 1.96 * pred_b_raw$se.fit),
    conf.high = exp(pred_b_raw$fit + 1.96 * pred_b_raw$se.fit)
  )

panel_b_interaction <- ggplot(pred_interaction, aes(x = mipex_center, y = estimate, 
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
    title = "Identity and Institutional Context in Legislative Activity",
    subtitle = "Model 4 Interaction Panel (Covariates fixed at reference levels/means)",
    theme = theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 13),
      plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d", size = 9.5)
    )
  )

# Mostra il grafico a schermo
print(stacked_panel)

# Esporta il file grafico pronto per il paper
ggsave(
  filename = here("output", "figures", "m4_interaction_magnitude_panel.png"), 
  plot = stacked_panel, 
  width = 7, height = 8.5, dpi = 300
)

message("   -> Model 4 interaction graphic successfully written to output folder.")