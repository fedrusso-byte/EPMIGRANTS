# CAP-201 dictionary-filter fix — implementation report (Phase 1, Option B)

**Date:** 2026-11-06 · **Scope:** `scripts/01_import_questions.R` + full pipeline rerun + old-vs-new diff · **Status:** EXECUTED
**Fix design:** audit §9 regex verbatim + Option-B rescue allowlist (audit §5 ⚠ rows), as approved.
**Pre-fix snapshot (rollback point):** `output/archive_cap201_prefilter_2026-11-06/` — contains pre-fix `epq.rds`/`epq.csv`, all five coefficient CSVs, `df_merged_3.csv`, `df_model_data.rds`, and both brms fits (`bayesian_model_cmp.rds`, `bayesian_model_mipex.rds`).
**Rerun log:** `/tmp/cap201_fix_rerun.log` — scripts `01 → 02 → 03 → 05_models.R → 05_models_Bayesian.R → 06 → 07`, 12:50:04 → 13:12:28, all successful. `04_models.R` skipped (DV-independent, per 2026-11-05 precedent); both brms fits were force-refit by deleting them from `output/` (copies preserved in the snapshot).

## 1. What changed in code

Only `scripts/01_import_questions.R`:

1. `cap201_exclusion_pattern` — the audit §9 "Phase 1 regex", verified byte-identical to the audit text (`verbatim-match: TRUE` via `/tmp/cap201_pattern_check.R`):

   ```r
   cap201_exclusion_pattern <- paste0("(?i)christian|\\bafrica\\b|palestin|Second World War|",
     "\\bhamas\\b|danube|turkey|turkish|istanbul|\\bindia\\b|china|chinese|\\busa\\b|\\basia\\b|israel|\\biran\\b|iranians?|syria|middle east|\\bnative\\b|",
     "pakistan|tibet|uighur|uyghur|vietnam|guatemala|burma|myanmar|rwanda|congo|cambodia|afghan|egypt|iraq|jerusalem|brazil|kashmir|nepal|coptic|ahmadi|\\bkaren\\b|degar|lausanne")
   ```

   (`\\b` in R source = `\b` word boundary in the regex. The code comment now documents: subject-only application — never the body text (audit §6.3, 371-row counterfactual); the regex history (unbounded stems + inert right-wing keys before, word boundaries + country/nationality keywords + the `\biran\b|iranians?` "Tirana" fix now); and the audit reference.)
2. `cap201_rescue_ids` — the 7 audit Appendix-A "⚠ FALSE (EU-relevant)" questions, re-included by question id (Option B):

   | question id | date | term | MEP | subject (truncated) | rationale |
   | :--- | :--- | :--- | :--- | :--- | :--- |
   | `E-0636/2000` | 2000-02-03 | pre | 2335 | Repopulation of northern regions in Greece… | Greece (Macedonian & Turkish minorities) |
   | `P-1626/2005` | 2005-04-25 | pre | 1934 | Access to EPSO competitions by Turkish Cypriot nationals | EU citizens |
   | `P-2304/2006` | 2006-05-16 | pre | 28576 | Illegal abduction of Pakistani citizens in Greece | Greece |
   | `E-004683/2012` | 2012-08-05 | VII | 4555 | Turkish as an official language of the European Parliament | EU institutional language policy |
   | `E-003234/2014` | 2014-07-01 | VIII | 96750 | Rights of the Turkish minority in Western Thrace, Greece | Greece |
   | `E-005109/2016` | 2016-06-24 | VIII | 124873 | Risk of Turkish becoming an official EU language | EU institutional language policy |
   | `E-006385/2018` | 2018-12-19 | VIII | 24942 | Education through the medium of Turkish in Greece | Greece |

   The 6 in-window "▲ borderline" rows and the Kosovo 2011 case stay excluded (pending Phase 2 LLM re-validation), exactly as scoped.
3. DV condition = `subtopic == "201" & (id %in% cap201_rescue_ids | !str_detect(subject, cap201_exclusion_pattern))`, implemented NA-safely: non-201 rows and 201 rows with NA subject map to 0, preserving the original `case_when` semantics. (The first run aborted at a new `stopifnot` guard — `if_else` with an NA condition returns NA, so ~187k join-unmatched rows would have become NA; no data was written on that run, by design.)
4. Drift guard `stopifnot` on the window keep-count: expected **1,290** on the raw date range. Rationale: the audit's *term-coding* count is 1,285, but five CAP-201 questions dated **2019-07-01** (e.g. "Demographic shift in the northern part of Cyprus") fall between the VIII-term end (2019-06-30) and IX-term start (2019-07-02) of the audit's coding, so the raw range [2009-07-14, 2024-06-15] catches 1,285 + 5. The guard's message documents both numbers.
5. Removed the pre-existing duplicated `write_csv`/`write_rds` block.

