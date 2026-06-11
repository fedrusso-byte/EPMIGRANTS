# Country-level data

library(tibble)
library(dplyr)
library(readr)
library(lubridate)
library(tidyr)
library(purrr)
library(forcats)
library(here)

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

message("  Building country classification...")
country_classification <- tribble(
  ~country, ~country_name, ~geographic_region, ~eu_enlargement_wave,
  "AT", "Austria",         "Western",           "1995",
  "BE", "Belgium",         "Western",           "Founding",
  "BG", "Bulgaria",        "Eastern",           "2007",
  "HR", "Croatia",         "Eastern",           "2013",
  "CY", "Cyprus",          "Southern",          "2004",
  "CZ", "Czechia",         "Eastern",           "2004",
  "DK", "Denmark",         "Northern",          "1973",
  "EE", "Estonia",         "Eastern",           "2004",
  "FI", "Finland",         "Northern",          "1995",
  "FR", "France",          "Western",           "Founding",
  "DE", "Germany",         "Western",           "Founding",
  "GR", "Greece",          "Southern",          "1981",
  "HU", "Hungary",         "Eastern",           "2004",
  "IE", "Ireland",         "Northern",          "1973",
  "IT", "Italy",           "Southern",          "Founding",
  "LV", "Latvia",          "Eastern",           "2004",
  "LT", "Lithuania",       "Eastern",           "2004",
  "LU", "Luxembourg",      "Western",           "Founding",
  "MT", "Malta",           "Southern",          "2004",
  "NL", "Netherlands",     "Western",           "Founding",
  "PL", "Poland",          "Eastern",           "2004",
  "PT", "Portugal",        "Southern",          "1986",
  "RO", "Romania",         "Eastern",           "2007",
  "SK", "Slovakia",        "Eastern",           "2004",
  "SI", "Slovenia",        "Eastern",           "2004",
  "ES", "Spain",           "Southern",          "1986",
  "SE", "Sweden",          "Northern",          "1995",
  "UK", "United Kingdom",  "Northern",          "1973"
) |> 
  mutate(
    old_new_ms = if_else(eu_enlargement_wave %in% c("Founding", "1973", "1981", "1986", "1995"), "Old", "New"),
    euro_member = country %in% c("AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT",
                                 "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES", "HR"),
    founding_member = country %in% c("DE", "FR", "IT", "BE", "NL", "LU")
  )


# NUOVO: Inserimento dati time-invariant estratti dal file claimmakingpressure.csv
message("  Adding discrimination and CMP time-invariant data...")
country_features <- tribble(
  ~country_name,     ~discrimination_mean, ~cmp_mean,
  "Austria",         25.45,                10.42,
  "Belgium",         17.12,                7.83,
  "Bulgaria",        8.71,                 2.25,
  "Cyprus",          16.82,                8.44,
  "Czechia",         22.29,                1.35,
  "Germany",         23.69,                11.18,
  "Denmark",         19.91,                10.96,
  "Estonia",         18.02,                6.08,
  "Spain",           16.74,                7.14,
  "Finland",         19.56,                11.55,
  "France",          27.27,                13.03,
  "United Kingdom",  22.16,                14.91,
  "Greece",          46.24,                7.65,
  "Croatia",         4.70,                 1.42,
  "Hungary",         4.27,                 NA, # Gestione n.a.
  "Ireland",         13.36,                4.77,
  "Italy",           26.73,                5.72,
  "Lithuania",       8.15,                 5.75,
  "Latvia",          26.45,                9.73,
  "Netherlands",     29.89,                15.11,
  "Poland",          10.11,                4.02,
  "Portugal",        21.16,                5.59,
  "Sweden",          18.59,                12.38,
  "Slovenia",        6.26,                 3.12,
  "Slovakia",        9.10,                 NA  # Gestione n.a.
)

# Uniamo i nuovi dati strutturali alla classificazione di base dei paesi
# I paesi mancanti nel file (es. Lussemburgo, Malta, Romania) riceveranno automaticamente NA
country_classification <- country_classification |> 
  left_join(country_features, by = "country_name")



############################ Time-varying data ###################################

