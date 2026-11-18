
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(writexl)
library(here)
library(stringr) 

dir.create(here("data_processed"), showWarnings = FALSE, recursive = TRUE)

# import questions

message("  Loading LLaMA classifications...")
df <- read_csv(here("data_raw", "epq_minor_classified-llama_202502.csv"))
stopifnot("LLaMA classification file is empty" = nrow(df) > 0)

# Step 1: Keep unique idOrig / most_frequent_subtopic pairs
df <- df %>%
  distinct(idOrig, major, most_frequent_subtopic) %>%
  rename(subtopic = most_frequent_subtopic,
         id = idOrig)

# remove duplicates keeping the first one of each
df <- df %>%
  distinct(id, .keep_all = TRUE)  # safeguard: keep one row per idOrig

#### join with larger dataset to take the text field ####
# import "text" from larger dataset
message("  Loading EPQ raw data...")
epq <- read_csv(here("data_raw", "epq_3.0.csv"))
stopifnot("EPQ raw file is empty" = nrow(epq) > 0)

# Check duplicates in epq
# epq %>%
#   count(id) %>%
#   filter(n > 1)
# ok, no duplicates!

# Step 1: Prepare epq by renaming and selecting necessary columns
epq <- epq %>%
  select(-"stuff", -"original_language", -"pdf_doc", -"word_doc", -"text", -"msr_s", -"date_approximated",)

epq <- epq %>%
  left_join(df %>% select(id, major, subtopic), by = "id")
stopifnot(
  "Join produced empty result" = nrow(epq) > 0,
  "All major codes are NA after join" = !all(is.na(epq$major))
)

# =============================================================================
# CAP-201 dictionary filter for pq_discrimination (fixed 2026-11-06, Phase 1)
# =============================================================================
# pq_discrimination = 1 for written questions classified under CAP minor topic
# "201" (Ethnic Minority and Racial Group Discrimination) that the keyword
# filter does NOT exclude. The filter applies to the question `subject` (title)
# only — never to the body text, which would additionally drop 371 on-scope
# questions (audit §6.3: e.g. titles whose body mentions "Second World War" or
# "American"). Subjects excluded:
#   1. extra-European contexts (non-EU countries/regions/peoples, including
#      EU-relevant *origin* countries via their nationality adjectives);
#   2. religion-only frames (Christian minorities) with no ethnic/racial
#      discrimination dimension subject to EU anti-discrimination rules;
#   3. historical/other anchors that in CAP-201 titles only flag off-scope
#      material (Second World War, Danube).
#
# Regex history:
#   - Pre-2026-11-06: unbounded keyword stems + a misleading comment (claimed
#     the filter ran on `text`) + 8 inert right-wing keys (patriot, woke,
#     quotas, ...). Root causes of both error types: substring traps
#     ("refusal", "thousands", "Asian", "Tirana") and missing keywords
#     (chinese, turkish, pakistan, tibet, uighur, egypt, iraq).
#     Audit: quality_reports/2026-11-06_CAP201-dictionary-audit.md
#   - This fix (audit §9 "Phase 1 regex", verbatim): word boundaries on the
#     substring-trap stems; new country/nationality keywords; `iran` fixed as
#     \biran\b|iranians? ("Tirana" trap); `america` and the 7 right-wing keys
#     dropped (0 subject hits). Impact (window VII-IX, 2009-2024): 1,323 kept
#     → 1,281; +49 clean extra-EU exclusions, +7 genuine re-inclusions.
#
# DV-201 validation (2026-11-13): FR hand-coded two review batches drawn from
# the non-kept frame (161 regex-excluded subtopic-201 rows + 55 strong-marker
# FN candidates across all CAP subtopics) and a 120-row precision sample of
# kept rows. Disposition: 29 questions are force-kept via id allowlist
# (`cap201_force_keep_ids` below — 28 sit OUTSIDE subtopic 201, so the
# force-keep must bypass the subtopic gate too); 28 of them come from batch B
# and 1 (E-002519/2021) from batch A. Audit trail:
#   data/dv201_validation_decisions_FR.csv  (216 explicit decisions; built by
#   scripts/utils/update_dv201_decisions.R)
#   Readout: quality_reports/2026-11-13_dv201-validation-and-final-models.md
# Validated kept counts (window VII-IX, 2009-07-14..2024-06-15): 1,319 total
# (608 / 482 / 229 per term), of which 1,291 subtopic-201.
cap201_exclusion_pattern <- paste0("(?i)christian|\\bafrica\\b|palestin|Second World War|",
  "\\bhamas\\b|danube|turkey|turkish|istanbul|\\bindia\\b|china|chinese|\\busa\\b|\\basia\\b|israel|\\biran\\b|iranians?|syria|middle east|\\bnative\\b|",
  "pakistan|tibet|uighur|uyghur|vietnam|guatemala|burma|myanmar|rwanda|congo|cambodia|afghan|egypt|iraq|jerusalem|brazil|kashmir|nepal|coptic|ahmadi|\\bkaren\\b|degar|lausanne")

