# CAP Topic Scan — Minority MEPs' Agenda (VII–IX)

**Exploratory.** Script: `explorations/cap_topic_scan/01_topic_scan.R` (seed `20260321`).
Run: `Rscript explorations/cap_topic_scan/01_topic_scan.R`. No pipeline files are modified.

## What this is

Follow-up to the null controlled result on CAP-201 (ethnic/racial/ethnic-minority
discrimination questions). The scan maps *where* minority-background MEPs put more
emphasis across the CAP coding (majors + minor subtopic codes), using two layers:

1. **Descriptive map** — question shares per group, MEP-level bootstrap 95% CIs
   (2,000 draws) on the *share difference*. Minority-authored: 1,801 questions
   (51 MEPs); non-minority: 120,422 (1,569 MEPs), VII–IX (2009-07-14 → 2024-06-08).
2. **Controlled scan** — per-topic MEP-year counts fitted with NB2 GLMMs
   (`glmmTMB`, no zero-inflation) on the *exact* sample of
   `scripts/05_models_Bayesian.R` (9,850 rows, 51 minority MEPs):
   `topic ~ minority + gender + misery_index + party_family + libe +
   offset(log(total_questions + 1)) + (1 | country)`; BH-FDR within each code family.

## Validation (mirroring the pipeline)

- Sanity A: reconstructed question→`leg_year` assignment reproduces the pipeline's
  `pqs_discrimination` **exactly** on all 9,850 rows (window mapping identical to `02`).
- Sanity B: summed topic counts == `total_questions` (difference = 0 rows; only the
  7 NA-coded `epq` rows in the full file never match a topic).
- Full-window (VI–IX) sensitivity replicates every sign (see
  `descriptives_major_fullwindow.csv`).

## Headline (descriptives, VII–IX)

**Over-indexed (share ratio; bootstrap share-diff CI in pp):**
International Affairs **1.47×** ([+1.0, +9.9]); Immigration **2.43×** ([−1.5, +19.3], wide);
Civil Rights 1.30× (ns); Transportation 1.53× (ns); **Defense 3.94×** ([−0.7, +6.2], n=55).

**Under-indexed (CIs exclude 0):** Environment −5.8pp, Agriculture −5.0pp,
Macroeconomics −4.3pp, Health −2.9pp, Energy −2.0pp, Housing −1.0pp, Government
Operations −0.9pp. Parity: Labor, Education, Domestic Commerce, Social Welfare,
Foreign Trade, Technology, Law and Crime.

## Controlled scan (IRR = exp(minority); FDR < 0.05 in bold)

**Majors:** **International Affairs 1.66** [1.34, 2.06]; **Defense 2.23** [1.44, 3.47];
**Transportation 1.36**; **Immigration 1.35** [1.04, 1.75]; **Environment 0.57**;
**Agriculture 0.54**; **Energy 0.45**; **Government Operations 0.42**; **Macroeconomics
0.76**; **Health 0.67**. Null: Civil Rights 1.17 (pBH .13), Science & Technology 1.03,
Law and Crime 1.07, etc.

**Minors (18 codes with ≥25 minority events):** FDR survivors —

| code | inductive label (from `examples_minor_top.csv` subjects) | IRR [CI] | FDR p |
|---|---|---|---|
| `2_201` | Ethnic/racial discrimination (project-established) | **2.40** [1.67, 3.44] | 4.1e-05 |
| `19_1925` | Human rights & democracy abroad (Iran, Saudi Arabia, Mexico, US death penalty) | **2.23** [1.58, 3.16] | 4.7e-05 |
| `9_950` | Border control & Frontex (irregular arrivals, European Border Guard) | **2.50** [1.60, 3.90] | 3.3e-04 |
| `19_1905` | Development aid & rights abroad (aid programmes, Cuba, Western Sahara) | **1.88** [1.31, 2.69] | 0.0024 |
| `19_1927` | Terrorism & security (EU list, Caucasus, Iraq) | **2.36** [1.40, 3.98] | 0.0045 |

Near-misses (FDR ≥ .05): `19_1901` aid management (1.48, .079), `10_1003` air
passenger rights (1.69, .106), `10_1002` road safety (.171), `2_202` women/gender
violence (1.39, .174), `9_933` irregular immigration & readmissions (1.37, .174).
Interesting non-replications: `7_731` climate (0.77), `1_107` EU taxation (0.76),
`2_208` data protection (0.90), `9_931` asylum (1.04).

## Reading

1. The story is **not immigration alone**. The over-emphasis concentrates on a
   coherent *human-rights/security* bundle — discrimination (201), human rights and
   democracy abroad (1925), aid (1901/1905), terrorism (1927), border enforcement
   (950) — against a strong *under*-emphasis on economic/domestic-productivity
   domains (environment, agriculture, energy, macro, health).
2. The "Civil Rights" major is diluted: its bulk (gender, disability, data
   protection, civil society) is at parity (IRR ≈ 0.9–1.4, ns); the family's raw
   over-indexation comes almost entirely from `2_201`.
3. Raw-vs-controlled divergence is biggest for Immigration: raw ratio 2.43×,
   but IRR 1.35 after controls — composition (party family, country) explains
   about half the raw over-emphasis; what resists is the enforcement component
   (`9_950` border control, IRR 2.50), while asylum (`9_931`, IRR 1.04) is at
   parity and `9_933` (irregular immigration, raw 2.27×) loses control
   (IRR 1.37, pBH .174). Transportation, by contrast, gains in the controlled layer.

## Relation to the paper's CAP-201 result

In the same 9,850-row sample, the paper's ZINB main effect of minority is null
(`b_minority` = 0.50 [−0.33, 1.20] CMP model; 0.44 [−0.26, 1.06] MIPEX model),
while this scan's NB2 GLMM returns IRR = 2.40 with FDR < 1e-4. Point estimates
overlap; the gap is estimator-driven (zero-inflation, priors, interaction
specification). The same coefficient is specification-sensitive across the
project's own models: frequentist ZINB appendix (per-MEP + country REs) gives
IRR ≈ 1.05 (p < .001), Bayesian ZINB 1.55 (ns), this scan's NB2 2.40 (sig);
post CAP-201-filter fix, the paper's H3 interaction is also ns ([−0.002, 0.080]).
The stable facts across all specifications: raw over-representation ≈ 2.5× and
the relative topic ranking above. Recommendation: keep the paper's ZINB result
untouched; read the scan IRRs as *relative emphasis* across topics (where the
same estimator is used for every topic, so comparisons are internally consistent).

## Caveats

- Attention asked ≠ position taken; PQs are an agenda indicator, not a stance.
- 51 minority MEPs (Social democrats + Greens/EFA heavy): composition, not
  ethnicity alone, drives the party-family controls; power is limited for thin topics.
- Minor codes are LLaMA-assigned; the repo has **no minor-codebook**, so labels
  here are inductive (subjects in `examples_minor_top.csv`); Phase-2 LLM
  re-validation remains an open project deliverable.
- NB2 without zero-inflation (scan) vs ZINB (paper); FDR per code family; minority
  MEP author-years ~301 of 9,850 rows.

## Files (in `explorations/cap_topic_scan/out/`)

`descriptives_major_vii_ix.csv`, `descriptives_minor_vii_ix.csv`,
`descriptives_major_fullwindow.csv`, `examples_minor_top.csv`,
`models_major.csv`, `models_minor.csv`,
`fig_share_diff_majors.png`, `fig_share_ratio_minors.png`, `fig_model_irr.png`.