# Create base panel
year_panel <- crossing(
  year = 2004:2024,
  country = country_classification$country
) |> 
  left_join(country_classification, by = "country")

# Eurozone entry years (simplified; source: ECB)
euro_entry_year <- tribble(
  ~country, ~euro_year,
  "AT", 1999, "BE", 1999, "FI", 1999, "FR", 1999, "DE", 1999, "IE", 1999, "IT", 1999, "LU", 1999, "NL", 1999, "ES", 1999, "PT", 1999,
  "GR", 2001,
  "SI", 2007,
  "CY", 2008,
  "MT", 2008,
  "SK", 2009,
  "EE", 2011,
  "LV", 2014,
  "LT", 2015,
  "HR", 2023
)

# Add eurozone membership by year
year_panel <- year_panel |> 
  left_join(euro_entry_year, by = "country") |> 
  mutate(euro_member = !is.na(euro_year) & year >= euro_year)

# Add UK exit
year_panel <- year_panel |> 
  mutate(eu_member = case_when(
    country == "UK" & year > 2020 ~ 0L,
    TRUE ~ 1L
  ))

# Populist/anti-establishment in government
# Based on The PopuList, Rooduijn et al., and updates for 2023–2024 (e.g. Meloni’s Italy, Sweden Democrats' support)
year_panel <- year_panel |> 
  mutate(populist_in_gov = case_when(
    # Italy: M5S + Lega (2018-2019), Meloni/FdI coalition (2022-2024)
    country == "IT" & year %in% c(2018:2019, 2022:2024) ~ 1L,
    
    # Hungary: Fidesz (populist shift post-2010)
    country == "HU" & year >= 2010 ~ 1L,
    
    # Poland: PiS (2015–2023)
    country == "PL" & year >= 2015 & year <= 2023 ~ 1L,
    
    # Slovakia: SMER, SNS, LSNS (2006–2010, 2012–2020, 2023–)
    country == "SK" & year %in% c(2006:2010, 2012:2020, 2023:2024) ~ 1L,
    
    # Czech Republic: ANO (2014–2021)
    country == "CZ" & year %in% 2014:2021 ~ 1L,
    
    # Greece: Syriza and ANEL (2015–2019)
    country == "GR" & year %in% 2015:2019 ~ 1L,
    
    # Bulgaria: Ataka + populist coalitions (2005–2009, 2021–2023 intermittent)
    country == "BG" & year %in% c(2005:2009, 2021:2023) ~ 1L,
    
    # Romania: PSD with strong populist rhetoric in gov (2000–2004, 2012–2015, 2017–2023)
    country == "RO" & year %in% c(2000:2004, 2012:2015, 2017:2023) ~ 1L,
    
    # Netherlands: PVV supported gov 2010–2012 (but not in coalition)
    country == "NL" & year %in% 2010:2012 ~ 1L,
    
    # Finland: Finns Party (in gov 2015-2017; re-entered coalition June 2023 under Orpo)
    country == "FI" & year %in% c(2015:2017, 2023:2024) ~ 1L,
    
    # Estonia: EKRE in coalition (2019–2021)
    country == "EE" & year %in% 2019:2021 ~ 1L,
    
    # Latvia: NA/NKP, populist in tone (2011–2022 intermittent)
    country == "LV" & year %in% c(2011:2014, 2016:2022) ~ 1L,
    
    # Lithuania: TT/LDP and Farmers/Greens Union (2006–2008, 2016–2020)
    country == "LT" & year %in% c(2006:2008, 2016:2020) ~ 1L,
    
    # Slovenia: SDS (2004–2008, 2012–2013, 2020–2022)
    country == "SI" & year %in% c(2004:2008, 2012:2013, 2020:2022) ~ 1L,
    
    # Austria: FPÖ in gov (2000–2005, 2017–2019)
    country == "AT" & year %in% c(2000:2005, 2017:2019) ~ 1L,
    
    # Denmark: DF supported gov (2001–2011, 2015–2019)
    country == "DK" & year %in% c(2001:2011, 2015:2019) ~ 1L,
    
    # Sweden: SD supported gov from 2022
    country == "SE" & year >= 2022 ~ 1L,
    
    # UK: Brexit Party never in gov, UKIP support but not governing
    country == "UK" ~ 0L,
    
    # Default
    TRUE ~ 0L
  ))

