# 📑 CAP-201 dictionary filter — audit and impact sizing

**Deliverable:** analysis-only audit report · **Date:** 2026-11-06 · **Audit:** Cline · **Decision:** Federico Russo — *"solo analisi per ora; fix completo in un secondo momento"*
**Status:** no pipeline changes in this session. A backlog entry (deferred fix) was added to `TO_DO.txt` (§6️⃣). Nothing in `scripts/`, `data_*`, `output/`, or the manuscript was modified.

---

## 1. Purpose and scope

The dependent variable (DV) of the study counts EP written questions on **discrimination of (national, ethnic, religious) minorities** assigned by LLaMA to CAP subtopic **201**, filtered by a keyword blacklist in `scripts/01_import_questions.R` (variable `pq_discrimination`). A question is kept only if its **subject** matches none of 24 exclusion keywords.

This report documents the **fourth read-only audit** of the filter (2026-11-06) and sizes its DV impact. Sources:

- `data_processed/epq.rds` — subjects, dates, MEP ids (2,324 CAP-201 rows);
- `data_raw/epq_3.0.csv` joined with `data_raw/epq_minor_classified-llama_202502.csv` (`id = idOrig`) — full-text counterfactual.

Audit goals: (i) verify baseline numbers; (ii) quantify **false exclusions** (EU-relevant questions wrongly dropped); (iii) quantify **extra-EU leakage** (out-of-scope questions wrongly kept); (iv) identify inert keywords and the paper–code / comment–code mismatches; (v) size (projection only, not applied) a revised filter; (vi) record a 3-phase roadmap. Every number below was recomputed live on 2026-11-06; scripts and raw outputs are listed in §11.

## 2. Current mechanism (verbatim)

