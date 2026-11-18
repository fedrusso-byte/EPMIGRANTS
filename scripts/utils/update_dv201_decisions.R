# scripts/utils/update_dv201_decisions.R
# =============================================================================
# update_dv201_decisions.R (created 2026-11-13)
# Consolidates FR's completed hand-codings for the DV-201 precision validation
# into a single audit-trail file: data/dv201_validation_decisions_FR.csv
#
# Inputs (coded by FR on 2026-11-12/13):
#   data/dv201_batchA_exclusions_tocode.csv   (161 rows; blank = OUT)
#   data/dv201_batchB_fncandidates_tocode.csv (55 rows; explicit IN / OUT)
# Output:
#   data/dv201_validation_decisions_FR.csv    (216 rows = 29 IN + 187 OUT)
#
# Decision convention (FR, 2026-11-13): "IN" only where an explicit token is
# present; blanks in batch A are OUT by agreement (no implicit INs).
# Final locked expectations: IN = 29 (VII 11 / VIII 10 / IX 8), OUT = 187.
# Read-only consolidation — no downstream writes beyond the decisions CSV.
# =============================================================================
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

a <- read_csv(here("data", "dv201_batchA_exclusions_tocode.csv"),
              show_col_types = FALSE) |>
  mutate(source = "batchA_exclusions",
         decision = if_else(coalesce(trimws(FR_decision), "") == "IN", "IN", "OUT"))

b <- read_csv(here("data", "dv201_batchB_fncandidates_tocode.csv"),
              show_col_types = FALSE) |>
  mutate(source = "batchB_fn_candidates",
         decision = if_else(coalesce(trimws(FR_decision), "") == "IN", "IN", "OUT"))

# Token audits: batch A may contain only explicit "IN" tokens or blanks;
# batch B must be fully explicitly coded ("IN"/"OUT", no blanks).
stopifnot(
  "batch A: unexpected explicit tokens (blanks or IN only)" =
    all(coalesce(trimws(a$FR_decision), "") %in% c("", "IN")),
  "batch B: all rows must be explicitly coded IN/OUT" =
    all(coalesce(trimws(b$FR_decision), "") %in% c("IN", "OUT"))
)

decisions <- bind_rows(
  a |> select(id, date, term, subject, source, decision, FR_notes),
  b |> select(id, date, term, subject, source, decision, FR_notes)
) |>
  arrange(term, date, id) |>
  mutate(date = as.character(date))

stopifnot(
  "expected 216 decision rows" = nrow(decisions) == 216,
  "expected 29 IN" = sum(decisions$decision == "IN") == 29,
  "expected 187 OUT" = sum(decisions$decision == "OUT") == 187,
  "no id may carry conflicting decisions (2 ids — E-002177/2014, E-008266/2015 — appear in BOTH batches; both are OUT in both, so the 216-row bind is conflict-free)" =
    all(decisions |> group_by(id) |> summarise(nd = n_distinct(decision)) |> pull(nd) == 1),
  "exactly 2 duplicated ids expected across batches (E-002177/2014, E-008266/2015)" =
    sum(duplicated(decisions$id)) == 2
)

term_tab <- table(decisions$term, decisions$decision)
stopifnot(
  "IN per term must be 11 / 10 / 8 (VII / VIII / IX)" =
    all(term_tab[c("VII", "VIII", "IX"), "IN"] == c(11L, 10L, 8L))
)

path_out <- here("data", "dv201_validation_decisions_FR.csv")
write_csv(decisions, path_out)
message("Wrote ", nrow(decisions), " decision rows to ", path_out)
message("IN per term: VII=", term_tab["VII", "IN"], " VIII=", term_tab["VIII", "IN"],
        " IX=", term_tab["IX", "IN"])
message("Batch A blanks -> OUT: ", sum(coalesce(trimws(a$FR_decision), "") == ""),
        " of ", nrow(a))

# --- Soft cross-check vs the provisional-reads sidecar (audit only) -----------
# data/dv201_provisional_reads.csv held LLM-assisted provisional reads for part
# of batch B, including 5 flagged-blank rows that FR later resolved (4 OUT,
# 1 IN = E-003602/2016). The definitive record is FR's explicit token; this
# block only PRINTS the correspondence for the session log.
side_path <- here("data", "dv201_provisional_reads.csv")
if (file.exists(side_path)) {
  pv <- read_csv(side_path, show_col_types = FALSE)
  pv_ids <- intersect(pv$id, decisions$id)
  joined <- decisions |>
    filter(id %in% pv_ids) |>
    inner_join(pv |> select(id, any_of("provisional_read")), by = "id")
  message("Sidecar overlap with final decisions: ", nrow(joined),
          " rows (print-only check):")
  print(as.data.frame(joined |> select(id, provisional_read = any_of("provisional_read"), decision, FR_notes)),
        row.names = FALSE, max = 999)
} else {
  message("Sidecar dv201_provisional_reads.csv not found — skipping cross-check.")
}