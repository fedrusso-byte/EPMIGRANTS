
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

# Create a dummy variable with value 1 when variable "subtopic" is 1 and at the same time the variable "text" does not contain the terms "christian" OR "Africa"


epq <- epq %>%
  mutate(
    pq_discrimination = case_when(
      # Condizione: subtopic è "201" E il testo NON contiene termini relativi a:
      # 1. Contesti extra-europei (Africa, Asia, Medio Oriente, etc.)
      # 2. Narrative di "discriminazione inversa" o critica alle politiche di anti-discriminazione (tipiche della destra)
      # 3. Temi religiosi specifici o conflitti storici/attuali non legati alla discriminazione etnica interna UE
      subtopic == "201" & !str_detect(subject, pattern = "(?i)christian|africa|palestin|Second World War|hamas|danube|turkey|istanbul|india|china|usa|america|asia|israel|iran|syria|middle east|native|patriot|political correctness|woke|reverse discrimination|traditional values|gender ideology|quotas") ~ 1,
      
      # In tutti gli altri casi, assegna 0
      TRUE ~ 0
    )
  )


message("  Writing ", nrow(epq), " questions to data_processed/")
write_csv(epq, here("data_processed", "epq.csv"))
write_rds(epq, here("data_processed", "epq.rds"))


message("  Writing ", nrow(epq), " questions to data_processed/")
write_csv(epq, here("data_processed", "epq.csv"))
write_rds(epq, here("data_processed", "epq.rds"))

# Step 2: Remove intermediate df to free memory
rm(df)