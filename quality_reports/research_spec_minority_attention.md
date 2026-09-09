# Research Specification — Minority Background, Anti-Discrimination Frameworks, and Legislative Attention in the European Parliament

**Project:** EPmigrants — Migration, Political Representation, and Policy Responsiveness in the European Parliament
**Working title:** *Does Biography Matter? Minority Background, National Anti-Discrimination Frameworks, and Legislative Attention in the European Parliament*
**Authors:** Zeynep Mentesoglu Tardivo (Università degli Studi di Milano); Federico Russo (Università del Salento)
**Created / last updated:** 2026-09-09
**Status:** CURRENT — shared design reference for both authors. §7 (H3 theory) is under active revision following SISP 2026 feedback.

---

## 1. Research Question

Does the migratory or racialised minority background of Members of the European Parliament (MEPs)
translate into legislative attention to discrimination-related issues — and does this relationship
depend on the strength of the national anti-discrimination policy framework in the MEPs' country of
election?

Written parliamentary questions are the observation window of choice: they are individually
discretionary instruments (unlike roll-call voting under party discipline), so choosing to ask about
discrimination signals issue prioritisation. A discrimination-related question evidences attention,
not necessarily an identity-based representative claim.

## 2. Division of Labor

| Workstream | Owner |
|---|---|
| Theory development, especially the H3 conditional argument (SISP 2026 revision) | Zeynep Mentesoglu Tardivo |
| Hand-coding of minority background, 7th term (468 MEPs; 6th term optional) | Zeynep Mentesoglu Tardivo |
| Data pipeline, merge, estimation, analyses | Federico Russo |
| Document drafting, merge automation, reports, cross-references | Cline (AI assistant) |

## 3. Theoretical Framework

### 3.1 Minority background and substantive representation (→ H1)

Descriptive representation can translate into substantive representation where legislators exercise
discretion over issue selection. In party-disciplined activities (roll-call voting) biography leaves
little scope; in parliamentary questions, debates, and committee activity the link is clearer
(Bird, 2011; Celis, 2008; Minta & Sinclair-Chapman, 2013; Saalfeld & Bischof, 2013; Toró, 2018).
Questions are low-barrier, individually visible instruments that representatives use to signal
concern and build individual reputations (Russo & Wiberg, 2010).

### 3.2 Policy feedback from anti-discrimination frameworks (→ H2)

Public policies restructure subsequent political processes by shaping resources, incentives,
information, and interpretive cues (Pierson, 1993; Mettler & Soss, 2004). Stronger national
anti-discrimination frameworks may generate (i) *resource effects* — legal procedures, equality
bodies, expertise, and institutional venues through which discrimination concerns can be articulated
and scrutinised; and (ii) *interpretive effects* — public recognition of discrimination as a
legitimate object of political intervention, plus legal categories and policy language for framing it.

### 3.3 Conditional effects (→ H3) — UNDER REVISION

Current rationale: policy elites differ in how they interpret and exploit institutional contexts.
Minority-background MEPs hold experiential knowledge and community ties, so stronger frameworks
disproportionately *activate* their biography, converting institutional resources into legislative
attention (informed by REPCHANCE evidence on "institutional conduits").
**Status: judged "too thin" at SISP 2026; revision in progress — see §7.**

## 4. Hypotheses and Current Empirical Status (8th–9th terms)

| # | Hypothesis | Status (Bayesian ZINB, manuscript Table 1) |
|---|---|---|
| H1 | MEPs with migratory or racialised minority backgrounds are more likely than other MEPs to submit parliamentary questions addressing discrimination-related issues. | **Not supported** — β = 0.327, 95% CrI [−0.595, 1.151] |
| H2 | MEPs elected in countries with stronger anti-discrimination policy frameworks devote greater parliamentary attention to discrimination-related issues. | **Not supported** — β = −0.0007, 95% CrI [−0.013, 0.011] |
| H3 | The relationship between minority background and discrimination-related parliamentary attention becomes stronger as national anti-discrimination frameworks become more comprehensive. | **Supported** — β = 0.0658, 95% CrI [0.016, 0.117] |

