# ==============================================================================
# FREQUENTIST MIRROR PANEL: expected counts by minority status and by MIPEX
# context, from the glmmTMB M1_total twin of Bayesian M1_total (mirror of
# 06_model_comparison_Bayesian.R — remediation of audit item 2, 2026-11-18).
# ==============================================================================
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(here)

# set.seed for uniformity with 06B (audit item 5, 2026-11-18); the glmmTMB
# panel is computed deterministically, so this has no practical effect.
set.seed(20260321)

message("   Loading model and data for visualization...")
df_model_data <- readRDS(here("output", "df_model_data.rds"))
zinb_model_m1_total <- readRDS(here("output", "zinb_model_m1_total.rds"))

message("   Generating expected count panel (glmmTMB engine, response-scale ZINB mean)...")

# Creiamo un dataset di base con i valori medi/regolati delle altre variabili.
# ATTENZIONE: M1_total esclude libe (total-effect estimand) -> colonna omessa.
base_grid <- df_model_data %>%
  summarise(
    gender = "M",                                           # Categoria di riferimento/più comune
    party_family = "Christian democrats and conservatives", # Categoria di riferimento/più comune
    misery_index = mean(misery_index, na.rm = TRUE),
    total_questions = mean(total_questions, na.rm = TRUE)   # Fissiamo l'offset alla media dei dati originali
  )

# ------------------------------------------------------------------------------
# Response-scale ZINB mean with delta-method CI:
#   E[Y] = mu * (1 - p_zero). On the log scale,
#   log E[Y] = log(mu) + log(1 - p_zero), and
#   d log(1 - p_zero)/d zlink = -p_zero, hence
#   SE(log E[Y]) = sqrt(se_mu^2 + (p_zero * se_zlink)^2).
# Audit fix: the former exp(predict(type = "link")) band ignored the
# zero-inflation component and mislabelled a conditional log-mu quantity as
# an expected count (06 used it with the y-label "Expected Mean Question
# Count"). This mirrors the Bayesian posterior-mean treatment in 06B.
zinb_logmean_se <- function(model, newdata) {
  pred_mu <- predict(model, newdata = newdata, se.fit = TRUE, re.form = NA, type = "link")
  mu <- exp(pred_mu$fit)
  pred_zi <- predict(model, newdata = newdata, se.fit = TRUE, re.form = NA, type = "zlink")
  p_zero <- plogis(pred_zi$fit)
  list(
    log_mean = log(mu) + log(1 - p_zero),
    se_log = sqrt(pred_mu$se.fit^2 + (p_zero * pred_zi$se.fit)^2)
  )
}

# ------------------------------------------------------------------------------
# PANEL A: Expected Counts for Minority Status (From Model 4)
# ------------------------------------------------------------------------------
grid_a <- base_grid %>%
  slice(rep(1, 2)) %>%
  mutate(
    minority = c(0, 1),
    mipex_center = 0 # Fissato alla media
  )

# Expected counts on the response scale (ZINB mean incl. zero inflation)
pred_a <- zinb_logmean_se(zinb_model_m1_total, grid_a)

pred_minority_m1 <- grid_a %>%
  mutate(
    estimate = exp(pred_a$log_mean),
    conf.low = exp(pred_a$log_mean - 1.96 * pred_a$se_log),
    conf.high = exp(pred_a$log_mean + 1.96 * pred_a$se_log)
  )

panel_a_discrete <- ggplot(pred_minority_m1, aes(x = factor(minority, labels = c("Non-Minority", "Minority")), 
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

# Expected counts on the response scale (ZINB mean incl. zero inflation)
pred_b <- zinb_logmean_se(zinb_model_m1_total, grid_b)

pred_interaction <- grid_b %>%
  mutate(
    estimate = exp(pred_b$log_mean),
    conf.low = exp(pred_b$log_mean - 1.96 * pred_b$se_log),
    conf.high = exp(pred_b$log_mean + 1.96 * pred_b$se_log)
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
    subtitle = "Frequentist mirror (M1_total): ZINB response mean = mu x (1 - excess-zero prob); covariates at reference means, RE integrated out",
    theme = theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 13),
      plot.subtitle = element_text(hjust = 0.5, color = "#7f8c8d", size = 9.5)
    )
  )

# Mostra il grafico a schermo
print(stacked_panel)

# Esporta il file grafico pronto per il paper
ggsave(
  filename = here("output", "figures", "freq_interaction_magnitude_panel.png"), 
  plot = stacked_panel, 
  width = 7, height = 8.5, dpi = 300
)

message("   -> Frequentist mirror interaction graphic successfully written to output folder.")