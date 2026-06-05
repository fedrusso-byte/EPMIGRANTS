# cap_issue_mapping.R — Shared CAP major topic mapping
# Single source of truth for CAP major code -> issue_name labels.
# Sourced by 02_df_setup.R and 06_responsiveness_data.R.

#' Map CAP major topic codes to human-readable issue names
#' @param major Integer vector of CAP major topic codes
#' @return Character vector of issue names
assign_issue_name <- function(major) {
  dplyr::case_when(
    major == 1  ~ "Macroeconomics",
    major == 2  ~ "Civil Rights",
    major == 3  ~ "Health",
    major == 4  ~ "Agriculture",
    major == 5  ~ "Labor",
    major == 6  ~ "Education",
    major == 7  ~ "Environment",
    major == 8  ~ "Energy",
    major == 9  ~ "Immigration",
    major == 10 ~ "Transportation",
    major == 12 ~ "Law and Crime",
    major == 13 ~ "Social Welfare",
    major == 14 ~ "Housing",
    major == 15 ~ "Domestic Commerce",
    major == 16 ~ "Defense",
    major == 17 ~ "Technology",
    major == 18 ~ "Foreign Trade",
    major == 19 ~ "International Affairs",
    major == 20 ~ "Government Operations",
    TRUE ~ "Other"
  )
}

#' Add committee-issue match dummy to a data frame
#' @param df Data frame with columns issue_name and committee_most_time
#' @return Data frame with added committee_match column (1L/0L)
add_committee_match <- function(df) {
  df %>%
    dplyr::mutate(
      committee_match = dplyr::case_when(
        issue_name == "Macroeconomics"       & committee_most_time %in% c("ECON", "FISC", "BUDG") ~ 1L,
        issue_name == "Civil Rights"         & committee_most_time %in% c("LIBE", "FEMM") ~ 1L,
        issue_name == "Agriculture"          & committee_most_time %in% c("AGRI", "AGRI/PECH") ~ 1L,
        issue_name == "Labor"                & committee_most_time == "EMPL" ~ 1L,
        issue_name == "Transportation"       & committee_most_time %in% c("TRAN", "REGI/TRAN") ~ 1L,
        issue_name == "Law and Crime"        & committee_most_time %in% c("LIBE", "JURI") ~ 1L,
        issue_name == "Social Welfare"       & committee_most_time %in% c("EMPL", "FEMM") ~ 1L,
        issue_name == "Domestic Commerce"    & committee_most_time == "IMCO" ~ 1L,
        issue_name == "Defense"              & committee_most_time %in% c("AFET", "SEDE") ~ 1L,
        issue_name == "Technology"           & committee_most_time %in% c("ITRE", "ITRE/INTA") ~ 1L,
        issue_name == "Foreign Trade"        & committee_most_time == "INTA" ~ 1L,
        issue_name == "International Affairs" & committee_most_time %in% c("AFET", "DEVE") ~ 1L,
        issue_name == "Government Operations" & committee_most_time %in% c("JURI", "CONT", "AFCO") ~ 1L,
        issue_name == "Education"            & committee_most_time == "CULT" ~ 1L,
        issue_name == "Energy"               & committee_most_time == "ITRE" ~ 1L,
        issue_name == "Environment"          & committee_most_time == "ENVI" ~ 1L,
        issue_name == "Health"               & committee_most_time %in% c("ENVI", "ENVI/SANT", "SANT") ~ 1L,
        issue_name == "Housing"              & committee_most_time %in% c("EMPL", "ITRE", "REGI") ~ 1L,
        issue_name == "Immigration"          & committee_most_time == "LIBE" ~ 1L,
        TRUE ~ 0L
      )
    )
}