# Transform relevant variables in factors

year_panel <- year_panel |>
  mutate(
    # Geographic region: custom order (West > East > South > North)
    geographic_region = factor(geographic_region,
                               levels = c("Western", "Eastern", "Southern", "Northern")),
    
    # EU enlargement wave: ordered chronologically
    eu_enlargement_wave = factor(eu_enlargement_wave,
                                 levels = c("Founding", "1973", "1981", "1986", "1995", "2004", "2007", "2013")),
    
    # Old/New MS: ensure consistent labeling
    old_new_ms = factor(old_new_ms, levels = c("Old", "New")),
    
    # Founding member: dummy to factor
    founding_member = factor(if_else(founding_member == TRUE, "Yes", "No"), levels = c("No", "Yes")),
    
    # Country as factor — useful for plotting or group modeling
    country = factor(country),
    
    # Optional: year as factor (if needed for fixed effects models or facet plots)
    year_f = factor(year)
  )

## Optional: add one-hot dummies
# Assume 'geographic_region' is a factor
dummies <- model.matrix(~ geographic_region, data = year_panel)

# Result: a matrix with 3 columns (if 4 levels, one dropped)
head(dummies)
# The first column is the intercept (if you use ~ geographic_region)
# You can use ~ geographic_region - 1 to exclude the intercept and get all 4 dummies.
# All 4 categories, no intercept
dummies_all <- model.matrix(~ geographic_region - 1, data = year_panel)

# bind columns if you want to use it
year_panel <- bind_cols(year_panel, as.data.frame(dummies_all))

# Turn to numeric (integer) dummy instead of logical
country_classification <- country_classification |> 
  mutate(across(where(is.logical), as.integer))

year_panel <- year_panel |> 
  mutate(across(where(is.logical), as.integer))

#############################################################

############################ Net budget position -> year_panel #####################################

# EU Net Budget Position by Country and Period

