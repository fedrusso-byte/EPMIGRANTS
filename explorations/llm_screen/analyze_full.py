#!/usr/bin/env python3
"""
Full-run analysis for the LLM screen (EPmigrants).

Reads the final full-corpus output (output/llm_screen/full_glm_body.csv,
i.e. run 1 + the post-429 retry pass), joins the 334 gold hand codes
(same join as analyze_phase0.py), and prints:

  1. confusion metrics with Wilson 95% CIs, per-source recall/specificity;
  2. the rescreen replication: LLM labels on the 1,319 kept-DV rows
     (1,291 subtopic-201) under benchmark params;
  3. full-corpus patterns: IN rate by term, OUT reason distribution;
  4. token totals (run 1 + retry passes).

Exports:
  data/dv201_llm_candidates_tocode.csv
      every LLM-IN outside the kept-DV net, in the existing FR batch
      format (memo 7c-b) plus lang, llm_reason, the verbatim LLM text
      input (as sent, 260-word cap) and the full corpus text;
  data/dv201_llm_adjudication_sample_tocode.csv
      optional memo 7c-a sample: 30 pilot INs + 150 random pilot OUTs
      (seed 42), same extended format;
  output/llm_screen/fullrun_analysis_cache.json

Run from the repo root:  python3 explorations/llm_screen/analyze_full.py
"""

import csv
import json
import math
import random
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WINDOW_LO, WINDOW_HI = "2009-07-14", "2024-07-15"
BATCH_FIELDS = ["id", "date", "term", "subject", "subtopic", "on_scope", "FR_notes"]
# 2026-11-14: FR asked for the question text in the two adjudication files.
EXPORT_FIELDS = BATCH_FIELDS + ["lang", "llm_reason", "text_llm_input", "text_full"]
BODY_MAX_WORDS = 260          # mirrors scripts/08_llm_screen.py


def norm_full_text(text):
    """Complete corpus text, whitespace-collapsed (nothing dropped, no cap)."""
    return re.sub(r"\s+", " ", text or "").strip()


def body_llm_input(text):
    """Verbatim replication of scripts/08_llm_screen.py::normalize_body (mode --body).

    Keep in sync with the screen script: drops everything before the first
    newline (the screen's 'document header' rule) and caps at BODY_MAX_WORDS
    words with a '[...]' marker.
    """
    if not text:
        return ""
    body = text.split("\n", 1)[1] if "\n" in text else text
    body = re.sub(r"\s+", " ", body).strip()
    words = body.split(" ")
    if len(words) > BODY_MAX_WORDS:
        body = " ".join(words[:BODY_MAX_WORDS]) + " [...]"
    return body


def body_truncated(text):
    return body_llm_input(text).endswith("[...]")


