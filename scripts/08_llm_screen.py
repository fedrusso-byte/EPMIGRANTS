#!/usr/bin/env python3
"""
08_llm_screen.py — LLM screen of EP written questions (EPmigrants DV rubric).

Screens European Parliament written questions with an open LLM (served through
the local Ollama daemon at http://localhost:11434, backed by the user's paid
Ollama cloud subscription) against the study's discrimination scope, as
operationalized in the manuscript's dependent-variable paragraph (CAP-201
retention protocol: EU-located ethnic/racial/national/racialised-religious
minority discrimination = IN; extra-EU, non-discrimination, non-ethnic grounds
= OUT with reason codes).

Python standard library only (Python >= 3.9). Uses the Ollama /api/chat
endpoint; per-call token usage is logged so subscription burn can be measured
exactly before any full-corpus run.

Subcommands
-----------
draw-pilot   Draw a term-stratified random pilot sample from the in-window
             corpus (data_raw/epq_3.0.csv).
screen       Run the screen over corpus rows, optionally restricted to an id
             list and/or enriched with gold hand-codes for benchmarking.

Phase 0 usage
-------------
  # 0b pilot draw (proportional by term, VII/VIII/IX)
  python3 scripts/08_llm_screen.py draw-pilot --n 1500 --seed 42 \
      --out data/dv201_llm_pilot_ids.csv

  # 0a benchmark, body mode, GLM flash
  python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
      --gold data/dv201_validation_decisions_FR.csv \
      --gold data/dv201_precision_sample_tocode.csv \
      --mode body --model glm-5.3-flash:cloud \
      --out output/llm_screen/bench_glmflash_body.csv

  # 0a benchmark, subject-only mode (cost comparison)
  python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
      --gold data/dv201_validation_decisions_FR.csv \
      --gold data/dv201_precision_sample_tocode.csv \
      --mode subject --model glm-5.3-flash:cloud \
      --out output/llm_screen/bench_glmflash_subject.csv

  # 0a benchmark, second family cross-check
  python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
      --gold data/dv201_validation_decisions_FR.csv \
      --gold data/dv201_precision_sample_tocode.csv \
      --mode body --model gemma4:31b-cloud --workers 6 \
      --out output/llm_screen/bench_gemma31b_body.csv

  # 0b pilot screen (burn / latency / yield measurement)
  python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
      --ids data/dv201_llm_pilot_ids.csv \
      --mode body --model glm-5.3-flash:cloud --workers 12 \
      --out output/llm_screen/pilot_glmflash_body.csv
"""

import argparse
import concurrent.futures
import csv
import json
import random
import re
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

OLLAMA_URL = "http://localhost:11434/api/chat"
CORPUS_DEFAULT = "data_raw/epq_3.0.csv"
# WINDOW CROSS-REFERENCE (audit item 8 fix, 2026-11-18 — doc-only; constants
# unchanged). This screen window is deliberately a SUPERSET of the analysis
# layers downstream:
#   1. LLM screen (this script):  2009-07-01 <= date < 2024-08-01 (in_window)
#   2. Question inclusion (scripts/01_import_questions.R):
#        2009-07-14 <= date <= 2024-06-15 (validated canonical window;
#        1,319 kept / 1,291 subtopic-201)
#   3. Covariate aggregation (scripts/04_download_problem_indicators.R):
#        no independent date cutoff — covariates are aggregated per EPDG
#        legislature (terms VII-IX) with no within-window date filter.
# The superset design means the screen never drops a corpus row that 01's
# inclusion criteria would keep; the narrower 01 bounds are what feed DV
# derivation and the estimation panel. Term boundaries agree across layers:
# both assign 2019-07-01 to term IX (01's helper at lines ~184-185; this
# script starts VIII at 2014-07 and IX at 2019-07).
WINDOW_START = "2009-07-01"
WINDOW_END_EXCL = "2024-08-01"
BODY_MAX_WORDS = 260

SYSTEM_PROMPT = (
    "You are a research assistant coding European Parliament written questions "
    "for a political science study. You will receive the formal title and, in "
    "some modes, the opening text of one question. Decide whether the question "
    "falls within the scope of the study's discrimination measure. Answer with "
    "EXACTLY three lines and nothing else:\n"
    "LABEL: IN or OUT\n"
    "REASON: <code>\n"
    "CONFIDENCE: high or low\n"
    "When LABEL is IN use REASON code in_scope. When LABEL is OUT use exactly "
    "one of: extra_EU | non_discrimination | non_ethnic | other"
)

