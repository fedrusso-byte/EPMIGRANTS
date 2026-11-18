#!/usr/bin/env Rscript
# make_table1_promotion.R -- build the manuscript Table 1 (refined DV) or
# Appendix B Table B1 (keyword DV) markdown from a two-estimand results CSV.
# Usage: Rscript scripts/utils/make_table1_promotion.R <in_csv> <out_md>
# Model split: M1 = rows labelled with "no LIBE"; M2 = other rows carrying "LIBE".
suppressMessages({ library(dplyr); library(stringr) })
args <- commandArgs(TRUE)
csv_path <- if (length(args) >= 1) args[1] else "output/bayesian_sensllm_r2_model_results.csv"
out_path <- if (length(args) >= 2) args[2] else "output/table1_r2.md"
r <- read.csv(csv_path)
min_minus <- function(s) str_replace_all(s, "-", "\u2212")
fmt <- function(x) min_minus(sprintf("%.4f", x))
ci_of <- function(lo, hi, underline = TRUE) {
  base <- paste0("[", fmt(lo), ", ", fmt(hi), "]")
  if (underline && (lo > 0 || hi < 0)) paste0(base, "{.underline}") else base
}
m1 <- r %>% filter(grepl("no LIBE", model))
m2 <- r %>% filter(grepl("LIBE", model), !grepl("no LIBE", model))
tag_sd <- function(d) {
  idx <- which(d$term == "sd__(Intercept)")
  labs <- paste0("sd__(Intercept)@", seq_along(idx))
  d$term[idx] <- labs
  d
}
m1 <- tag_sd(m1); m2 <- tag_sd(m2)
message("M1 rows: ", nrow(m1), " | M2 rows: ", nrow(m2))
get1 <- function(d, term) { v <- d[d$term == term, , drop = FALSE]; if (nrow(v) == 0) NULL else v[1, ] }
bc <- m1$estimate[m1$term == "sd__(Intercept)@1"]; bm <- m1$estimate[m1$term == "sd__(Intercept)@2"]
stopifnot("first sd row must be the (smaller) country SD" = length(bc) == 1 && length(bm) == 1 && bc < bm)
rows <- list(
  c("(Intercept)", "(Intercept)"),
  c("genderM", "Gender: Male"),
  c("misery_index", "Misery Index"),
  c("REF", "PartyFamily (Ref. Christian Democrats)"),
  c("party_familyCommunistsandsocialists", "The Left"),
  c("party_familyEuroscepticconservatives", "Eurosceptic Conservatives"),
  c("party_familyEurosceptics", "Eurosceptics"),
  c("party_familyGreensDEFA", "Greens-EFA"),
  c("party_familyLiberals", "Liberals"),
  c("party_familyNI", "Non Inscripts"),
  c("party_familyRightMwingnationalists", "Right Wing Nationalists"),
  c("party_familySocialdemocrats", "Social Democrats"),
  c("libe", "Committee: LIBE"),
  c("minority", "Minority"),
  c("mipex_center", "Mipex"),
  c("minority:mipex_center", "Minority \u00d7 Mipex"),
  c("sd__(Intercept)@1", "Random-intercept SD (Country)"),
  c("sd__(Intercept)@2", "Random-intercept SD (MEP)")
)
se_cell <- function(d, term) { v <- get1(d, term); if (is.null(v)) "\u2014" else paste0(fmt(v$estimate), " (", fmt(v$std.error), ") ") }
ci_cell <- function(d, term) { v <- get1(d, term); if (is.null(v)) "\u2014" else ci_of(v$conf.low, v$conf.high) }
e_cell <- function(d, term) { v <- get1(d, term); if (is.null(v)) "\u2014" else fmt(exp(v$estimate)) }
out <- c(
  "| **Predictor** | **M1: \u03b2 (SE)** | **M1: 95% CrI** | **M1: Exp(\u03b2)** | **M2: \u03b2 (SE)** | **M2: 95% CrI** | **M2: Exp(\u03b2)** |",
  "|:-------------------------|----------------:|:----------------------|---------------:|----------------:|:----------------------|---------------:|"
)
for (rw in rows) {
  k <- rw[1]; lab <- rw[2]
  if (k == "REF") { out <- c(out, paste0("| *", lab, "* |   |   |   |   |   |   |")); next }
  out <- c(out, paste0("| *", lab, "* | ", se_cell(m1, k), "| ", ci_cell(m1, k), " | ", e_cell(m1, k), " | ", se_cell(m2, k), "| ", ci_cell(m2, k), " | ", e_cell(m2, k), " |"))
}
writeLines(out, out_path)
message("written: ", out_path)