def load_text_map(ids):
    """Single streaming pass over the corpus -> {id: original text} for ids."""
    found, left = {}, set(ids)
    with open(ROOT / "data_raw/epq_3.0.csv", newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            q = (row.get("id") or "").strip()
            if q in left:
                found[q] = row.get("text") or ""
                left.discard(q)
                if not left:
                    break
    return found


def load_gold():
    """Same gold join as analyze_phase0.py (dict overwrite resolves the 2 conflicting ids)."""
    gold = {}
    with open(ROOT / "data/dv201_validation_decisions_FR.csv", newline="",
              encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            src = "batchA" if r["source"].startswith("batchA") else "batchB"
            gold[r["id"].strip()] = (r["decision"], src)
    with open(ROOT / "data/dv201_precision_sample_tocode.csv", newline="",
              encoding="utf-8") as fh:
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


def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (p, max(0.0, c - h), min(1.0, c + h))


def term_from_date(s):
    try:
        key = int(s[:4]) * 12 + int(s[5:7])
    except (ValueError, IndexError):
        return ""
    if 2009 * 12 + 7 <= key < 2014 * 12 + 7:
        return "VII"
    if key < 2019 * 12 + 7:
        return "VIII"
    if key <= 2024 * 12 + 7:
        return "IX"
    return ""


def main():
    gold = load_gold()
    meta, kept = load_meta_and_kept()
    meta201 = {q for q in kept if meta.get(q, {}).get("subtopic") == "201"}
    print(f"gold: {len(gold)} ids {dict(Counter(g for g, _ in gold.values()))}; "
          f"kept-DV={len(kept)} (subtopic-201: {len(meta201)})")

    rows = [r for r in csv.DictReader(open(ROOT / "output/llm_screen/full_glm_body.csv",
                                           newline="", encoding="utf-8"))]
    assert len({r['id'] for r in rows}) == len(rows), "duplicate ids in full run"
    labels = Counter(r["label"] for r in rows)
    print(f"full run: {len(rows)} rows, labels {dict(labels)}\n")

    # ---- 1. confusion vs gold -------------------------------------------------
    tp = fp = fn = tn = 0
    bysrc = Counter()
    fn_rows, fp_rows = [], []
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
            fn += 1
            fn_rows.append((q, src, r["reason"]))
        elif lab == "IN":
            fp += 1
            fp_rows.append((q, src, r["subject"][:52]))
        else:
            tn += 1
    print("FULL-RUN metrics (vs 334 gold):")
    print(conf_int_line("accuracy   ", tp + tn, tp + fp + fn + tn))
    print(conf_int_line("precision  ", tp, tp + fp))
    print(conf_int_line("recall     ", tp, tp + fn))
    print(conf_int_line("F1 (point) ", 2 * tp, 2 * tp + fp + fn))
    for s in ("batchA", "batchB", "prec"):
        a = bysrc.get((s, "IN", "IN"), 0)
        b = bysrc.get((s, "IN", "OUT"), 0)
        c = bysrc.get((s, "OUT", "OUT"), 0)
        d = bysrc.get((s, "OUT", "IN"), 0)
        print(f"    {s:7s} recall {a}/{a + b} = {a / max(a + b, 1):.2f} | "
              f"specificity {c}/{c + d} = {c / max(c + d, 1):.2f}")
    print("    FN detail (gold IN -> LLM OUT):")
    for q, src, rsn in fn_rows:
        print(f"        {q:22s} {src:7s} {rsn}")

    # ---- 2. rescreen replication ----------------------------------------------
    kin = [r for r in rows if r["id"].strip() in kept]
    k201 = [r for r in kin if r["id"].strip() in meta201]
    for name, subset in (("kept-DV (1,319)", kin), ("subtopic-201 (1,291)", k201)):
        i = sum(1 for r in subset if r["label"] == "IN")
        o = sum(1 for r in subset if r["label"] == "OUT")
        t = dict(Counter(r["label"] for r in subset
                         if r["label"] not in ("IN", "OUT")))
        line = conf_int_line(f"LLM PASS on {name}", i, i + o)
        print(line + (f"  other labels {t}" if t else ""))
        if name.startswith("subtopic"):
            for term in ("VII", "VIII", "IX"):
                sub = [r for r in subset
                       if meta.get(r["id"].strip(), {}).get("term") == term]
                a = sum(1 for r in sub if r["label"] == "IN")
                print(f"        {term}: PASS {a}/{len(sub) if sub else 0}")

    # ---- 3. full-corpus patterns ------------------------------------------------
    print("\nFULL-CORPUS patterns:")
    byt = Counter((meta.get(r["id"].strip(), {}).get("term", "?"), r["label"])
                  for r in rows if r["label"] in ("IN", "OUT"))
    for t in ("VII", "VIII", "IX", "?"):
        i, o = byt.get((t, "IN"), 0), byt.get((t, "OUT"), 0)
        n = i + o
        if n:
            print(f"    term {t}: n={n} IN={i} ({100 * i / n:.2f}%)")
    outs = [r for r in rows if r["label"] == "OUT"]
    for rsn, v in Counter(r["reason"] or "(blank)" for r in outs).most_common():
        print(f"    OUT reason {rsn:20s} {v} ({100 * v / len(outs):.1f}%)")

    # ---- 4. tokens ---------------------------------------------------------------
    tot_p = tot_e = 0
    for mf in ("full_glm_body_meta_run1.json", "full_glm_body_meta.json"):
        p = ROOT / "output/llm_screen" / mf
        if p.exists():
            m = json.load(open(p))
            tot_p += m.get("prompt_tokens", 0)
            tot_e += m.get("eval_tokens", 0)
            print(f"    {mf}: prompt={m.get('prompt_tokens', 0):,} "
                  f"eval={m.get('eval_tokens', 0):,}")
    print(f"    TOTAL: prompt {tot_p:,} + eval {tot_e:,} tokens")

    # ---- 5. exports ---------------------------------------------------------------
    cands = [r for r in rows if r["label"] == "IN" and r["id"].strip() not in kept]
    pilot_ids = {(r.get("id") or "").strip()
                 for r in csv.DictReader(open(ROOT / "data/dv201_llm_pilot_ids.csv",
                                              newline="", encoding="utf-8"))}
    pilot = [r for r in rows if r["id"].strip() in pilot_ids
             and r["id"].strip() not in gold]
    pin = [r for r in pilot if r["label"] == "IN"]
    pout = [r for r in pilot if r["label"] == "OUT"]
    rs = random.Random(42)
    sample = pin + rs.sample(pout, min(150, len(pout)))

    export_ids = {r["id"].strip() for r in cands} | {r["id"].strip() for r in sample}
    texts = load_text_map(export_ids)

    def batch_row(r, on_scope):
        q = r["id"].strip()
        mm = meta.get(q, {})
        raw = texts.get(q)
        return {"id": q, "date": mm.get("date", ""), "term": mm.get("term", ""),
                "subject": mm.get("subject", ""),
                "subtopic": mm.get("subtopic", ""), "on_scope": on_scope,
                "FR_notes": "", "lang": r.get("lang", ""),
                "llm_reason": r.get("reason", ""),
                "text_llm_input": body_llm_input(raw) or "(text unavailable)",
                "text_full": norm_full_text(raw)}

    with open(ROOT / "data/dv201_llm_candidates_tocode.csv", "w", newline="",
              encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=EXPORT_FIELDS)
        w.writeheader()
        w.writerows(batch_row(r, "IN") for r in cands)
    with open(ROOT / "data/dv201_llm_adjudication_sample_tocode.csv", "w",
              newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=EXPORT_FIELDS)
        w.writeheader()
        w.writerows(batch_row(r, r["label"]) for r in sample)

    print(f"\ncandidates (LLM-IN outside kept-DV): {len(cands)} "
          f"-> data/dv201_llm_candidates_tocode.csv")
    nok = sum(1 for r in cands if r["id"].strip() not in meta)
    print(f"    candidates missing from data_processed/epq.csv "
          f"(term/subtopic left blank): {nok}")
    print(f"7c(a) sample: {len(pin)} pilot INs + {len(sample) - len(pin)} "
          f"random pilot OUTs -> data/dv201_llm_adjudication_sample_tocode.csv "
          f"(seed 42)")
    nmiss = len(export_ids - set(texts))
    ntr = sum(1 for t in texts.values() if body_truncated(t))
    nml = sum(1 for t in texts.values() if "\n" in (t or ""))
    print(f"    text columns: full text for {len(texts)}/{len(export_ids)} export "
          f"ids (missing: {nmiss}); llm input truncated at 260 words: {ntr}; "
          f"corpus text multiline (screen dropped line 1): {nml}")

    cache = {
        "metrics": {"acc": (tp + tn) / (tp + fp + fn + tn), "prec": tp / max(tp + fp, 1),
                    "rec": tp / max(tp + fn, 1), "TP": tp, "FP": fp, "FN": fn, "TN": tn},
        "fn_ids": [q for q, _, _ in fn_rows],
        "fp_ids": [q for q, _, _ in fp_rows],
        "rescreen": {"kept": len(kin), "kept201": len(k201),
                     "pass201": sum(1 for r in k201 if r["label"] == "IN")},
        "candidates_ids": [r["id"].strip() for r in cands],
        "tokens": {"prompt": tot_p, "eval": tot_e},
        "labels": dict(labels),
    }
    out = ROOT / "output/llm_screen/fullrun_analysis_cache.json"
    out.write_text(json.dumps(cache, indent=1), encoding="utf-8")
    print(f"analysis cache -> {out}")


def load_meta_and_kept():
    """id -> {date, term, subtopic, subject} and the kept-DV id set (paper window)."""
    meta, kept = {}, set()
    with open(ROOT / "data_processed/epq.csv", newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            q = (r.get("id") or "").strip()
            d = (r.get("date") or "").strip()
            if q and q not in meta:
                meta[q] = {"date": d, "term": term_from_date(d),
                           "subtopic": (r.get("subtopic") or "").strip(),
                           "subject": (r.get("subject") or "")}
            if ((r.get("pq_discrimination") or "").strip().upper() in ("TRUE", "1")
                    and WINDOW_LO <= d <= WINDOW_HI):
                kept.add(q)
    with open(ROOT / "data/epq.csv", newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            q = (r.get("id") or "").strip()
            if q and q not in meta:
                d = (r.get("date") or "").strip()
                meta[q] = {"date": d, "term": term_from_date(d),
                           "subtopic": (r.get("subtopic") or "").strip(),
                           "subject": (r.get("subject") or "")}
    return meta, kept


def conf_int_line(name, k, n):
    p, lo, hi = wilson(k, n)
    return f"    {name}: {k}/{n} = {p:.3f} [{lo:.3f}, {hi:.3f}]"


if __name__ == "__main__":
    main()
