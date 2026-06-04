# Add libraries and functions ####
library(tidyverse)
library(stringr)
library(lubridate)
library(here)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

rm(list = ls())

check_na <- function(dataset) {
  
  dataset %>% 
    dplyr::summarise_all(list(~sum(is.na(.)))) %>% 
    as.data.frame()
  
}

clean_names <- function(x) {
  x <- tolower(x)                         # tutto minuscolo
  x <- gsub("[^a-z ]", "", x)            # rimuove tutto tranne lettere e spazi
  x <- trimws(x)                         # rimuove spazi prima e dopo
  return(x)
}

# Assign EP legislative term from a date vector
assign_term <- function(date_col) {
  case_when(
    date_col >= ymd("1994-07-19") & date_col <= ymd("1999-07-19") ~ "4th",
    date_col >= ymd("1999-07-20") & date_col <= ymd("2004-07-19") ~ "5th",
    date_col >= ymd("2004-07-20") & date_col <= ymd("2009-07-13") ~ "6th",
    date_col >= ymd("2009-07-14") & date_col <= ymd("2014-06-30") ~ "7th",
    date_col >= ymd("2014-07-01") & date_col <= ymd("2019-07-01") ~ "8th",
    date_col >= ymd("2019-07-02") & date_col <= ymd("2024-07-15") ~ "9th",
    TRUE ~ NA_character_
  )
}

# Legislature start/end dates
legislature_starts <- tibble(
  legislative_term = c("4th", "5th", "6th", "7th", "8th", "9th"),
  term_start = ymd(c("1994-07-19", "1999-07-20", "2004-07-20", "2009-07-14", "2014-07-01", "2019-07-02")),
  term_end = ymd(c("1999-07-19", "2004-07-19", "2009-07-13", "2014-06-30", "2019-07-01", "2024-07-15"))
)

# Load the data ####

## Data on all meps ####
message("  Loading MEP data...")
all_meps <- read_csv(here("data_raw", "meps.csv")) |>
  select(
    parliamentary_id:president,
    contains(c("1994_1999","1999_2004","2004_2009","2009_2014","2014_2019","2019_2024")),
    mep_given_name:mep_name
  ) |>
  mutate(country_name = case_when(nationalty == "Czech Republic" ~ "Czechia", TRUE ~ nationalty)) |>
  select(-nationalty) |> 
  arrange(parliamentary_id) |> 
  mutate(political_groups = str_replace_all(political_groups, fixed("..."), "/ 15-07-2024")) |> 
  rename(p1994_1999 = "1994_1999",
         p1999_2004 = "1999_2004",
         p2004_2009 = "2004_2009",
         p2009_2014 = "2009_2014",
         p2014_2019 = "2014_2019",
         p2019_2024 = "2019_2024") |>
  filter(if_any(c(p1994_1999, p1999_2004, p2004_2009, p2009_2014, p2014_2019, p2019_2024), ~ !is.na(.)))
stopifnot("MEPs data is empty" = nrow(all_meps) > 0)