**Provenance correction (important).** The planning session's numeric rescue list (2335, 1934, 28576, 4555, 96750, 124873, 24942) reproduces the audit Appendix-A **third column, which is MEP ids**, not question ids (`epq$id` are strings like `E-004683/2012`). The allowlist above uses question ids verified live: a preflight run matched each id to the expected ⚠ subject/date and confirmed all 7 are exactly "currently kept & newly excluded by the new regex" rows. MEP affiliations in the table above come from the audit.

## 2. Input verification (preflight, on the archived pre-fix `epq.rds`)

- Baseline reproduces audit §3 exactly: 2,324 rows / 185 excluded / 2,139 kept / window 1,446 / 1,323 kept / 123 excluded.
- Pure §9 regex reproduces audit §5/§8: flip-out 49 in-window (VII 26 / VIII 16 / IX 7) and 78 all-terms; re-inclusions 7 in-window; projected kept 1,281.
- Audit erratum (cosmetic): all-terms re-inclusions are **13**, not 12 — the 1996 German hunting-licences title contains "ref**usa**l" and is freed by word-bounding `usa`; the audit's "12" missed this pre-window row (§4.1 itself documents the row). No window impact.

## 3. Question-level diff (CAP-201, raw `epq`)

| Quantity | Before | After |
| :--- | :--- | :--- |
| CAP-201 questions | 2,324 | 2,324 |
| Kept, all terms | 2,139 | **2,081** |
| Kept, VII–IX (term-coded) | 1,323 | **1,285** |
| Excluded, VII–IX | 123 | **161** (11.1% of 1,446) |
| Raw MEPs with ≥ 1 kept DV (VII / VIII / IX) | 237 / 226 / 129 | **234 / 220 / 124** |
| Newly excluded by the regex | — | 71 all-terms; 45 in-window (VII 25 / VIII 13 / IX 7) |
| Re-included by the regex | — | 13 all-terms; 7 in-window (4 BAME rows + Bulgaria schools + Silesia accommodation + African-descent resolution) |
| Rescued by allowlist | — | 7 (3 pre-window + 4 in-window) |

Arithmetic checks: 2,139 − 71 + 13 = 2,081 ✓; 1,323 − 45 + 7 = 1,285 ✓; 78 pure-§9 exclusions − 7 rescues = 71 ✓; 49 pure-§9 in-window exclusions − 4 in-window rescues = 45 ✓; audit MEP projection 233/219/124, adjusted for the rescued window rows (MEP 4555 returns in VII; one VIII rescue MEP stays covered) → 234/220/124 ✓. Rescue verification: 7/7 allowlisted rows have `pq_discrimination == 1` in the new `data_processed/epq.rds` ✓.

## 4. Panel-level diff

**Panel composition is unchanged** — `04`-independent, DV-driven values only: `df_model_data.rds` has the same 9,850 MEP-year rows before and after (inner-join on `mep_id × leg_year` = 9,850), the same 1,543 unique MEPs, 301 minority rows and 51 unique minority MEPs. `df_merged_3.csv` (full roster) likewise: 15,108 rows, 2,262 MEPs.

**Panel roster (`df_merged_3`, incl. VI):**

| MEPs with ≥ 1 DV | VI | VII | VIII | IX |
| :--- | :--- | :--- | :--- | :--- |
| Before | 145 | 227 | 218 | 117 |
| After | 143 | **224** | **212** | **113** |

(Before-values reproduce the 2026-11-05 QA-note baseline 227/218/117 exactly — the source of those numbers is `df_merged_3`, not the model frame.) Minority roster by term unchanged: 12 / 27 / 21 / 23. Total DV in roster: 1,751 → 1,700.

**Model frame (`df_model_data`, the model input):**

| Quantity | Before | After |
| :--- | :--- | :--- |
| MEPs with ≥ 1 DV (VII / VIII / IX) | 196 / 189 / 101 | **193 / 183 / 97** |
| DV questions in frame | 1,074 | **1,038** |
| Minority rows / unique minority MEPs | 301 / 51 | unchanged |

## 5. Targeted checks

