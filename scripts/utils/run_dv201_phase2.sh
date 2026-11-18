#!/usr/bin/env bash
# scripts/utils/run_dv201_phase2.sh (2026-11-13)
# RETIRED 2026-11-18 (audit remediation item 1, Option A). HISTORY: this
# one-off dated runner waited for the primary re-run (01..07), archived the
# stale TERM/LIBE brms caches, and re-ran sens + TERM + LIBE. PROBLEM: under
# the 2026-11-17 refined-DV promotion a rerun of this script would HARD-FAIL
# on 05_models_Bayesian_TERM.R (recomputed minority-event invariants) while
# refitting on the wrong (keyword) vintage. The variant scripts now carry the
# refined-DV promotion themselves (2026-11-18, Option A) and are refit by
# scripts/utils/run_promotion_refits_2026-11-18.sh.
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

# Retirement guard (2026-11-18): see header above. Override only if you truly
# intend to replay the 2026-11-13 procedure against today's tree.
if [ "${FORCE_DV201_PHASE2:-0}" != "1" ]; then
  echo "run_dv201_phase2.sh was RETIRED on 2026-11-18 — use scripts/utils/run_promotion_refits_2026-11-18.sh" >&2
  echo "(override with FORCE_DV201_PHASE2=1)" >&2
  exit 1
fi

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