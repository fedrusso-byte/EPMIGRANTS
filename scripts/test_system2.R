library(here)
script_path <- here("scripts", "01_import_questions.R")
cat("Testing system2 with:", script_path, "\n")
tryCatch({
  result <- system2("Rscript", args = script_path, stdout = TRUE, stderr = TRUE)
  print(head(result))
}, error = function(e) {
  cat("Error occurred:\n")
  print(e)
})
