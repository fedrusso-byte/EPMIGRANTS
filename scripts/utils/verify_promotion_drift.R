#!/usr/bin/env Rscript
# verify_promotion_drift.R -- assert that the promoted canonical two-estimand
# results (output/bayesian_model_results.csv) reproduce the cached R2
# derivation fits (output/bayesian_sensllm_r2_model_results.csv) within
# Monte-Carlo noise: estimates <= 0.02, interval endpoints <= 0.03.
suppressMessages({ library(dplyr); library(stringr) })
new <- read.csv("output/bayesian_model_results.csv")
old <- read.csv("output/bayesian_sensllm_r2_model_results.csv")
tag_sd <- function(d) {
  idx <- which(d$term == "sd__(Intercept)")
  d$term[idx] <- paste0("sd__(Intercept)", seq_along(idx))
  d
}
mk <- function(d) {
  d <- tag_sd(d)
  d %>% mutate(side = ifelse(grepl("no LIBE", model), "M1", "M2"),
               key = paste(side, term))
}
n <- mk(new); o <- mk(old)
stopifnot("matched key sets must be equal" = setequal(n$key, o$key))
j <- inner_join(
  n %>% transmute(key, est_new = estimate, lo_new = conf.low, hi_new = conf.high),
  o %>% transmute(key, est_old = estimate, lo_old = conf.low, hi_old = conf.high),
  by = "key"
) %>%
  mutate(
    d_est = abs(est_new - est_old),
    d_lo  = abs(lo_new - lo_old),
    d_hi  = abs(hi_new - hi_old),
    d_max = pmax(d_est, d_lo, d_hi)
  ) %>%
  arrange(desc(d_max))
options(width = 250)
print(as.data.frame(j), digits = 4, row.names = FALSE)
cat("\nMAX |drift| estimate:", max(j$d_est), "| low:", max(j$d_lo), "| high:", max(j$d_hi), "\n")
stopifnot(
  "estimate drift must be <= 0.02" = max(j$d_est) <= 0.02,
  "interval-bound drift must be <= 0.03 (MC endpoint wobble)" =
    max(j$d_lo) <= 0.03 && max(j$d_hi) <= 0.03
)
message("PROMOTION DRIFT GATE PASSED: estimates within 0.02 and bounds within 0.03 of the R2 derivation fits (Monte-Carlo noise)")
