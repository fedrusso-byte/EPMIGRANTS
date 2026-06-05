# generates samples for coders to verify minor topics coded by llama
# This is the first, non-fine-tuned codings.
# I am now creating the samples so my students can verify the codings and we can then fine-tune the model
# the set includes all parliamentary questions from 1994 to 2024, so including those downloaded in 2025
# except 10k observations which had been dropped by the scraper
# I took those from the old set and fixed all the issues


# This is what the code does:
# Filters unique combinations of idOrig, major, and most_frequent_subtopic.
# Ensures all subtopics are represented: For each (major, most_frequent_subtopic) group, the script includes up to 10 observations, or all available if fewer than 10.
# Draws stratified samples: Divides the dataset into 5 student samples, each with:
#   
# - 1000 questions.
# - Representation from 5 majors (randomly selected for each student).
# - ~100 overlapping questions between any pair of students.

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(writexl)


# Read data
df <- read_csv("data/epq_minor_classified-llama_202502.csv")  # update path if needed

# Set seed for reproducibility
# set.seed(42) # seed for first set of sets
set.seed(123)

# Step 1: Keep unique idOrig / most_frequent_subtopic pairs
modal_unique <- df %>%
  distinct(idOrig, major, most_frequent_subtopic)

# Step 2: Take max 10 observations per (major, most_frequent_subtopic)
balanced_sample <- modal_unique %>%
  group_by(major, most_frequent_subtopic) %>%
  arrange(runif(n())) %>%        # shuffle within group
  slice_head(n = 10) %>%
  ungroup()

# Step 3: Add a column to track how often each idOrig appears
balanced_sample <- balanced_sample %>%
  group_by(idOrig) %>%
  mutate(obs_count = n()) %>%
  ungroup()

# Step 4: Define number of samples and overlap
n_students <- 5
obs_per_student <- 1000
overlap_per_pair <- 100

# Step 5: Get all possible overlaps
overlap_pool <- balanced_sample %>%
  slice_sample(n = overlap_per_pair * choose(n_students, 2)) %>%
  mutate(overlap_id = rep(1:choose(n_students, 2), each = overlap_per_pair))

# Helper: assign each overlap_id to a pair of students
student_pairs <- combn(n_students, 2, simplify = FALSE)

overlap_list <- map2_dfr(
  student_pairs,
  1:length(student_pairs),
  ~ overlap_pool %>%
    filter(overlap_id == .y) %>%
    mutate(student = list(c(.x[1], .x[2]))) %>%
    unnest(student)
)

# Step 6: Assign remaining unique IDs to students
remaining_ids <- anti_join(balanced_sample, overlap_pool, by = "idOrig")

# Split equally among students to reach 1000 each
student_samples <- vector("list", n_students)

for (i in 1:n_students) {
  n_overlap <- nrow(overlap_list %>% filter(student == i))
  n_remaining <- obs_per_student - n_overlap
  
  student_samples[[i]] <- remaining_ids %>%
    slice_sample(n = n_remaining) %>%
    mutate(student = i)
}

# Step 7: Combine and add columns
final_samples <- bind_rows(
  overlap_list %>% select(-overlap_id),
  bind_rows(student_samples)
) %>%
  distinct(student, idOrig, .keep_all = TRUE) %>%
  mutate(correct = NA_integer_,
         true = NA_integer_)

#### join with larger dataset to take the text field ####
# import "text" from larger dataset
df2 <- read_csv("data/epq_new.csv")  # load the dataset with the field text

# problem: in df2 there are 33 duplicates
# Count duplicates in df2
df2 %>%
  count(id) %>%
  filter(n > 1)
# > df2_text %>%
#   +   count(idOrig) %>%
#   +   filter(n > 1)
# A tibble: 23 × 2
# I will look more closely into that later. For now, with df2 I can just 
# keep only the first of each duplicate

# Step 1: Prepare df2 by renaming and selecting necessary columns
df2_text <- df2 %>%
  rename(idOrig = id) %>%
  select(idOrig, text) %>%
  distinct(idOrig, .keep_all = TRUE)  # safeguard: keep one row per idOrig

# check
# df2_text %>%
#   count(idOrig) %>%
#   filter(n > 1)
# ok!