- **BAME MEP 124948 (VIII).** Gains exactly **+4** DV questions (12 → 16 across VIII year-rows) — the four BAME titles that were "falsi esclusi", now re-included. ✓
- **Only-DV leakage MEPs.** 25 MEP-year rows lose all their DV credit (VII 9 / VIII 10 / IX 6; 24 distinct MEPs); **12 distinct MEPs lose their entire DV presence** (ids 1403, 28276, 28358, 28584, 96897, 124823, 125107, 188624, 197539, 197611, 197627, 197650 — each held exactly one leakage question). Reconciliation with the audit's "17 MEPs whose only DV is leakage" (pure §9): 17 − 4 in-window rescue MEPs (4555, 96750, 124873, 24942) − 1 whose MEP sits outside the study roster = 12. ✓
- **Gains.** 2 MEP-year rows gain their first DV questions: 124866 (VIII, via the Bulgaria-schools re-inclusion) and 130100 (IX, via a 2020 re-inclusion). Minor audit reconciliation: audit §8 counted "1 MEP gaining a first DV" under pure §9; Option B observed 2.
- **Newly excluded in window (45)** match the audit Appendix-A ✅ verdicts (Pakistani blasphemy/Pashtun, Tibet, Uighur, Coptic Egypt, Congo, Rwanda, Burma, Guatemala, Vietnam, Iraq, Afghanistan, Brazil, Turkey-state actions, the four ▲ borderline rows kept excluded, …). Full list in `/tmp/cap201_diff.out`; the snapshot's `epq.rds` + the list above make the diff fully reproducible.

## 6. Coefficients (Bayesian, Table-1 model = MIPEX Interaction) and H3 verdict

| Term | Before | After |
| :--- | :--- | :--- |
| H1: minority | 0.418 [−0.247, 1.030] ns | 0.438 [−0.256, 1.063] ns |
| H2: mipex_center | 0.0009 [−0.0098, 0.0114] ns | 0.0017 [−0.0095, 0.0126] ns |
| **H3: minority × mipex_center** | **0.0398 [0.0022, 0.0787] ★** | **0.0376 [−0.0019, 0.0800] — loses ★** |
| LIBE membership | 0.470 [0.227, 0.703] ★ | 0.507 [0.270, 0.743] ★ |
| Gender: male | 0.016 [−0.143, 0.171] ns | 0.019 [−0.141, 0.174] ns |
| CMP: minority × cmp_center | 0.115 [−0.032, 0.290] ns | 0.107 [−0.038, 0.275] ns |
| CMP: minority | 0.472 [−0.362, 1.171] ns | 0.498 [−0.330, 1.197] ns |

Frequentist appendix (M1–M4, `05_models.R`): M4 interaction 0.040 → 0.0364 with the **pre-existing NaN-SE/p-value fallback** (unchanged caveat — use the Bayesian route in the manuscript).

**H3 verdict (honest, as mandated by the plan).** The interaction estimate is essentially unchanged in size but the posterior has widened slightly: 95% CrI now includes zero (lower bound −0.0019). **H3 is no longer supported at the strict CrI-excludes-zero criterion**; it should be reported as a positive but non-significant interaction (IRR ≈ 1.038 per MIPEX point), i.e. "suggestive rather than decisive". H1 and H2 remain ns; LIBE remains the significant control. Diagnostics for both new fits: max R̂ = 1.0039 (CMP) / 1.0033 (MIPEX); min Bulk/Tail ESS = 1,538 / 1,609 — matching the 2026-11-05 quality bar.

## 7. Ready-to-paste manuscript updates (no direct `paper/` edits made)

(a) **Measurement paragraph** — `paper/MEPArticle_Updated.md` L428–438; replaces the paragraph after the "75 per cent" sentence block:

> The automated classification of parliamentary questions at the CAP minor-topic level has an estimated accuracy of approximately 75 per cent. Before running the analysis, questions assigned to code 201 were therefore reviewed and further cleaned to improve the substantive validity of the measure. The cleaning relies on a subject-based keyword filter: questions whose *titles* point to discrimination against Christians — a religious-only frame outside the substantive scope of EU anti-discrimination rules — or to situations occurring outside Europe, identified through country, region and nationality terms (e.g. Africa, Asia, the United States, China, India, Turkey, Pakistan), were excluded from the measure; 1,285 of the 1,446 CAP-201 questions submitted between July 2009 and June 2024 remain. A small number of titles wrongly caught by these keywords — because they in fact concern EU-resident or EU-institution minority issues (e.g. the Turkish-speaking minority of Western Thrace, Greece, or Turkish as an official language of the European Parliament) — were retained by hand, while borderline titles on EU contexts affected by Turkish foreign and security policies were conservatively excluded. For robustness, alternative specifications use a binary indicator distinguishing whether an MEP submitted at least one discrimination-related question and a term-level count of all such questions submitted during each legislature.

