#!/usr/bin/env bash
# scripts/utils/run_promotion_refits_2026-11-18.sh (2026-11-18)
# Option-A promotion refits (FR decision; audit remediation item 1 in
# quality_reports/2026-11-18_pipeline-scripts-audit.md): the TERM / CMP / LIBE
# alternative fits move from the keyword DV to the refined LLM (R2) DV that
# was promoted to the primary specification on 2026-11-17 (05_models.R §1b).
#   1. Preflight guards: promotion markers present in the three variant
#      scripts; promoted id lists and refined-vintage panel in place.
#   2. Archive keyword-vintage variant artifacts to
#      output/archive_keyword_dv_2026-11-18/ (+ md5 manifest) BEFORE refitting,
#      so the stale fits can never be silently reloaded by brm(file=...).
#   3. Re-run in sequence (each ~30-60 min; 4 chains x 4 cores):
#        05_models_Bayesian_TERM.R
#        05_models_Bayesian_CMP.R   (M1 interaction + M2 libe-only)
#        05_models_Bayesian_LIBE.R
# Log: quality_reports/session_logs/2026-11-18_promotion_refits.log
# NOT wired into run_pipeline.R. This dated runner supersedes the one-off
# scripts/utils/run_dv201_phase2.sh (2026-11-13), which assumed df_merged_3.csv
# still shipped the keyword DV and is retired.
set -uo pipefail
cd "$(dirname "$0")/../.."
LOGDIR=quality_reports/session_logs
DATE=2026-11-18
LOG="$LOGDIR/${DATE}_promotion_refits.log"
ARCH="output/archive_keyword_dv_2026-11-18"

echo "=== promotion refits start $(date '+%F %T') ===" >> "$LOG"

# --- 1. Preflight guards -------------------------------------------------------
guard_fail () {
  echo "=== PREFLIGHT FAILED: $1 $(date +%T) ===" >> "$LOG"
  echo "PREFLIGHT FAILED: $1" >&2
  exit 1
}
grep -q "DV PROMOTION (decision FR, 2026-11-18" scripts/05_models_Bayesian_TERM.R \
  || guard_fail "TERM promotion marker missing (script not promoted?)"
grep -q "DV PROMOTION OVERLAY (2026-11-18" scripts/05_models_Bayesian_CMP.R \
  || guard_fail "CMP promotion overlay marker missing (script not promoted?)"
grep -q "DV PROMOTION OVERLAY (2026-11-18" scripts/05_models_Bayesian_LIBE.R \
  || guard_fail "LIBE promotion overlay marker missing (script not promoted?)"
[ -f data/dv201_llm_refined_keptdv_ids.csv ] || guard_fail "data/dv201_llm_refined_keptdv_ids.csv missing"
[ -f data/dv201_llm_verified_in_ids.csv ]    || guard_fail "data/dv201_llm_verified_in_ids.csv missing"
[ -f data_processed/epq.rds ]                || guard_fail "data_processed/epq.rds missing"
[ output/df_model_data.rds -nt output/archive_spec_promotion_2026-11-17/df_model_data.rds ] \
  || guard_fail "output/df_model_data.rds is not the refined-vintage build"
echo "=== preflight OK $(date +%T) ===" >> "$LOG"

# --- 2. Archive keyword-vintage variant artifacts BEFORE refitting -------------
mkdir -p "$ARCH"
for f in bayesian_model_term.rds bayesian_model_cmp.rds \
         bayesian_model_cmp_libeonly.rds bayesian_model_libe.rds \
         df_model_data_cmp.rds df_model_data_libe.rds \
         bayesian_term_model_results.csv bayesian_term_diagnostics.csv \
         bayesian_term_focal_coefficients.csv bayesian_term_irr_contrasts.csv \
         bayesian_cmp_model_results.csv bayesian_cmp_diagnostics.csv \
         bayesian_cmp_focal_coefficients.csv bayesian_cmp_irr_contrasts.csv \
         bayesian_cmp_libeonly_model_results.csv bayesian_cmp_libeonly_diagnostics.csv \
         bayesian_cmp_libeonly_focal_coefficients.csv bayesian_cmp_libeonly_irr_contrasts.csv \
         bayesian_libe_model_results.csv bayesian_libe_diagnostics.csv \
         bayesian_libe_focal_coefficients.csv bayesian_libe_irr_contrasts.csv; do
  if [ -f "output/$f" ]; then
    mv "output/$f" "$ARCH/"
    echo "archived: $f" >> "$LOG"
  fi
done
md5sum "$ARCH"/*.rds "$ARCH"/*.csv > "$ARCH/md5_manifest.txt" 2>/dev/null || true
echo "=== keyword-vintage variant artifacts archived $(date +%T) ===" >> "$LOG"

# --- 3. Sequential refits -------------------------------------------------------
run_step () {
  local s="$1"
  echo "=== STEP $s start $(date +%T) ===" >> "$LOG"
  if Rscript "scripts/$s" >> "$LOG" 2>&1; then
    echo "=== STEP $s OK $(date +%T) ===" >> "$LOG"
  else
    echo "=== STEP $s FAILED $(date +%T) ===" >> "$LOG"
    tail -25 "$LOG"
    exit 1
  fi
}

run_step 05_models_Bayesian_TERM.R
run_step 05_models_Bayesian_CMP.R
run_step 05_models_Bayesian_LIBE.R
echo "=== PROMOTION REFITS COMPLETE $(date '+%F %T') ===" >> "$LOG"
