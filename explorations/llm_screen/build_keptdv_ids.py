#!/usr/bin/env python3
"""Build the kept-DV screening universe for the §7d refined-operative re-screen
(FR decision = A, 2026-11-17 pomeriggio).

Universe =
  subtopic-201 LLM-kept ids (dv201_llm_kept201_ids.csv, 1,291)
  UNION FR force-keeps (validation_decisions_FR decision == 'IN', 29)
  then FR arbitration (data/dv201_gold_arbitration_overrides.csv, 2026-11-17)
  is applied as FR's most recent decision:
    - every id arbitrated OUT is removed from the universe;
    - every id arbitrated IN is added as a force-keep.

Operative DV-201 (Step 3 output) = refined-INs on this universe UNION force-keeps.
Writes data/dv201_llm_keptdv_ids.csv (single `id` column, same format as the
kept201 ids file) and prints the overlap accounting.
Run from the project root.
"""
import csv
from pathlib import Path

ROOT = Path("/home/federusso/progetti/EPmigrants")
KEPT = ROOT / "data/dv201_llm_kept201_ids.csv"
FR = ROOT / "data/dv201_validation_decisions_FR.csv"
OVR = ROOT / "data/dv201_gold_arbitration_overrides.csv"
OUT = ROOT / "data/dv201_llm_keptdv_ids.csv"

kept = {(r.get("id") or "").strip() for r in csv.DictReader(open(KEPT)) if r.get("id")}
fr_rows = list(csv.DictReader(open(FR)))
force_keep = {(r.get("id") or "").strip() for r in fr_rows
              if (r.get("decision") or "").strip() == "IN"}

ovr_rows = list(csv.DictReader(open(OVR)))
assert len(ovr_rows) == 11, f"expected 11 override rows, got {len(ovr_rows)}"
arb_out = {(r["id"] or "").strip() for r in ovr_rows if r["FR_decision"] == "OUT"}
arb_in = {(r["id"] or "").strip() for r in ovr_rows if r["FR_decision"] == "IN"}
assert arb_out and arb_in, "arbitration rows not parsed"
assert not (arb_out & arb_in), "conflicting arbitration decisions"
assert len(arb_out) == 10 and len(arb_in) == 1, (arb_out, arb_in)

dropped_from_kept = kept & arb_out
dropped_from_force = force_keep & arb_out
added_force = arb_in - kept
force_keep -= arb_out
force_keep |= arb_in
kept -= arb_out

union = kept | force_keep
assert not (union & arb_out), "arbitrated-OUT id leaked into kept-DV universe"

with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["id"])
    for qid in sorted(union):
        w.writerow([qid])

per_term = {}
for r in fr_rows:
    i, d = (r.get("id") or "").strip(), (r.get("decision") or "").strip()
    if d == "IN":
        per_term[r.get("term") or "?"] = per_term.get(r.get("term") or "?", 0) + 1
print("kept201 (after arbitration):", len(kept))
print("arbitrated OUT dropped from kept201:", len(dropped_from_kept), sorted(dropped_from_kept))
print("force_keep (decisions_FR IN):", len(force_keep), per_term)
print("force-keeps removed by arbitration:", len(dropped_from_force), sorted(dropped_from_force))
print("force-keeps added by arbitration:", len(added_force), sorted(added_force))
print("overlap in both:", len(kept & force_keep))
print("universe written:", len(union), "->", OUT.relative_to(ROOT))

