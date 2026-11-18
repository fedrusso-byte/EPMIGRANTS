#!/usr/bin/env Rscript
# =============================================================================
# build_dv201_review_batches.R — Pacchetti di review DV (CAP-201) per FR
#
# Scopo: generare i quattro fogli di lavoro di validazione del DV (CAP-201)
# del piano approvato il 2026-11-13. File scritti in data/, colonna
# FR_decision vuota da riempire a mano.
#
#   1) dv201_batchA_exclusions_tocode.csv   — le domande in-finestra (VII-IX,
#      2009-07-14..2024-06-15) codificate CAP-201 ma ESCLUSE dal filtro
#      (regex + rescue di scripts/01_import_questions.R). Bandiere:
#      PENDING-audit (le 6 righe "▲ borderline" di Appendix A + il caso
#      Kosovo di §4.3, mai singolarmente valutate), CHECK-european
#      (soggetto con indizi europei; da sguardo rapido), TRIVIAL (extra-EU
#      ovvie, escluse dai nuovi chiavi-paese, non mai passate in review
#      ma valutabili a colpo d'occhio).
#   2) dv201_batchB_fncandidates_tocode.csv — possibili FALSI NEGATIVI:
#      domande in-finestra NON tenute il cui soggetto contiene un termine
#      forte di discriminazione *e* un marker di minoranza (censimento,
#      non campione).
#   3) dv201_precision_sample_tocode.csv    — campione stratificato n=120
#      delle domande TENUTE (stima di precisione; CI di Wilson +-ca. 5pp).
#   4) dv201_probe_sample_tocode.csv        — campione n=60 delle domande
#      NON tenute SENZE termine forte (stima di FNs invisibili al lexicon).
#
# Lexicon di validazione (provisorio, definito QUI e non nel pipeline):
#   strong = discrimin|racis|racial|xenophob|hate speech|hatred
#   marker = roma|sinti|gypsy|traveller|minori*|ethnic|islam|muslim|
#            jew*|migr*|immigr|asylum|refugee|foreigner|expat
# Soggetti soltanto: il body testo resta in data_raw/epq_3.0.csv per una
# eventuale seconda passata dopo il primo giro FR.
#
# Riproducibilita': pattern del filtro ripresi via parse() da
# scripts/01_import_questions.R (fonte unica, verbatim); seed 20261113.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

# --- Pattern verbatim da 01 (fonte unica) ------------------------------------
code01 <- parse(here("scripts", "01_import_questions.R"))
get_assign <- function(exprs, nm) {
  nm_rows <- vapply(exprs, function(e)
    if (is.call(e) && identical(e[[1]], quote(`<-`)) && is.symbol(e[[2]])) {
      as.character(e[[2]])
    } else "", character(1))
  eval(exprs[[which(nm_rows == nm)]], envir = new.env(parent = baseenv()))
}
cap201_exclusion_pattern <- get_assign(code01, "cap201_exclusion_pattern")
cap201_rescue_ids        <- get_assign(code01, "cap201_rescue_ids")
stopifnot(
  "Pattern 01 non riconosciuto" = startsWith(cap201_exclusion_pattern, "(?i)christian"),
  "Rescue list non e' 7" = length(cap201_rescue_ids) == 7
)

# --- Lexicon di validazione ---------------------------------------------------
strong_pattern <- "(?i)discrimin|racis|racial|xenophob|hate speech|hatred"
marker_pattern <- paste0("(?i)\\broma\\b|\\bsinti\\b|gypsy|traveller|minori",
  "|\\bethnic\\b|islam|muslim|\\bjew|\\bmigr|immigr|asylum|refugee",
  "|\\bforeigner\\b|expat")

# sanity: il leggendario trap "Tirana" non deve matchare \\biran\\b
stopifnot(!str_detect("Pupils of the Greek minority in Tirana",
                       regex("\\biran\\b|iranians?")))

# --- Data load ----------------------------------------------------------------
epq <- readRDS(here("data_processed", "epq.rds")) |>
  mutate(date = as.Date(date)) |>
  filter(date >= as.Date("2009-07-14"), date <= as.Date("2024-06-15")) |>
  mutate(
    term = case_when(
      date <  as.Date("2014-07-01") ~ "VII",
      date <  as.Date("2019-07-01") ~ "VIII",
      TRUE ~ "IX"),
    subtopic = as.character(subtopic),
    id = as.character(id)
  )
stopifnot(
  "In-window kept DV deve essere 1,290 (invariante 2026-11-06)" =
    sum(epq$pq_discrimination == 1 & epq$subtopic == "201") == 1290
)

kept    <- epq |> filter(pq_discrimination == 1, subtopic == "201")
nonkept <- epq |> filter(!(pq_discrimination == 1 & subtopic == "201"))

# --- 1) Batch A: esclusioni in-finestra --------------------------------------
# segmenti della regex 01 replicati singolarmente per l'attribuzione
keys <- c(
  christian = "christian", africa = "\\bafrica\\b", palestin = "palestin",
  ww2 = "Second World War", hamas = "\\bhamas\\b", danube = "danube",
  turkey = "turkey", turkish = "turkish", istanbul = "istanbul",
  india = "\\bindia\\b", china = "china", chinese = "chinese",
  usa = "\\busa\\b", asia = "\\basia\\b", israel = "israel",
  iran = "\\biran\\b|iranians?", syria = "syria", middle_east = "middle east",
  native = "\\bnative\\b", pakistan = "pakistan", tibet = "tibet",
  uighur = "uighur|uyghur", vietnam = "vietnam", guatemala = "guatemala",
  myanmar = "burma|myanmar", rwanda = "rwanda", congo = "congo",
  cambodia = "cambodia", afghan = "afghan", egypt = "egypt", iraq = "iraq",
  jerusalem = "jerusalem", brazil = "brazil", kashmir = "kashmir",
  nepal = "nepal", coptic = "coptic", ahmadi = "ahmadi", karen = "\\bkaren\\b",
  degar = "degar", lausanne = "lausanne"
)