Secondary correlates: LIBE Committee membership β = 0.429, 95% CrI [0.079, 0.751]; gender (male)
β = 0.015, 95% CrI [−0.191, 0.219]. The frequentist `glmmTMB` counterpart corroborates H3
(M4 `minority:mipex_center`, p = 0.024). Full estimates: `output/bayesian_model_results.csv` and
`quality_reports/bayesian_model_results_report.md`.

## 5. Data and Measurement

- **Corpus:** EUQuest — ~180,000 Questions for Written Answer (1994–2024), classified into 20 CAP
  policy topics (LLaMA-assisted), with a comprehensive MEP-level biographical and political dataset.
- **Sample:** MEPs elected in 26 EU Member States and the United Kingdom, 8th (2014–2019) and
  9th (2019–2024) terms; MEP-year panel.
- **Dependent variable:** annual count per MEP of questions under CAP minor-topic 201, *"Ethnic
  Minority and Racial Group Discrimination"* (~1.1% of all 8th/9th-term questions; ≥1 such question
  from 225 MEPs in the 8th and 124 in the 9th term). Automated classification accuracy ≈ 75%, so
  code-201 questions were manually reviewed and cleaned (excluded, e.g., exclusively anti-Christian
  discrimination; cases outside Europe). Robustness DVs: any-question binary; term-level count.
- **Minority background (key IV):** hand-coded — first- or second-generation migrant from a non-EU
  country outside the Global North; Roma MEPs included (racialised minority exposed to persistent
  ethnic discrimination). The EP collects no systematic ethnicity data and place of birth is an
  incomplete proxy (misses second-generation MEPs), so the indicator was built through original
  biographical research on public sources. Current counts: **20** minority-background MEPs in the
  8th and **30** in the 9th term (ENAR benchmark: 3.3% / 28 and 4.5% / 39 MEPs respectively).
- **MIPEX anti-discrimination score:** 0–100 index of the legal and institutional framework
  protecting against discrimination by racial or ethnic origin, religion, and nationality; available
  **2007+**; matched to MEP-year by country of election (nearest *preceding* assessment when the
  exact year is missing; future values never used; assessment year retained for transparency).
- **Controls:** gender, party family, LIBE Committee membership, national misery index; exposure
  offset `log(total_questions + 1)`.

## 6. Estimation Strategy

- **Primary specification** (`scripts/05_models_Bayesian.R`): Bayesian zero-inflated negative
  binomial GLMMs (`brms`). Hypothesis model: `pqs_discrimination ~ gender + misery_index +
  party_family + libe + minority * mipex_center + offset(log(total_questions + 1)) + (1 | country)`;
  priors `student_t(3, 0, 2.5)` on `b` and `zi`; 4 chains × 2,000 iterations (1,000 warm-up),
  `adapt_delta = 0.95`; fits cached to `output/bayesian_model_{cmp,mipex}`.
- **Why Bayesian:** robust to the small number of country groups; accommodates time-invariant
  country characteristics in interactions (which break fixed-effects models); handles zero inflation
  and overdispersion.
- **Robustness/comparison:** frequentist ZINB multilevel models (`glmmTMB`, `05_models.R`, crossed
  `(1 | mep_id) + (1 | country)`: M2/M4 converge — M4 interaction p = 0.024; M1/M3 produce NaN SEs,
  resolution options in TO_DO.txt); FE variants (`05_models_FE.R`); exploratory
  `minority * cmp_center` model (`bayesian_model_cmp`); model comparison (`06_model_comparison*.R`);
  unified coefficient extraction (`07_extract_all_coefficients.R`).
- **Pipeline:** `scripts/run_pipeline.R` runs 01 → 02 → 03 → 04 → 05 (Bayesian) → 06 (Bayesian).

## 7. Planned Revision — H3 Theory (SISP 2026 Feedback)

Discussants judged the H3 rationale too thin. Owner: Zeynep. First step: complete
`quality_reports/2026-09-09_sisp-feedback.md`. Candidate directions (menu, not a mandate):

1. **Citizenship/policy regimes and claims-making** — Koopmans, Statham, Giugni & Passy,
   *Contested Citizenship* (2005): national citizenship and anti-discrimination regimes shape who
   makes which claims, and how — the macro-level analogue of H3.
