# Zeynep's latest paper revision vs *MEPArticle_UpdatedFR.docx*

**Date:** 2026-10-14 · **Compared files (in `paper/`):**
- `MEPArticle_UpdatedFR.docx` (baseline, "FR")
- `MEPArticle_Updated_ZM.docx` (Zeynep's revision, "ZM")

**Method:** text extracted with pandoc (`-t plain`, `--track-changes=accept`), diffed wrapped and unwrapped. ZM contains **no tracked changes** (0 `w:ins`/`w:del`) — it is a direct edit; word count grows 7,924 → 8,949 (+~13%). Title and author block unchanged.

**Section mapping:** FR `Introduction, 1 Theoretical, 2 Data, 3 Concepts and Measures, 4 Findings, 5 Conclusion` → ZM `1 Introduction, 2 Theoretical, 3 Data, 4 Concepts and Measures, 5 Findings, 6 Conclusion`.

---

## 1. Abstract — fully rewritten
- Shorter and more hedged; neither minority background nor MIPEX shows a "clearly identifiable association"; drops the explicit CAP code 201 detail; FR's "the study" becomes "we".
- **Adds a new headline result:** "Right-wing nationalist affiliation is also associated with greater discrimination-related attention" (not in FR abstract).
- **UK dropped:** "26 EU Member States" instead of FR's "26 EU Member States and the United Kingdom".

## 2. Introduction — heavily expanded and re-cited
- New/expanded paragraphs on inequality of political voice for migrants and their descendants: Mügge & Erzeel (2016), Arrighi & Bauböck (2017), Dancygier et al. (2015), **Auer et al. (2025)**.
- **New footnote 1**: "Germany, Spain, the Netherlands, the United Kingdom, and Switzerland" anchoring the immigrant-origin-MP-share claim from **Bergmann et al. (2025)** (REPCHANCE).
- New paragraphs on workplace discrimination against minority MPs (Swedish parliament, **Albertsson & Erikson, 2025**) and REPCHANCE interview evidence (tokenism, portfolio steering in DE/CH).
- Research questions reframed in associational language: FR's "whether biography *systematically shapes*" and "the *prevalence* of migration-related discrimination" become "whether representatives' backgrounds are *associated with*" and "the *strength of* national anti-discrimination frameworks".
- EP/WQ-justification paragraphs merged and condensed.

## 3. Theoretical framework — logic of H3 rebuilt (the big change)
- Descriptive/substantive opening condensed; constructivist/agency paragraphs shortened.
- H1: one wording tweak ("other MEPs" → "their colleagues without such backgrounds"); H2 unchanged.
- **Interaction argument rebuilt.** FR's "institutional conduits" paragraph replaced by a new conditional-representation chain:
  1. Substantive representation as *conditional* on institutional opportunities — **new cites Preuhs (2006), Hänni (2017)**;
  2. Political-opportunity-structure approaches — **new cites Koopmans & Statham (1999), Koopmans (2004)**;
  3. Policy-feedback mechanism (Pierson 1993; Mettler & Soss 2004) moved here and rewritten;
  4. Gyroscopic-representation sensitivity argument;
  5. Non-essentialism paragraph: the argument "does not imply that minority-background representatives necessarily identify with or act on behalf of minority constituencies"; REPCHANCE evidence repurposed as support.
- **H3 restated:** FR "The *expected* relationship … is stronger among MEPs … than among other MEPs." → ZM "The *positive* relationship … *will be* stronger among MEPs … than among their colleagues without such backgrounds."

## 4. Data — 7th term added; MIPEX matching rule tightened
- EUQuest sample now **7th, 8th and 9th terms (2009–2024)** with justification (more minority MEPs, ~2015 politicisation of migration). FR described only 2014–2024.
- **"26 EU Member States"** (no UK) in abstract/intro/data/conclusion. ⚠️ **Inconsistent with the coded data:** `data/minorities7th_coded_final.csv` covers **28 countries — UK 35 MEPs and Croatia 5 included** (full EU-28); FR also analysed the UK and reported it through 2020. ZM still keeps the UK in (a) the five-country footnote, (b) the ENAR benchmark ("28 and 39 MEPs"), (c) the Appendix note ("UK reported through 2020"). Scope description to be decided after the merge.
- MIPEX paragraph: carry-forward rule made explicit ("most recent preceding observation rather than assigning a later score retrospectively"), plus a new sentence that the measure captures the formal framework, not the prevalence/experience of discrimination; term-level measures downgraded to "alternative specification".

## 5. Concepts and Measures — placeholders inserted; robustness sentence dropped
- DV section now contains **two placeholders**: "approximately **[updated percentage]** of all written questions" (FR: 1.1% for 8th–9th) and "**[X] MEPs in the seventh legislature**" submitted ≥1 discrimination-related question (FR: 225 eighth, 124 ninth — unchanged).
- **FR's robustness sentence removed** ("For robustness, alternative specifications use a binary indicator … and a term-level count …") — ZM describes no alternative specifications anywhere (grep: 0 hits).
- MEP-background paragraph: second-generation criterion now explicit ("at least one parent originated from such a country"); new citation **Zevnik & Russell (2026)** for the Roma classification.
- **New conservative-coding paragraph:** "where the available information was ambiguous or insufficient to verify an MEP's migratory or racialised minority background, no minority-background status was assigned." — Direct textual support for keeping our 30 doubt cases at 0 (pending Zeynep's URL checks).
- Minority counts: "**[X]** MEPs in the seventh legislature, 20 in the eighth, and 30 in the ninth"; with current coding **[X] = 16** (subject to change if a doubt case resolves to 1 after her links arrive).
- Figure 1/2 captions updated to "migratory or racialised minority background" / "by parliamentary term"; ENAR paragraph gains an explanation of divergence via the conservative coding rule.

## 6. Findings — results untouched, right-wing discussion expanded
- **Table 1 and the surrounding numbers (LIBE β=0.429, H3 CI [1.6%, 12.5%], male β=0.015, …) are identical to FR** — reported estimates are still from the 8th/9th-term fit; no re-estimation with the 7th term yet.
- Changes: heading renumbered; cosmetic fix `]). ]).` → `]).]).`; and the **right-wing nationalist result rewritten from one cautious paragraph into three**: β rounded to 0.525 [0.158, 0.899] ("69.1 per cent"), new interpretation that attention ≠ substantively favourable representation, discussion of alternative political uses (protection vs. challenging anti-discrimination measures), and a DV-interpretation implication paragraph — consistent with the new abstract sentence.

## 7. Conclusion — fully rewritten
- Framed around 7th–9th terms (2009–2024) and a "conditional understanding" of descriptive vs substantive representation.
- Three contributions kept but rephrased; gyroscopic citation corrected to Mansbridge (2003) (both Mansbridge 1999 and 2003 are already in the reference list).
- Expanded limitations: DV direction/content; small-N sensitivity (extending to the 7th legislature increased coverage while remaining limited; 6th flagged as future work); MIPEX formal-vs-implementation; single-arena (written questions) caveat.
- New closing paragraph tying conditionality to the right-wing attention finding.

## 8. Reference list, keywords, footnotes
- **References list unchanged — five in-text citations now lack entries:** Koopmans & Statham (1999); Koopmans (2004); Preuhs (2006); Hänni (2017); Zevnik & Russell (2026). (Verified: 0 hits in ZM's references block, lines 977–1236.)
- Only docx footnote (MIPEX link) renumbered [2]; new footnote [1] (five-country list).
- Keywords changed: "migrant-origin politicians" → "migrant-origin representatives"; **"European Parliament; EUQuest; MIPEX" removed**; "Members of the European Parliament (MEPs)" added.

## 9. Typos / editing slips in ZM (actionable)
1. "**[updated percentage]**" — DV share, §Measures (fill from pipeline after merge).
2. "**[X]** MEPs in the seventh legislature" — ×2 (minority count; ≥1-question MEPs).
3. Duplicated sentence: "The article makes three main contributions. The article makes three main contributions." (opening of §Conclusion).
4. "pollical agendas" → "political agendas" (§Introduction, first paragraph).
5. "This barriers matter" → "These barriers matter" (§Introduction).
6. "Eventually, this procedure identified [X]…" — suggest "Overall," / "In total,".

## 10. Implications for the repo pipeline (merge + re-run)
- The merge (`minorities7th_coded_zm.xlsx` → `euquest/data_raw/minority.csv`, keyed upsert) plus the pipeline re-run are what fill the placeholders and regenerate Table 1 for the claimed 2009–2024 sample; as of this revision the manuscript still carries the 8th/9th-only estimates.
- DV placeholders need: code-201 share among 7–9-term questions, and the count of 7th-term MEPs with ≥1 such question.
- To resolve with Zeynep/Federico: country scope ("26 EU Member States" vs data incl. UK/Croatia); whether dropping the robustness-specification sentence is intentional; add the five missing reference entries.

## 11. Reproduction
```bash
cd /home/federusso/progetti/EPmigrants/paper
pandoc -t plain MEPArticle_UpdatedFR.docx -o /tmp/fr_w.txt
pandoc -t plain MEPArticle_Updated_ZM.docx -o /tmp/zm_w.txt
diff -u /tmp/fr_w.txt /tmp/zm_w.txt          # wrapped diff, 1152 changed lines
pandoc --track-changes=all -t markdown MEPArticle_Updated_ZM.docx -o /tmp/mep_zm_all.md
grep -c '\.insertion\|\.deletion' /tmp/mep_zm_all.md   # 0 → no tracked changes
```
