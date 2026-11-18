#!/usr/bin/env python3
"""Build FR's arbitration sheet for path C (section 7d): refined-only FNs + FPs.

Recomputes the FN/FP sets from the already-computed run outputs (refined run on
the gold ids, phase-0 full run post-hoc join) and asserts the session-log counts
(ORIGINAL 76/16/14/228; REFINED 65/27/8/234; refined-only FN = 13; refined FP = 8),
then writes one to-code row per item: gold provenance, both LLM labels, refined
reason code, triage_fp subject tag, the 2026-11-17 session-log body triage where
it exists, FR's 180-sample ruling where the id overlaps, a body excerpt + url
from the corpus, and empty FR_decision / FR_notes columns for FR. No LLM calls.
Run from the project root: python3 explorations/llm_screen/build_arbitration_sheet.py
"""
import csv
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import triage_fp  # noqa: E402

ROOT = Path("/home/federusso/progetti/EPmigrants")
VAL = ROOT / "data/dv201_validation_decisions_FR.csv"
PREC = ROOT / "data/dv201_precision_sample_tocode.csv"
ADJ = ROOT / "data/dv201_llm_adjudication_sample_tocode.csv"
CORPUS = ROOT / "data_raw/epq_3.0.csv"
REFINED = ROOT / "output/llm_screen/refined_glm_body_gold.csv"
ORIGINAL = ROOT / "output/llm_screen/full_glm_body.csv"
OUT = ROOT / "data/dv201_arbitration_tocode.csv"

# 2026-11-17 session-log §2c body triage (the 6 non-language concerning cases)
PRIOR = {
    "E-001045/2021": "by-design (autochthonous-national family hit in body)",
    "E-001218/2022": "refugee/discrimination framing; borderline",
    "E-005645/2011": "refugee/discrimination framing; borderline",
    "E-012873/2015": "body is subsidy-fraud procedure; LLM 'other' defensible",
    "E-003602/2016": "body is anti-bullying programme; gold IN questionable",
    "P-005607/2021": "body carries racism_racial nexus, gold IN defensible; "
                     "strongest genuine refined miss",
}


def load_rows(path):
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
        return list(csv.DictReader(fh))


def canon(qid):
    """Fold zero-padding variants (E-1836/2010 == E-001836/2010)."""
    qid = (qid or "").strip()
    m = re.match(r"^([EP])-(\d+)/(\d+)$", qid)
    return f"{m.group(1)}-{int(m.group(2))}/{m.group(3)}" if m else qid


def load_gold(last_wins=True):
    """id -> IN/OUT from the two FR hand-coding files (dict merge)."""
    gold = {}
    for path in (VAL, PREC):
        for r in load_rows(path):
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
            if last_wins or qid not in gold:
                gold[qid] = lab
    return gold


def pick_gold(ref):
    """Resolve merge order empirically vs the refined run's gold_label column."""
    best = None
    for last_wins in (True, False):
        gold = load_gold(last_wins=last_wins)
        mism = [q for q in ref if gold.get(q) != ref[q].get("gold_label")]
        if best is None or len(mism) < len(best[2]):
            best = (last_wins, gold, mism)
    return best


def confusion(gold, labels):
    """Confusion matrix restricted to ids the run actually labeled."""
    tp = fn = fp = tn = 0
    fn_ids, fp_ids = [], []
    for qid, gl in gold.items():
        r = labels.get(qid)
        if not r:
            continue
        if gl == "IN":
            if r["label"] == "IN":
                tp += 1
            else:
                fn += 1
                fn_ids.append(qid)
        elif r["label"] == "OUT":
            tn += 1
        else:
            fp += 1
            fp_ids.append(qid)
    return tp, fn, fp, tn, fn_ids, fp_ids


