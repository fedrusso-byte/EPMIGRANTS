# -----------------------------------------------------------------------------
# minority_coding_worksheet_6th7th.R
# -----------------------------------------------------------------------------
# Purpose:
#   Build the hand-coding research worksheets for the minority-background
#   variable (MEPs with a migrant/minority background) for the 6th (2004-2009)
#   and 7th (2009-2014) legislative terms of the European Parliament.
#
# Context:
#   `data_raw/minority.csv` currently codes only MEPs who served in the 8th/9th
#   terms (44 minority = 1, 1255 minority = 0). MEPs who served only in the
#   6th/7th terms have no coding at all (not even 0). To extend the analysis
#   back to at least the 7th term, every uncoded MEP active in those terms
#   must be hand-researched.
#
# What the script does:
#   1. Loads `data/meps.csv`, `data_raw/minority.csv`, `data/meps_com_gr.csv`.
#   2. Selects MEPs active in the 6th/7th terms who are absent from
#      `minority.csv`.
#   3. Attaches basic biographical data (gender, birth year/place, country,
#      national party during the term) plus the party group and the committee
#      held for the longest time during the term.
#   4. Quality-controls `national_party_in_term`: a block of 6th-term MEPs
#      (parliamentary_id ~28380-29100) carries a mis-aligned `national_parties`
#      column in `meps.csv` (e.g. Polish MEPs with Greek party histories), so
#      values whose country tags contradict the MEP's nationality are dropped
#      (set to NA) to avoid misleading the coders. Upstream fix is pending.
#   5. Adds empty `minority`, `notes`, `link` columns in the same format as the
#      hand-coded file `data/minorities8th9th.csv`, so the completed sheets can
#      be merged directly into the master coding file.
#   6. Writes, for each term:
#        data/minorities7th_tocode.csv  (468 MEPs, priority)
#        data/minorities6th_tocode.csv  (749 MEPs, optional)
#      plus an .xlsx twin of each (if `writexl` is installed) for convenient
#      manual editing.
#
# After the hand-coding is done:
#   - append the coded results to `data_raw/minority.csv`;
#   - widen the term filter in `scripts/05_models_Bayesian.R` from
#     `c("8th", "9th")` to include `"7th"`.
#
# Run from the project root:
#   Rscript scripts/utils/minority_coding_worksheet_6th7th.R
# -----------------------------------------------------------------------------

library(dplyr)
library(readr)

# ---- 0. Load inputs and check they are as expected ---------------------------

stopifnot(
  file.exists("data/meps.csv"),
  file.exists("data_raw/minority.csv"),
  file.exists("data/meps_com_gr.csv"),
  file.exists("data/minorities8th9th.csv")
)

meps        <- read_csv("data/meps.csv",             show_col_types = FALSE)
minority    <- read_csv("data_raw/minority.csv",     show_col_types = FALSE)
com_gr      <- read_csv("data/meps_com_gr.csv",      show_col_types = FALSE)
# `minorities8th9th.csv` is saved in Latin-1/Windows encoding (e.g. 0xD3 = Ó),
# so it must be read with that locale or accented names arrive as invalid bytes.
hand_coded  <- read_csv(
  "data/minorities8th9th.csv", show_col_types = FALSE,
  locale = locale(encoding = "latin1")
)

stopifnot(
  all(c("parliamentary_id", "mep_name", "gender", "birth_year", "birth_place",
        "nationalty", "national_parties", "2004_2009", "2009_2014") %in%
        names(meps)),
  all(c("parliamentary_id", "minority") %in% names(minority)),
  all(c("parliamentary_id", "legislative_term", "committee_most_time",
        "group_abbr") %in% names(com_gr))
)

# ---- 1. Term definitions ------------------------------------------------------

