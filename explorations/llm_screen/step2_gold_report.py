#!/usr/bin/env python3
"""Step-2 gold-334 re-benchmark analysis (section 7d): refined vs original rubric.

Post-hoc join on output/llm_screen/full_glm_body.csv (phase-0 run whose gold
columns are empty due to the bash-quoting bug, see memo section 8) to recover
the original-rubric FN/FP id sets, then compares with the refined run on the
same 334 gold ids; tags refined FNs with triage_fp rule families; Wilson CIs.
Run from project root: python3 explorations/llm_screen/step2_gold_report.py
"""
import csv
import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import triage_fp  # noqa: E402  (rule families from FR's 180-row adjudication)

ROOT = Path("/home/federusso/progetti/EPmigrants")
GOLD_FILES = [ROOT / "data/dv201_validation_decisions_FR.csv",
              ROOT / "data/dv201_precision_sample_tocode.csv"]
REFINED = ROOT / "output/llm_screen/refined_glm_body_gold.csv"
ORIGINAL = ROOT / "output/llm_screen/full_glm_body.csv"


def load_gold():
    gold = {}
    for p in GOLD_FILES:
        for r in csv.DictReader(open(p, encoding="utf-8-sig", errors="replace")):
            qid = (r.get("id") or "").strip()
            if not qid:
                continue
            dec = (r.get("decision") or "").strip()
            scope = (r.get("on_scope") or "").strip()
            if dec in ("IN", "OUT"):
                lab = dec
            elif scope.startswith("IN"):
                lab = "IN"
            elif "OUT" in scope:
                lab = "OUT"
            else:
                continue
            gold.setdefault(qid, lab)
    return gold


def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return c - h, c + h


def main():
    gold = load_gold()
    print("gold ids merged:", len(gold), Counter(gold.values()))

    ref = {r["id"]: r for r in csv.DictReader(open(REFINED)) if r.get("label")}
    old = {r["id"]: r for r in csv.DictReader(open(ORIGINAL)) if r.get("label")}

    def confusion(labels, tag):
        tp = fn = fp = tn = 0
        fn_ids, fp_ids = [], []
        for qid, gl in gold.items():
            r = labels.get(qid)
            if not r or r["label"] not in ("IN", "OUT"):
                continue
            m = r["label"] == gl
            if gl == "IN":
                if m:
                    tp += 1
                else:
                    fn += 1
                    fn_ids.append(qid)
            else:
                if m:
                    tn += 1
                else:
                    fp += 1
                    fp_ids.append(qid)
        n = tp + fn + fp + tn
        rec, prc = tp / max(tp + fn, 1), tp / max(tp + fp, 1)
        rlo, rhi = wilson(tp, tp + fn)
        plo, phi = wilson(tp, tp + fp)
        print(f"[{tag}] n={n} TP={tp} FN={fn} FP={fp} TN={tn}  "
              f"recall={rec:.3f} Wilson95[{rlo:.3f},{rhi:.3f}]  "
              f"precision={prc:.3f} Wilson95[{plo:.3f},{phi:.3f}]")
        return fn_ids, fp_ids

    old_fn, old_fp = confusion(old, "ORIGINAL")
    new_fn, new_fp = confusion(ref, "REFINED ")

    shared = set(old_fn) & set(new_fn)
    print(f"FN overlap: shared={len(shared)}  original-only="
          f"{len(set(old_fn) - set(new_fn))}  refined-only(new)={len(set(new_fn) - set(old_fn))}")
    print(f"FP ids original: {old_fp}")
    print(f"FP ids refined:  {new_fp}")

    print("\n--- refined FN detail (id | LLM reason | old label | rule-tag | subject):")
    for qid in sorted(new_fn):
        r = ref[qid]
        blob = (r.get("subject") or "") + " || " + " "
        fp_hits = triage_fp.hits(blob, triage_fp.FP_PATTERNS)
        tp_hits = triage_fp.hits(blob, triage_fp.TP_PATTERNS)
        tag = ("FP-family:" + ",".join(fp_hits)) if fp_hits else \
              ("TP-family:" + ",".join(tp_hits)) if tp_hits else "no-signal"
        print(f"  {qid:<20} {r['reason']:<18} old={old.get(qid, {}).get('label', '?'):<4}"
              f" [{tag:<34}] {r['subject'][:58]}")
    fam = Counter((triage_fp.hits(ref[q]["subject"], triage_fp.FP_PATTERNS) or
                   triage_fp.hits(ref[q]["subject"], triage_fp.TP_PATTERNS) or
                   ["no-signal"])[0] for q in new_fn)
    print("refined FN rule-tag counts:", dict(fam))


if __name__ == "__main__":
    main()