#political groups per legislature-year
groups <- all_meps |> 
  select(parliamentary_id, political_groups) |> 
  # Extract each record that looks like "DD-MM-YYYY / DD-MM-YYYY : some text"
  mutate(records = str_extract_all(
    political_groups,
    "\\d{2}-\\d{2}-\\d{4} / \\d{2}-\\d{2}-\\d{4} : .*?(?=\\d{2}-\\d{2}-\\d{4} /|$)"
  )) %>%
  unnest(records) %>%
  # Now split each record into start_date, end_date, and position
  separate(
    records,
    into = c("start", "end", "position"),
    sep = " / | : ",
    remove = TRUE,
    extra = "merge"
  ) |>
  mutate(start = as.Date(start, format = "%d-%m-%Y"),
         end = as.Date(end, format = "%d-%m-%Y")) |>
  filter(start  >= as.Date("1994-07-19")) |> 
  mutate(start = ymd(start)) |> 
  mutate(legislative_term = assign_term(start)) |>
  mutate(
    first_political_group = position |> 
      str_remove("^Confederal Group of the\\s+") |>
      str_remove("^Group of the\\s+") |>
      str_remove("^The\\s+") |> 
      str_remove("\\s+-\\s+Member.*$") |> 
      str_remove("\\s+Member.*$") |> 
      str_remove(regex("\\b(chair|vice-chair|observer|treasurer).*", ignore_case = TRUE)) |> 
      str_trim(),
    # Mappatura a sigle standard
    group_abbr = case_when(
      str_detect(first_political_group, regex("Group Union for Europe|Forza Europa Group|European People's Party", ignore_case = TRUE)) ~ "PPE",
      str_detect(first_political_group, regex("Progressive Alliance of Socialists and Democrats|Party of European Socialists|Socialist Group", ignore_case = TRUE)) ~ "S&D",
      str_detect(first_political_group, regex("European Radical Alliance|European Liberal, Democrat|Renew Europe|Alliance of Liberals and Democrats", ignore_case = TRUE)) ~ "RE",
      str_detect(first_political_group, regex("European Conservatives and Reformists", ignore_case = TRUE)) ~ "ECR",
      str_detect(first_political_group, regex("Identity and Democracy|Nations and Freedom|Europe of Nations|Identity, Tradition|Europe of freedom and democracy|Union for Europe of the Nations", ignore_case = TRUE)) ~ "ID",
      str_detect(first_political_group, regex("United Left|GUE|Nordic Green Left|The Left|Communist", ignore_case = TRUE)) ~ "GUE/NGL",
      str_detect(first_political_group, regex("Greens|European Free Alliance|Green Group|Rainbow Group", ignore_case = TRUE)) ~ "Greens/EFA",
      str_detect(first_political_group, regex("Group for a Europe of Democracies and Diversities|Freedom and Direct Democracy|Independence/Democracy|European Democratic Alliance|European Democratic Group", ignore_case = TRUE)) ~ "EFDD",
      str_detect(first_political_group, regex("Technical Group of Independent|Non-attached|Non attached", ignore_case = TRUE)) ~ "NI",
      TRUE ~ NA_character_
    ),
    party_family = case_when(
      str_detect(first_political_group, regex("Forza Europa Group|European People's Party|European Democratic Group", ignore_case = TRUE)) ~ "Christian democrats and conservatives",
      str_detect(first_political_group, regex("Progressive Alliance of Socialists and Democrats|Party of European Socialists|Socialist Group", ignore_case = TRUE)) ~ "Social democrats",
      str_detect(first_political_group, regex("European Radical Alliance|European Liberal, Democrat|Renew Europe|Alliance of Liberals and Democrats", ignore_case = TRUE)) ~ "Liberals",
      str_detect(first_political_group, regex("Group Union for Europe|European Conservatives and Reformists|Union for Europe of the Nations|European Democratic Alliance", ignore_case = TRUE)) ~ "Eurosceptic conservatives",
      str_detect(first_political_group, regex("Identity and Democracy|Nations and Freedom|Identity, Tradition", ignore_case = TRUE)) ~ "Right-wing nationalists",
      str_detect(first_political_group, regex("United Left|GUE|Nordic Green Left|The Left|Communist", ignore_case = TRUE)) ~ "Communists and socialists",
      str_detect(first_political_group, regex("Greens|European Free Alliance|Green Group|Rainbow Group", ignore_case = TRUE)) ~ "Greens/EFA",
      str_detect(first_political_group, regex("Group for a Europe of Democracies and Diversities|Freedom and Direct Democracy|Independence/Democracy|Europe of Nations|Europe of freedom and democracy", ignore_case = TRUE)) ~ "Eurosceptics",
      str_detect(first_political_group, regex("Technical Group of Independent|Non-attached|Non attached", ignore_case = TRUE)) ~ "NI",
      TRUE ~ NA_character_
    )
  )

