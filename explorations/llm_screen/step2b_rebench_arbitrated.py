#!/usr/bin/env python3
"""Step-2b re-benchmark: apply FR's arbitration decisions to the gold-334.

Reads data/dv201_arbitration_tocode.csv (FR_decision IN/OUT/DROP; blank keeps
the current gold label), applies the decisions on top of the two FR hand-coding
files, and reprints ORIGINAL (phase-0 post-hoc join) and REFINED confusion
matrices with Wilson CIs on the ALREADY-COMPUTED LLM labels — zero LLM cost.
Applied changes are mirrored to data/dv201_gold_arbitration_overrides.csv
(provenance for the memo §11 addendum). Dry-run with a blank sheet must
reproduce the halt numbers exactly: ORIGINAL 76/16/14/228 (recall .826 /
precision .844) and REFINED 65/27/8/234 (recall .707 / precision .890).
Run from the project root: python3 explorations/llm_screen/step2b_rebench_arbitrated.py
"""
import csv
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import build_arbitration_sheet as base  # noqa: E402

ROOT = base.ROOT
SHEET = ROOT / "data/dv201_arbitration_tocode.csv"
OVERR = ROOT / "data/dv201_gold_arbitration_overrides.csv"


def main():
    ref = {r["id"]: r for r in base.load_rows(base.REFINED)
           if r.get("label") in ("IN", "OUT")}
    old = {r["id"]: r for r in base.load_rows(base.ORIGINAL)
           if r.get("label") in ("IN", "OUT")}
    _, gold, mism = base.pick_gold(ref)
    print(f"gold merged: {len(gold)} {dict(Counter(gold.values()))} "
          f"(join mismatches: {len(mism)})")

    try:
        sheet = base.load_rows(SHEET)
    except FileNotFoundError:
        raise SystemExit(f"arbitration sheet missing: {SHEET}")
    applied, dropped = [], []
    for r in sheet:
        qid = (r.get("id") or "").strip()
        dec = (r.get("FR_decision") or "").strip().upper()
        if not qid or not dec:
            continue
        if qid not in gold:
            raise SystemExit(f"FR_decision on non-benchmark id: {qid}")
        if dec not in ("IN", "OUT", "DROP"):
            raise SystemExit(f"invalid FR_decision '{dec}' for {qid} (IN/OUT/DROP)")
        before = gold[qid]
        if dec == "DROP":
            del gold[qid]
            dropped.append((qid, before, "", (r.get("FR_notes") or "").strip()))
        elif dec != before:
            gold[qid] = dec
            applied.append((qid, before, dec, (r.get("FR_notes") or "").strip()))
    print(f"applied label changes: {len(applied)} | dropped from benchmark: {len(dropped)}")
    for qid, before, after, notes in applied + dropped:
        arrow = after if after else "DROP"
        print(f"  {qid:<16} {before:<4} -> {arrow:<5} {notes[:80]}")
    if applied or dropped:
        with open(OVERR, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["id", "gold_before", "FR_decision", "gold_after", "FR_notes"])
            for qid, before, after, notes in applied:
                w.writerow([qid, before, after, after, notes])
            for qid, before, after, notes in dropped:
                w.writerow([qid, before, "DROP", "", notes])
        print("wrote", OVERR, "(drop rows keep gold_after blank)")
    else:
        print("decisions blank -> DRY RUN (gold unchanged)")

    o = base.confusion(gold, old)
    n = base.confusion(gold, ref)
    for tag, c in (("ORIGINAL", o), ("REFINED ", n)):
        tp, fn, fp, tn = c[:4]
        rlo, rhi = base.wilson(tp, tp + fn)
        plo, phi = base.wilson(tp, tp + fp)
        rec = tp / max(tp + fn, 1)
        prc = tp / max(tp + fp, 1)
        print(f"[{tag}] n={tp+fn+fp+tn} TP={tp} FN={fn} FP={fp} TN={tn}  "
              f"recall={rec:.3f} Wilson95[{rlo:.3f},{rhi:.3f}]  "
              f"precision={prc:.3f} Wilson95[{plo:.3f},{phi:.3f}]")
    print("ORIGINAL FN ids:", o[4])
    print("ORIGINAL FP ids:", o[5])
    print("REFINED  FN ids:", n[4])
    print("REFINED  FP ids:", n[5])
    print("gold after:", len(gold), dict(Counter(gold.values())))


if __name__ == "__main__":
    main()