term_defs <- list(
  "7th" = list(
    term_col   = "2009_2014",
    active_col = "active_2009_2014",
    win_start  = as.Date("2009-07-14"),
    win_end    = as.Date("2014-06-30"),
    out_file   = "data/minorities7th_tocode.csv"
  ),
  "6th" = list(
    term_col   = "2004_2009",
    active_col = "active_2004_2009",
    win_start  = as.Date("2004-07-20"),
    win_end    = as.Date("2009-07-13"),
    out_file   = "data/minorities6th_tocode.csv"
  )
)

# Expected number of uncoded MEPs per term (verified on 2026-09-09);
# the hard check below catches silent upstream data changes.
expected_uncoded <- c("7th" = 468, "6th" = 749)

# ---- 2. Helper: extract party/group entries active in a date window -----------
# History strings in `meps.csv` look like:
#   "05-09-1991 / 18-07-1994 : Party (Country) 19-07-1994 / 19-07-1999 : ..."
# Each record is "start / end : label"; records are concatenated with a space.
# NB: implemented with gregexpr() + substr() because strsplit() with a
# zero-width perl lookahead silently shifts every split by one character.

extract_in_window <- function(history, win_start, win_end) {
  vapply(history, function(h) {
    if (is.na(h) || !nzchar(h)) return(NA_character_)
    hdr_re <- "(\\d{2}-\\d{2}-\\d{4}) / (\\d{2}-\\d{2}-\\d{4})\\s*:\\s*"
    gl <- gregexpr(hdr_re, h)
    pos <- gl[[1]]
    if (pos[1] == -1) return(NA_character_)
    g <- regmatches(h, gl)[[1]]   # the matched "start / end : " record headers
    n <- length(pos)
    hdr_end <- pos + attr(pos, "match.length") - 1L
    starts  <- as.Date(substr(g, 1L, 10L), format = "%d-%m-%Y")
    ends    <- as.Date(substr(g, 14L, 23L), format = "%d-%m-%Y")
    labels <- character(0)
    for (i in seq_len(n)) {
      if (is.na(starts[i]) || is.na(ends[i])) next
      if (ends[i] >= win_start && starts[i] <= win_end) {
        # label = text from the end of header i to the start of header i+1
        lab_to <- if (i < n) pos[i + 1L] - 1L else nchar(h)
        lab <- trimws(gsub("\\s+", " ", substr(h, hdr_end[i] + 1L, lab_to)))
        if (nzchar(lab)) labels <- c(labels, lab)
      }
    }
    if (length(labels) == 0L) NA_character_ else paste(labels, collapse = " | ")
  }, character(1), USE.NAMES = FALSE)
}

# TRUE for party strings whose country tags contradict the MEP's nationality
# (no "(Country)" tag matches `meps.csv`'s `nationalty` for that MEP). Used to
# neutralise the mis-aligned `national_parties` block described in the header.
is_suspect_party <- function(parties, ids, nat_lookup) {
  suspect <- rep(FALSE, length(parties))
  idx <- which(!is.na(parties) & nzchar(parties))
  if (length(idx) > 0) {
    suspect[idx] <- vapply(idx, function(j) {
      tags <- regmatches(parties[j], gregexpr("\\([^()]*\\)", parties[j]))[[1]]
      if (length(tags) == 0) return(FALSE)  # no tags: cannot verify, keep
      !any(gsub("[()]", "", tags) == nat_lookup[as.character(ids[j])])
    }, logical(1))
  }
  suspect
}

# ---- 3. Build the worksheets --------------------------------------------------

coded_ids  <- minority$parliamentary_id
nat_lookup <- setNames(meps$nationalty, meps$parliamentary_id)

meps <- meps %>%
  mutate(
    active_2004_2009 = !is.na(.data[["2004_2009"]]),
    active_2009_2014 = !is.na(.data[["2009_2014"]])
  )