# Join with the final student samples
final_samples <- final_samples %>%
  left_join(df2_text, by = "idOrig")

# Step 8: Split into separate dataframes and write if needed
student_sets <- final_samples %>%
  select(student, obs_count, idOrig, text, major, most_frequent_subtopic, correct, true) %>%
  group_split(student)

# Example: write each student's sample
# walk2(student_sets, 1:5, ~ write_csv(.x, paste0("data/student_", .y, "_sample.csv"))) # for first round
# walk2(student_sets, 1:5, ~ write_xlsx(.x, paste0("data/student_", .y, "_sample.xlsx"))) # for second round

walk2(student_sets, 6:10, ~ write_csv(.x, paste0("data/student_", .y, "_sample.csv")))
walk2(student_sets, 6:10, ~ write_xlsx(.x, paste0("data/student_", .y, "_sample.xlsx")))


############# checks ###############
# Show student pairs and their shared overlapping idOrig
overlap_pairs <- overlap_list %>%
  group_by(idOrig) %>%
  summarise(students = paste(sort(unique(student)), collapse = " & ")) %>%
  count(students, name = "n_shared_ids")

print(overlap_pairs)

# Show which ids are shared by a pair #
overlap_list %>%
  filter(student %in% c(2, 4)) %>%
  group_by(idOrig) %>%
  filter(n() == 2) %>%
  ungroup() %>%
  distinct(idOrig)

############ how many unique obs are verified in this way? ###
# Combine all student samples into one data frame
all_ids <- bind_rows(student_sets) %>% 
  select(idOrig)

# Count how many unique questions are assigned across all samples
n_unique_ids <- n_distinct(all_ids$idOrig)

# Compare to the total number of rows assigned (should be 5 * 1000)
n_total_ids <- nrow(all_ids)

# How many IDs appear more than once?
overlap_counts <- all_ids %>%
  count(idOrig) %>%
  filter(n > 1) %>%
  arrange(desc(n))

n_overlap_ids <- nrow(overlap_counts)

# Output the results
cat("🔢 Total assigned rows:       ", n_total_ids, "\n",
    "🔢 Unique idOrig values:     ", n_unique_ids, "\n",
    "🔁 Repeated idOrig values:   ", n_overlap_ids, "\n",
    "📊 Max number of times a question is repeated: ", max(overlap_counts$n), "\n")


### summarise subtopic coverage ###
# Combine all student samples into one data frame
all_samples <- bind_rows(student_sets)

# Count the number of unique subtopics and their frequency
subtopic_summary <- all_samples %>%
  count(most_frequent_subtopic, sort = TRUE) %>%
  rename(Frequency = n)

# Display the number of unique subtopics and the table
cat("🔢 Unique most_frequent_subtopics coded:", nrow(subtopic_summary), "\n")

# View the summary as a table
subtopic_summary
View(subtopic_summary)


#################### ACCURACY STATISTICS ########################

library(readxl)
library(dplyr)
library(purrr)

## for manual inspection
# stud_1 <- read_excel("output/student_1_sample.xlsx")
# stud_2 <- read_excel("output/student_2_sample.xlsx")
# stud_3 <- read_excel("output/student_3_sample.xlsx")
# stud_4 <- read_excel("output/student_4_sample.xlsx")
# stud_5 <- read_excel("output/student_5_sample.xlsx")


# Step 1: Helper to extract major from minor code
extract_major <- function(code) {
  code <- as.character(code)
  ifelse(nchar(code) == 3, substr(code, 1, 1),
         ifelse(nchar(code) == 4, substr(code, 1, 2), NA_character_))
}

# Step 2: Robust Excel reader
read_student_excel <- function(path) {
  df <- tryCatch(
    read_excel(path, skip = 0),
    error = function(e) {
      message("⚠️ Problem reading file: ", path)
      return(NULL)
    }
  )
  
  # Fallback: try skipping the first row
  if (is.null(df) || ncol(df) == 0 || nrow(df) == 0) {
    df <- tryCatch(
      read_excel(path, skip = 1),
      error = function(e) {
        message("❌ Still couldn't read: ", path)
        return(NULL)
      }
    )
  }
  
  return(df)
}

# Step 3: Truncation logic

