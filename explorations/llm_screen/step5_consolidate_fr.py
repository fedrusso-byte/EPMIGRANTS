#!/usr/bin/env python3
"""Step 5 (§7c-b): consolidate FR's LLM-verified-IN adjudication sheet into the
two id lists that feed the R1/R2 Bayesian sensitivity refits.

Inputs
  data/dv201_llm_candidates_majority_tocode.csv   FR-coded sheet (621 decided)
  data_processed/epq.csv                          question-level baseline
  data/dv201_llm_keptdv_ids.csv                   kept-DV universe (1,309)
  output/llm_screen/refined_glm_body_keptdv.csv   refined re-screen of universe
  data/dv201_validation_decisions_FR.csv          earlier FR decisions (audit)

Outputs (epq-format ids, so the R scripts match epq$id literally)
  data/dv201_llm_verified_in_ids.csv       R1 additive overlay    (255 rows)
  data/dv201_llm_refined_keptdv_ids.csv    R2 replacement DV      (529 rows)

Verified expectations (2026-11-17 session): 621 decided = 258 IN + 363 OUT;
255/258 in-window (VII 115 / VIII 102 / IX 38), 3 pre-window exclusions
(E-3845/2009, E-3675/2009, E-4252/2009); 0 canon collisions; 0 keptdv overlap;
R2 = 524 refined-IN + 5 FR force-keeps held IN over refined-OUT.

No LLM calls. Run from the project root:
python3 explorations/llm_screen/step5_consolidate_fr.py
"""
import csv
import re
from datetime import date
from pathlib import Path

ROOT = Path("/home/federusso/progetti/EPmigrants")
SHEET = ROOT / "data/dv201_llm_candidates_majority_tocode.csv"
EPQ = ROOT / "data_processed/epq.csv"
KEPTDV = ROOT / "data/dv201_llm_keptdv_ids.csv"
REFINED_RUN = ROOT / "output/llm_screen/refined_glm_body_keptdv.csv"
DECISIONS = ROOT / "data/dv201_validation_decisions_FR.csv"
OUT_VERIFIED = ROOT / "data/dv201_llm_verified_in_ids.csv"
OUT_REFINED = ROOT / "data/dv201_llm_refined_keptdv_ids.csv"

# Force-keeps held IN over refined-OUT (session log 2026-11-17, refined step 3).
R2_FORCE_KEEPS = {
    "E-000782/2013", "E-001218/2022", "E-002519/2021",
    "E-007949/2017", "E-016119/2015",
}
# The three sheet-INs with corpus dates before the VII term start (2009-07-14);
# they exit via the same window filter as the pre-window keyword hits.
EXPECTED_PRE_WINDOW = {"E-3845/2009", "E-3675/2009", "E-4252/2009"}

# Analysis window: VII..IX, verbatim 02_df_setup.R / 05_models.R boundaries.
TERM_BOUNDS = {
    "VII": (date(2009, 7, 14), date(2014, 6, 30)),
    "VIII": (date(2014, 7, 1), date(2019, 7, 1)),
    "IX": (date(2019, 7, 2), date(2024, 7, 15)),
}

PQ_RE = re.compile(r"^([EP])-(\d+)/(\d{4})(.*)$")


def canon(qid):
    """Fold zero-padding variants; keep any /rev.N suffix verbatim."""
    qid = (qid or "").strip()
    m = PQ_RE.match(qid)
    return f"{m.group(1)}-{int(m.group(2))}/{m.group(3)}{m.group(4)}" if m else qid


def load_rows(path):
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
        return list(csv.DictReader(fh))


def parse_date(s):
    s = (s or "").strip()
    return date.fromisoformat(s[:10]) if len(s) >= 10 else None


def term_of(d):
    if d is None:
        return None
    for term, (lo, hi) in TERM_BOUNDS.items():
        if lo <= d <= hi:
            return term
    return None


def canon_index(rows, id_col="id"):
    """canon qid -> list of raw ids (length 1 required for unambiguous joins)."""
    idx = {}
    for r in rows:
        q = canon(r.get(id_col))
        if q:
            idx.setdefault(q, []).append((r.get(id_col) or "").strip())
    return idx


