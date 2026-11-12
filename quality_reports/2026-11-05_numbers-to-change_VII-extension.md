# Memo — Numeri da aggiornare nel manoscritto dopo l'estensione alla VII legislatura

**Data:** 2026-11-05 · **Modello di riferimento:** `05_models_Bayesian.R` (Minority × MIPEX), come Table 1 ms · **Decisione:** integrazione manuale da parte di Federico (nessuna edit diretta al ms).
**File freschi in `output/`:** `bayesian_model_results.csv`, `all_model_coefficients_comprehensive.csv`, `model_coefficients_wide_comparison.csv`, `bayesian_coefficients_comparison.csv`, `interaction_effects_summary.csv`, `table_bayesian_mipex_model.csv`, `figures/bayesian_interaction_magnitude_panel.png`. Valori pre-merge in `output/archive_8th9th/`; log completo `/tmp/epmigrants_rerun_vii.log`.

## 1. Riferimenti delle righe ms: `paper/MEPArticle_Updated.md`

| Riga ms | Vecchio → Nuovo candidabile (Bayesian) |
|---|---|
| 549 | H1 `minority`: 0.327 [−0.595, 1.151] → **0.418 [−0.247, 1.030]** (resta ns: frase "not supported" invariata) |
| 567 | H2 `mipex`: −0.0007 [−0.013, 0.011] → **0.0009 [−0.010, 0.011]** (resta ns) |
| 581, 603 | H3 `minority × mipex`: 0.0658 [0.016, 0.117] → **0.0398 [0.0022, 0.079]** (CrI ancora sopra lo 0: la frase resta valida, ma l'entità si dimezza; IRR 1.068 → 1.041) |
| 598 (Table 1 H1) | 0.327 [−0.595, 1.151] → 0.418 [−0.247, 1.030] |
| 601 (Table 1 H2) | −0.0007 [−0.013, 0.011] → 0.0009 [−0.010, 0.011] |
| 603 (Table 1 H3) | 0.0658\* [0.016, 0.117] → 0.0398\* [0.0022, 0.079] |
| 605, 622 (LIBE) | 0.429 [0.079, 0.751] → **0.470 [0.227, 0.703]** (CrI si stringe, sempre sig) |
| 607, 641 (gender M) | 0.015 [−0.191, 0.219] → 0.016 [−0.143, 0.171] (ns) |
| Table 1 block (591–616) | vedi §2 sotto, testo pronto da incollare |

## 2. Table 1 — blocco sostitutivo (Bayesian, VII-IX, N = 9.850)

```
**Table 1.** Posterior estimates from the Bayesian zero-inflated negative binomial model
  H1: Migratory or racialised minority background   0.418        [−0.247, 1.030]
  H2: MIPEX anti-discrimination score               0.0009       [−0.010, 0.011]
  H3: Minority background × MIPEX                   0.0398*      [0.0022, 0.079]
  LIBE Committee membership                         0.470*       [0.227, 0.703]
  Gender: male                                      0.016        [−0.143, 0.171]
```
(Notes invariate.)

## 3. Descrizione del campione e descriptives (da decidere il criterio)

| Riga ms | Contenuto | Aggiornamento candidabile |
|---|---|---|
| 27–28 | "approximately 180,000 written questions from the eighth and ninth terms" | sorgente dati attuale = 187.473 righe 2004–2024; nel pannello VII-IX: 53.330 (VII) + 44.826 (VIII) + 22.114 (IX) = **120.270**. Riscrivere (es. "a panel of the seventh to ninth parliamentary terms with ~120,000 MEP-year question counts") o riformulare |
| 163 | "eighth and ninth parliamentary terms (2014–2024)" | **"seventh to ninth parliamentary terms (2009–2024)"** |
| 423–426 | "1.1% di tutte le domande… 225 MEP (VIII) / 124 (IX)" | share per termine: **1.14 / 1.05 / 0.93%** (VII/VIII/IX); MEP con ≥1 domanda disc nel pannello: **227 / 218 / 117**. NB: 225/124 non riproducibili col pipeline di oggi (criterio del vecchio script descrittivo); decidere quale conteggio citare |
| 455–456 | "20 MEP minority (VIII), 30 (IX)" (Fig 1) | candidabili pannello: **21 (VIII), 23 (IX), 27 (VII)**; dataset modelli: 19/20/26 — verificare lo script di Figure 1–2 (non in scripts/01-07) e rigenerare con il master nuovo |
| 483 | "increased between the eighth and ninth parliamentary terms" | riformulare su tre termini (VII–IX) |
| 670 | "the eighth and ninth European Parliament legislatures" | "the seventh to ninth European Parliament legislatures" |
| 742–748 | limitazioni: "eighth and ninth…" + "Extending the dataset to the sixth and seventh" | la VII è ora inclusa → limitazione da riformulare su **VI (2004–2009)** sola |

## 4. Nota interpretativa per la revisione del testo

- **H3 sopravvive**(CrI sopra 0) ma a metà entità: coerente con l'aggiunta di una VII legislatura in cui i regime anti-discriminazione erano mediamente più deboli e i casi minority=1 proporzionalmente più diffusi (3.4% delle righe VII vs 2.4% VIII / 3.4% IX).
- Nel modello CMP (non nel ms): `minority` main effect perde significatività: 1.059 [0.080, 1.917] → 0.472 [−0.362, 1.171]; interazione `minority × cmp` sale: 0.0407 [−0.138, 0.254] → **0.115 [−0.032, 0.290]**. Da tenere presente se l'appendice o la discussione citano il CMP.
- Nell'appendice frequentista (M1–M4): N 6.372 → 9.850; M2/M3 `minority` 1.28/1.29 → **1.05/1.05 (p < 0.001)**; M4 interazione 0.069 → **0.040**; problema pre-esistente SE NaN si sposta da M1/M3 a M1/M4 (nota: p = NaN per i termini M4 — usare la via Bayesian). 
- Frase ms L582 "The findings therefore provide support for H3" resta valida con i nuovi numeri.
## 5. ADDENDUM 2026-11-06 — fix filtro CAP-201 (sostituisce §1/§2 per i coefficienti)

Il fix del filtro DV (Fase 1: audit §9 verbatim + allowlist Option-B, v. `2026-11-06_CAP201-filter-implementation.md`) ha ribattuto l'intera pipeline. I valori di §1/§2 qui sopra sono **superati** da questi (stessi anchor di riga del ms):

| Riga ms | Vecchio (ms) → Post-fix (Bayesian, VII–IX) |
|---|---|
| 549 | H1 `minority`: 0.327 [−0.595, 1.151] → **0.438 [−0.256, 1.063]** (resta ns) |
| 567 | H2 `mipex`: −0.0007 [−0.013, 0.011] → **0.0017 [−0.0095, 0.013]** (resta ns) |
| 581, 603 | H3 `minority × mipex`: 0.0658* [0.016, 0.117] → **0.0376 [−0.002, 0.080] SENZA stella** — la CrI include ora lo zero: la frase L582 "The findings therefore provide support for H3" va riformulata (testo pronto in §7 del rapporto) |
| 605, 622 (LIBE) | 0.429 [0.079, 0.751] → **0.507 [0.270, 0.743]** (sempre sig) |
| 607, 641 (gender M) | 0.015 [−0.191, 0.219] → **0.019 [−0.141, 0.174]** (ns) |

- Table 1 pronto da incollare: `2026-11-06_CAP201-filter-implementation.md` §7(b).
- Counts (L423–426, roster `df_merged_3`): MEP con ≥1 DOM VIII **218 → 212**, IX **117 → 113** (VII 227 → 224) — sostituisce anche 225/124 (che non riproducibili).
- Diff verificato: `2026-11-06_CAP201-filter-implementation.md` §3–§6 (+ `quality_reports/session_logs/2026-11-06_cap201-fix-diff.log`).