eu_budget_status <- tribble(
  ~country,           ~period,        ~status,
  "Germany",          "1994–2003",    "Contributor",
  "Germany",          "2004–2013",    "Contributor",
  "Germany",          "2014–2020",    "Contributor",
  "Germany",          "2021–2024",    "Contributor",
  
  "France",           "1994–2003",    "Contributor",
  "France",           "2004–2013",    "Contributor",
  "France",           "2014–2020",    "Contributor",
  "France",           "2021–2024",    "Contributor",
  
  "Italy",            "1994–2003",    "Contributor",
  "Italy",            "2004–2013",    "Contributor",
  "Italy",            "2014–2020",    "Contributor",
  "Italy",            "2021–2024",    "Contributor",
  
  "Netherlands",      "1994–2003",    "Contributor",
  "Netherlands",      "2004–2013",    "Contributor",
  "Netherlands",      "2014–2020",    "Contributor",
  "Netherlands",      "2021–2024",    "Contributor",
  
  # "Sweden",           "1994–2003",    "Contributor",
  # "Sweden",           "2004–2013",    "Contributor",
  # "Sweden",           "2014–2020",    "Contributor",
  # "Sweden",           "2021–2024",    "Contributor",
  
  "Austria",          "1994–2003",    "Contributor",
  "Austria",          "2004–2013",    "Contributor",
  "Austria",          "2014–2020",    "Contributor",
  "Austria",          "2021–2024",    "Contributor",
  
  "Denmark",          "1994–2003",    "Contributor",
  "Denmark",          "2004–2013",    "Contributor",
  "Denmark",          "2014–2020",    "Contributor",
  "Denmark",          "2021–2024",    "Contributor",
  
  "Finland",          "1994–2003",    "Contributor",
  "Finland",          "2004–2013",    "Contributor",
  "Finland",          "2014–2020",    "Contributor",
  "Finland",          "2021–2024",    "Contributor",
  
  "United Kingdom",   "1994–2003",    "Contributor",
  "United Kingdom",   "2004–2013",    "Contributor",
  "United Kingdom",   "2014–2020",    "Contributor",
  "United Kingdom",   "2021–2024",    "Left EU",
  
  "Ireland",          "1994–2003",    "Recipient",
  "Ireland",          "2004–2013",    "Recipient",
  "Ireland",          "2014–2020",    "Contributor",
  "Ireland",          "2021–2024",    "Contributor",
  
  "Spain",            "1994–2003",    "Recipient",
  "Spain",            "2004–2013",    "Recipient",
  "Spain",            "2014–2020",    "Recipient",
  "Spain",            "2021–2024",    "Recipient",
  
  "Portugal",         "1994–2003",    "Recipient",
  "Portugal",         "2004–2013",    "Recipient",
  "Portugal",         "2014–2020",    "Recipient",
  "Portugal",         "2021–2024",    "Recipient",
  
  "Greece",           "1994–2003",    "Recipient",
  "Greece",           "2004–2013",    "Recipient",
  "Greece",           "2014–2020",    "Recipient",
  "Greece",           "2021–2024",    "Recipient",
  
  "Poland",           "2004–2013",    "Recipient",
  "Poland",           "2014–2020",    "Recipient",
  "Poland",           "2021–2024",    "Recipient",
  
  "Hungary",          "2004–2013",    "Recipient",
  "Hungary",          "2014–2020",    "Recipient",
  "Hungary",          "2021–2024",    "Recipient",
  
  "Czechia",   "2004–2013",    "Recipient",
  "Czechia",   "2014–2020",    "Recipient",
  "Czechia",   "2021–2024",    "Recipient",
  
  "Slovakia",         "2004–2013",    "Recipient",
  "Slovakia",         "2014–2020",    "Recipient",
  "Slovakia",         "2021–2024",    "Recipient",
  
  "Lithuania",        "2004–2013",    "Recipient",
  "Lithuania",        "2014–2020",    "Recipient",
  "Lithuania",        "2021–2024",    "Recipient",
  
  "Latvia",           "2004–2013",    "Recipient",
  "Latvia",           "2014–2020",    "Recipient",
  "Latvia",           "2021–2024",    "Recipient",
  
  "Estonia",          "2004–2013",    "Recipient",
  "Estonia",          "2014–2020",    "Recipient",
  "Estonia",          "2021–2024",    "Recipient",
  
  "Slovenia",         "2004–2013",    "Recipient",
  "Slovenia",         "2014–2020",    "Recipient",
  "Slovenia",         "2021–2024",    "Recipient",
  
  "Bulgaria",         "2007–2013",    "Recipient",
  "Bulgaria",         "2014–2020",    "Recipient",
  "Bulgaria",         "2021–2024",    "Recipient",
  
  "Romania",          "2007–2013",    "Recipient",
  "Romania",          "2014–2020",    "Recipient",
  "Romania",          "2021–2024",    "Recipient"
)


eu_budget_status <- eu_budget_status |> 
  bind_rows(
    tribble(
      ~country,          ~period,        ~status,
      "Croatia",         "2014–2020",    "Recipient",
      "Croatia",         "2021–2024",    "Recipient",
      "Cyprus",          "2004–2013",    "Recipient",
      "Cyprus",          "2014–2020",    "Recipient",
      "Cyprus",          "2021–2024",    "Recipient",
      "Malta",           "2004–2013",    "Recipient",
      "Malta",           "2014–2020",    "Recipient",
      "Malta",           "2021–2024",    "Recipient",
      "Belgium",         "1994–2024",    "Contributor",
      "Luxembourg",      "1994–2024",    "Contributor",
      "Sweden",          "1995–2024",    "Contributor"
    )
  )

# 2. Expand Periods to Years
# Turn the 10-year periods into individual rows for each country-year:

# Convert 'period' like "2004–2013" to numeric start/end years
eu_budget_yearly <- eu_budget_status |>
  separate(period, into = c("start", "end"), sep = "–", convert = TRUE) |>
  rowwise() |>
  mutate(year = list(seq(start, end))) |>
  unnest(year) |>
  select(country, year, status)

