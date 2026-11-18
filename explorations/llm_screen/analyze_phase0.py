#!/usr/bin/env python3
"""
Phase 0 analysis for the LLM screen (EPmigrants).

Reads the phase-0 output files written by scripts/08_llm_screen.py:
  output/llm_screen/bench_glmflash_body.csv     (334 gold + 1,498 pilot rows)
  output/llm_screen/bench_glmflash_subject.csv  (334 gold rows)
  output/llm_screen/bench_gemma31b_body.csv     (334 gold rows)
joins the gold hand codes (data/dv201_validation_decisions_FR.csv,
data/dv201_precision_sample_tocode.csv), and prints confusion matrices,
per-source recall, reason-code cross-tabs, pilot yield, and full-run
projections. Run from the repo root:

  python3 explorations/llm_screen/analyze_phase0.py
"""

import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_gold():
    gold = {}
    with open(ROOT / "data/dv201_validation_decisions_FR.csv", newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            src = "batchA" if r["source"].startswith("batchA") else "batchB"
            gold[r["id"].strip()] = (r["decision"], src)
    with open(ROOT / "data/dv201_precision_sample_tocode.csv", newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            s = r["on_scope"].strip()
            if s == "IN":
                gold[r["id"].strip()] = ("IN", "prec")
            else:
                tag = ("extraEU" if "extra" in s.lower() else
                       "nondisc" if "non-discrim" in s.lower() else
                       "nonethnic" if "non-ethnic" in s.lower() else "other")
                gold[r["id"].strip()] = ("OUT", "prec_" + tag)
    return gold


def confusion(rows, gold):
    tp = fp = fn = tn = 0
    bysrc = Counter(); fn_rows = []; fp_rows = []
    for r in rows:
        q = r["id"].strip()
        if q not in gold:
            continue
        g, src = gold[q]
        lab = r["label"]
        bysrc[(src, g, lab)] += 1
        if g == "IN" and lab == "IN":
            tp += 1
        elif g == "IN":
            fn += 1; fn_rows.append((q, src, r["reason"]))
        elif lab == "IN":
            fp += 1; fp_rows.append((q, src, r["subject"][:52]))
        else:
            tn += 1
    n = tp + fp + fn + tn
    metrics = {"n": n, "acc": (tp + tn) / n, "prec": tp / max(tp + fp, 1),
               "rec": tp / max(tp + fn, 1), "F1": 2 * tp / max(2 * tp + fp + fn, 1),
               "TP": tp, "FP": fp, "FN": fn, "TN": tn}
    return metrics, bysrc, fn_rows, fp_rows


def report(path, gold, name):
    rows = list(csv.DictReader(open(ROOT / path, newline="", encoding="utf-8")))
    m, bysrc, fnr, fpr = confusion(rows, gold)
    print(f"{name}: n={m['n']} acc={m['acc']:.3f} prec={m['prec']:.3f} "
          f"rec={m['rec']:.3f} F1={m['F1']:.3f} (TP={m['TP']} FP={m['FP']} "
          f"FN={m['FN']} TN={m['TN']})")
    srcs = sorted(set(k[0] for k in bysrc))
    for s in srcs:
        a = bysrc.get((s, "IN", "IN"), 0)
        b = bysrc.get((s, "IN", "OUT"), 0)
        c = bysrc.get((s, "OUT", "OUT"), 0)
        d = bysrc.get((s, "OUT", "IN"), 0)
        print(f"    {s:9s} recall {a}/{a + b} = {a / max(a + b, 1):.2f} | "
              f"specificity {c}/{c + d} = {c / max(c + d, 1):.2f}")
    return m, fnr, fpr, rows

def main():
    gold = load_gold()
    print(f"gold: {len(gold)} ids ({dict(Counter(g for g, _ in gold.values()))})\n")

    mb, fnb, fpb, rows_g = report(
        "output/llm_screen/bench_glmflash_body.csv", gold, "GLM-5.3-flash BODY")
    ms, fns, fps, rows_s = report(
        "output/llm_screen/bench_glmflash_subject.csv", gold, "GLM-5.3-flash SUBJECT")
    mm, fnm, fpm, rows_m = report(
        "output/llm_screen/bench_gemma31b_body.csv", gold, "gemma4:31b BODY")

    print("\nFN detail, GLM body (gold IN -> LLM OUT):")
    for q, src, rsn in fnb:
        print(f"    {q:22s} {src:7s} -> LLM reason: {rsn}")
    print(f"\nFP detail, GLM body (gold OUT -> LLM IN), all {len(fpb)}:")
    for q, src, subj in fpb:
        print(f"    {q:22s} {src:7s} {subj}")

    rc = Counter((gold[r["id"].strip()][1], r["reason"])
                 for r in rows_g
                 if r["id"].strip() in gold and r["label"] == "OUT"
                 and gold[r["id"].strip()][0] == "OUT")
    print("\ngold OUT -> LLM OUT-reason cross-tab (GLM body):")
    for k, v in sorted(rc.items()):
        print(f"    {k[0]:12s} -> {k[1]:18s} {v}")

    pilot = [r for r in rows_g if r["id"].strip() not in gold]
    byt = Counter((r["term"], r["label"]) for r in pilot)
    print(f"\nPILOT (GLM body): n={len(pilot)}")
    for t in ("VII", "VIII", "IX"):
        i = byt.get((t, "IN"), 0); o = byt.get((t, "OUT"), 0)
        print(f"    {t}: n={i + o} IN={i} ({100 * i / max(i + o, 1):.2f}%)")
    pin = sum(byt.get((t, "IN"), 0) for t in ("VII", "VIII", "IX"))
    print(f"    ALL raw IN rate: {100 * pin / max(len(pilot), 1):.2f}%")

    wanted = {r["id"].strip() for r in pilot}
    subjmap = {}
    with open(ROOT / "data/epq.csv", newline="", encoding="utf-8", errors="replace") as fh:
        for r in csv.DictReader(fh):
            q = (r.get("id") or "").strip()
            if q in wanted and q not in subjmap:
                subjmap[q] = (r.get("major") or "", r.get("subtopic") or "")
    in201 = sum(1 for r in pilot if r["label"] == "IN"
                and subjmap.get(r["id"].strip(), ("", ""))[1] == "201")
    in_not201 = sum(1 for r in pilot if r["label"] == "IN"
                    and r["id"].strip() in subjmap
                    and subjmap[r["id"].strip()][1] != "201")
    out201 = sum(1 for r in pilot if r["label"] == "OUT"
                 and subjmap.get(r["id"].strip(), ("", ""))[1] == "201")
    print(f"    LLM INs inside CAP-201 net: {in201} | outside CAP-201 (candidates): {in_not201}")
    print(f"    LLM OUTs that sit in CAP-201 (already keyword-screened FPs): {out201}")

    m1 = json.load(open(ROOT / "output/llm_screen/bench_glmflash_body_meta.json"))
    n1 = m1["labels"]["IN"] + m1["labels"]["OUT"]
    per_call = {"prompt": m1["prompt_tokens"] / n1, "eval": m1["eval_tokens"] / n1}
    subj_prompt = 152152 / 334
    print("\nPROJECTIONS (full run n=125,081):")
    print(f"    body:    {125081 * per_call['prompt'] / 1e6:.0f}M prompt + "
          f"{125081 * per_call['eval'] / 1e6:.1f}M eval tokens")
    print(f"    subject: {125081 * subj_prompt / 1e6:.0f}M prompt tokens")

    cache = {
        "metrics": {"glm_body": mb, "glm_subject": ms, "gemma_body": mm},
        "fn_glm_body": fnb, "fp_glm_body": fpb,
        "pilot_IN_ids": [r["id"].strip() for r in pilot if r["label"] == "IN"],
        "pilot_IN_outside201":
            [r["id"].strip() for r in pilot if r["label"] == "IN"
             and subjmap.get(r["id"].strip(), ("", ""))[1] != "201"],
        "tokens_per_call": {k: round(v, 1) for k, v in per_call.items()},
    }
    out = ROOT / "output/llm_screen/phase0_analysis_cache.json"
    out.write_text(json.dumps(cache, indent=1), encoding="utf-8")
    print(f"\nanalysis cache -> {out}")


if __name__ == "__main__":
    main()
