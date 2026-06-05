# ==============================================================================
# check_face_validity.R — Verifica coerenza Misery Index
# ==============================================================================

library(tidyverse)
library(here)

# Caricamento
df <- read_csv(here("output", "problem_indicators.csv"))

# Definizione paesi e aggiunta della riga EU
target_countries <- c("IT", "NL", "DE", "GR", "ES", "GR") # GR è diventato GR nel file finale

df_plot <- df %>%
  filter(country %in% target_countries | country == "EU") %>%
  filter(!is.na(misery_index))

# Grafico con Media UE evidenziata
ggplot(df_plot, aes(x = year, y = misery_index, color = country, group = country)) +
  # Linea per i paesi
  geom_line(data = filter(df_plot, country != "EU"), size = 1, alpha = 0.7) +
  # Linea speciale per la Media UE (nera e tratteggiata)
  geom_line(data = filter(df_plot, country == "EU"),
            color = "black", linetype = "dashed", size = 1.5) +
  geom_point(size = 2) +
  annotate("text", x = max(df_plot$year), y = last(df_plot$misery_index[df_plot$country=="EU"]),
           label = "Media UE", vjust = -1, fontface = "bold") +
  theme_minimal() +
  labs(
    title = "Misery Index: Confronto Paesi vs Media UE",
    subtitle = "Formula: Unemployment + Bond Yield - GDP Growth",
    caption = "La linea tratteggiata nera rappresenta il benchmark europeo.",
    x = "Anno", y = "Indice", color = "Paese"
  ) +
  scale_color_brewer(palette = "Set1") +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