2. **Social construction of target populations** — Schneider & Ingram (1993): policies send
   interpretive cues about groups' social standing and deservingness, directly operationalising the
   interpretive channel.
3. **Political opportunity structures** — stronger frameworks as open opportunity structures that
   minority-background representatives are uniquely positioned to exploit (Tarrow; McAdam),
   formalising the "institutional conduit" intuition.
4. **Mechanism separation + competing expectation** — derive the resource and interpretive channels
   explicitly and state the rival *substitution* expectation (strong frameworks raise everyone's
   attention, narrowing the minority gap), so H3 becomes a discriminating test rather than a
   one-sided prediction.
5. **Micro-foundations from national parliaments** — Saalfeld & Bischof (2013) plus evidence on
   migrant-origin MPs (e.g., Wüst; Daneri) showing the mechanism travels across arenas.
6. **Observable implications** — sign of the interaction; marginal-effects profile of `minority`
   across the observed MIPEX range; stated as ex-ante predictions.

**Deliverable:** revised theory section in `paper/MEPArticle_Updated.md` + new references for `ep.bib`.

## 8. Scope Extension — 7th (optionally 6th) Term

- **7th term (2009–2014):** all inputs are already in-repo (biographies `data/meps.csv`; groups and
  committees `data/meps_com_gr.csv`; questions `epq_3.0.csv` 1994–2025; MIPEX 2007–2024;
  country-level variables 2004–2024; MEP-year panel via `02_df_setup.R`). Only the minority coding
  is missing: **468 MEPs** in `data/minorities7th_tocode.{csv,xlsx}`.
- **6th term (2004–2009, optional):** **749 MEPs** in `data/minorities6th_tocode.{csv,xlsx}`.
  Caveat: MIPEX starts in 2007, so 2004–2006 MEP-years lack scores → restrict the 6th-term sample
  to 2007+ or exclude the term. **218 MEPs** overlap between the two worksheets; coding is
  reusable across terms.
- **Pipeline change:** widen the term filter at `scripts/05_models_Bayesian.R` (~line 51) to
  `c("7th", "8th", "9th")`, archive cached fits, re-run `scripts/run_pipeline.R`.

## 9. Known Limitations

1. The DV captures attention, not its direction or normative content — right-wing nationalist MEPs
   also raise CAP 201 issues, possibly critically; textual analysis is needed to separate protective
   advocacy from oppositional framing.
2. Few minority-background MEPs (20 + 30 in the current sample) → limited power; estimates may be
   sensitive to a few individuals. The 7th-term extension mitigates this.
3. MIPEX captures formal legal strength, not implementation or experienced discrimination.
4. Hand-coding for earlier terms depends on biographical availability; a cross-coder consistency
   spot-check is recommended.

## 10. Open Decisions

| # | Decision | Options / notes | Owner |
|---|---|---|---|
| 1 | Primary specification | Bayesian `brms` (current pipeline default) vs frequentist `glmmTMB` | Federico |
| 2 | Random-intercept reconciliation | Manuscript states a per-MEP intercept; `05_models_Bayesian.R` has `(1 | country)` only → add `(1 | mep_id)`, amend the text, or run both as robustness | Federico (+ Cline) |
| 3 | M1/M3 NaN standard errors in `05_models.R` | `nlminb` + more iterations / simplify random effects / Bayesian-primary | Federico |
| 4 | 6th-term scope | Exclude, or include with MIPEX 2007+ restriction | Both |
| 5 | Target journal | Shapes framing, length, review strategy | Both |

## 11. Related Documents

- Implementation plan: `quality_reports/plans/2026-09-09_minority-attention-implementation.md`
- Next steps plan: `quality_reports/plans/2026-09-09_minority-attention-next-steps.md`
- SISP 2026 feedback memo: `quality_reports/2026-09-09_sisp-feedback.md`
- Manuscript: `paper/MEPArticle_Updated.md`; results report: `quality_reports/bayesian_model_results_report.md`
- Task tracker: `TO_DO.txt`; project index: `PROJECT_INDEX.md`