def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * (p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5 / d
    return c - h, c + h


def main():
    ref = {r["id"]: r for r in load_rows(REFINED) if r.get("label") in ("IN", "OUT")}
    old = {r["id"]: r for r in load_rows(ORIGINAL) if r.get("label") in ("IN", "OUT")}
    last_wins, gold, mism = pick_gold(ref)
    print(f"gold merged: {len(gold)} {dict(Counter(gold.values()))} "
          f"(merge={'last' if last_wins else 'first'}-row-wins; join mismatches "
          f"vs refined gold_label: {len(mism)})")

    o = confusion(gold, old)
    n = confusion(gold, ref)
    fn_only = sorted(q for q in n[4] if q not in set(o[4]))
    print(f"ORIGINAL TP/FN/FP/TN: {o[0]}/{o[1]}/{o[2]}/{o[3]}")
    print(f"REFINED  TP/FN/FP/TN: {n[0]}/{n[1]}/{n[2]}/{n[3]}")
    print(f"refined-only FN: {len(fn_only)} | refined FP: {len(n[5])}")
    assert (o[0], o[1], o[2], o[3]) == (76, 16, 14, 228), "original replication drifted"
    assert (n[0], n[1], n[2], n[3]) == (65, 27, 8, 234), "refined counts drifted"

    origin = {}
    for r in load_rows(VAL):
        qid = (r.get("id") or "").strip()
        if not qid:
            continue
        txt = (f"validation_decisions_FR.csv/{(r.get('source') or '').strip()} "
               f"decision={(r.get('decision') or '').strip()}")
        notes = (r.get("FR_notes") or "").strip()
        if notes:
            txt += f" notes={notes[:110]}"
        origin.setdefault(qid, []).append(txt)
    for r in load_rows(PREC):
        qid = (r.get("id") or "").strip()
        if not qid:
            continue
        txt = f"precision_sample_tocode.csv on_scope={(r.get('on_scope') or '').strip()}"
        notes = (r.get("FR_notes") or "").strip()
        if notes:
            txt += f" notes={notes[:110]}"
        origin.setdefault(qid, []).append(txt)

    adj = {}
    for r in load_rows(ADJ):
        qid = (r.get("id") or "").strip()
        if not qid:
            continue
        notes = (r.get("FR_notes") or "").strip()
        adj[qid] = f"11-17 sample ruling: {(r.get('on_scope') or '').strip()}"
        if notes:
            adj[qid] += f" ({notes[:110]})"

    targets = fn_only + sorted(n[5])
    tcanon = {canon(q): q for q in targets}
    corp = {}
    with open(CORPUS, newline="", encoding="utf-8-sig", errors="replace") as fh:
        for r in csv.DictReader(fh):
            qid = (r.get("id") or "").strip()
            t = tcanon.get(canon(qid)) if qid else None
            if t and t not in corp:
                corp[t] = (r.get("url") or "", r.get("text") or "")
                if len(corp) == len(targets):
                    break
    missing = [q for q in targets if q not in corp]
    if missing:
        print("WARNING no corpus row for:", missing)
    fieldnames = ["type", "id", "date", "term", "subject", "url", "gold_origin",
                  "gold_label", "orig_llm_label", "orig_reason",
                  "refined_llm_label", "refined_reason", "rule_tag",
                  "prior_triage", "adjud180_ruling", "body_excerpt",
                  "FR_decision", "FR_notes"]
    out_rows = []
    for typ, ids in (("refined-only_FN", fn_only), ("refined_FP", n[5])):
        for q in sorted(ids, key=lambda q: ref[q].get("date") or ""):
            rr, oo = ref[q], old.get(q, {})
            url, text = corp.get(q, ("", ""))
            subj = rr.get("subject") or ""
            fp_h = triage_fp.hits(subj, triage_fp.FP_PATTERNS)
            tp_h = triage_fp.hits(subj, triage_fp.TP_PATTERNS)
            tag = ("FP-family:" + ",".join(fp_h)) if fp_h else \
                  (("TP-family:" + ",".join(tp_h)) if tp_h else "no-signal")
            excerpt = " ".join((text or "").split())
            if len(excerpt) > 700:
                excerpt = excerpt[:700] + " …"
            out_rows.append({
                "type": typ, "id": q, "date": rr.get("date") or "",
                "term": rr.get("term") or "", "subject": subj, "url": url,
                "gold_origin": " || ".join(origin.get(q, [])),
                "gold_label": gold.get(q, ""),
                "orig_llm_label": oo.get("label") or "",
                "orig_reason": oo.get("reason") or "",
                "refined_llm_label": rr["label"],
                "refined_reason": rr.get("reason") or "",
                "rule_tag": tag, "prior_triage": PRIOR.get(q, ""),
                "adjud180_ruling": adj.get(q, ""), "body_excerpt": excerpt,
                "FR_decision": "", "FR_notes": ""})
    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(out_rows)
    print(f"wrote {len(out_rows)} rows -> {OUT}")
    for b in out_rows:
        print(f"  {b['type']:<15} {b['id']:<16} {b['gold_label']}->"
              f"{b['refined_llm_label']:<4} [{b['rule_tag'][:28]:<28}] "
              f"{b['subject'][:50]}")


if __name__ == "__main__":
    main()