RUBRIC_TEMPLATE = """Study scope: discrimination against ethnic, racial, national, linguistic, or racialised religious minorities -- including Roma and Sinti, Jews, Muslims in Europe, migrants targeted as an ethnic group, and autochthonous national minorities -- located in the European Union.

Label the question IN (in_scope) when EU-located minority discrimination is a central theme: unequal treatment, exclusion, racism or xenophobia, hate crime or hate speech, police or institutional profiling, segregation, minority-rights violations.

Label the question OUT with exactly one reason code otherwise:
- extra_EU: the minority or discrimination issue lies outside the EU -- e.g. Turkey, Ukraine, the Western Balkans, Russia, the Middle East, China, or any other non-EU country -- including EU statements about discrimination elsewhere, and non-EU countries' treatment of their own minorities, even when the minority also lives in the EU if the question is anchored to the non-EU state.
- non_discrimination: the question deals with migration, asylum, integration, security, or another policy area without any discrimination or minority-rights framing.
- non_ethnic: discrimination on grounds other than ethnic, racial, or national origin -- gender, sexual orientation, disability, age, or religion as such (including discrimination against Christians, even within the EU); also death penalty, children's rights, or general human-rights issues.
- other: purely procedural or unrelated to the study.

Formal title: {subject}
Date: {date}"""

# Rubric v2 (refined, 2026-11-17, memo section 7d): narrows the operative scope
# after the FP-purge adjudication (15 known FPs, all language-rights /
# national-minority / non-ethnic items). Validated on FR's 180-row sample before
# the full re-screen: TP 13 / FN 2 / FP 0 / TN 165 (precision 1.000, recall
# .867, agreement .989). Use `--rubric original` to reproduce any pre-7d run.
RUBRIC_TEMPLATE_REFINED = """Study scope: discrimination against ethnic, racial, or racialised religious minorities -- including Roma and Sinti, Jews, Muslims in Europe, and migrants targeted as an ethnic group -- located in the European Union.

Label the question IN (in_scope) when EU-located discrimination against such groups is a central theme: unequal treatment, exclusion, racism or xenophobia, hate crime or hate speech, police or institutional profiling, segregation, or minority-rights violations specifically targeting these groups.

Label the question OUT with exactly one reason code otherwise:
- extra_EU: the minority or discrimination issue lies outside the EU -- e.g. Turkey, Ukraine, the Western Balkans, Russia, the Middle East, China, or any other non-EU country -- including EU statements about discrimination elsewhere, and non-EU countries' treatment of their own minorities, even when the minority also lives in the EU if the question is anchored to the non-EU state.
- non_discrimination: the question deals with migration, asylum, integration, security, or another policy area without any discrimination or minority-rights framing.
- non_ethnic: discrimination on grounds other than ethnic or racial origin -- gender, sexual orientation, disability, age, or religion as such (including discrimination against Christians, even within the EU). Also OUT: language-rights or language-policy questions of autochthonous national or regional linguistic minorities (regional languages, bilingual education, road signage, broadcasting, linguistic equality in EU institutions); national-minority or inter-communal questions with no racial dimension (e.g., the Hungarian minority in Romania, Greek or Turkish Cypriot communities); generic victims-rights, workplace-dispute, or institutional-integrity questions with no racial or ethnic nexus; also death penalty, children's rights, or general human-rights issues.
- other: purely procedural or unrelated to the study.

Formal title: {subject}
Date: {date}"""

RUBRICS = {
    "original": RUBRIC_TEMPLATE,
    "refined": RUBRIC_TEMPLATE_REFINED,
}

_think_support = {}          # model -> True / False / None (unknown)
_think_lock = threading.Lock()
_print_lock = threading.Lock()

def term_from_date(date_str):
    """Derive parliamentary term from an ISO date (month-level precision ok)."""
    if not date_str or len(date_str) < 7:
        return ""
    ym = date_str[:7]
    if "2009-07" <= ym < "2014-07":
        return "VII"
    if "2014-07" <= ym < "2019-07":
        return "VIII"
    if "2019-07" <= ym < "2024-07":
        return "IX"
    if ym == "2024-07":          # end of IX (window closes 2024-07-15)
        return "IX"
    return ""


