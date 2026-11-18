#!/usr/bin/env python3
"""Step 4 (§7d, FR decision A): majority vote of the two refined runs on the 1,421
original LLM-IN candidates, plus the FR-facing arbitration sheet for the refined
candidate pool.

run1 = refined_glm_body_candidates.csv   (2026-11-17 09:31, pre-halt run, err=0)
run2 = refined2_glm_body_candidates.csv  (2026-11-17, decision-A re-screen)

Pool for FR coding = rows with at least one IN across the two runs:
agree_IN (2/2) + split (1/2); agree_OUT rows drop out of the pool.
Writes data/dv201_llm_candidates_majority_tocode.csv and prints the census.
No LLM calls. Run from the project root.
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path("/home/federusso/progetti/EPmigrants")
RUN1 = ROOT / "output/llm_screen/refined_glm_body_candidates.csv"
RUN2 = ROOT / "output/llm_screen/refined2_glm_body_candidates.csv"
TRIAGE = ROOT / "output/llm_screen/candidates_ruletriage.csv"
M1 = ROOT / "output/llm_screen/refined_glm_body_candidates_meta.json"
M2 = ROOT / "output/llm_screen/refined2_glm_body_candidates_meta.json"
CORPUS = ROOT / "data_raw/epq_3.0.csv"
OUT = ROOT / "data/dv201_llm_candidates_majority_tocode.csv"


def load_rows(path):
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
        return list(csv.DictReader(fh))


def canon(qid):
    """Fold zero-padding variants (E-1836/2010 == E-001836/2010)."""
    qid = (qid or "").strip()
    m = re.match(r"^([EP])-(\d+)/(\d+)$", qid)
    return f"{m.group(1)}-{int(m.group(2))}/{m.group(3)}" if m else qid


def index_run(rows):
    idx = {}
    for r in rows:
        q = canon(r.get("id"))
        if not q or q in idx:
            continue
        idx[q] = r
    return idx


idx1 = index_run(load_rows(RUN1))
idx2 = index_run(load_rows(RUN2))
assert set(idx1) == set(idx2), (len(idx1), len(idx2), "run id sets differ")
n = len(idx1)

tri = {}
for r in load_rows(TRIAGE):
    q = canon(r.get("id"))
    if q and q not in tri:
        tri[q] = r

pool_ids = [q for q in sorted(idx1) if "IN" in (idx1[q].get("label"), idx2[q].get("label"))]
pset = set(pool_ids)
corp = {}
with open(CORPUS, newline="", encoding="utf-8-sig", errors="replace") as fh:
    for r in csv.DictReader(fh):
        q = canon(r.get("id"))
        if q in pset and q not in corp:
            corp[q] = (r.get("url") or "", r.get("text") or "")

missing_text = [q for q in pool_ids if q not in corp]


def type_of(l1, l2):
    if l1 == "IN" and l2 == "IN":
        return "agree_IN"
    if l1 == "OUT" and l2 == "OUT":
        return "agree_OUT"
    return "split"


fieldnames = ["type", "id", "date", "term", "subject", "lang", "url",
              "rule_category", "known_fr_from_sample",
              "run1_label", "run1_reason", "run1_conf",
              "run2_label", "run2_reason", "run2_conf",
              "body_excerpt", "FR_decision", "FR_notes"]
rows = []
for q in sorted(idx1):
    a, b = idx1[q], idx2[q]
    l1, l2 = (a.get("label") or "").strip(), (b.get("label") or "").strip()
    typ = type_of(l1, l2)
    if typ == "agree_OUT":
        continue
    t = tri.get(q, {})
    url, text = corp.get(q, ("", ""))
    excerpt = " ".join((text or "").split())
    if len(excerpt) > 700:
        excerpt = excerpt[:700] + " …"
    rows.append({
        "type": typ, "id": q, "date": a.get("date") or "",
        "term": a.get("term") or "", "subject": a.get("subject") or "",
        "lang": a.get("lang") or "", "url": url,
        "rule_category": (t.get("category") or "").strip(),
        "known_fr_from_sample": (t.get("known_fr_from_sample") or "").strip(),
        "run1_label": l1, "run1_reason": a.get("reason") or "",
        "run1_conf": a.get("confidence") or "",
        "run2_label": l2, "run2_reason": b.get("reason") or "",
        "run2_conf": b.get("confidence") or "",
        "body_excerpt": excerpt, "FR_decision": "", "FR_notes": ""})

# split rows first (the informative ones), then agree_IN, both by date
rows.sort(key=lambda r: (0 if r["type"] == "split" else 1, r["date"]))
with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(rows)

meta = {p.name: json.load(open(p)) for p in (M1, M2)}
census = {"agree_IN": 0, "agree_OUT": 0, "split": 0}
per_term = {}
run1_in = run2_in = 0
for q in sorted(idx1):
    l1 = (idx1[q].get("label") or "").strip()
    l2 = (idx2[q].get("label") or "").strip()
    run1_in += l1 == "IN"
    run2_in += l2 == "IN"
    c = type_of(l1, l2)
    census[c] += 1
    if c != "agree_OUT":
        term = idx1[q].get("term") or "?"
        per_term[term] = per_term.get(term, 0) + 1
m1, m2 = meta[M1.name], meta[M2.name]
print(f"runs compared: {n} ids | run1 IN={run1_in} run2 IN={run2_in}")
print("vote census:", census)
print("pool for FR coding (>=1 IN):", len(rows), "per term:", per_term)
print(f"pool share: {100 * len(rows) / n:.1f}% of the 1,421 original candidates")
print(f"tokens: run1 prompt={m1['prompt_tokens']:,} eval={m1['eval_tokens']:,} | "
      f"run2 prompt={m2['prompt_tokens']:,} eval={m2['eval_tokens']:,}")
print(f"errors: run1={len(m1['errors'])} run2={len(m2['errors'])}")
print(f"wrote {len(rows)} rows -> {OUT.relative_to(ROOT)}")
if missing_text:
    print("WARNING no corpus row for:", missing_text[:10])