euro_check_pattern <- paste0(
  "(?i)kosovo|\\bserb|serbia|croatia|bosnia|swabian|albania|montenegro|macedonia",
  "|moldova|switzerland|ukraine|belarus|russia|\\bsloveni|\\bslovak",
  "|\\bEU\\b|European Union|Europe|western societies")

pending_subject_prefixes <- c(
  "Extradition of Turkish trade unionist Gulaferit Unsal",
  "Justice for persons affected by Turkish policies",
  "App by means of which EU residents can be reported to the Turkish police",
  "European report on Islamophobia drafted by a Turkish research centre",
  "Turkish Cypriot peace activists are not a threat to Turkish national security",
  "Human genome research projects in Europe conducted by companies linked to",
  "Protection by the EU of the Christian Serb minority in Kosovo")

batchA <- nonkept |>
  filter(subtopic == "201") |>
  mutate(
    matched_keys = apply(
      sapply(keys, function(k) str_detect(subject, regex(k))), 1,
      function(r) paste(names(keys)[r], collapse = ";")),
    flag = case_when(
      str_detect(subject, regex(paste0("^", pending_subject_prefixes, collapse = "|"))) ~ "PENDING-audit",
      str_detect(subject, regex(euro_check_pattern)) ~ "CHECK-european",
      TRUE ~ "TRIVIAL")
  ) |>
  select(id, date, term, subject, matched_keys, flag) |>
  arrange(flag, date) |>
  mutate(FR_decision = "", FR_notes = "")

# --- 2) Batch B: candidati falsi negativi (strong x marker) -------------------
batchB <- nonkept |>
  mutate(
    strong_hit = str_detect(subject, regex(strong_pattern)),
    marker_hit = str_detect(subject, regex(marker_pattern))) |>
  filter(strong_hit, marker_hit) |>
  mutate(
    eu_hint = str_detect(subject, regex(euro_check_pattern)),
    is_excluded_201 = subtopic == "201") |>
  select(id, date, term, subject, subtopic, strong_hit, marker_hit,
         eu_hint, is_excluded_201) |>
  arrange(desc(is_excluded_201), desc(eu_hint), date) |>
  mutate(FR_decision = "", FR_notes = "")

# --- 3) Campione di precisione (n=120, stratificato per term) -----------------
set.seed(20261113)
target <- 120L
tc <- kept |> count(term)
n_stratum <- pmin(tc$n, round(target * tc$n / sum(tc$n)))
names(n_stratum) <- tc$term
delta <- target - sum(n_stratum)
if (delta > 0) n_stratum[which.max(tc$n)] <- n_stratum[which.max(tc$n)] + delta
if (delta < 0) n_stratum[which.min(n_stratum)] <- n_stratum[which.min(n_stratum)] + delta

precision_sample <- kept |>
  group_split(term) |>
  lapply(function(g) slice_sample(g, n = unname(n_stratum[as.character(unique(g$term))]))) |>
  list_rbind() |>
  select(id, date, term, subject, subtopic) |>
  arrange(term, date) |>
  mutate(on_scope = "", FR_notes = "")

# --- 4) Campione proiezione (n=60, non-kept senza lexicon) --------------------
probe_sample <- nonkept |>
  filter(!str_detect(subject, regex(strong_pattern))) |>
  slice_sample(n = 60) |>
  select(id, date, term, subject, subtopic) |>
  arrange(date) |>
  mutate(on_scope = "", FR_notes = "")

# --- Write e sintesi -----------------------------------------------------------
# Output guard (2026-11-13): after FR's hand-coding, these four files carry
# manual verdicts. Refuse to overwrite an existing coded file unless the
# environment variable DV201_OVERWRITE=1 is set explicitly.
stopifnot(
  "Batch A non e' 161" = nrow(batchA) == 161,
  "Campione precisione non e' 120" = nrow(precision_sample) == target,
  "Campione proiezione non e' 60" = nrow(probe_sample) == 60
)
write_guarded <- function(df, path) {
  if (file.exists(path) && !identical(Sys.getenv("DV201_OVERWRITE"), "1")) {
    stop(
      "Refusing to overwrite coded file: ", path,
      "\n  It contains FR's manual codings (DV-201 validation). To regenerate\n",
      "  the to-code sheets you would erase them — set DV201_OVERWRITE=1 only\n",
      "  if that is really intended."
    )
  }
  write_csv(df, path)
}
write_guarded(batchA,           here("data", "dv201_batchA_exclusions_tocode.csv"))
write_guarded(batchB,           here("data", "dv201_batchB_fncandidates_tocode.csv"))
write_guarded(precision_sample, here("data", "dv201_precision_sample_tocode.csv"))
write_guarded(probe_sample,     here("data", "dv201_probe_sample_tocode.csv"))

message("Batch A: ", nrow(batchA), " esclusioni in-finestra | flag: ",
        paste(names(table(batchA$flag)), table(batchA$flag), sep = "=", collapse = " "))
message("Batch B: ", nrow(batchB), " candidati FN strong x marker | per term: ",
        paste(names(table(batchB$term)), table(batchB$term), sep = "=", collapse = " "),
        " | excluded-201: ", sum(batchB$is_excluded_201), " | eu_hint: ", sum(batchB$eu_hint))
message("Precision sample: ", nrow(precision_sample), " | per term: ",
        paste(names(table(precision_sample$term)), table(precision_sample$term), sep = "=", collapse = " "))
message("Probe sample: ", nrow(probe_sample))