# Committee memberships ####
committee <- all_meps |>
  select(parliamentary_id, member) |> 
  # Extract each record that looks like "DD-MM-YYYY / DD-MM-YYYY : some text"
  mutate(records = str_extract_all(
    member,
    "\\d{2}-\\d{2}-\\d{4} / \\d{2}-\\d{2}-\\d{4} : .*?(?=\\d{2}-\\d{2}-\\d{4} /|$)"
  )) %>%
  unnest(records) %>%
  # Now split each record into start_date, end_date, and position
  separate(
    records,
    into = c("start", "end", "position"),
    sep = " / | : ",
    remove = TRUE,
    extra = "merge"
  ) |>
  mutate(start = as.Date(start, format = "%d-%m-%Y"),
         end = as.Date(end, format = "%d-%m-%Y")) |>
  filter(start  >= as.Date("1994-07-19")) |> 
  mutate(start = ymd(start)) |> 
  mutate(legislative_term = assign_term(start)) %>%
# Filter using str_detect() to elimitate delegations and special/temporary/inquiry committees
  filter(str_detect(position, "Committee")) |> 
  filter(!str_detect(position, "Delegation")) |>
  filter(!str_detect(position, "Special Committee")) |>
  filter(!str_detect(position, "Temporary Committee")) |>
  filter(!str_detect(position, "Committee of Inquiry")) |>
  filter(!str_detect(position, "Conference of Committee Chairs")) |>
#aggregate committee
  mutate(
    committee_abbr = case_when(
      str_detect(position, regex("Agriculture|Fisheries", ignore_case = TRUE)) ~ "AGRI/PECH",
      str_detect(position, regex("Industry, External Trade, Research and Energy", ignore_case = TRUE)) ~ "ITRE/INTA",
      str_detect(position, regex("Environment, Public Health", ignore_case = TRUE)) ~ "ENVI/SANT",
      str_detect(position, regex("Regional Policy, Transport and Tourism", ignore_case = TRUE)) ~ "REGI/TRAN",
      str_detect(position, regex("Budget|Budgetary", ignore_case = TRUE)) ~ "BUDG",
      str_detect(position, regex("Home Affairs|Internal Affairs", ignore_case = TRUE)) ~ "LIBE",
      str_detect(position, regex("Constitutional Affairs|Institutional Affairs|Rules of Procedure", ignore_case = TRUE)) ~ "AFCO",
      str_detect(position, regex("Culture", ignore_case = TRUE)) ~ "CULT",
      str_detect(position, regex("Development", ignore_case = TRUE)) ~ "DEVE",
      str_detect(position, regex("Economic and Monetary Affairs", ignore_case = TRUE)) ~ "ECON",
      str_detect(position, regex("Employment", ignore_case = TRUE)) ~ "EMPL",
      str_detect(position, regex("External Economic Relations|International Trade", ignore_case = TRUE)) ~ "INTA",
      str_detect(position, regex("Foreign Affairs", ignore_case = TRUE)) ~ "AFET",
      str_detect(position, regex("Industry, Research and Energy|Research, Technological Development and Energy", ignore_case = TRUE)) ~ "ITRE",
      str_detect(position, regex("Legal Affairs", ignore_case = TRUE)) ~ "JURI",
      str_detect(position, regex("Petitions", ignore_case = TRUE)) ~ "PETI",
      str_detect(position, regex("Regional Development|Regional Policy", ignore_case = TRUE)) ~ "REGI",
      str_detect(position, regex("Internal Market", ignore_case = TRUE)) ~ "IMCO",
      str_detect(position, regex("Transport and Tourism", ignore_case = TRUE)) ~ "TRAN",
      str_detect(position, regex("Women", ignore_case = TRUE)) ~ "FEMM",
      TRUE ~ NA_character_
    )
  )

# Ensure dates are in Date format
committee$start <- as.Date(committee$start)
committee$end <- as.Date(committee$end)
legislature_starts$term_start <- as.Date(legislature_starts$term_start)
legislature_starts$term_end <- as.Date(legislature_starts$term_end)


