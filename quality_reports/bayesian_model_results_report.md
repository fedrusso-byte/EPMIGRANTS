# 📊 Bayesian Model Results Report

*Updated 2026-11-06 — re-fitted after the **CAP-201 DV dictionary-filter fix** (audit §9 regex + rescue allowlist; implementation & diff: `quality_reports/2026-11-06_CAP201-filter-implementation.md`): N = 9,850 observations, 1,543 unique MEPs (51 with a migration-minority background — panel composition unchanged), VII–IX kept DV questions 1,323 → 1,285. Diagnostics: max R̂ = 1.004, min ESS ≈ 1,538. Full estimates: `output/bayesian_model_results.csv`; the pre-fix fit is archived in `output/archive_cap201_prefilter_2026-11-06/`. Previous fit (2026-11-05, before the filter fix): all R̂ ≤ 1.005, min ESS ≈ 1,000.*

## 1. Executive Summary
The Bayesian analysis examines the interaction between MEP characteristics and the responsiveness of policy positions to external indicators (CMP and MIPEX). 

**Key Finding:** The strong, statistically significant positive effects of being a **Right-Wing Nationalist** and a **Liberal** (as well as **Greens**, **Eurosceptics** and **Non-attached** MEPs) on responsiveness are robust to the extended sample and to the CAP-201 DV-filter fix. By contrast, the previously significant main effect of "minority" status in the CMP model is **no longer significant** once the 7th legislature is included; the minority-related finding remains the **positive interaction between minority status and the MIPEX center (H3)** — however, after the DV-filter fix its 95% credible interval **no longer excludes zero** (β = 0.038, CrI [−0.002, 0.080]): evidence for H3 is suggestive rather than decisive.

---

## 2. Detailed Model Analysis

### 📈 CMP Interaction Model
The CMP Interaction model evaluates how MEP attributes influence the relationship between the CMP center and policy positions.

| Variable | Estimate | 95% Credible Interval | Significance |
| :--- | :---: | :---: | :---: |
| **Right-Wing Nationalists** | `0.542` | `[0.229, 0.853]` | ✅ Significant |
| **Liberals** | `0.308` | `[0.029, 0.575]` | ✅ Significant |
| **Minority Status** | `0.498` | `[-0.330, 1.197]` | ❌ Not Sig. |
| **Minority $\times$ CMP Center** | `0.107` | `[-0.038, 0.275]` | ❌ Not Sig. |
| **Eurosceptic Cons.** | `0.357` | `[0.052, 0.665]` | ✅ Significant |
| **Misery Index** | `0.002` | `[-0.009, 0.013]` | ❌ Not Sig. |

**Observations:**
- The largest positive effects now belong to **party families** rather than minority status: **Right-Wing Nationalists** ($\beta \approx 0.54$), **Eurosceptics** ($\beta \approx 0.53$), **Greens** ($\beta \approx 0.49$), **Non-attached** ($\beta \approx 0.63$, the largest) and **Liberals** ($\beta \approx 0.31$) are all significantly more responsive to the CMP metrics than the baseline. **Eurosceptic Conservatives** ($\beta \approx 0.36$) cross the significance threshold in this fit (negligible in the 8th/9th-only fit).
- The **minority main effect** ($\beta \approx 0.50$) and its **interaction with the CMP center** ($\beta \approx 0.11$) are indistinguishable from zero — the strong minority-CMP result from the 8th/9th-only fit ($\beta \approx 1.06$, `[0.080, 1.917]`) does not survive the 7th-legislature extension.

### 📈 MIPEX Interaction Model
The MIPEX Interaction model looks at the responsiveness to the MIPEX (migration policy) indicators.

| Variable | Estimate | 95% Credible Interval | Significance |
| :--- | :---: | :---: | :---: |
| **Right-Wing Nationalists** | `0.496` | `[0.182, 0.812]` | ✅ Significant |
| **Liberals** | `0.289` | `[0.027, 0.553]` | ✅ Significant |
| **Minority Status** | `0.438` | `[-0.256, 1.063]` | ❌ Not Sig. |
| **Minority $\times$ MIPEX Center** | `0.038` | `[-0.002, 0.080]` | ❌ Not Sig. |

**Observations:**
- Similar to the CMP model, **Right-Wing Nationalists** and **Liberals** show significant positive responsiveness.
- The **interaction between minority status and the MIPEX center** remains positive ($\beta \approx 0.038$, 95% CrI `[-0.002, 0.080]`; IRR $\approx$ 1.04 per point of mipex_center), but after the CAP-201 DV-filter fix its 95% CrI **includes zero** — H3 is no longer supported at the strict CrI-excludes-zero criterion. The main effect of "minority" stays non-significant ($\beta \approx 0.44$), keeping H3's interpretation interaction-driven.

---

## 3. Comparative Conclusions
1. **Consistency:** The responsiveness of **Right-Wing Nationalists** and **Liberals** — together with **Eurosceptic**, **Green** and **Non-attached** MEPs — is consistent across both the CMP and MIPEX frameworks.
2. **Minority Dynamics:** The general responsiveness of minority MEPs found in the earlier 8th/9th-only CMP fit does not replicate on the extended sample; minority-related responsiveness is confined to the **interaction with the MIPEX center (H3)**, which is positive in sign but, after the DV-filter fix, statistically non-significant ($\beta \approx 0.038$, CrI including 0).
3. **Non-Factors:** Gender, the Misery Index, and the main effects of the CMP/MIPEX centers do not appear to play a significant role in the responsiveness of these models.

*Note: Figures generated by the pipeline in `output/figures/` (`bayesian_interaction_magnitude_panel.png`) should be cross-referenced with these tables to visualize the distribution of the posterior estimates. This report reflects the 2026-11-06 re-run after the CAP-201 DV dictionary-filter fix (`output/archive_cap201_prefilter_2026-11-06/` holds the pre-fix snapshot); the earlier 2026-11-05 fit merged the hand-coded 7th-legislature minority roster, and the 8th/9th-only estimates are archived in `output/archive_8th9th/`.*