#07_Exploratory analysis

library(dplyr)

# Assuming df_merged_3 is your data frame
df_merged_3 <- df_merged_3 %>%
  mutate(proportion_subtopic_201 = n_subtopic_201 / total_questions) %>%
  filter(!is.na(proportion_subtopic_201)) # Remove rows where proportion is NA (e.g., when total_questions = 0)

# Calculate the proportion of questions asked on subtopic 201 by legislative_term
proportion_by_legislative_term <- df_merged_3 %>%
  group_by(legislative_term) %>%
  summarise(
    total_subtopic_201_questions = sum(n_subtopic_201),
    total_questions = sum(total_questions),
    proportion_subtopic_201 = total_subtopic_201_questions / total_questions
  )
# View the result

print(proportion_by_legislative_term)

#HOW MANY MEPS ASKED QUESTIONS ON SUBTOPIC 201 IN EACH LEGISLATIVE TERM?

  # Assuming df_merged_3 is your data frame and it has columns mep_id and legislative_term
df_merged_4 <- df_merged_3 %>%
  filter(n_subtopic_201 > 0) # Filter to include only rows where n_subtopic_201 > 0

# Count the number of unique MEPs in each legislative term
meps_by_legislative_term <- df_merged_4 %>%
  group_by(legislative_term) %>%
  summarise(
    num_meeps_with_questions = n_distinct(mep_id)
  )

# View the result
print(meps_by_legislative_term)