# Option-B rescue allowlist: the 7 audit Appendix-A "⚠ FALSE (EU-relevant)"
# questions that the new regex wrongly excludes are re-included by question id.
# These subjects describe EU-relevant minority situations (the Greek-based
# Turkish minority, Turkish-language policy in EU institutions/Greece, EU
# citizens) and were verified against epq$id on 2026-11-06 (MEPs affected:
# 2335, 1934, 28576 pre-VII — no window effect; 4555 VII; 96750, 124873,
# 24942 VIII). The 6 in-window "▲ borderline" rows and the Kosovo 2011
# "christian" case stay excluded, pending Phase 2 (LLM re-validation).
cap201_rescue_ids <- c(
  "E-0636/2000",   # 2000-02-03: Repopulation of northern regions in Greece (Macedonian & Turkish minorities) — Greece
  "P-1626/2005",   # 2005-04-25: Access to EPSO competitions by Turkish Cypriot nationals — EU citizens
  "P-2304/2006",   # 2006-05-16: Illegal abduction of Pakistani citizens in Greece — Greece
  "E-004683/2012", # 2012-08-05: Turkish as an official language of the European Parliament — EU institutional language policy
  "E-003234/2014", # 2014-07-01: Rights of the Turkish minority in Western Thrace, Greece
  "E-005109/2016", # 2016-06-24: Risk of Turkish becoming an official EU language — EU institutional language policy
  "E-006385/2018"  # 2018-12-19: Education through the medium of Turkish in Greece
)

# DV-201 validation force-keeps (2026-11-13): the 29 questions FR's hand-code
# classified as genuinely on-scope DV questions despite falling outside the
# CAP-201 kept gates. These BYPASS BOTH the `subtopic == "201"` gate and the
# exclusion-regex gate (28 of the 29 sit outside subtopic 201; 1 is a
# subtopic-201 row killed by the exclusion regex). Coding rules behind the
# verdicts are documented in the 2026-11-13 readout memo.
cap201_force_keep_ids <- c(
  # --- batch A rescue (subtopic 201, regex-killed): IX
  "E-002519/2021",  # Islamophobia report drafted by Turkish-linked research centre — the `turkey|turkish` key hit is spurious here
  # --- batch B FN candidates (strong-marker, non-201 subtopics): VII
  "E-0311/2010",    # discrimination against undocumented immigrants in Vic
  "E-005644/2011",  # migrant workers: discrimination and exclusion
  "E-005645/2011",  # migrant workers: discrimination and exclusion
  "E-001571/2011",  # multiple discrimination against recognisable ethnic groups
  "E-009417/2011",  # racist attacks on asylum seekers in Greece
  "E-012197/2011",  # discrimination against members of minority groups
  "E-000201/2013",  # racist article on Roma by a founder member of Fidesz
  "P-004581/2012",  # delayed FRA annual report on discrimination against Roma
  "E-002966/2012",  # assisted voluntary return for EU citizens: ethnic discrimination (Italy)
  "E-002967/2012",  # assisted voluntary return for EU citizens: freedom to move (Italy)
  "E-000782/2013",  # anti-discrimination legislation as EU access requirement
  # --- VIII
  "E-006662/2014",  # right to healthcare denied to immigrants; institutional racism
  "P-012116/2015",  # discriminatory intentions re relocation of migrants (Slovakia)
  "E-005788/2015",  # ESF implementation: discrimination against migrants and homeless
  "E-004907/2015",  # multi-faith dialogue on discrimination against Jews and Muslims
  "E-016119/2015",  # discrimination against refugees
  "E-005932/2017",  # EU-MIDIS I: Muslims — selected findings
  "E-007949/2017",  # EU-MIDIS II: Muslims — selected findings
  "E-002788/2018",  # Russian-speaking minority in Latvia (EU citizen minority)
  "E-001703/2018",  # minorities & anti-discrimination decision compliance
  "E-003602/2016",  # bullying involving discrimination against minorities
  # --- IX
  "P-004037/2019",  # discrimination by ethnic/cultural background
  "E-003943/2020",  # combating discrimination against Roma in the EU
  "E-007067/2020",  # police discrimination of migrants, Valencia
  "P-000972/2022",  # racial profiling of refugees at EU-Ukraine borders
  "E-001218/2022",  # inadmissible discrimination by EU/national governments against refugees
  "E-002910/2023",  # police discrimination of migrants, Valencia II
  "P-002311/2023"   # funds for the combating anti-Muslim hatred position
)

