
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

# Check duplicates in df2
df %>%
  count(id) %>%
  filter(n > 1)
# 22 duplicates. Let's remove them

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

epq <- epq %>%
  mutate(
    pq_discrimination = if_else(
      # Non-201 rows always get 0; a 201 row is kept (1) iff it sits in the
      # rescue allowlist or its subject matches none of the exclusion keys.
      # NA-safe guards preserve the original case_when semantics:
      # NA subtopic -> 0; a 201 row with NA subject -> 0 (not kept).
      !is.na(subtopic) & subtopic == "201" &
        (id %in% cap201_rescue_ids |
           (!is.na(subject) & !str_detect(subject, cap201_exclusion_pattern))),
      1, 0
    )
  )

stopifnot(
  "Rescue ids must exist in epq$id" = all(cap201_rescue_ids %in% epq$id),
  "pq_discrimination must contain no NA" = !any(is.na(epq$pq_discrimination)),
  "pq_discrimination must be 0/1" = all(epq$pq_discrimination %in% c(0, 1)),
  "CAP-201 kept count in window VII-IX drifted from the 2026-11-06 projection (expected 1,290 on the raw date range; the audit's term coding gives 1,285 because 5 questions dated 2019-07-01 fall between the VIII and IX term-coding windows)" =
    nrow(filter(epq, pq_discrimination == 1, as.character(subtopic) == "201",
                as.Date(date) >= as.Date("2009-07-14"),
                as.Date(date) <= as.Date("2024-06-15"))) == 1290
)


message("  Writing ", nrow(epq), " questions to data_processed/")
write_csv(epq, here("data_processed", "epq.csv"))
write_rds(epq, here("data_processed", "epq.rds"))

# Step 2: Remove intermediate df to free memory
rm(df)