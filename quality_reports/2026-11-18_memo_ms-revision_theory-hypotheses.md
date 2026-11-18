# Memo — theory/hypotheses-relevant implications of the TERM/LIBE integration

**Date:** 2026-11-18 · **For:** Federico Russo · **Base:** `paper/MEPArticle_12_11_2026.md` @ `1640bd9` + today's integration edits

## Scope

FR directed that Section 2 (Theoretical Framework and Hypotheses) and the hypothesis statements stay untouched in this integration round. This memo records, for future drafts, the points raised by the promoted variant results (TERM heterogeneity, LIBE interaction) that bear on the theory section and on H1–H3. None of them is a contradiction; all are candidates for one targeted paragraph or an explicit revision decision later.

## Items

### 1. H1 is term-varying; a salience-moderation clause is the natural extension

The TERM variant shows the minority-background association peaking in the eighth term (2014--2019: IRR ≈ 10.30, CrI [3.72, 27.07]) relative to the seventh (≈ 2.80) and ninth (≈ 5.86); the eighth-vs-seventh contrast is credible (3.72, CrI [1.33, 10.18]). Section 2's current account (biography-driven attention) is agnostic about temporal heterogeneity, so no inconsistency arises — but a reviewer may ask the theory to anticipate *why* the association strengthens exactly when migration salience peaks (the 2015 crisis falls inside the eighth term). Candidate refinement: an explicit "political environment × biography" salience clause, kept distinct from H3's policy-context (MIPEX) channel. Note the asymmetry the variants expose: policy context does **not** moderate (H3 null under both engines), while temporal-political variation **is** credible.

### 2. The LIBE interaction null supports the "channel" reading of committee membership

Interaction β = 0.584, CrI [−0.593, 1.739] (ns), while both components are large (ON-LIBE minority IRR 7.06; OFF-LIBE 3.92; LIBE boost 3.39 among minority vs 1.91 among others). This is consistent with committee membership operating as an institutional *channel* through which biographically grounded attention is translated into activity — the interpretation underlying the total/direct-effect distinction — rather than as a moderator of the minority effect. No hypothesis currently commits to either reading; if a future draft states an institutional-moderation expectation, the variant bears on it directly.

### 3. Uncited Jones & Baumgartner (2005)

The reference list contains "Jones, B. D., & Baumgartner, F. R. (2005). *The politics of attention*" — never cited in the text (grep-verified 2026-11-18: the only occurrence is the References entry). Decision needed: cite in Section 2 (the attention/agenda literature fits the salience point of item 1) or drop the entry. Not fixed in this round — out of scope.

### 4. MIPEX main-effect threshold instability (frequentist vs Bayesian)

In the maximum-likelihood mirror the MIPEX main effect clears the conventional threshold (Wald p ≈ .007/.010 in M1/M2), while the Bayesian CrIs in Table 1 include zero by a hair; the Non-Inscrits dummy shows the mirror-image flip (Bayesian CrI excludes zero, Wald does not). Now disclosed in Appendix C. H3 itself (the interaction) is null under **both** engines, so the hypothesis-level conclusion is robust; only the descriptive claim about national frameworks is engine-dependent at the threshold.

### 5. VIII-term peak and the observation-window rationale

The Data section motivates the 2009--2024 window by the post-2015 heightened salience; the VIII-term peak is consistent with that motivation, and the new Findings passage says so with an explicit caveat (the design cannot separate the salience environment from the composition of the eighth Parliament). If Section 2 adopts a salience-moderation mechanism (item 1), this limitation should travel with it.

## Collateral (recorded for completeness; none bears on the hypotheses)

- **ML country-RE boundary:** in the glmmTMB twins the country-level random-intercept SD sits at the boundary (≈ 0) vs Bayesian 0.4409/0.4323; MEP-level SD 1.3529/1.2991 vs Bayesian 1.1224/1.0774. Verified with a controlled synthetic-fit experiment; the archived ladder-fit thetas are byte-identical, so this is not remediation damage. Disclosed in Appendix C.
- **ZI intercept at the boundary:** the ML fits place the zero-inflation intercept at logit ≈ −16.5/−15.4 with huge SEs — zero-inflation is only weakly identified without a prior. Harmless for the fixed-effect mirror.
- **Lighter variant sampling settings** (4 chains × 2,000 iterations, 1,000 warm-up vs primary 4 × 4,000/1,500) are disclosed inline in both Findings passages; a uniform-settings re-run remains an available optional follow-up (FR decision).
- **27-vs-28-country discrepancy resolved:** the LIBE variant sample is 28 countries (11,042 rows; Malta retained once the MIPEX coverage restriction is lifted); the "27" in the promotion report is stale.

## Provenance

All integrated numbers were verified this session against `quality_reports/2026-11-18_variant-promotion-refits_term-cmp-libe.md` (§6b) and the variant scripts' formulas (read directly); the Table C1 maximum-likelihood coefficients were re-extracted live from `output/zinb_model_m1_total.rds` / `output/zinb_model_m2_direct.rds` on 2026-11-18 and match the manuscript's Robustness prose exactly.