epq <- epq %>%
  mutate(
    pq_discrimination = if_else(
      # Force-keep allowlist first: FR-validated INs bypass BOTH the
      # `subtopic == "201"` gate and the exclusion-regex gate. Otherwise the
      # 2026-11-06 rule applies unchanged; NA-safe guards preserve the
      # original case_when semantics: NA subtopic -> 0; a 201 row with NA
      # subject -> 0 (not kept).
      id %in% cap201_force_keep_ids |
        (!is.na(subtopic) & subtopic == "201" &
           (id %in% cap201_rescue_ids |
              (!is.na(subject) & !str_detect(subject, cap201_exclusion_pattern)))),
      1, 0
    )
  )

# Derived term coding (2026-11-13 validation check; matches the coding that
# produced the 2026-11-06 projection: questions dated 2019-07-01 land in IX
# here, whereas the audit's alternative term coding leaves them between
# windows — the reason the audit's standalone total is 5 lower): helper
# column only, removed before epq is written out.
epq$term_check <- with(epq, if_else(
  as.Date(date) <= as.Date("2014-06-30"), "VII",
  if_else(as.Date(date) <= as.Date("2019-06-30"), "VIII", "IX")
))
kept_win <- epq$pq_discrimination == 1 & !is.na(epq$date) &
  as.Date(epq$date) >= as.Date("2009-07-14") &
  as.Date(epq$date) <= as.Date("2024-06-15")
per_term_kept <- table(epq$term_check[kept_win])

stopifnot(
  "Rescue ids must exist in epq$id" = all(cap201_rescue_ids %in% epq$id),
  "Force-keep ids must exist in epq$id" = all(cap201_force_keep_ids %in% epq$id),
  "pq_discrimination must contain no NA" = !any(is.na(epq$pq_discrimination)),
  "pq_discrimination must be 0/1" = all(epq$pq_discrimination %in% c(0, 1)),
  "Subtopic-201 kept in window VII-IX must be 1,291 = 1,290 (2026-11-06 projection, raw date range) + 1 batch-A force-keep (E-002519/2021)" =
    sum(kept_win & epq$subtopic == "201", na.rm = TRUE) == 1291,
  "Total kept in window VII-IX must be 1,319 = 1,290 + 29 force-keeps (DV-201 validation disposition, 2026-11-13)" =
    sum(kept_win) == 1319,
  "In-window 2019-07-01 edge case must hold (5 subtopic-201 kept rows dated 2019-07-01)" =
    sum(kept_win & as.Date(epq$date) == as.Date("2019-07-01"), na.rm = TRUE) == 5,
  "Kept per term must be 608 / 482 / 229 (VII / VIII / IX)" =
    all(per_term_kept[c("VII", "VIII", "IX")] == c(608L, 482L, 229L)),
  "All 29 force-keeps must be kept and in-window" =
    all(epq$pq_discrimination[epq$id %in% cap201_force_keep_ids] == 1) &&
    sum(kept_win & epq$id %in% cap201_force_keep_ids) == 29
)
epq$term_check <- NULL
rm(kept_win, per_term_kept)


message("  Writing ", nrow(epq), " questions to data_processed/")
write_csv(epq, here("data_processed", "epq.csv"))
write_rds(epq, here("data_processed", "epq.rds"))

# Step 2: Remove intermediate df to free memory
rm(df)