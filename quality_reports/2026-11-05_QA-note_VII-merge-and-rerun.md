# QA note — Integrazione VII legislatura nel master minority + re-running pipeline

**Data:** 2026-11-05 · **Autore:** Cline (esecuzione piano approvato) · **Stato:** completata

## 1. Cosa è stato fatto

### Merge (`scripts/utils/append_7th_coding.R`, idempotente)
- **Master `data_raw/minority.csv` (symlink → `euquest/data_raw/`, gitignored): 1.299 → 1.770 righe** (+471: 468 dal roster VII di Zeynep `data/minorities7th_coded_final.csv`, + 3 hand-coded VIII/IX assenti dal master: Orville 234344, Lavocat 251859, López Gil 197777, tutti `minority=1`).
- **`minority=1`: 44 → 63** (identità verificata: 1.770 righe, 1.770 ID unici, 0 NA, 0 duplicati; anti-join: nessun ID sovrapposto tra i due sorgenti; 44 ID hand-coded già in master saltati).
- Backup pre-merge: `data_raw/minority_backup_pre7th_2026-11-05.csv`.
- Coding Zeynep (da Step 1 QA, 2026-10-14): 468/468 con valore; **16 `minority=1`**; 15/16 con nota (**Agnès Le Brun 105849 senza nota** — open request); `link` ancora vuoti; **30 casi di dubbio restano `minority=0`** (sidecar `data/minorities7th_coding_sources.csv`, 46 righe, flag `doubt_case`).

### Copertura post-merge (panel, pre-filtri)
| Termine | Righe codificate | MEP codificati / tot | `minority=1` (MEP) |
|---|---|---|---|
| 7th | 3.855/3.855 (**100%**) | 857/857 | 27 |
| 8th | 3.841/3.854 | 855/859 | 21 |
| 9th | 3.346/3.376 | 670/676 | 23 |

- I 10 MEP VIII/IX ancora scoperti (43 righe NA) = **backlog per Zeynep** (§3).
- **Bonus VI leg.**: 218 MEP del roster VII attivi anche 2004–2009 → VI passa da 879 a **1.894/4.023 righe codificate** (fuori dai modelli — VI resta esclusa).

### Ereditarietà dei codici (rielezione)
Nel dataset modelli VII ha **26 MEP `minority=1`** = 16 (Zeynep, nuovo) + 10 (rieletti VII→VIII/IX che ereditano il coding hand-coded del master). Nessun conflitto di codifica: per costruzione il roster VII escludeva i MEP già in master.

## 2. Re-running pipeline (fit archiviati in `output/archive_8th9th/`, log: `/tmp/epmigrants_rerun_vii.log`)

- Ordine: `02 → 03 → 05_models.R → 05_models_Bayesian.R → 06 → 07` (skip 01 e 04; `problem_indicators.csv` intoccato; cache brms `file=` azzerata per costringere il refit).
- **N modelli: 6.372 → 9.850** (+3.478 = 3.445 VII + 23 VIII + 10 IX); MEP unici 1.115 → 1.543; `minority=1` unici 34 → 51.
- Esclusi strutturali invariati: **HU, LU, MT, RO, SK** (cmp/discrimination time-invariant) — la VII si comporta come VIII/IX.
- Convergenza Bayesian: R-hat max **1.0048** (cmp) / **1.0026** (mipex); ESS min **1.005 / 1.079** — pulito.
- Frequensit: il problema pre-esistente di SE NaN (Hessian, GLMM doppio livello RE) si sposta: **prima M1/M3, ora M1/M4** (M2/M3 ora finiti, `minority` p<0.001, IRR ≈ 2.86). Conoscuto, non bloccante ("falling back to internal vcov estimate").
- Risultato chiave (memo numeri: `quality_reports/2026-11-05_numbers-to-change_VII-extension.md`): `minority:mipex_center` = **0.0398, CrI 95% [0.0022, 0.0787]** (era 0.0658 [0.0163, 0.1175]) → H3 confermata ma attenuata alla metà; `minority:cmp_center` = 0.1146 [−0.0322, 0.2903] (era 0.0407 [−0.1383, 0.2541]).

## 3. Backlog per Zeynep (10 MEP VIII/IX senza coding)

| mep_id | Nome | Paese | Termine |
|---|---|---|---|
| 124892 | Marek Jurek | Poland | 8th |
| 124938 | Janice Atkinson | United Kingdom | 8th |
| 190464 | Thomas Waitz | Austria | 8th |
| 193706 | Giovanni Miccichè | Italy | 8th |
| 5392 | Lara Wolters | Netherlands | 9th |
| 129141 | Frans Timmermans | Netherlands | 9th |
| 197394 | Josianne Cutajar | Malta | 9th |
| 197464 | Hannah Neumann | Germany | 9th |
| 197709 | Robert Roos | Netherlands | 9th |
| 198490 | Emmanouil Fragkos | Greece | 9th |

(Decisione approvata: restano NA, nessuna codifica di comodo.)

Open request a Zeynep (da draft 2026-10-14): (1) `link`/fonti per i 16 `minority=1`; (2) nota Le Brun 105849; (3) conferma che i 30 casi di dubbio debbano stare a 0.