# 2. Generate all MEP-legislature-legislative_year combinations
mep_legislature_combinations <- committee %>%
  distinct(parliamentary_id, legislative_term) %>%
  left_join(legislature_starts, by = "legislative_term")

mep_legislature_years_expanded <- mep_legislature_combinations %>%
  rowwise() %>%
  mutate(
    num_legislative_years = ceiling(as.numeric(difftime(term_end, term_start, units = "days")) / 365.25),
    legislative_year = list(seq_len(num_legislative_years))
  ) %>%
  unnest(legislative_year) %>%
  ungroup()

# 3. Calculate the start and end dates for each legislative_year
mep_legislature_years_with_dates <- mep_legislature_years_expanded %>%
  mutate(
    leg_year_start = term_start %m+% years(legislative_year - 1),
    leg_year_end = if_else(legislative_year < num_legislative_years,
                           term_start %m+% years(legislative_year) %m-% days(1),
                           term_end)
  )

# 4. Join with committee data and calculate overlap using lubridate intervals
processed_data <- mep_legislature_years_with_dates %>%
  left_join(committee, by = c("parliamentary_id", "legislative_term"), relationship = "many-to-many") %>%
  mutate(
    # Define the legislative year interval
    leg_year_interval = interval(leg_year_start, leg_year_end),
    # Define the committee membership interval
    committee_interval = interval(start, end),
    
    # Calculate the intersection of the two intervals
    # The intersection is an interval itself, or an empty interval if no overlap
    overlap_interval = intersect(leg_year_interval, committee_interval),
    
    # Get the length of the overlap interval in days.
    # If there's no overlap, duration(empty_interval) is 0.
    overlap_days = as.numeric(as.duration(overlap_interval), "days")
  ) %>%
  # Select only relevant columns for the next step and remove temporary interval columns
  select(-leg_year_interval, -committee_interval, -overlap_interval)

# 5. For each MEP-legislature-legislative_year, find the committee with the maximum overlap

final_data <- processed_data %>%
  group_by(parliamentary_id, legislative_term, legislative_year) %>%
  # Arrange by overlap_days in descending order
  arrange(desc(overlap_days), .by_group = TRUE) %>%
  # Slice the first row for each group (max overlap)
  slice(1) %>%
  ungroup() %>%
  select(parliamentary_id, legislative_term, legislative_year, committee_abbr, overlap_days) %>%
  rename(committee_most_time = committee_abbr)

# 6.Eliminate all data with legislative_year = 6 , create leg and rename parliamentary_id
final_data = final_data |>
  filter(legislative_year != 6) |>
  mutate(leg_year = paste0(legislative_term, legislative_year)) |>
  rename(mep_id = parliamentary_id)|>
  select(mep_id, leg_year, committee_most_time)

# Build MEP mandate panel ####
mandati <- groups |> 
  group_by(parliamentary_id, group_abbr, party_family, legislative_term) |> 
  summarise(
    mandate_start = min(start, na.rm = TRUE),
    mandate_end = max(end, na.rm = TRUE),
    .groups = "drop"
  )

# Expand mandates to yearly panel
mandati_expanded <- mandati |> 
  left_join(legislature_starts, by = "legislative_term") |> 
  mutate(
    years_served = interval(term_start, mandate_end) %/% years(1) + 1
  ) |> 
  ungroup() |> 
  mutate(year_index = map2(mandate_start, years_served, ~ seq(0, .y - 1))) |> 
  unnest(year_index) |> 
  mutate(
    year_start = term_start + years(year_index),
    year_end = pmin(term_start + years(year_index + 1) - days(1), mandate_end),
    days_served = as.integer(pmin(year_end, mandate_end) - pmax(year_start, mandate_start)) + 1
  ) |> 
  filter(days_served > 0) |> 
  select(parliamentary_id, group_abbr, party_family, legislative_term, year_index, year_start, year_end, days_served) |> 
  filter(year_index != 5) |> 
  mutate(leg_year = paste0(legislative_term, year_index + 1))

