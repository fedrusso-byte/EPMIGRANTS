#!/usr/bin/env bash
# scripts/utils/archive_pre_dv201_rerun.sh
# [RETIRED 2026-11-18 — superseded by scripts/utils/run_promotion_refits_2026-11-18.sh
# with its preflight guard scripts/utils/preflight_promotion_invariants_2026-11-18.R.]
# Archive pre-DV-201-rerun model artifacts (2026-11-13). Files are MOVED (not
# copied): output/ is left clean for the two-estimand re-run. Idempotence
# guard: aborts if the archive dir already exists — never mix vintages.
set -euo pipefail
cd "$(dirname "$0")/../.."
DEST="output/archive_dv201_2026-11-13"
if [ -e "$DEST" ]; then
  echo "ABORT: $DEST already exists — refusing to mix archive vintages" >&2
  exit 1
fi
mkdir -p "$DEST"
for f in bayesian_model_mipex.rds zinb_model1.rds zinb_model2.rds zinb_model3.rds zinb_model4.rds df_model_data.rds bayesian_model_results.csv; do
  if [ -f "output/$f" ]; then
    mv "output/$f" "$DEST/"
    echo "moved: output/$f"
  else
    echo "MISSING (not archived): output/$f" >&2
  fi
done
md5sum "$DEST"/* > "$DEST/md5_manifest.txt"
echo "MD5 manifest written to $DEST/md5_manifest.txt:"
cat "$DEST/md5_manifest.txt"