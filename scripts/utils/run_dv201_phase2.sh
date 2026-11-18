#!/usr/bin/env bash
# scripts/utils/run_dv201_phase2.sh (2026-11-13)
# Phase-2 runner for the DV-201 validation disposition: waits for the primary
# re-run (01..07) to finish, archives the stale TERM/LIBE brms caches
# (brm(file=) caches by path: formulas are unchanged, so the pre-DV-201 fits
# would be silently reloaded), then re-runs, in sequence:
#   1. 05_models_Bayesian_sens.R  (keyword-extension sensitivity, M1/M2_sens)
#   2. 05_models_Bayesian_TERM.R  (term heterogeneity, updated invariants)
#   3. 05_models_Bayesian_LIBE.R  (LIBE alternative model)
# Each step logs to quality_reports/session_logs/2026-11-13_dv201_phase2.log
set -uo pipefail
cd "$(dirname "$0")/../.."
LOGDIR=quality_reports/session_logs
DATE=2026-11-13

while ! grep -qE '^=== STEP 07_extract_all_coefficients.R (OK|FAILED)' \
        "$LOGDIR/${DATE}_primary_rerun.log" 2>/dev/null; do
  sleep 60
done

echo "=== primary pipeline finished $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"
grep -E '^=== STEP' "$LOGDIR/${DATE}_primary_rerun.log" >> "$LOGDIR/${DATE}_dv201_phase2.log"

mkdir -p "output/archive_dv201_2026-11-13/term_libe"
for f in bayesian_model_term.rds bayesian_model_libe.rds df_model_data_libe.rds; do
  if [ -f "output/$f" ]; then
    mv "output/$f" "output/archive_dv201_2026-11-13/term_libe/"
    echo "archived: $f" >> "$LOGDIR/${DATE}_dv201_phase2.log"
  fi
done
md5sum output/archive_dv201_2026-11-13/term_libe/* \
  > output/archive_dv201_2026-11-13/term_libe/md5_manifest.txt 2>/dev/null || true
echo "=== stale TERM/LIBE caches archived $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"

run_step () {
  local s="$1"
  echo "=== PHASE2 STEP $s start $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"
  if Rscript "scripts/$s" >> "$LOGDIR/${DATE}_dv201_phase2.log" 2>&1; then
    echo "=== PHASE2 STEP $s OK $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"
  else
    echo "=== PHASE2 STEP $s FAILED $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"
    tail -25 "$LOGDIR/${DATE}_dv201_phase2.log"
  fi
}

run_step 05_models_Bayesian_sens.R
run_step 05_models_Bayesian_TERM.R
run_step 05_models_Bayesian_LIBE.R
echo "=== PHASE2 COMPLETE $(date +%T) ===" >> "$LOGDIR/${DATE}_dv201_phase2.log"