build_worksheet <- function(term_label) {
  td <- term_defs[[term_label]]

  gr_term <- com_gr %>%
    filter(legislative_term == term_label) %>%
    group_by(parliamentary_id) %>%
    slice(1) %>%                    # guard against duplicated id-term rows
    ungroup() %>%
    select(parliamentary_id, group_abbr, committee_most_time)

  meps %>%
    filter(.data[[td$active_col]], !parliamentary_id %in% coded_ids) %>%
    mutate(
      country = if_else(nationalty == "Czech Republic", "Czechia", nationalty),
      national_party_in_term = extract_in_window(
        national_parties, td$win_start, td$win_end
      )
    ) %>%
    left_join(gr_term, by = "parliamentary_id") %>%
    mutate(
      party_suspect = is_suspect_party(
        national_party_in_term, parliamentary_id, nat_lookup
      ),
      national_party_in_term = if_else(
        party_suspect, NA_character_, national_party_in_term
      )
    ) %>%
    transmute(
      parliamentary_id,
      name                  = mep_name,
      country,
      gender,
      birth_year,
      birth_place,
      national_party_in_term,
      party_group_in_term   = group_abbr,
      committee_in_term     = committee_most_time,
      group_membership_raw   = .data[[td$term_col]],
      active_2004_2009,
      active_2009_2014,
      party_suspect,
      minority              = NA_integer_,
      notes                 = NA_character_,
      link                  = NA_character_
    ) %>%
    arrange(country, name)
}

for (term_label in c("7th", "6th")) {
  ws <- build_worksheet(term_label)
  td <- term_defs[[term_label]]
  n_suspect <- sum(ws$party_suspect)
  ws <- select(ws, -party_suspect)

  # ---- Consistency checks ----------------------------------------------------
  stopifnot(
    nrow(ws) == expected_uncoded[[term_label]],
    !any(duplicated(ws$parliamentary_id)),
    all(!ws$parliamentary_id %in% coded_ids),
    all(ws[[td$active_col]])
  )

  write_csv(ws, td$out_file)
  if (requireNamespace("writexl", quietly = TRUE)) {
    writexl::write_xlsx(ws, sub("\\.csv$", ".xlsx", td$out_file))
  }

  # ---- Console report --------------------------------------------------------
  cat("\n==== ", term_label, " term worksheet ====\n", sep = "")
  cat("File: ", td$out_file, " (", nrow(ws), " MEPs to code)\n", sep = "")
  cat("Missing party group: ", sum(is.na(ws$party_group_in_term)),
      " | missing national party: ", sum(is.na(ws$national_party_in_term)),
      " (of which ", n_suspect, " dropped as mis-aligned upstream)",
      " | missing birth place: ", sum(is.na(ws$birth_place)), "\n", sep = "")
  cat("Also active in the other early term: ",
      sum(term_label == "7th" & ws$active_2004_2009) +
        sum(term_label == "6th" & ws$active_2009_2014), "\n", sep = "")
  print(as.data.frame(table(ws$country)))
}

# ---- 4. Consistency check with the existing hand-coded file -------------------
# MEPs flagged by hand in `minorities8th9th.csv` must be present (and coded 1)
# in the master file `data_raw/minority.csv`.

# NB: `coded_ids` is used here (not `minority$parliamentary_id`) because
# `hand_coded` contains a column named `minority`, which would shadow the
# master coding table inside filter()'s data mask.
missing_in_master <- hand_coded %>%
  filter(!parliamentary_id %in% coded_ids) %>%
  select(name, parliamentary_id, country)

if (nrow(missing_in_master) > 0) {
  warning(
    "Hand-coded minority MEPs absent from data_raw/minority.csv: ",
    paste0(missing_in_master$name, " (", missing_in_master$parliamentary_id,
           ", ", missing_in_master$country, ")", collapse = "; "),
    call. = FALSE
  )
}

cat("\nDone. Worksheets written to data/minorities7th_tocode.csv and",
    " data/minorities6th_tocode.csv (+ .xlsx twins when writexl is available).")