`scripts/01_import_questions.R` (L57–72; comments are the author's):

```r
# Create a dummy variable with value 1 when variable "subtopic" is 1 and at the same time the variable "text" does not contain the terms "christian" OR "Africa"

epq <- epq %>%
  mutate(
    pq_discrimination = case_when(
      # Condizione: subtopic è "201" E il testo NON contiene termini relativi a:
      # 1. Contesti extra-europei (Africa, Asia, Medio Oriente, etc.)
      # 2. Narrative di "discriminazione inversa" o critica alle politiche di anti-discriminazione (tipiche della destra)
      # 3. Temi religiosi specifici o conflitti storici/attuali non legati alla discriminazione etnica interna UE
      subtopic == "201" & !str_detect(subject, pattern = "(?i)christian|africa|palestin|Second World War|hamas|danube|turkey|istanbul|india|china|usa|america|asia|israel|iran|syria|middle east|native|patriot|political correctness|woke|reverse discrimination|traditional values|gender ideology|quotas") ~ 1,
      # In tutti gli altri casi, assegna 0
      TRUE ~ 0
    )
  )
```

> **STATUS UPDATE — 2026-11-06 (Phase 1 executed).** This report's §9 regex (verbatim) plus the Option-B rescue allowlist has been **implemented in `scripts/01_import_questions.R`** and the full pipeline rerun; verified old-vs-new diff in **`2026-11-06_CAP201-filter-implementation.md`** (VII–IX kept 1,323 → **1,285**; roster MEPs ≥1 DV 227/218/117 → 224/212/113; H3 coefficient 0.0376 with the CrI **now including zero**). Corrections surfaced while executing: §10's "12 re-inclusions" is **13**; Appendix A's third column is **MEP id** (rescue must use `epq$id` strings); §8's 165 excluded-window is the pure-§9 figure (with the 4 in-window rescues the applied figure is **161**). Phase 2 (LLM re-validation) and Phase 3 (manuscript integration) remain open.
Two implementation facts drive everything below (see §6):

1. The comment says the filter applies to **`text`**; the code applies it to **`subject`** only. Subject-only is the *correct* choice (371-row counterfactual in §6.3);
2. Most keywords are unbounded stems of arbitrary length (`africa`, `usa`, `china`, `native`, `syria`, …), a few with asymmetric coverage (`china` does not catch `chinese`, `turkey` does not catch `turkish`). Missing word boundaries are the root cause of both error types found in §4–§5.

## 3. Baseline numbers (live `data_processed/epq.rds`)

| Quantity | Value |
| :--- | :--- |
| CAP-201 questions, all terms | **2,324** (10 Jun 1994 → 1 May 2024) |
| Excluded by current filter | **185** (8.0%) |
| Kept (the DV) | **2,139** |
| Study window VII–IX (14 Jul 2009 – 15 Jun 2024) | 1,446 questions |
| … kept in VII–IX | **1,323** |
| … excluded in VII–IX | **123** (8.5%) |
| MEPs with ≥ 1 kept DV (VII / VIII / IX) | **237 / 226 / 129** |

Notes. (a) `epq.rds$date` is a `Date` column; the earliest CAP-201 question is 10 Jun 1994 (this corrects an earlier working note of "1999–2024"). (b) The panel-filtered MEP counts reported elsewhere (227/218/117) differ from the raw counts above because of the study's panel filters in `scripts/02_df_setup.R` (UK, HU, LU, MT, partial SK/RO exclusion); this audit works on the raw PQ data.

## 4. False exclusions (EU-relevant questions wrongly dropped)

### 4.1 Keyword-overmatching examples (root cause: unbounded stems)

| Question (subject, truncated) | Date / term | Fired (wrong) keyword |
| :--- | :--- | :--- |
| Refusal to accept holiday accommodation bookings from people from Silesia Province (Poland) | 2020-03-06 (IX) | `usa` → "refu**usa**l" |
| Implementation of the resolution on fundamental rights of people of African descent | 2020-03-06 (IX) | `africa` → "African-descent" (a European anti-discrimination case) |
| Workers of black, Asian or minority ethnic (BAME) heritage employed in the Council | 2014-10-13 (VIII) | `asia` → "Asian" contains "Asia" |
| Poor representation of workers of BAME heritage in the Commission | 2014-12-18 (VIII) | `asia` → "Asian" |
| Number of Black, Asian and Minority Ethnic managers at the ECDC | 2015-05-19 (VIII) | `asia` → "Asian" |
| Number of employees of BAME heritage at EASA | 2015-12-03 (VIII) | `asia` → "Asian" |
| Thousands of children not in education in Bulgaria | 2017-09-25 (VIII) | `usa` → "Tho**usa**nds" |
| Continued use of the generally accepted terms 'Macedonians' and 'Macedonian' in the language usage of the EP | 2009-01-28 (pre-VII) | `usa` → "l**usa**ge" ("usage") |
| Bedouin expulsion from the east of Jerusalem | 2011-10-18 (VII) | `usa` → "Jer**usa**lem" |

The `usa`→refusal/thousands/usage/Jerusalem/Lausanne family and the `asia`→Asian family are pure substring accidents. The four BAME questions belong to **one MEP (124948)** — a member of the VIII legislature who currently receives **no DV credit** for any of them.

### 4.2 Word-boundary-only variant (v2) — right idea, insufficient

Replacing unbounded stems with word boundaries (`\bafrica\b`, `\busa\b`, `\bchina\b`, `\bsyria\b`, `\biran\b`, …) would re-include **23** questions (15 in VII–IX). But **11 of the 23 must stay excluded** — they are extra-EU cases freed by making `syria`/`iran`/`turkey`/`jerusalem` word-bounded:

- Assyrian/Syriac Christians in Turkey (Tur Abdin 1998; Midyat 2005) and Assyrian minority in Iraq (2009);
- Observance of the Treaty of Lausanne for Imbros and Tenedos (2020); Blatant disregard for the Lausanne Treaty by the Turkish Foreign Ministry spokesperson (2020, 2 rows);
- VP/HR – Treatment of Arab minority by the Iranian Government (2011);
- Refusal of Egypt's Freedom and Justice Party to cooperate with international observers (2011);
- Bedouin expulsion from the east of Jerusalem (2011);
- Harassment of the Guarani Indian people in Brazil (2008).

Hence the fix must combine word boundaries **and newly added keywords** (§9). The projected final configuration (§8) re-includes **12** questions:

| # | Date / term | MEP | Subject (truncated) | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 1996-09-02 pre-VII | 1916 | Refusal to grant daily hunting licences in Germany to Germans living abroad on a long-term basis | re-include per rule — flag: likely LLaMA topic error (§7) |
| 2 | 1998-06-02 pre-VII | 1949 | Refusal by Slovenia to grant citizenship to 70 000 residents | EU-relevant ✓ |
| 3 | 2003-11-11 pre-VII | 24030 | Anti-Semitism among North African and other Islamic immigrants in Europe | EU-relevant ✓ |
| 4 | 2008-09-17 pre-VII | 28255 | UN accusations of racial discrimination | EU-relevant ✓ (vague subject) |
| 5 | 2009-01-28 pre-VII | 4508 | Continued use of the generally accepted terms 'Macedonians' and 'Macedonian' in the language usage of the EP | EU-relevant ✓ |
| 6–9 | 2014-10-13 / 2014-12-18 / 2015-05-19 / 2015-12-03 (VIII) | 124948 | BAME heritage in Council / Commission / ECDC / EASA | EU-relevant ✓✓✓✓ |
| 10 | 2017-09-25 VIII | 124866 | Thousands of children not in education in Bulgaria | EU-relevant ✓ |
| 11 | 2020-03-06 IX | 197523 | Refusal to accept holiday accommodation bookings from people from Silesia Province (Poland) | EU-relevant ✓ |
| 12 | 2020-03-06 IX | 130100 | Implementation of the resolution on fundamental rights of people of African descent | EU-relevant ✓ |

**Inside the study window: 7 genuine questions are currently invisible to the DV** (rows 6–12); the 5 pre-VII re-inclusions have no window impact.

### 4.3 Borderline still excluded — decision table

| Question | Date / term | Keyword | Assessment / action |
| :--- | :--- | :--- | :--- |
| Protection by the EU of the Christian Serb minority in Kosovo | 2011-11-18 (VII) | `christian` | **In-window.** Exclusion follows the manuscript rule ("exclusively Christians") but the case is a European minority; decide in Phase 2. If re-included, MEP 21817 gains 1 DV question in VII. |
| Future prospects for native inhabitants of the Sandžak region of Serbia and Montenegro, who regard themselves as Bosnians | 2005-08-23 (pre-VII) | `native` | EU-relevant Bosniak case; no window impact (pre-VII). |
| Discrimination against native speakers of languages other than English | 2005-05-25 (pre-VII) | `native` | LLaMA topical error; no window impact. |
| Language discrimination – English native speakers | 2002-03-25 (pre-VII) | `native` | Same as above. |
| Preferential treatment of native people in New Caledonia and French Polynesia in the area of employment | 2018-08-03 (VIII) | `native` | **Correct exclusion** (extra-European) — shows why `\bnative\b` must be retained as such. |
| Pupils belonging to the Greek ethnic minority in Tirana deprived of their democratic right to education | 2007-10-15 (pre-VII) | `iran` → "in**Tiran**a" | FALSE exclusion (Europe); caused by the raw `iran` stem matching inside "Tirana"; no window impact; the §9 regex uses `\biran\b|iranians?` to fix the trap. |

Keep `\bnative\b` unchanged: within VII–IX its only match is New Caledonia (correct exclusion); the Sandžak / native-speaker errors are all pre-2009.


## 5. Extra-EU leakage (out-of-scope questions wrongly kept)

A keyword scan of the kept VII–IX set for country/nationality terms absent from the dictionary (`pakistan, tibet, uighur, uyghur, chinese, china, vietnam, guatemala, burma, myanmar, rwanda, congo, cambodia, afghanistan, iraq, egypt, turkish, nigeria, kashmir, nepal, ahmadi, coptic, karen, degar, brazil`) identifies:

- **47 kept VII–IX questions** under the original audit-4 pattern, **49** after adding the two Brazilian-indigenous rows (the audit-4 list predated the Brazil hit);
  - by term: **VII 26 / VIII 16 / IX 7**;
  - **44 distinct MEPs** affected (21 / 16 / 7);
  - **17 MEPs (4 VII / 7 VIII / 6 IX) have these questions as their ONLY DV questions** — i.e. their entire DV presence in the study window is leakage. (The interim figure "16 MEPs" = 4/7/5 referred to the 47-row pattern and missed the Brazilian MEP.)
- Of the 49: **≈ 39 are clean out-of-scope** (Pakistan blasphemy/Ahmadi cases, Tibet repression, Uighur camps, Coptic Egypt, Kurdistan operations, Rwanda, Burma…); **4 are false drops** the revised keywords would wrongly perform (Turkish-speaking minority in Western Thrace, Greece 2014; "Turkish as an official language of the European Parliament" 2012; "Risk of Turkish becoming an official EU language" 2016; "Education through the medium of Turkish in Greece" 2018); **≈ 6 borderline** (Turkish trade-unionist extradition 2011; "Justice for persons affected by Turkish policies" 2011; EU-resident surveillance app 2018; Islamophobia report drafted by a Turkish-linked centre 2021; Turkish Cypriot peace activists 2022; genome research in Europe by Chinese-linked companies 2024).

Missing keywords are the driver: `chinese`, `turkish`, `pakistan`, `tibet`, `uighur/uyghur`, `egypt`, `iraq` are absent from the current list. In the 78-row all-terms projection (Appendix A) keyword attribution (with overlaps): `turkish` 21, `pakistan` 15, `tibet` 6, `uighur` 5, `vietnam` 5, `iraq` 5, `chinese` 5, `burma` 4, `ahmadi` 4, `guatemala/egypt/brazil` 3 each, `rwanda/congo` 2 each, and 1 each for `cambodia, afghan, kashmir, coptic, karen, degar` (`jerusalem, nepal, lausanne, korean` only ever fire on rows already excluded).

## 6. Inert keywords, paper–code mismatch, comment-vs-code

### 6.1 Inert keywords (0 subject hits)

Eight of the 24 keywords never fire on any subject in the 2,324-question set: `patriot`, `political correctness`, `woke`, `reverse discrimination`, `traditional values`, `gender ideology`, `quotas`, `america`. **The documented right-wing result (IRR ≈ 1.7) is therefore not shaped by the keyword filter** — those questions enter (or fail to enter) the DV through the LLaMA topic assignment, not through these keys. Removing the keys from the regex changes nothing in the DV; keeping them only documents an intent the filter does not execute.

On full text the same keys fire rarely and only in prose (full 2,324 set): `patriot` 5, `political correctness` 1, `traditional values` 2, `quotas` 2, `americ*` 15, all others 0 — one more reason to keep the filter off the body text (§6.3). (This corrects the interim session note of "1/0/0/0/2/2/5/0" — superseded by the live counts above.)

### 6.2 Paper vs code

`paper/MEPArticle_Updated.md` describes the exclusion as questions "exclusively concerning Christians, or cases occurring outside Europe". Two mismatches:

1. the implemented rule also excludes **right-wing "reverse discrimination" frames** (7 inert keys); the manuscript's measurement paragraph never mentions this;
2. the implemented geography/religion keys are both over-inclusive (`refusal`, `thousands`, `Asian`, `usage`, `Assyrian`, `native speakers`, `Tirana`) and under-inclusive (no `chinese`, `turkish`, `pakistan`, …) relative to that wording (§4, §5).

### 6.3 Comment vs code (`text` vs `subject`)

The inline comment (§2) says the dummy excludes questions whose **text** contains the keywords; the code applies the keys to **`subject`** only. Subject-only is correct: applying the same keys to title+body would additionally exclude **371** of the 2,139 kept questions (**244 in VII–IX**), including plainly on-scope questions such as "Rampant euroscepticism in Hungary", "Recognition of the German minority in Slovenia", "Cyrillic alphabet in Croatia", "The 'Minority Safepack' citizens' initiative", "UN resolution on 'Elimination of racism, racial discrimination, xenophobia and related intolerance'", and 15 questions on the EU anti-racism framework ("Combating racism and xenophobia…"), which mention "Second World War"/"America"/"Africa" in the body. Text-only-drop attribution (371 rows, overlapping): `usa` 117, `native` 61, `turkey` 55, `christian` 40, `Second World War` 30, `asia` 22, `israel` 22, `africa` 21, `china` 14, `india` 13, `america` 12, `istanbul` 9, `iran` 8, `syria` 8, `palestin` 7, `patriot` 5, `middle east` 4, `hamas` 3, `traditional values` 2, `quotas` 2, `danube` 1, `political correctness` 1, others 0. The manuscript should therefore say *subject/title-based* keyword filter explicitly.

## 7. Residual blind spot: LLaMA topic errors (unfixable by keywords)

Keyword surgery cannot correct upstream misclassification. Examples found during the audit: the 1996 German hunting-licences question (in CAP-201, not a discrimination case), "Rampant euroscepticism in Hungary" (matched only in full text), the 2002 Pancevo/Danube pollution question, the 2024 genome-research question. These stem from the LLaMA topic assignment and motivate the planned **LLM re-validation of all 2,324 CAP-201 questions** (Phase 2) with ~100 manual spot-checks; cf. the existing error taxonomy in `output/GemmaReport_2026-07-22.md`.


## 8. Impact sizing (projection, NOT applied)

Applying the recommended configuration (§9) to the live data:

| Quantity | Current | Projected |
| :--- | :--- | :--- |
| VII–IX kept | 1,323 | **1,281** |
| VII–IX excluded | 123 (8.5%) | 165 (11.4%) |
| MEPs VII / VIII / IX (≥ 1 kept DV) | 237 / 226 / 129 | **233 / 219 / 124** |
| Newly excluded (VII–IX / all terms) | — | 49 (26/16/7) / 78 (29 pre-VII) |
| Re-included | — | 7 in-window / 12 all terms |
| MEPs losing their only DV question | — | 17 (4 / 7 / 6) |
| MEPs gaining a first DV question | — | 1 |

Honest decomposition of the net −42 VII–IX questions:

- **≈ −39** clean extra-EU removals (§5): the largest and most defensible change; it removes 17 MEPs whose DV presence is entirely spurious;
- **−4 to −6** false/borderline drops that Phase 2 must adjudicate (Greek-based Turkish-minority and Turkish language-policy cases, plus the borderline cluster);
- **+7** genuine in-window re-inclusions (4 BAME rows of one MEP; Bulgaria schools; Silesia accommodation refusal; African-descent resolution) and 5 pre-window re-inclusions with no window effect.

Net: the headline count falls **3.2%** while measurement validity improves materially; the EU-relevant DV gains roughly +3 questions. Panel construction and the minority-vs-non MEP counts (51 `minority=1` in the current panel) must be recomputed when Phase 1 runs (`01 → 02 → 05`).

## 9. Recommendations and 3-phase roadmap

**Recommended Phase 1 regex** (word boundaries, added keywords, inert-key removal, `iran`-stem fix; intentional stems kept for `china|turkey|syria|palestin|israel`):

```
(?i)christian|\bafrica\b|palestin|Second World War|\bhamas\b|danube|turkey|turkish|istanbul|\bindia\b|china|chinese|\busa\b|\basia\b|israel|\biran\b|iranians?|syria|middle east|\bnative\b|pakistan|tibet|uighur|uyghur|vietnam|guatemala|burma|myanmar|rwanda|congo|cambodia|afghan|egypt|iraq|jerusalem|brazil|kashmir|nepal|coptic|ahmadi|\bkaren\b|degar|lausanne
```

Design notes: `turkey` stays a stem but `turkish` must be added explicitly (the `chinese`/`china` asymmetry); the `syria` stem keeps catching `Assyrian/Syriac` (Middle-East minorities, per current practice); `iran` must not be a raw stem ("Tirana" trap, §4.3) — hence `\biran\b|iranians?`; `\bnative\b` is kept (§4.3); `america` and the 7 right-wing keys are dropped (0 subject hits, §6.1); `jerusalem` is needed to keep the Bedouin question excluded once `\busa\b` is fixed; the remaining small keys are cheap future-proofing; `korea` can be omitted (0 current hits).

Deferred phases — **"solo analisi per ora; fix completo in un secondo momento"**:

1. **Phase 1 — revised regex + rerun.** Implement the regex in `scripts/01_import_questions.R`, rerun `01 → 02 → 05`, produce an old-vs-new diff report (DV counts, MEP counts, coefficients) in `quality_reports/`.
2. **Phase 2 — LLM re-validation (secondo momento).** Re-validate all 2,324 CAP-201 questions (topic + scope), ~100 manual spot-checks; adjudicate the ⚠/▲ rows of §5 and Appendix A and the Kosovo case of §4.3.
3. **Phase 3 — documentation.** Update the measurement paragraph of `paper/MEPArticle_Updated.md` (subject-based filter; criteria; new counts), the numbers memo, and close this report's status.


## 10. Corrections to the interim session notes (2026-11-06)

- Date range: **10 Jun 1994 → 1 May 2024** (not "1999–2024");
- Only-DV leakage MEPs: **17** (4/7/6) with the two Brazilian-indigenous rows included (the interim "16", 4/7/5, was pattern-limited);
- Inert keys on full text: `patriot` 5, `political correctness` 1, `traditional values` 2, `quotas` 2, `americ*` 15 (interim "1/0/0/0…" note superseded);
- Leakage list: **49 VII–IX** (not 47 — the 2 Brazilian rows came from the extended pattern);
- v2/proj2: "23 (15 in VII–IX)" was the word-boundary-only variant; the recommended configuration re-includes **12 (7 in-window)**.

## 11. Reproducibility appendix

- Audit scripts (session temp, not in repo): `/tmp/dict_audit5.R` … `/tmp/dict_audit9.R`; logs `/tmp/audit6.out`, `/tmp/audit7.out`, `/tmp/audit8b.out`, `/tmp/audit9.out`. This report is self-contained (§2, §4–§6, Appendix A embed all relevant findings).
- Core counts reproduce with:

```r
library(dplyr); library(stringr); library(readr)
epq <- read_rds("data_processed/epq.rds") |>
  mutate(d = as.Date(as.numeric(date), origin = "1970-01-01"),
         term = case_when(d >= "2009-07-14" & d <= "2014-06-30" ~ "VII",
                          d >= "2014-07-01" & d <= "2019-06-30" ~ "VIII",
                          d >= "2019-07-02" & d <= "2024-06-15" ~ "IX",
                          TRUE ~ "pre-VII"))
q   <- filter(epq, as.character(subtopic) == "201")
cur <- "(?i)christian|africa|palestin|Second World War|hamas|danube|turkey|istanbul|india|china|usa|america|asia|israel|iran|syria|middle east|native|patriot|political correctness|woke|reverse discrimination|traditional values|gender ideology|quotas"
q   <- q |> mutate(cur_excl = str_detect(subject, cur))
# → 2,324 rows; 185 excluded; 2,139 kept; VII-IX: 1,323 kept / 123 excluded
#   MEPs ≥1 kept: VII 237 / VIII 226 / IX 129
```

- **v2** projection regex = same list with word boundaries on `africa|hamas|turkey|india|china|usa|asia|iran|syria|native|patriot|quotas`; **proj2** regex = the §9 recommended regex.
- Text counterfactual (§6.3): join `epq_3.0.csv` with `epq_minor_classified-llama_202502.csv` by `id = idOrig` (subtopic = `most_frequent_subtopic`, first row per id), filter `subtopic == "201"`, body = `sub("^[^\n]*\n", "", text)`.

## Appendix A — the 78 questions newly excluded under the recommended regex (all terms)

Verdicts: ✅ correct extra-EU exclusion · ⚠ FALSE (EU-relevant — Phase 2 should rescue) · ▲ borderline (decision).

| Date | Term | MEP | Subject (truncated) | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| 1995-10-25 | pre | 1461 | Immediate release of Ibrahim Akso, a Turkish Kurd | ✅ |
| 1996-04-26 | pre | 2073 | Genuine participation by indigenous peoples in project ALA/93/55 in Guatemala | ✅ |
| 1996-12-06 | pre | 1178 | Ahmadi Muslims in Pakistan | ✅ |
| 2000-02-03 | pre | 2335 | Repopulation of northern regions in Greece where minorities of Macedonian and Turkish origin are resident | ⚠ FALSE (Greece) |
| 2002-08-13 | pre | 2281 | Ending of teaching in the Uighur language in the universities of eastern Turkestan (Xinjiang) | ✅ |
| 2002-11-09 | pre | 1002 | Failure to denounce the Cooperation Agreement with Vietnam (infringement of Article 2) | ✅ |
| 2003-05-02 | pre | 2281 | Situation of Mr Tohti Tunyaz, an ethnic Uighur sentenced to 11 years in prison | ✅ |
| 2003-10-06 | pre | 4745 | Serious and persistent violations of the human rights of the Uighur minority in the Chinese province… | ✅ |
| 2004-03-24 | pre | 4260 | Ethnic discrimination in funding and administration of reconstruction in Iraq | ✅ |
| 2004-07-01 | pre | 24029 | Treatment of Turkish human rights organisation | ✅ |
| 2004-07-21 | pre | 4521 | Protection of religious minorities in Egypt | ✅ |
| 2004-10-26 | pre | 28586 | Statements by Turkish Prime Minister Erdogan | ✅ |
| 2005-04-25 | pre | 1934 | Access to EPSO competitions by Turkish Cypriot nationals | ⚠ FALSE (EU citizens) |
| 2006-03-03 | pre | 28587 | Commission funding of Turkish nationalist organisation | ▲ borderline |
| 2006-05-16 | pre | 28576 | Illegal abduction of Pakistani citizens in Greece | ⚠ FALSE (Greece) |
| 2006-06-13 | pre | 4740 | Arrest by Chinese authorities of three Uyghur adult children of activist Rebiya Kadeer | ✅ |
| 2006-07-11 | pre | 28587 | Turkish racism on Imbros and Tenedos | ✅ (Greek minority, Turkish state — current practice) |
| 2007-07-01 | pre | 1956 | EU-Iraq trade and cooperation agreement | ✅ |
| 2007-12-06 | pre | 28255 | Directives on beatings issued by Turkish Ministry for Religion | ✅ |
| 2008-03-17 | pre | 1002 | Crushing of non-violent demonstrations in Tibet | ✅ |
| 2008-03-18 | pre | 28117 | Democratic Republic of Congo | ✅ |
| 2008-04-12 | pre | 28316 | Support for the indigenous population of Iraq | ✅ |
| 2008-05-20 | pre | 4529 | Unmarked graves in Kashmir | ✅ |
| 2008-05-27 | pre | 21817 | Chinese 'repopulation' of Tibet | ✅ |
| 2008-06-13 | pre | 28134 | Violations of the human rights of Ahmadiyya Muslims in Pakistan | ✅ |
| 2008-07-18 | pre | 23881 | Travelling prohibitions imposed on Turkish Cypriots | ▲ borderline |
| 2008-10-13 | pre | 23881 | Persecution of Catholics in Vietnam | ✅ |
| 2008-10-31 | pre | 28513 | Ahmadi minority in Pakistan | ✅ |
| 2009-03-17 | pre | 4519 | Protection of the Awá tribe in Brazil | ✅ |
| 2009-11-02 | VII | 28117 | Human rights and religious persecution in the Democratic Republic of Congo | ✅ |
| 2009-11-09 | VII | 28251 | Anti-minority laws in Pakistan | ✅ |
| 2010-06-30 | VII | 1403 | Gojra communal violence in Pakistan | ✅ |
| 2010-10-09 | VII | 97203 | Continuous violations of the human rights of the Degar (Montagnard) people, Central Highlands of Vietnam | ✅ |
| 2010-10-12 | VII | 4521 | The case of Karma Samdrup and environmental activism in Tibet | ✅ |
| 2010-10-28 | VII | 96981 | Human rights - the Ahmadiyya Movement | ✅ |
| 2011-02-18 | VII | 4521 | The situation of the Karen people in Burma | ✅ |
| 2011-03-10 | VII | 28584 | Extradition of Turkish trade unionist Gulaferit Unsal | ▲ borderline |
| 2011-03-30 | VII | 4393 | Assassination of Pakistan's Minister for Minorities, Shahbaz Bhatti | ✅ |
| 2011-04-28 | VII | 96733 | Possible funding for projects to protect minorities in Iraq | ✅ |
| 2011-05-18 | VII | 96981 | Turkish AKP Government operations against the Kurds and reports of a massacre | ✅ |
| 2011-06-16 | VII | 96660 | Sectarian Violence in post-revolution Egypt | ✅ |
| 2011-06-16 | VII | 99416 | Justice for persons affected by Turkish policies | ▲ borderline |
| 2011-11-25 | VII | 96994 | VP/HR - The imprisonment of Tibetan monks | ✅ |
| 2011-12-10 | VII | 96813 | VP/HR - Abduction of Coptic girls in Egypt | ✅ |
| 2012-02-21 | VII | 28409 | VP/HR - Indigenous peoples of Guatemala and Colombia | ✅ |
| 2012-05-23 | VII | 28358 | Funds from the EU budget for forced sterilisation in Rwanda | ✅ |
| 2012-08-05 | VII | 4555 | Turkish as an official language of the European Parliament | ⚠ FALSE (EU context) |
| 2012-09-27 | VII | 4393 | VP/HR - Ethnic minorities in Vietnam | ✅ |
| 2012-10-23 | VII | 4393 | VP/HR - Chin ethnic and religious minority in Burma | ✅ |
| 2012-12-17 | VII | 96786 | VP/HR - Victims of Pakistan's blasphemy law | ✅ |
| 2013-01-21 | VII | 97050 | Rapid naturalisation of Turkish citizens by the Turkish Cypriot puppet state | ✅ |
| 2013-02-12 | VII | 96993 | VP/HR - Forced conversions in Pakistan: the case of Saba Waris | ✅ |
| 2013-10-09 | VII | 4521 | VP/HR - Decision by Pakistani Government to downsize the Federal Ministry of Human Rights | ✅ |
| 2014-02-25 | VII | 97198 | Update on discrimination against religious minorities in Pakistan | ✅ |
| 2014-03-20 | VII | 96951 | VP/HR - Employment of religious minorities in Pakistan | ✅ |
| 2014-07-01 | VIII | 96750 | Rights of the Turkish minority in Western Thrace, Greece | ⚠ FALSE (Greece) |
| 2014-12-02 | VIII | 97198 | Arrest of Rimsha Masih in Pakistan: update | ✅ |
| 2015-04-22 | VIII | 125107 | VP/HR - Detention of Mrs Victoire Ingabire in Rwanda | ✅ |
| 2015-07-27 | VIII | 96897 | Educational bias in Pakistani schools | ✅ |
| 2015-10-28 | VIII | 124790 | VP/HR - Protection of indigenous communities in Mato Grosso, Brazil | ✅ |
| 2015-11-30 | VIII | 124866 | VP/HR - Recent attacks against Iraqi Turkmen | ✅ |
| 2016-01-13 | VIII | 125049 | Kurdish women murdered by Turkish police | ✅ |
| 2016-06-24 | VIII | 124873 | Risk of Turkish becoming an official EU language | ⚠ FALSE (EU context) |
| 2016-12-15 | VIII | 28276 | VP/HR - Religious war in Afghanistan | ✅ |
| 2017-07-06 | VIII | 124828 | Racial profiling of the Pashtuns in Pakistan | ✅ |
| 2017-11-28 | VIII | 188624 | EU development projects and humanitarian aid in Myanmar - red lines | ✅ |
| 2018-01-10 | VIII | 96813 | VP/HR - Uighur 're-education' camps | ✅ |
| 2018-01-15 | VIII | 124823 | VP/HR - Economic treaty and human rights in Guatemala | ✅ |
| 2018-03-09 | VIII | 97203 | VP/HR - Thailand: refugees of Cambodian and Vietnamese nationality | ✅ |
| 2018-11-10 | VIII | 38398 | App by means of which EU residents can be reported to the Turkish police | ▲ borderline |
| 2018-12-19 | VIII | 24942 | Education through the medium of Turkish in Greece | ⚠ FALSE (Greece) |
| 2019-09-01 | IX | 28307 | VP/HR - Brazilian President's assault on the rights of indigenous peoples | ✅ |
| 2020-07-05 | IX | 197650 | Repression encouraged by the Chinese authorities in Tibet, on the pretext of tackling COVID-19 | ✅ |
| 2020-10-14 | IX | 197539 | Sensitive personal data wrongfully published by EEAS collaborators in the upcoming election in Myanmar | ✅ |
| 2020-10-29 | IX | 197611 | The militarised educational and training system in Tibet | ✅ |
| 2021-11-05 | IX | 197627 | European report on Islamophobia drafted by a Turkish research centre closely linked to the Muslim Brotherhood | ▲ borderline |
| 2022-02-03 | IX | 197415 | Turkish Cypriot peace activists are not a threat to Turkish national security | ▲ borderline |
| 2024-04-17 | IX | 28353 | Human genome research projects in Europe conducted by companies linked to the Chinese Government and military | ▲ borderline |

**Tally:** ✅ 63 · ⚠ FALSE 7 (of which 4 in-window) · ▲ borderline 8 (of which 6 in-window). Rows 1–29 = pre-VII (no window impact); rows 30–78 = 49 in-window drops.

Phase 2 implications: if all in-window ⚠ rows are rescued, projected VII–IX kept rises from 1,281 to **1,285**; if all in-window ▲ rows are also kept, the plausible range is **1,281 → 1,291** (against the current 1,323). The single most important in-window corrections remain §4.2's 7 re-inclusions — they dwarf the 4–6 rescues in this Appendix in DV terms (one MEP's entire BAME cluster is currently absent from the DV).

---

*Report generated 2026-11-06; read-only audit; no pipeline or manuscript changes. Next step on approval: Phase 1 (§9).*