(b) **Table 1 block** (L591–608; supersedes the 2026-11-05 memo §2 block, which had not yet been integrated):

```
**Table 1.** Posterior estimates from the Bayesian zero-inflated
negative binomial model

  ------------------------------------------------------------------------------
  **Hypothesis / predictor**                 **Estimate**   **95% credible
                                                             interval**
  ------------------------------------------ -------------- --------------------
  H1: Migratory or racialised minority       0.438          \[−0.256, 1.063\]
  background                                               

  H2: MIPEX anti-discrimination score        0.002          \[−0.010, 0.013\]

  H3: Minority background × MIPEX            0.0376         \[−0.002, 0.080\]

  LIBE Committee membership                  0.507\*        \[0.270, 0.743\]

  Gender: male                               0.019          \[−0.141, 0.174\]
  ------------------------------------------------------------------------------
```

(*Notes unchanged; H3 now carries no star.*)

(c) **Sentence replacements**
- L580–582 (H3): "…positive, and its 95 per cent
  credible interval excludes zero (β = 0.0658, 95% CrI \[0.016, 0.117\]).
  The findings therefore provide support for H3." → "…positive (β = 0.0376, 95% CrI \[−0.002, 0.080\]). The estimate remains directionally consistent with H3, but its credible interval now includes zero; the evidence is therefore suggestive rather than decisive."
- L622 (LIBE): "(β = 0.429, 95% CrI \[0.079, 0.751\])" → "(β = 0.507, 95% CrI \[0.270, 0.743\])".
- Note: the manuscript still carries the pre-2026-11-05 numbers throughout (0.0658, 0.429, …); all 2026-11-05 memo §1 values are themselves superseded by §6 of this report (same line anchors).

## 8. Outputs, logs, artifacts

- Refreshed in `output/`: `bayesian_model_results.csv`, `all_model_coefficients_comprehensive.csv`, `model_coefficients_wide_comparison.csv`, `bayesian_coefficients_comparison.csv`, `interaction_effects_summary.csv`, `df_merged_2_2004_2024.csv/.rds`, `df_merged_3.csv`, `df_model_data.rds`, and freshly refit `bayesian_model_cmp.rds` / `bayesian_model_mipex.rds`.
- Logs (also copied to `quality_reports/session_logs/`): `/tmp/cap201_fix_rerun.log` → `2026-11-06_cap201-fix-rerun.log`; preflight + diff console output → `2026-11-06_cap201-fix-diff.log`.
- Session scripts (in `/tmp`): `cap201_preflight.R`, `cap201_pattern_check.R`, `cap201_diff_a.R`, `cap201_diff_b.R` (all embedded findings above).

## 9. Documentation closure (done in this session)

- This implementation report; status block added to the audit report; `TO_DO.txt` header/status/§6 updated; dated addendum §5 added to `quality_reports/2026-11-05_numbers-to-change_VII-extension.md` (post-fix ms values supersede its §1/§2 tables); `quality_reports/bayesian_model_results_report.md` refreshed (+ HTML regenerated); `http.server 8461` shut down. No git commits.

## 10. Audit errata found while executing & rollback

Errata (window numbers all confirmed):
1. Audit §10 "re-includes 12 (7 in-window)" → **13** all-terms (see §2).
2. Audit Appendix A third column is **MEP id** (clarified; rescue ids must be the string `epq$id` values — see §1).
3. Audit §8's "MEPs gaining a first DV question: 1" → **2** observed in the panel (124866 VIII, 130100 IX); §8's excluded-window figure 165 is pure-§9 — with the 4 in-window rescues the applied figure is **161**.

**Rollback** (if ever needed): `cp output/archive_cap201_prefilter_2026-11-06/{epq.rds,epq.csv} data_processed/ && cp output/archive_cap201_prefilter_2026-11-06/*.csv output/ && cp output/archive_cap201_prefilter_2026-11-06/*.rds output/` (the archive already contains the pre-fix brms fits, so no rerun is needed), then `git checkout -- scripts/01_import_questions.R` to restore the old filter.

`==== IMPLEMENTATION COMPLETE 2026-11-06 ====`