read_and_truncate <- function(path) {
  df <- read_excel(path)
  
  # Convert types safely
  df$correct <- suppressWarnings(as.numeric(df$correct))
  df$true <- as.character(df$true)
  
  # Truncate to last verified row
  valid_rows <- which(df$correct == 1)
  if (length(valid_rows) == 0) return(NULL)
  
  df[1:max(valid_rows), ]
}


# Step 4: Read and combine all 5 files
file_paths <- paste0("data/student_", 1:8, "_checked.xlsx")
all_samples <- map_dfr(file_paths, read_and_truncate)

skipped <- file_paths[map_lgl(file_paths, ~ is.null(read_and_truncate(.x)))]
message("🔍 Skipped files (no valid `correct == 1`):\n", paste(skipped, collapse = "\n"))

# Map student ID to coder name
coder_map <- tibble(
  student = 1:8,
  coder = c(
    "Rosario Shari Rapisarda",  # 1
    "Claudia Federico",         # 2
    "Alessandro Motta",         # 3
    "Fabrizio Nicotra",         # 4
    "Giulia Di Salvo",          # 5
    "Alessandro Motta",         # 6
    "Rosario Shari Rapisarda",  # 7
    "Fabrizio Nicotra"          # 8
  )
)

all_samples <- all_samples %>%
  mutate(student = as.integer(student)) %>%
  left_join(coder_map, by = "student")


# Step 5: Compute true major and accuracy flags
accuracy_df <- all_samples %>%
  mutate(
    major = as.character(major),
    correct = as.numeric(correct),
    correct_flag = if_else(correct == 1, 1L, 0L, missing = 0L),  # treat NA or "" as incorrect
    true_clean = na_if(trimws(true), ""),
    true_clean = na_if(true_clean, "NA"),
    true_major = if_else(correct_flag == 0, extract_major(true_clean), NA_character_),
    major_correct = case_when(
      correct_flag == 1 ~ 1L,  # if minor is correct, major is assumed correct
      correct_flag == 0 & !is.na(true_major) & major == true_major ~ 1L,
      correct_flag == 0 & !is.na(true_major) ~ 0L,
      TRUE ~ NA_integer_
    )
  )



# Step 6: Accuracy by student
accuracy_by_coder <- accuracy_df %>%
  group_by(coder) %>%
  summarise(
    n = n(),
    minor_correct_n = sum(correct == 1, na.rm = TRUE),
    major_correct_n = sum(major_correct == 1, na.rm = TRUE),
    minor_accuracy = minor_correct_n / n,
    major_accuracy = major_correct_n / n,
    .groups = "drop"
  )

# Step 7: Average accuracy across students
avg_accuracy <- accuracy_by_coder %>%
  summarise(
    minor_accuracy_avg = mean(minor_accuracy, na.rm = TRUE),
    major_accuracy_avg = mean(major_accuracy, na.rm = TRUE)
  )

# Step 8: Display results
print(accuracy_by_coder)
print(avg_accuracy)

# View(accuracy_by_coder)

# Diagnostic Check
accuracy_df %>%
  summarise(
    total = n(),
    missing_true = sum(is.na(true)),
    usable_for_major = sum(!is.na(major_correct))
  )

table(accuracy_df$major == accuracy_df$true_major, useNA = "ifany")

#################### INTER-CODER RELIABILITY #########################

library(dplyr)
library(tidyr)
library(purrr)

