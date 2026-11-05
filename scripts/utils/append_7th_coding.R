#!/usr/bin/env Rscript
# =============================================================================
# append_7th_coding.R — Append del coding VII legislatura (2009-2014) al master
#
# Scopo: integrare nel master `data_raw/minority.csv` (colonne:
#   parliamentary_id, minority; 1.299 righe VIII/IX) la codifica a mano
#   della VII legislature (2009-2014):
#
#   1) data/minorities7th_coded_final.csv — 468 MEP VII codificati da Zeynep
#      (16 minority=1 / 452 = 0), prodotto da scripts/utils/convert_7th_coded_zm.py
#   2) data/minorities8th9th.csv — coding manuale VIII/IX; di questi 47, 3 NON
#      sono nel master (Orville 234344, Lavocat 251859, Lopez Gil 197777,
#      tutti minority=1): li si aggiunge per completezza
#
# L'append e' PURO (nessun upsert): per costruzione il roster VII contiene solo
# MEP attivi 2009-2014 assenti dal master (i rieletti VII->VIII/IX sono gia'
# nel master). Idempotente: gli ID gia' presenti nel master vengono saltati.
#
# NB: `data_raw/` e' un symlink a ~/progetti/euquest/data_raw (repo euquest,
# gitignored): il file master vive fuori da questa repo git.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

# --- Percorsi e lettura -------------------------------------------------------
master_path <- here("data_raw", "minority.csv")
vii_path    <- here("data", "minorities7th_coded_final.csv")
h89_path    <- here("data", "minorities8th9th.csv")

master <- read_csv(master_path, show_col_types = FALSE,
                   col_types = cols(parliamentary_id = col_double(),
                                    minority = col_double()))

stopifnot(
  "Master: colonne attese mancanti" = all(c("parliamentary_id", "minority") %in% names(master)),
  "Master: valori minority fuori da {0,1}" = all(master$minority %in% c(0, 1)),
  "Master: NA in minority" = !any(is.na(master$minority)),
  "Master: parliamentary_id duplicati nel master" = anyDuplicated(master$parliamentary_id) == 0
)

new_vii <- read_csv(vii_path, show_col_types = FALSE) |>
  select(parliamentary_id, minority)
new_h89 <- read_csv(h89_path, show_col_types = FALSE) |>
  select(parliamentary_id, minority)

stopifnot(
  "Overlap inatteso roster VII / hand-coded VIII-IX" =
    !any(new_vii$parliamentary_id %in% new_h89$parliamentary_id),
  "Valori minority fuori da {0,1} nel roster VII" =
    all(new_vii$minority %in% c(0, 1)),
  "Valori minority fuori da {0,1} nell'hand-coded VIII/IX" =
    all(new_h89$minority %in% c(0, 1)),
  "NA non ammessi in minority (nuovi dati)" =
    !any(is.na(new_vii$minority)) && !any(is.na(new_h89$minority))
)

new_ids <- bind_rows(new_vii, new_h89)
to_add  <- new_ids |> filter(!parliamentary_id %in% master$parliamentary_id)
skipped <- nrow(new_ids) - nrow(to_add)

if (nrow(to_add) == 0) {
  message("Master gia' aggiornato: 0 righe da appendere (no-op idempotente).")
  quit(save = "no", status = 0)
}

# --- Append e scrittura -------------------------------------------------------
master_new <- master |> bind_rows(to_add)

stopifnot(
  "Duplicati creati dall'append" = anyDuplicated(master_new$parliamentary_id) == 0
)

write_csv(master_new, master_path)

add_1 <- sum(to_add$minority == 1)
message(
  sprintf(
    "Append completato: +%d righe (%d dal roster VII, %d dal hand-coded VIII/IX) | minority=1 aggiunte: %d | master: %d -> %d righe (minority=1: %d -> %d)",
    nrow(to_add),
    sum(to_add$parliamentary_id %in% new_vii$parliamentary_id),
    sum(to_add$parliamentary_id %in% new_h89$parliamentary_id),
    add_1,
    nrow(master), nrow(master_new),
    sum(master$minority == 1), sum(master_new$minority == 1)
  )
)
if (skipped > 0) message(sprintf("ID gia' presenti nel master (saltati): %d", skipped))