# 3: Merge with year_panel

# Match by country_name and year, then convert status to a dummy or factor:

year_panel <- year_panel |>
  left_join(
    eu_budget_yearly |> 
      rename(country_name = country),
    by = c("country_name", "year")
  ) |>
  mutate(
    net_contributor = case_when(
      status == "Contributor" ~ 1L,
      status == "Recipient" ~ 0L,
      TRUE ~ NA_integer_
    )
  )
stopifnot(
  "year_panel is empty after budget join" = nrow(year_panel) > 0,
  "net_contributor is all NA" = !all(is.na(year_panel$net_contributor))
)


############################################################
# Save
write_csv(country_classification, here("output", "country_classification.csv"))
saveRDS(country_classification, here("output", "country_classification.rds"))
write_csv(year_panel, here("output", "country_panel.csv"))
saveRDS(year_panel, here("output", "country_panel.rds"))


### Problem: we need to align solar years with parliamentary years

# Generate the full list of parliamentary years by country

# Define term starts
legislature_starts <- tribble(
  ~legislative_term, ~term_start,
  "6th", ymd("2004-07-20"),
  "7th", ymd("2009-07-14"),
  "8th", ymd("2014-07-01"),
  "9th", ymd("2019-07-02")
)

# Each term typically has 5 parliamentary years
parl_years <- legislature_starts |>
  mutate(leg_years = map(term_start, ~ tibble(
    leg_year = 1:5,
    start_date = .x + years(0:4),
    end_date = lead(.x + years(1:5), default = .x + years(5)) - days(1)
  ))) |>
  unnest(leg_years)

# Cross with country classification
country_parl_year_panel <- crossing(
  country = country_classification$country,
  legislative_term = unique(parl_years$legislative_term),
  leg_year = 1:5
) |> 
  left_join(country_classification, by = "country") |> 
  left_join(parl_years, by = c("legislative_term", "leg_year"))

###### removing euro_member to avoid clashes and duplicated columns after the join below
country_parl_year_panel <- country_parl_year_panel |>
  select(-euro_member)  # drop static column

# Add time-varying variables (e.g., euro, populism)
country_parl_year_panel <- country_parl_year_panel |> 
  mutate(
    mid_date = start_date + floor((end_date - start_date) / 2),
    mid_year = year(mid_date)
  ) |> 
  left_join(
    year_panel |> 
      select(country, year, euro_member, eu_member, populist_in_gov, net_contributor),
    by = c("country", "mid_year" = "year")
  )

# Make leg_year include identifier for the term as in df_merged
country_parl_year_panel <- country_parl_year_panel |> 
  mutate(
    leg_year = paste0(legislative_term, leg_year)
  )

# Add a panel_id to country_parl_year_panel
# useful in panel models (e.g., plm, fixest) for indexing country–year units.

# panel_id: unique row identifier for panel model indexing
country_parl_year_panel <- country_parl_year_panel |>
  arrange(country, leg_year) |>
  mutate(panel_id = row_number())

write_csv(country_parl_year_panel, here("output", "country_parl_year_panel.csv"))
saveRDS(country_parl_year_panel, here("output", "country_parl_year_panel.rds"))



message("  Merging country-level variables into panel...")
df_merged_2 <- read_csv(here("output", "df_merged_2_2004_2024.csv"))

df_merged_3 <- df_merged_2 |>
  left_join(
    country_parl_year_panel |>
      select(-legislative_term) |>  # already in df_merged_2, avoid .x/.y
      select(country_name, leg_year, everything()),
    by = c("country_name", "leg_year")
  )
stopifnot(
  "df_merged_3 has fewer rows than df_merged_2" = nrow(df_merged_3) >= nrow(df_merged_2),
  "geographic_region is all NA after join" = !all(is.na(df_merged_3$geographic_region)),
  "euro_member is all NA after join" = !all(is.na(df_merged_3$euro_member))
)

message("  Writing df_merged_3: ", nrow(df_merged_3), " rows")
write_csv(df_merged_3, here("output", "df_merged_3.csv"))
saveRDS(df_merged_3, here("output", "df_merged_3.rds"))


