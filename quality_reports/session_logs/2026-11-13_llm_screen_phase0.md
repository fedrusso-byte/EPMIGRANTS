# Session log — 2026-11-13 — LLM screen Phase 0 (gold benchmark + pilot)

**Mode:** act (plan approved 2026-11-13 with amendments: gemma dual-screen + 1,500 pilot 0b).

## What was built
- `scripts/08_llm_screen.py`: stdlib-only Python 3.12 CLI (Ollama `/api/chat`, checkpoint/resume, per-call token logging, format-repair retries, `think:false` auto-fallback; subcommands `draw-pilot`, `screen`).
- `explorations/llm_screen/analyze_phase0.py`: gold join + confusion/reason/yield/projection analysis; caches `output/llm_screen/phase0_analysis_cache.json`.

## Runs executed (all against `output/llm_screen/phase0_corpus.csv`, 1,832 rows = gold ∪ pilot extract)
| Run | out | rows | tokens (prompt/eval) |
|---|---|---|---|
| GLM-flash body, 8w | `bench_glmflash_body.csv` (+pilot rows) | 1,832 | 1,043,952 / 40,848 |
| GLM-flash subject, 8w | `bench_glmflash_subject.csv` | 334 | 152,152 / 8,888 |
| gemma4:31b body, 6w | `bench_gemma31b_body.csv` | 334 | 204,048 / 5,320 |

Timeline: pilot draw 22:45 (125,081 in-window unique: VII 54,922 / VIII 45,892 / IX 24,267);
GLM body 22:52–23:01; runs 2–3 ~23:05–23:14. Zero parse/API errors; 10 format-repair retries, all resolved on attempt 2.

## Results (see memo for full tables)
- GLM body: acc 0.910, prec 0.844, **rec 0.826 [0.74–0.90]**; subject: prec 0.894, rec 0.826; gemma: rec 0.859 prec 0.798.
- Pilot: IN 2.00%; 30 INs (7 inside CAP-201, 23 candidates outside ≈ 1,900 full-corpus).

## Issues
- Bash `$G` quoting → `--gold` flags lost in phase-0 launches; gold columns empty in CSVs; join post-hoc in analysis (documented in memo §8).
- 2 gold ids with conflicting codes dropped (334 evaluated of 336).
- Window/count delta 125,081 vs paper's 124,337 (memo §8).

## Decision gate
Full-run GLM-flash body (~74M tokens, ~6.8h @12w) awaiting user go; adjudication design (sampled vs full export); LLaMA-201 rescreen add-on (0.74M tokens).

## Phase 1 launch (same evening, user-approved gate)

- Rescreen ids extracted from `data_processed/epq.csv` (`pq_discrimination`, paper window 2009-07-14..2024-07-15): reproduced **1,319 kept / 1,291 subtopic-201** exactly; list `data/dv201_llm_kept201_ids.csv`.
- Background chain PID 377926 (`runlog_phase1.txt`): rescreen (1,291 rows) -> full run (125,081 rows, seeded with 1,832 phase-0 rows, ~123,249 to code).
- **Rescreen result: PASS 629/1,291 = 48.7%** (VII .52 / VIII .51 / IX .36) vs hand precision sample 52.5% [0.43-0.62]; cut reasons extra_EU 260 / non_discrimination 161 / other 158 / non_ethnic 80; burn 0.79M tokens; latency mean 3.64 s.
- Transient cloud-queue congestion observed ~23:35-23:45 (completion rate fell to ~0.3 q/s, then flushed); steady state recovered ~4.3 q/s at 12 workers. Full-run ETA ~7.5-8.5 h from ~23:45.

## Phase 1 completion (2026-11-14 morning, Act mode)

- Run 1 finished 07:45: 122,763 valid rows; 2,316 HTTP 429 (overnight throttle 02:00-07:45) + 2 PARSE_ERROR; 68.7M prompt / 2.47M eval tokens; latency 2.34 s.
- Cleanup (Act-approved): backup -> `full_glm_body_run1.bak.csv` (+ `full_glm_body_meta_run1.json`); rewrote CSV dropping the 2,318 error rows; identical resume command (no `--fresh`) re-coded exactly those rows: **IN 37 / OUT 2,281 / err 0** (~40 min, 1.31M/48k tokens; a watcher loop flagged FULLRUN_DONE; monitor CSV line count, runlog is block-buffered).
- Final `full_glm_body.csv`: 125,081 clean rows — **IN 2,063 (1.65%) / OUT 123,018**.
- `explorations/llm_screen/analyze_full.py`: gold metrics **identical to the phase-0 benchmark** (TP 76 / FP 14 / FN 16 / TN 228; recall .826 [.736, .890], precision .844) — re-roll stable, 16 FNs unchanged; kept-DV PASS 642/1,319, subtopic-201 617/1,291 = 47.8% replicating the rescreen's 48.7% (98.1% agreement) → hand precision 52.5% [0.43-0.62] doubly confirmed; IN rate by term 1.80/1.58/1.44%; total burn 70.01M prompt + 2.51M eval.
- Exports: `data/dv201_llm_candidates_tocode.csv` — **1,421 LLM-INs outside the kept-DV net** (only 9 are subtopic-201; VII 677 / VIII 483 / IX 261) + `data/dv201_llm_adjudication_sample_tocode.csv` — 180 rows (30 pilot INs + 150 random pilot OUTs, seed 42) + `output/llm_screen/fullrun_analysis_cache.json`.
- Pending: FR decision on memo §7c design (a) sampled vs (b) full candidates; optional §7d prompt iteration targeting the 16 FNs; DV ∪ verified-LLM-INs robustness refit (05_Bayesian_sens precedent); recall/precision sentence in the DV validation paragraph; reconcile 125,081 (epq_3.0, month window) vs 124,337 (paper, day window).

## Addendum (2026-11-14, ~09:00) — text columns in the adjudication exports

- FR: "to verify the coding I need csv files with also the text, not only the title." Both §7c exports regenerated from `analyze_full.py` (deterministic; seed-42 sample identical): original 7 batch columns verified unchanged (0 field diffs, same row order) + appended `lang`, `llm_reason`, `text_llm_input` (verbatim LLM input, `[...]` at the 260-word cap; 83/1,578 truncated) and `text_full` (complete corpus text, whitespace-collapsed). Full text found for all 1,578 unique export ids (1,421 ∪ 180, 23 overlap; 0 missing from the corpus).
- Incidental finding: `normalize_body()` strips EVERYTHING before the first newline "as a header", but corpus line 1 is usually real opening text (masthead-like first lines in only ~7.5k of ~180k multiline corpus rows) → the LLM never saw paragraph 1 of most questions (1,504/1,578 = 95.3% of export texts are multiline). The gold recall .826 [.74–.90] was achieved without paragraph 1; the §7d lever list grows ("keep line 1", 260-word cap); the ms description of the LLM input must be fixed ("opening text" → "body excluding the first line, capped at 260 words").