meps_expanded <-
  left_join(
  mandati_expanded,
  all_meps |>
  select(
    parliamentary_id:birth_place,
    political_groups,
    mep_given_name,
    mep_family_name,
    country_name),
  by = "parliamentary_id"
  ) |>
  rename( mep_id = parliamentary_id) |> 
  arrange(mep_id, leg_year) |> 
  group_by(mep_id, leg_year) |> # tolgo le osservazioni duplicate perché c'è stato un cambio di gruppo
  slice_max(order_by = days_served, n = 1, with_ties = FALSE) |> 
  mutate(year_parl = year(year_start)) |> 
  ungroup() 

rm(groups, mandati, mandati_expanded, all_meps)

# Join meps_expanded with final_data to get committee
meps_expanded = meps_expanded |>
  left_join(final_data, by= c("mep_id", "leg_year"))


## Data on questions ####
message("  Loading questions data...")
questions <- read_csv(here("data_processed", "epq.csv")) |>
  select(-url, -author_s, -party_s, -subject) |>
  filter(date >= as.Date("1994-07-19")) |> 
  filter(date <= as.Date("2024-06-08")) |> 
  mutate(
    issue_name = case_when(
      major == 1 ~ "Macroeconomics",
      major == 2 ~ "Civil Rights",
      major == 4 ~ "Agriculture",
      major == 5 ~ "Labor",
      major == 10 ~ "Transportation",
      major == 12 ~ "Law and Crime",
      major == 13 ~ "Social Welfare",
      major == 15 ~ "Domestic Commerce",
      major == 16 ~ "Defense",
      major == 17 ~ "Technology",
      major == 18 ~ "Foreign Trade",
      major == 19 ~ "International Affairs",
      major == 20 ~ "Government Operations",
      major == 6 ~ "Education",
      major == 8 ~ "Energy",
      major == 7 ~ "Environment",
      major == 3 ~ "Health",
      major == 14 ~ "Housing",
      major == 9 ~ "Immigration",
      TRUE ~ "Other"
  )) |> 
  mutate(legislative_term = assign_term(date)) |> 
  left_join(legislature_starts, by = "legislative_term") |> 
  mutate(
    year_index = floor(as.numeric(difftime(date, term_start, units = "days")) / 365.25) + 1) |> 
  select(-term_start, -term_end) |> 
  mutate(leg_year = paste0(legislative_term, year_index))

stopifnot(
  "Questions data is empty" = nrow(questions) > 0,
  "Expected 30 leg_years in questions" = n_distinct(questions$leg_year) == 30
)

# Aggregate the data on questions by mep_id
questions_df <- questions |> 
  group_by(mep_id, leg_year, issue_name) |> 
  summarise(
    n_questions = n()
  ) |> 
  group_by(mep_id, leg_year) |> 
  mutate(
    total_questions = sum(n_questions),
    perc_questions = round(n_questions / total_questions * 100, digits = 1)) |> 
  ungroup() |>
  group_by(mep_id, leg_year) |> 
  mutate(
    total_questions = sum(n_questions)) |> 
  ungroup()


# Merge data ####
message("  Constructing MEP-year-issue panel...")
issue_names <- questions_df |> 
  distinct(issue_name) 

df_merged_2 <- meps_expanded |> 
  cross_join(issue_names)

## merge questions data with meps data data using mep_id, leg_year, issue_name ####

df_merged_2 <- df_merged_2 |>
  left_join(questions_df, by = c("mep_id", "leg_year", "issue_name")) |>
  # fill NAs
  mutate(
    n_questions = replace_na(n_questions, 0),
    total_questions = replace_na(total_questions, 0),
    perc_questions = replace_na(perc_questions, 0),
    age = year_parl-birth_year,
    meps_age_cat = case_when(
      age < 40 ~ "age < 40",
      age >= 40 & age < 60 ~ "40-60",
      age >= 60 ~ "age > 60"
    ))