# Step 1: Recode `correct` to binary and compute major_correct again
accuracy_df <- all_samples %>%
  mutate(
    correct = as.numeric(correct),
    correct_flag = if_else(correct == 1, 1L, 0L, missing = 0L),
    true_clean = na_if(trimws(true), ""),
    true_clean = na_if(true_clean, "NA"),
    major = as.character(major),
    true_major = if_else(correct_flag == 0, extract_major(true_clean), NA_character_),
    major_correct = case_when(
      correct_flag == 1 ~ 1L,
      correct_flag == 0 & !is.na(true_major) & major == true_major ~ 1L,
      correct_flag == 0 & !is.na(true_major) ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# Step 2: Keep only shared observations (same idOrig across multiple students)
shared_obs <- accuracy_df %>%
  group_by(idOrig) %>%
  filter(n() > 1) %>%
  select(idOrig, coder, correct_flag, major_correct, major)


# Step 3: Create all pairs of students for each shared idOrig
coder_pairs <- shared_obs %>%
  full_join(shared_obs, by = "idOrig", suffix = c("_a", "_b"), relationship = "many-to-many") %>%
  filter(coder_a < coder_b)


# Step 4: Compute agreement
agreement_by_pair <- coder_pairs %>%
  mutate(
    minor_agree = correct_flag_a == correct_flag_b,
    major_agree = major_correct_a == major_correct_b
  ) %>%
  group_by(coder_a, coder_b) %>%
  summarise(
    n_shared = n(),
    minor_agree_n = sum(minor_agree, na.rm = TRUE),
    major_agree_n = sum(major_agree, na.rm = TRUE),
    minor_agreement_rate = minor_agree_n / n_shared,
    major_agreement_rate = major_agree_n / n_shared,
    .groups = "drop"
  )

# Step 5: Print the table
print(agreement_by_pair)


# View(agreement_by_pair)

################ COMPARE AGREEMENT BY MAJOR ######################

agreement_by_major_topic <- coder_pairs %>%
  mutate(
    major_topic = major_a,  # codice assegnato da coder_a
    minor_agree = correct_flag_a == correct_flag_b,
    major_agree = major_correct_a == major_correct_b
  ) %>%
  group_by(major_topic, coder_a, coder_b) %>%
  summarise(
    n_shared = n(),
    minor_agree_n = sum(minor_agree, na.rm = TRUE),
    major_agree_n = sum(major_agree, na.rm = TRUE),
    minor_agreement_rate = minor_agree_n / n_shared,
    major_agreement_rate = major_agree_n / n_shared,
    .groups = "drop"
  )


View(agreement_by_major_topic)

## summary agreement by major

summary_by_major <- agreement_by_major_topic %>%
  group_by(major_topic) %>%
  summarise(
    avg_minor_agreement = mean(minor_agreement_rate, na.rm = TRUE),
    avg_major_agreement = mean(major_agreement_rate, na.rm = TRUE),
    n_pairs = n()
  ) %>%
  arrange(desc(avg_major_agreement))

View(summary_by_major)

# filter out nas from agreements
agreement_by_major_topic <- agreement_by_major_topic %>%
  filter(!is.na(major_topic))

# filter out small joint sets
agreement_by_major_topic_filtered <- agreement_by_major_topic %>%
  filter(n_shared >= 5)

# aggregate over all pairs

summary_by_major <- agreement_by_major_topic %>%
                           group_by(major_topic) %>%
                           summarise(
                             total_shared = sum(n_shared),
                             avg_minor_agreement = weighted.mean(minor_agreement_rate, n_shared),
                             avg_major_agreement = weighted.mean(major_agreement_rate, n_shared)
                           )
                         

######################### HEATMAP OF INTER-CODER REL ######################

library(dplyr)
library(tidyr)
library(ggplot2)

# Step 1: Prepare binary `correct_flag` and `major_correct`
accuracy_df <- all_samples %>%
  mutate(
    correct_flag = if_else(as.numeric(correct) == 1, 1L, 0L, missing = 0L),
    major = as.character(major),
    true_clean = na_if(trimws(true), ""),
    true_clean = na_if(true_clean, "NA"),
    true_major = if_else(correct_flag == 0, extract_major(true_clean), NA_character_),
    major_correct = case_when(
      correct_flag == 1 ~ 1L,
      correct_flag == 0 & !is.na(true_major) & major == true_major ~ 1L,
      correct_flag == 0 & !is.na(true_major) ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# Step 2: Keep only shared observations
shared_obs <- accuracy_df %>%
  group_by(idOrig) %>%
  filter(n() > 1) %>%
  select(idOrig, coder, correct_flag, major_correct)

# Step 3: Expand into all student pairs per idOrig
coder_pairs <- shared_obs %>%
  full_join(shared_obs, by = "idOrig", suffix = c("_a", "_b"), relationship = "many-to-many") %>%
  filter(coder_a < coder_b)

# Step 4: Compute agreement matrix (use minor_agree or major_agree)
agreement_matrix <- coder_pairs %>%
  mutate(
    agree = major_correct_a == major_correct_b  # for minor: use correct_flag_a == correct_flag_b
  ) %>%
  group_by(coder_a, coder_b) %>%
  summarise(
    n_shared = n(),
    n_agree = sum(agree, na.rm = TRUE),
    agreement_rate = n_agree / n_shared,
    .groups = "drop"
  )

# Step 5: Complete the matrix (symmetrical, including lower triangle)
symmetric_matrix <- agreement_matrix %>%
  bind_rows(
    agreement_matrix %>%
      rename(coder_a = coder_b, coder_b = coder_a)
  ) %>%
  complete(coder_a, coder_b)  # fill in all combinations

# Step 6: Plot as heatmap
ggplot(symmetric_matrix, aes(x = factor(coder_a), y = factor(coder_b), fill = agreement_rate)) +
  geom_tile(color = "white") +
  geom_text(aes(label = scales::percent(agreement_rate, accuracy = 1)), na.rm = TRUE, size = 4) +
  scale_fill_gradient(low = "white", high = "steelblue", na.value = "grey90") +
  labs(
    title = "Pairwise Agreement on Major Topic Correctness",
    x = "Student A",
    y = "Student B",
    fill = "Agreement Rate"
  ) +
  theme_minimal() +
  coord_fixed()

# Agreement by major topic and couple of coders

agreement_by_major_topic <- coder_pairs %>%
  mutate(
    major_topic = major_a,  # codice major assegnato da coder a
    minor_agree = correct_flag_a == correct_flag_b,
    major_agree = major_correct_a == major_correct_b
  ) %>%
  group_by(major_topic, coder_a, coder_b) %>%
  summarise(
    n_shared = n(),
    minor_agree_n = sum(minor_agree, na.rm = TRUE),
    major_agree_n = sum(major_agree, na.rm = TRUE),
    minor_agreement_rate = minor_agree_n / n_shared,
    major_agreement_rate = major_agree_n / n_shared,
    .groups = "drop"
  )


# Precision, Recall, F1 per ogni coppia di coder

# Per ogni coppia (coder_a, coder_b), calcoliamo:
#   
#   Precision = % di casi classificati correttamente da coder_a tra quelli classificati positivamente da coder_a
# 
# Recall = % di casi classificati correttamente da coder_a tra quelli classificati positivamente da coder_b
# 
# F1 = 2 * (Precision * Recall) / (Precision + Recall)
# 
# Questo presuppone che il coder_b sia il "gold standard", e che confrontiamo quanto coder_a si avvicina.

f1_metrics <- coder_pairs %>%
  mutate(
    minor_tp = correct_flag_a == 1 & correct_flag_b == 1,
    minor_fp = correct_flag_a == 1 & correct_flag_b == 0,
    minor_fn = correct_flag_a == 0 & correct_flag_b == 1,
    
    major_tp = major_correct_a == 1 & major_correct_b == 1,
    major_fp = major_correct_a == 1 & major_correct_b == 0,
    major_fn = major_correct_a == 0 & major_correct_b == 1
  ) %>%
  group_by(coder_a, coder_b) %>%
  summarise(
    # Minor
    minor_tp = sum(minor_tp, na.rm = TRUE),
    minor_fp = sum(minor_fp, na.rm = TRUE),
    minor_fn = sum(minor_fn, na.rm = TRUE),
    
    minor_precision = minor_tp / (minor_tp + minor_fp),
    minor_recall = minor_tp / (minor_tp + minor_fn),
    minor_f1 = 2 * minor_precision * minor_recall / (minor_precision + minor_recall),
    
    # Major
    major_tp = sum(major_tp, na.rm = TRUE),
    major_fp = sum(major_fp, na.rm = TRUE),
    major_fn = sum(major_fn, na.rm = TRUE),
    
    major_precision = major_tp / (major_tp + major_fp),
    major_recall = major_tp / (major_tp + major_fn),
    major_f1 = 2 * major_precision * major_recall / (major_precision + major_recall),
    
    .groups = "drop"
  )

# Print them all
f1_metrics %>%
  select(coder_a, coder_b,
         minor_precision, minor_recall, minor_f1,
         major_precision, major_recall, major_f1) %>%
  arrange(desc(minor_f1))

### heatmap average accuracy per major topic

# Step 1: Clean major codes (in case there are leading/trailing spaces)
accuracy_df <- accuracy_df %>%
  mutate(major_topic = trimws(major))

# Step 2: Calculate accuracy per major topic
accuracy_by_topic <- accuracy_df %>%
  filter(!is.na(major_correct)) %>%
  group_by(major_topic) %>%
  summarise(
    n = n(),
    major_accuracy = mean(major_correct, na.rm = TRUE),
    .groups = "drop"
  )

ggplot(accuracy_by_topic, aes(x = reorder(major_topic, major_accuracy), y = major_accuracy, fill = major_accuracy)) +
  geom_col(color = "black") +
  coord_flip() +
  scale_fill_gradient(low = "red", high = "green") +
  labs(
    title = "Average Major Accuracy by Topic",
    x = "Major Topic",
    y = "Accuracy",
    fill = "Accuracy"
  ) +
  theme_minimal(base_size = 14)

### heatmap average accuracy per minor topic
### In practice: minor accuracy per major
# 1. Compute average minor accuracy per topic
# We assume that the assigned topic is in the major column
# and that the correctness of the minor code is in correct_flag (1 = correct, 0 = incorrect).
# Step 1: Ensure clean topic codes
accuracy_df <- accuracy_df %>%
  mutate(major_topic = trimws(major))

# Step 2: Calculate minor accuracy per topic
minor_accuracy_by_topic <- accuracy_df %>%
  filter(!is.na(correct_flag)) %>%
  group_by(major_topic) %>%
  summarise(
    n = n(),
    minor_accuracy = mean(correct_flag, na.rm = TRUE),
    .groups = "drop"
  )

# Plot
ggplot(minor_accuracy_by_topic, aes(x = reorder(major_topic, minor_accuracy), y = minor_accuracy, fill = minor_accuracy)) +
  geom_col(color = "black") +
  coord_flip() +
  scale_fill_gradient(low = "red", high = "green") +
  labs(
    title = "Average Minor Accuracy by Topic",
    x = "Major Topic",
    y = "Minor Accuracy",
    fill = "Accuracy"
  ) +
  theme_minimal(base_size = 14) + geom_text(aes(label = sprintf("%.2f", minor_accuracy)), 
                                            hjust = -0.1, size = 4, color = "black")


### similar but different,
### average of minor-level accuracy grouped by major
# Accuracy per minor topic (e.g., 101, 102, 103, etc.):
#   
#   Accuracy = share of times each minor code was correctly assigned when it was used
# 
# Group these minor codes by their corresponding major topic (e.g., 1, 2, 3, etc.)
# 
# Compute the average accuracy across minors for each major
# Step 1: Compute accuracy per minor topic
minor_accuracy <- accuracy_df %>%
  filter(!is.na(correct_flag)) %>%
  group_by(minor = most_frequent_subtopic) %>%
  summarise(
    n = n(),
    correct_n = sum(correct_flag == 1),
    minor_accuracy = correct_n / n,
    .groups = "drop"
  ) %>%
  mutate(minor = as.character(minor))

# Step 2: Add major from minor using extract_major()
minor_accuracy <- minor_accuracy %>%
  mutate(major = extract_major(minor))

# Step 3: Group by major and compute average of minor-level accuracy
avg_minor_accuracy_by_major <- minor_accuracy %>%
  group_by(major) %>%
  summarise(
    n_minors = n(),
    avg_minor_accuracy = mean(minor_accuracy, na.rm = TRUE),
    .groups = "drop"
  )

# Step 4: Show results
print(avg_minor_accuracy_by_major)

# Plot: Average of minor-level accuracy per major topic
ggplot(avg_minor_accuracy_by_major, aes(x = reorder(major, avg_minor_accuracy), y = avg_minor_accuracy, fill = avg_minor_accuracy)) +
  geom_col(color = "black") +
  coord_flip() +
  scale_fill_gradient(low = "red", high = "green") +
  labs(
    title = "Average Minor Accuracy by Major Topic",
    x = "Major Topic",
    y = "Average Accuracy",
    fill = "Accuracy"
  ) +
  theme_minimal(base_size = 14) + geom_text(aes(label = sprintf("%.2f", avg_minor_accuracy)), 
                                            hjust = -0.1, size = 4, color = "black")















