# =============================================================================
# 1. FR sheet parse
# =============================================================================
sheet = load_rows(SHEET)
raw_dec = [(r.get("FR_decision") or "").strip().upper() for r in sheet]
bad = [r["id"] for r, d in zip(sheet, raw_dec) if d not in {"IN", "OUT", ""}]
assert not bad, f"sheet rows with non IN/OUT/blank FR_decision: {bad}"
decided = [r for r, d in zip(sheet, raw_dec) if d in {"IN", "OUT"}]
blank_ids = [r["id"] for r, d in zip(sheet, raw_dec) if d == ""]
sheet_in = [r for r, d in zip(sheet, raw_dec) if d == "IN"]
sheet_out = [r for r, d in zip(sheet, raw_dec) if d == "OUT"]
print(f"sheet parsed: {len(sheet)} rows | decided {len(decided)} "
      f"(IN {len(sheet_in)} / OUT {len(sheet_out)}) | blank {len(blank_ids)}")
assert len(decided) == 621, f"expected 621 decided rows, got {len(decided)}"
assert len(sheet_in) == 258, f"expected 258 sheet INs, got {len(sheet_in)}"
assert len(sheet_out) == 363, f"expected 363 sheet OUTs, got {len(sheet_out)}"
assert not blank_ids, f"unexpected undecided rows: {blank_ids}"

# =============================================================================
# 2. Canon join to epq (zero-strip; assert unambiguous, no collisions)
# =============================================================================
epq_rows = load_rows(EPQ)
epq_canon = canon_index(epq_rows)
collisions = {q: ids for q, ids in epq_canon.items() if len(ids) != 1}
assert not collisions, f"epq canon collisions: {collisions}"
epq_fmt = {q: ids[0] for q, ids in epq_canon.items()}

in_unmatched, verified = [], []
for r in sheet_in:
    q = canon(r.get("id"))
    if q not in epq_fmt:
        in_unmatched.append(r.get("id"))
        continue
    verified.append({"id": epq_fmt[q], "canon_id": q, "sheet_date": r.get("date") or "",
                     "sheet_term": r.get("term") or "", "sheet_type": r.get("type") or "",
                     "run1_label": r.get("run1_label") or "",
                     "run2_label": r.get("run2_label") or "",
                     "known_fr_from_sample": r.get("known_fr_from_sample") or ""})
assert not in_unmatched, f"sheet INs missing from epq: {in_unmatched}"
assert len(verified) == 258

# =============================================================================
# 3. Window filter (epq date authoritative) -> 255 additions for R1
# =============================================================================
epq_date = {r["id"].strip(): r["date"] for r in epq_rows}
epq_dv = {r["id"].strip(): int(float(r["pq_discrimination"] or 0))
          for r in epq_rows}
for v in verified:
    v["epq_date"] = epq_date[v["id"]]

in_window, pre_window = [], []
for v in verified:
    (in_window if term_of(parse_date(v["epq_date"])) else pre_window).append(v)

per_term = {t: sum(1 for v in in_window
                   if term_of(parse_date(v["epq_date"])) == t)
            for t in ("VII", "VIII", "IX")}
pre_window_ids = sorted(v["canon_id"] for v in pre_window)
print(f"window filter: kept {len(in_window)} "
      f"(VII {per_term['VII']} / VIII {per_term['VIII']} / IX {per_term['IX']}) "
      f"| pre-window excluded {len(pre_window)}: {pre_window_ids}")
assert per_term == {"VII": 115, "VIII": 102, "IX": 38}, per_term
assert set(pre_window_ids) == EXPECTED_PRE_WINDOW, pre_window_ids

# =============================================================================
# 4. Overlap + pre-overlay guards
# =============================================================================
keptdv_canon = {canon(r.get("id")) for r in load_rows(KEPTDV)}
ov = {v["canon_id"] for v in verified} & keptdv_canon
assert not ov, f"verified-IN overlap with kept-DV universe: {sorted(ov)}"
dv_nonzero = [v["id"] for v in verified
              if epq_dv[v["id"]] != 0 and v["id"] in {v2["id"] for v2 in in_window}]
assert not dv_nonzero, f"verified-INs already DV1 in epq (additive guard): {dv_nonzero}"
pre_window_dv1 = [v["id"] for v in pre_window if epq_dv[v["id"]] == 1]
print(f"pre-window exclusions (DV1 keyword rows, not overlay targets): {pre_window_dv1}")
print("guards OK: 0 keptdv overlap | 255 verified-INs all DV=0 in epq pre-overlay")

# Deliberate flips audit: sheet-OUT rows that FR coded IN in the decisions CSV.
dec_in = {canon(r.get("id")) for r in load_rows(DECISIONS)
          if (r.get("decision") or "").strip().upper() == "IN"}
flips = sorted({canon(r.get("id")) for r in sheet_out} & dec_in)
print(f"flips audit: sheet-OUT ids also in decisions-CSV IN set: "
      f"{len(flips)} {flips}")

