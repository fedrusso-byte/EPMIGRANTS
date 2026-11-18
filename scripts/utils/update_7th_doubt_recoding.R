#!/usr/bin/env Rscript
# =============================================================================
# update_7th_doubt_recoding.R — Upsert FR dei 30 casi doubt (VII legislatura)
#
# Scopo: applicare al master `data_raw/minority.csv` (colonne:
#   parliamentary_id, minority) la decisione FR sui 30 casi `doubt_case=1`
#   codificati in data/minorities7th_coding_sources.csv.
#
#   1) data/minorities7th_doubt_recoding_FR.csv — coding FR (2026-11-13):
#      solo Anna Ibrisagic (28125) passa a minority=1 (rifugiata bosniaca in
#      Svezia: migrant di prima generazione da Paese europeo extra-UE, sotto
#      il criterio L421 del ms); gli altri 29 restano minority=0 (confermati).
#
# Upsert (non append): i 30 ID sono tutti gia' presenti nel master. Idempotente:
# i 29 confermati a 0 sono no-op (il master li ha gia' a 0); 28125 passa 0 -> 1
# solo alla prima esecuzione.
#
# NB: `data_raw/` e' un symlink (repo euquest, gitignored): il file master
# vive fuori da questa repo git. Backup del 2026-11-13: data_raw/minority_backup_2026-11-13.csv
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

# --- Percorsi e lettura -------------------------------------------------------
master_path  <- here("data_raw", "minority.csv")
recod_path   <- here("data", "minorities7th_doubt_recoding_FR.csv")

master <- read_csv(master_path, show_col_types = FALSE,
                   col_types = cols(parliamentary_id = col_double(),
                                    minority = col_double()))

recod <- read_csv(recod_path, show_col_types = FALSE) |>
  select(parliamentary_id, name, minority_FR)

stopifnot(
  "Master: colonne attese mancanti" = all(c("parliamentary_id", "minority") %in% names(master)),
  "Master: valori minority fuori da {0,1}" = all(master$minority %in% c(0, 1)),
  "Master: NA in minority" = !any(is.na(master$minority)),
  "Master: parliamentary_id duplicati nel master" = anyDuplicated(master$parliamentary_id) == 0,
  "Sidecar FR: deve contenere esattamente i 30 casi doubt" = all(c(30L == nrow(recod),
    anyDuplicated(recod$parliamentary_id) == 0,
    all(recod$minority_FR %in% c(0, 1)),
    !any(is.na(recod$minority_FR)),
    all(recod$parliamentary_id %in% master$parliamentary_id))),
  "Sidecar FR: esattamente un minority_FR=1 atteso (Ibrisagic)" = sum(recod$minority_FR == 1) == 1L
)

# Idempotenza: il sidecar puo' solo confermare un valore gia' applicato
# (equality) o fare un upgrade 0 -> 1; mai un downgrade 1 -> 0.
cur  <- master |> filter(parliamentary_id %in% recod$parliamentary_id) |>
  arrange(parliamentary_id) |> pull(minority)
des  <- recod |> arrange(parliamentary_id) |> pull(minority_FR)
stopifnot(
  "Il solo flip FR non e' 28125 (Ibrisagic)" = recod |> filter(minority_FR == 1) |>
    pull(parliamentary_id) == 28125L,
  "Sidecar incompatibile col master attuale (downgrade 1->0 proibito)" = all(cur <= des)
)

# --- Upsert -------------------------------------------------------------------
n_before <- sum(master$minority == 1)
master_new <- master |>
  rows_update(recod |> select(parliamentary_id, minority = minority_FR),
              by = "parliamentary_id")

# invarianti post-upsert
stopifnot(
  "Duplicati creati dall'upsert" = anyDuplicated(master_new$parliamentary_id) == 0,
  "Valori minority fuori da {0,1} post-upsert" = all(master_new$minority %in% c(0, 1)),
  "NA in minority post-upsert" = !any(is.na(master_new$minority)),
  "L'upsert deve toccare solo i 30 ID sidecar" =
    all(master_new |> anti_join(recod, by = "parliamentary_id") |>
          select(parliamentary_id, minority) |>
          anti_join(master, by = c("parliamentary_id", "minority")) |>
          nrow() == 0)
)

write_csv(master_new, master_path)

changed <- master |>
  left_join(master_new |> rename(minority_new = minority), by = "parliamentary_id") |>
  filter(minority != minority_new)

n_after <- sum(master_new$minority == 1)
message(sprintf(
  "Upsert completato: %d righe modificate (%s) | master minority=1: %d -> %d",
  nrow(changed),
  paste0(changed$parliamentary_id, ":", changed$minority, "->", changed$minority_new, collapse = " "),
  n_before, n_after
))