# Filter ####

## remove "Other" from policy areas ####
df_merged_2 <- df_merged_2 |> 
  filter(issue_name != "Other")

## remove UK meps from 9th ####
df_merged_2 <- df_merged_2 |> 
  filter(!(country_name == "United Kingdom" & legislative_term =="9th"))

## Create dummy when the issue corresponds with the committee
## NOTE: some double committees must still be integrated
df_merged_2 = df_merged_2 |>
  mutate(
    issue_name = as.character(issue_name)
  ) |>
  mutate(
    committee = case_when(
      (issue_name == "Macroeconomics" & committee_most_time %in% c("ECON", "FISC", "BUDG")) ~ 1,
      (issue_name == "Civil Rights" & committee_most_time %in% c("LIBE", "FEMM")) ~ 1,
      (issue_name == "Agriculture" & committee_most_time %in% c("AGRI", "AGRI/PECH")) ~ 1, 
      (issue_name == "Labor" & committee_most_time == "EMPL") ~ 1,
      (issue_name == "Transportation" & committee_most_time %in% c("TRAN", "REGI/TRAN")) ~ 1,
      (issue_name == "Law and Crime" & committee_most_time %in% c("LIBE", "JURI")) ~ 1,
      (issue_name == "Social Welfare" & committee_most_time %in% c("EMPL", "FEMM")) ~ 1, # Corrected EMPOL to EMPL based on common committee_most_time names
      (issue_name == "Domestic Commerce" & committee_most_time == "IMCO") ~ 1,
      (issue_name == "Defense" & committee_most_time %in% c("AFET", "SEDE")) ~ 1,
      (issue_name == "Technology" & committee_most_time %in% c("ITRE", "ITRE/INTA")) ~ 1,
      (issue_name == "Foreign Trade" & committee_most_time == "INTA") ~ 1, # Changed ENVI to INTA (Environment is ENVI, Foreign Trade is INTA)
      (issue_name == "International Affairs" & committee_most_time %in% c("AFET", "DEVE")) ~ 1, # AFET is foreign affairs; INTA is trade (mapped to Foreign Trade above)
      (issue_name == "Government Operations" & committee_most_time %in% c("JURI", "CONT", "AFCO")) ~ 1,
      (issue_name == "Education" & committee_most_time == "CULT") ~ 1,
      (issue_name == "Energy" & committee_most_time == "ITRE") ~ 1,
      (issue_name == "Environment" & committee_most_time == "ENVI") ~ 1,
      (issue_name == "Health" & committee_most_time %in% c("ENVI", "ENVI/SANT", "SANT")) ~ 1, # Changed SANT to ENVI ( health falls under ENVI in 4th-8th EP)
      (issue_name == "Housing" & committee_most_time %in% c("EMPL", "ITRE", "REGI")) ~ 1, # Housing: social/employment, industrial policy, or regional development
      (issue_name == "Immigration" & committee_most_time == "LIBE") ~ 1,
      TRUE ~ 0
    )
  )

# Sanity checks ####
stopifnot(
  "df_merged_2 is empty" = nrow(df_merged_2) > 0,
  "No issue names in df_merged_2" = n_distinct(df_merged_2$issue_name) > 0,
  "No MEPs in df_merged_2" = n_distinct(df_merged_2$mep_id) > 1000,
  "committee dummy has unexpected values" = all(df_merged_2$committee %in% c(0, 1))
)

# Save the data ####
message("  Writing ", nrow(df_merged_2), " rows, ",
        n_distinct(df_merged_2$mep_id), " MEPs, ",
        n_distinct(df_merged_2$issue_name), " issues")
write_csv(df_merged_2, here("output", "df_merged_2_1994_2024.csv"))
saveRDS(df_merged_2, here("output", "df_merged_2_1994_2024.rds"))