# =============================================================================
# 5. Write the R1 additive overlay list
# =============================================================================
cols = ["id", "canon_id", "epq_date", "sheet_date", "sheet_term", "sheet_type",
        "run1_label", "run2_label", "known_fr_from_sample"]
with open(OUT_VERIFIED, "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=cols)
    w.writeheader()
    for v in sorted(in_window, key=lambda x: x["epq_date"]):
        w.writerow({c: v[c] for c in cols})
print(f"wrote {len(in_window)} rows -> {OUT_VERIFIED.relative_to(ROOT)}")

# =============================================================================
# 6. R2 refined retained-DV: refined re-screen of the kept-DV universe (1,309)
#    -> refined-INs + the 5 FR force-keeps held IN over refined-OUT.
# =============================================================================
run_rows = load_rows(REFINED_RUN)
labels = [(r.get("label") or "").strip().upper() for r in run_rows]
assert all(l in {"IN", "OUT"} for l in labels), "unexpected labels in refined keptdv run"
assert len(run_rows) == 1309, f"expected 1,309 refined keptdv rows, got {len(run_rows)}"

run_canon = canon_index(run_rows)
assert all(len(v) == 1 for v in run_canon.values()), "refined keptdv canon collisions"
refined_in = {canon(r.get("id")) for r in run_rows
              if (r.get("label") or "").strip().upper() == "IN"}
refined_out = {canon(r.get("id")) for r in run_rows
               if (r.get("label") or "").strip().upper() == "OUT"}
assert len(refined_in) == 524, f"refined-IN count {len(refined_in)} != 524"
assert len(refined_out) == 785, f"refined-OUT count {len(refined_out)} != 785"
assert not (refined_in & refined_out), "refined IN/OUT sets overlap"

fk_canon = set()
for raw in R2_FORCE_KEEPS:
    q = canon(raw)
    assert q in epq_fmt, f"force-keep {raw} not in epq"
    assert q in refined_out, f"force-keep {raw} is not refined-OUT"
    fk_canon.add(q)
union = refined_in | fk_canon
assert len(union) == 529, len(union)
print(f"R2 refined keptdv census: {len(run_rows)} screened | "
      f"IN {len(refined_in)} / OUT {len(refined_out)} | "
      f"+ force-keeps {len(fk_canon)} held over refined-OUT | union {len(union)}")

# universe integrity: all 1,309 keptdv ids in epq, DV1, in-window
univ = []
for r in load_rows(KEPTDV):
    q = canon(r.get("id"))
    rid = epq_fmt.get(q)
    assert rid, f"keptdv id {r.get('id')} missing from epq"
    d = parse_date(epq_date[rid])
    assert term_of(d), f"keptdv id outside window: {rid} ({epq_date[rid]})"
    assert epq_dv[rid] == 1, f"keptdv id not DV1 in epq: {rid}"
    univ.append(q)
assert len(univ) == 1309 and len(set(univ)) == 1309
assert refined_in <= set(univ), "refined-IN leaked outside the universe"

ov2 = refined_in & {v["canon_id"] for v in verified}
assert not ov2, f"R2 refined-INs overlap with verified-INs: {sorted(ov2)}"

r2_rows = [{"id": epq_fmt[q], "canon_id": q,
            "source": "force_keep" if q in fk_canon else "refined_in",
            "epq_date": epq_date[epq_fmt[q]],
            "term": term_of(parse_date(epq_date[epq_fmt[q]]))}
           for q in sorted(union, key=lambda x: epq_date[epq_fmt[x]])]
r2_per_term = {t: sum(1 for r in r2_rows if r["term"] == t)
               for t in ("VII", "VIII", "IX")}
print(f"R2 union per term: {r2_per_term}")

cols2 = ["id", "canon_id", "source", "epq_date", "term"]
with open(OUT_REFINED, "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=cols2)
    w.writeheader()
    w.writerows(r2_rows)
print(f"wrote {len(r2_rows)} rows -> {OUT_REFINED.relative_to(ROOT)}")

# =============================================================================
# 7. Summary
# =============================================================================
print("\n=== SUMMARY ===")
print(f"R1 additive overlay   : {len(in_window)} verified-INs "
      f"(258 sheet INs - {len(pre_window)} pre-window); DV 1,319 + 255 = 1,574")
print(f"R2 replacement DV     : {len(union)} retained-DV ids + {len(in_window)} "
      f"verified-INs = {len(union) + len(in_window)}")