def in_window(date_str):
    return bool(date_str) and WINDOW_START <= date_str[:10] < WINDOW_END_EXCL


def normalize_body(text):
    """Strip the document header (first line) and cap the body length."""
    if not text:
        return ""
    body = text.split("\n", 1)[1] if "\n" in text else text
    body = re.sub(r"\s+", " ", body).strip()
    words = body.split(" ")
    if len(words) > BODY_MAX_WORDS:
        body = " ".join(words[:BODY_MAX_WORDS]) + " [...]"
    return body


def ollama_chat(messages, model, temperature=0.0, num_predict=160, timeout=180):
    """Single Ollama /api/chat call with think-flag fallback. Returns response dict."""
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {"temperature": temperature, "num_predict": num_predict},
    }
    with _think_lock:
        think_known = _think_support.get(model)
    if think_known is not False:
        payload["think"] = False
    data = json.dumps(payload).encode("utf-8")
    last_err = None
    for attempt in range(3):
        req = urllib.request.Request(
            OLLAMA_URL, data=data, headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                out = json.loads(resp.read().decode("utf-8"))
            return out
        except urllib.error.HTTPError as exc:
            body_txt = ""
            try:
                body_txt = exc.read().decode("utf-8", "replace")[:300]
            except Exception:  # noqa: BLE001 - diagnostics only
                pass
            last_err = f"HTTP {exc.code}: {body_txt}"
            with _think_lock:
                if think_known is not False and "think" in body_txt.lower():
                    _think_support[model] = False
                    payload.pop("think", None)
                    data = json.dumps(payload).encode("utf-8")
                    continue
        except Exception as exc:  # noqa: BLE001 - network layer errors
            last_err = f"{type(exc).__name__}: {exc}"
        time.sleep([2, 5, 10][attempt])
    raise RuntimeError(f"Ollama call failed after retries: {last_err}")


def parse_answer(text):
    """Parse the rigid three-line answer. Returns (label, reason, confidence)."""
    if text is None:
        return "PARSE_ERROR", "", ""
    label = re.search(r"LABEL\s*:\s*\**\s*(IN|OUT)\b", text, re.I)
    reason = re.search(r"REASON\s*:\s*\**\s*([A-Za-z_\- ]+)", text, re.I)
    conf = re.search(r"CONFIDENCE\s*:\s*\**\s*(high|low)", text, re.I)
    if not label:
        return "PARSE_ERROR", "", ""
    lab = label.group(1).upper()
    rsn = ""
    if reason:
        rsn = re.sub(r"[\s\-]+", "_", reason.group(1).strip().lower())
        aliases = {"extra-eu": "extra_EU", "extraeu": "extra_EU", "extra_eu": "extra_EU",
                   "non_discrimination_out": "non_discrimination",
                   "non_ethnic": "non_ethnic", "nonethnic": "non_ethnic"}
        rsn = aliases.get(rsn, rsn)
    cfd = conf.group(1).lower() if conf else ""
    expected = ({("in", "in_scope")} if lab == "IN" else
                {("out", "extra_EU"), ("out", "non_discrimination"),
                 ("out", "non_ethnic"), ("out", "other")})
    if (lab.lower(), rsn) not in expected:
        return (lab, "MALFORMED_" + rsn if rsn else "MALFORMED_EMPTY", cfd)
    return lab, rsn, cfd

def read_gold(paths):
    """Merge gold-code files (batch decisions + precision sample). id -> (label, reason)."""
    gold = {}
    dup = Counter()
    for p in paths:
        with open(p, newline="", encoding="utf-8", errors="replace") as fh:
            for row in csv.DictReader(fh):
                qid = (row.get("id") or "").strip()
                if not qid:
                    continue
                if "decision" in row and row.get("decision") in ("IN", "OUT"):
                    label, reason = row["decision"], ""
                elif row.get("on_scope"):
                    scope = row["on_scope"].strip()
                    if scope == "IN":
                        label, reason = "IN", "in_scope"
                    elif "OUT" in scope:
                        label = "OUT"
                        reason = ("extra_EU" if "extra" in scope.lower() else
                                  "non_discrimination" if "non-discrimination" in scope.lower() else
                                  "non_ethnic" if "non-ethnic" in scope.lower() else "other")
                    else:
                        continue
                else:
                    continue
                key = (label, reason)
                if qid in gold and gold[qid] != key:
                    dup[qid] += 1
                    continue
                gold[qid] = key
    if dup:
        print(f"[gold] {len(dup)} conflicting duplicate ids kept as first read", file=sys.stderr)
    return gold


def stream_rows(corpus_path, ids=None, want_window=False):
    """Yield corpus dicts (id, date, term, subject, text, lang), streamed."""
    with open(corpus_path, newline="", encoding="utf-8", errors="replace") as fh:
        for row in csv.DictReader(fh):
            qid = (row.get("id") or "").strip()
            row_date = (row.get("date") or "").strip()
            if ids is not None:
                if qid not in ids:
                    continue
            elif want_window and not in_window(row_date):
                continue
            yield {"id": qid, "date": row_date,
                   "term": term_from_date(row_date),
                   "subject": (row.get("subject") or "").strip(),
                   "text": row.get("text") or "",
                   "lang": (row.get("original_language") or "").strip()}


def screen_one(item, model, mode, max_attempts=3, rubric_template=RUBRIC_TEMPLATE):
    """One question -> one result dict (thread worker)."""
    subject = item["subject"]
    body = normalize_body(item["text"]) if mode == "body" else ""
    user_txt = rubric_template.format(subject=subject or "(none)",
                                      date=item["date"] or "(unknown)")
    if mode == "body":
        user_txt += "\nQuestion text (opening): " + (body or "(text unavailable)")
    elif mode == "subject":
        user_txt += "\n(Only the formal title is available; judge the title.)"
    if not subject and not body:
        return {**item, "label": "EMPTY", "reason": "", "confidence": "",
                "attempts": 0, "error": "no subject and no text"}
    messages = [{"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_txt}]
    attempts, resp = 0, {}
    t0 = time.time()
    while True:
        attempts += 1
        try:
            resp = ollama_chat(messages, model)
        except RuntimeError as exc:
            return {**item, "label": "API_ERROR", "reason": "", "confidence": "",
                    "attempts": attempts, "error": str(exc)}
        label, reason, conf = parse_answer((resp.get("message") or {}).get("content"))
        if label not in ("PARSE_ERROR",) and not label.startswith("MALFORMED"):
            return {**item, "label": label, "reason": reason, "confidence": conf,
                    "attempts": attempts, "error": "",
                    "prompt_tokens": resp.get("prompt_eval_count") or 0,
                    "eval_tokens": resp.get("eval_count") or 0,
                    "elapsed_s": round(time.time() - t0, 2)}
        if attempts >= max_attempts:
            fin = label if label and label != "PARSE_ERROR" else "PARSE_ERROR"
            return {**item, "label": fin, "reason": reason if fin != "PARSE_ERROR" else "",
                    "confidence": conf, "attempts": attempts,
                    "error": "answer format not parseable",
                    "prompt_tokens": resp.get("prompt_eval_count") or 0,
                    "eval_tokens": resp.get("eval_count") or 0,
                    "elapsed_s": round(time.time() - t0, 2)}
        messages = [{"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_txt},
                    {"role": "assistant",
                     "content": (resp.get("message") or {}).get("content") or ""},
                    {"role": "user",
                     "content": ("Your reply did not follow the required format. Answer again "
                                 "with EXACTLY three lines: LABEL: IN or OUT / "
                                 "REASON: <code> / CONFIDENCE: high or low.")}]

def cmd_draw_pilot(args):
    rows_by_term = {"VII": [], "VIII": [], "IX": []}
    seen = set()
    total = 0
    for item in stream_rows(args.corpus, ids=None, want_window=True):
        if item["id"] in seen or not item["term"]:
            continue
        seen.add(item["id"])
        rows_by_term[item["term"]].append(item)
        total += 1
    print(f"[draw] in-window unique questions: {total} "
          f"(VII={len(rows_by_term['VII'])}, VIII={len(rows_by_term['VIII'])}, "
          f"IX={len(rows_by_term['IX'])})")
    rng = random.Random(args.seed)
    alloc = {t: min(round(args.n * len(rows_by_term[t]) / total), len(rows_by_term[t]))
             for t in ("VII", "VIII", "IX")}
    diff = args.n - sum(alloc.values())
    order = ["VII", "VIII", "IX"]
    for i in range(abs(diff)):   # distribute remainder to largest population
        alloc[order[i % 3]] += 1 if diff > 0 else -1
    picked = []
    for term in order:
        for item in rng.sample(rows_by_term[term], alloc[term]):
            picked.append({k: item[k] for k in ("id", "date", "term", "subject", "lang")})
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["id", "date", "term", "subject", "lang"])
        w.writeheader()
        w.writerows(picked)
    print("[draw] wrote %d ids -> %s (alloc: %s; seed=%d)" % (
        len(picked), args.out,
        ", ".join(f"{t}={alloc[t]}" for t in order), args.seed))


def cmd_screen(args):
    ids = None
    if args.ids:
        with open(args.ids, newline="", encoding="utf-8", errors="replace") as fh:
            ids = {r["id"].strip() for r in csv.DictReader(fh) if r.get("id")}
        print(f"[screen] restricting to {len(ids)} ids from {args.ids}")
    gold = read_gold(args.gold) if args.gold else {}
    if gold:
        print(f"[screen] gold codes loaded: {len(gold)} ids "
              f"({dict(Counter(l for l, _ in gold.values()))})")

    out_fields = ["id", "date", "term", "subject", "lang", "model", "mode",
                  "label", "reason", "confidence", "gold_label", "gold_reason",
                  "match", "prompt_tokens", "eval_tokens", "elapsed_s",
                  "attempts", "error"]
    done = set()
    if Path(args.out).exists() and not args.fresh:
        with open(args.out, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r.get("id") and r.get("label") and r["label"] != "PENDING":
                    done.add(r["id"].strip())
        print(f"[screen] resuming: {len(done)} rows already coded in {args.out}")
    else:
        with open(args.out, "w", newline="", encoding="utf-8") as fh:
            csv.DictWriter(fh, fieldnames=out_fields).writeheader()

    items = []
    for item in stream_rows(args.corpus, ids=ids, want_window=(ids is None)):
        if item["id"] in done:
            continue
        items.append(item)
        if args.limit and len(items) >= args.limit:
            break
    print(f"[screen] queue: {len(items)} questions to code with "
          f"{args.model} ({args.mode} mode, {args.workers} workers)")

    meta = {"model": args.model, "mode": args.mode, "rubric": args.rubric,
            "workers": args.workers,
            "queued": len(items), "started": time.strftime("%F %T"),
            "prompt_tokens": 0, "eval_tokens": 0, "labels": Counter(),
            "errors": Counter(), "elapsed": []}
    fh = open(args.out, "a", newline="", encoding="utf-8")
    writer = csv.DictWriter(fh, fieldnames=out_fields)
    written = 0

    def handle(res):
        nonlocal written
        gold_label, gold_reason = gold.get(res["id"], ("", ""))
        match = str(res["label"] == gold_label) if gold_label else ""
        writer.writerow({"id": res["id"], "date": res["date"],
                         "term": res["term"],
                         "subject": (res["subject"] or "")[:180],
                         "lang": res["lang"], "model": args.model,
                         "mode": args.mode,
                         "label": res["label"], "reason": res["reason"],
                         "confidence": res["confidence"],
                         "gold_label": gold_label, "gold_reason": gold_reason,
                         "match": match,
                         "prompt_tokens": res.get("prompt_tokens", ""),
                         "eval_tokens": res.get("eval_tokens", ""),
                         "elapsed_s": res.get("elapsed_s", ""),
                         "attempts": res["attempts"], "error": res["error"][:200]})
        fh.flush()
        written += 1
        with _print_lock:
            if res["label"] in ("IN", "OUT"):
                meta["labels"][res["label"]] += 1
                meta["prompt_tokens"] += res.get("prompt_tokens") or 0
                meta["eval_tokens"] += res.get("eval_tokens") or 0
                meta["elapsed"].append(res.get("elapsed_s") or 0)
            else:
                meta["errors"][res["label"]] += 1

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = [pool.submit(screen_one, it, args.model, args.mode,
                            rubric_template=RUBRICS[args.rubric]) for it in items]
        for i, fut in enumerate(concurrent.futures.as_completed(futs), 1):
            try:
                handle(fut.result())
            except Exception as exc:  # noqa: BLE001 - keep the batch alive
                meta["errors"]["WORKER_EXC"] += 1
                print(f"[screen] worker exception: {exc}", file=sys.stderr)
            if i % 100 == 0 or i == len(items):
                el = meta["elapsed"]
                done_n = meta["labels"]["IN"] + meta["labels"]["OUT"]
                if el:
                    print(f"[screen] {i}/{len(items)} | coded={done_n} "
                          f"IN={meta['labels']['IN']} OUT={meta['labels']['OUT']} "
                          f"err={sum(meta['errors'].values())} | mean {sum(el)/len(el):.2f}s")
                else:
                    print(f"[screen] {i}/{len(items)} | err={sum(meta['errors'].values())}")
    fh.close()

    meta["labels"] = dict(meta["labels"])
    meta["errors"] = dict(meta["errors"])
    meta["finished"] = time.strftime("%F %T")
    el = meta.pop("elapsed", [])
    if el:
        el.sort()
        meta["latency_mean_s"] = round(sum(el) / len(el), 2)
        meta["latency_p90_s"] = el[min(int(0.9 * len(el)), len(el) - 1)]
        done_n = meta["labels"].get("IN", 0) + meta["labels"].get("OUT", 0)
        meta["throughput_q_per_worker_s"] = round(done_n / max(sum(el), 1e-9), 3)
    if args.meta:
        meta["out"] = args.out
        Path(args.meta).write_text(json.dumps(meta, indent=2), encoding="utf-8")
        print(f"[screen] run meta -> {args.meta}")
    labels = meta["labels"]
    print(f"[screen] DONE: wrote {written} rows -> {args.out}; "
          f"IN={labels.get('IN', 0)} OUT={labels.get('OUT', 0)} "
          f"err={sum(meta['errors'].values())}; "
          f"tokens: prompt={meta['prompt_tokens']} eval={meta['eval_tokens']}")
    if gold:
        confusion_report(args.out)


def confusion_report(out_csv):
    """Print the confusion matrix + agreement diagnostics for a gold-coded run."""
    tp = fp = fn = tn = 0
    diag = Counter()
    with open(out_csv, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            if not r.get("gold_label") or r.get("match") in ("", None):
                continue
            m = r["match"] == "True"
            if r["gold_label"] == "IN":
                if m:
                    tp += 1
                else:
                    fn += 1
                    diag["missed gold IN -> LLm said " + (r.get("reason") or r["label"])] += 1
            elif m:
                tn += 1
            else:
                fp += 1
                diag["gold OUT -> LLM said " + (r.get("reason") or r["label"])] += 1
    n = tp + fp + fn + tn
    if not n:
        print("[confusion] no gold-labelled rows in output")
        return
    print(f"[confusion] n={n}  TP={tp} FP={fp} FN={fn} TN={tn}  "
          f"accuracy={(tp + tn) / n:.3f}  precision={tp / max(tp + fp, 1):.3f}  "
          f"recall={tp / max(tp + fn, 1):.3f}")
    for k, v in diag.most_common(12):
        print(f"[confusion]   {k}: {v}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    dp = sub.add_parser("draw-pilot", help="draw a term-stratified pilot sample")
    dp.add_argument("--corpus", default=CORPUS_DEFAULT)
    dp.add_argument("--n", type=int, default=1500)
    dp.add_argument("--seed", type=int, default=42)
    dp.add_argument("--out", required=True)
    dp.set_defaults(func=cmd_draw_pilot)

    sc = sub.add_parser("screen", help="run the LLM screen")
    sc.add_argument("--corpus", default=CORPUS_DEFAULT)
    sc.add_argument("--ids", help="CSV with an 'id' column restricting the screen")
    sc.add_argument("--gold", action="append", default=[], help="gold codes CSV; repeatable")
    sc.add_argument("--mode", choices=["body", "subject"], default="body")
    sc.add_argument("--model", default="glm-5.3-flash:cloud")
    sc.add_argument("--workers", type=int, default=10)
    sc.add_argument("--limit", type=int, default=0, help="cap rows coded (testing)")
    sc.add_argument("--rubric", choices=["original", "refined"], default="refined",
                    help="rubric variant: 'refined' (v2, FP-purged 2026-11-17) or "
                         "'original' (phase-0 rubric; reproduces prior runs)")
    sc.add_argument("--out", required=True)
    sc.add_argument("--meta", default="")
    sc.add_argument("--fresh", action="store_true", help="overwrite existing output")
    sc.set_defaults(func=cmd_screen)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
