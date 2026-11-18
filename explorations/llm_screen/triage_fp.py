#!/usr/bin/env python3
"""Rule-based FP triage for DV-201 LLM screen codings.
Families calibrated on FR's 180-row adjudication (30 LLM-INs = 15 TP / 15 FP)."""
import argparse, csv, re
from collections import Counter

ROOT = '/home/federusso/progetti/EPmigrants'
SAMP = ROOT + '/data/dv201_llm_adjudication_sample_tocode.csv'
CAND = ROOT + '/data/dv201_llm_candidates_tocode.csv'
OUTC = ROOT + '/output/llm_screen/candidates_ruletriage.csv'

TP_PATTERNS = [
    ('roma_sinti_travellers', r"\b(roma|sinti|travell\w*|gyps\w*|manouch\w*)\b"),
    ('racism_racial',        r"\b(racis\w*|racial|xenophob\w*)\b"),
    ('antisemitism_jewish',  r"\b(anti-?semit\w*|jew\w*|zionis\w*|holocaust|auschwitz|shoah|nazi\w*)\b"),
    ('muslim',               r"\b(muslim\w*|islamophob\w*|mosques?)\b"),
    ('migration_terms',      r"\b(migrant\w*|immigrant\w*|refugees?|asylum|hate\s+(crime|speech)|hatred)\b"),
]
FP_PATTERNS = [
    ('language_rights',      r"\b(linguistic\w*|languages?|vernaculars?|dialects?|bilingual\w*)\b"),
    ('cypriot',              r"\bcypr\w*\b"),
    ('valencian',            r"\bvalencian\w*\b"),
    ('welsh',                r"\bwelsh\b"),
    ('catalan_basque',       r"\b(catal[ao]\w*|basque|euskera|galician|occitan)\b"),
    ('autochthonous_national', r"\b(autochthono\w*|national\s+minorit\w*)\b"),
]

def hits(text, patterns):
    if not text: return []
    return [name for name, rx in patterns if re.search(rx, text, re.I)]

def load(path):
    with open(path, newline='', encoding='utf-8-sig', errors='replace') as fh:
        return list(csv.DictReader(fh))

def analyze(r):
    blob = (r.get('subject') or '') + ' || ' + (r.get('text_llm_input') or '')
    tp = hits(blob, TP_PATTERNS)
    fp = hits(blob, FP_PATTERNS)
    if fp and not tp: cat = 'Likely FP (rules)'
    elif tp and not fp: cat = 'Likely genuine (rules)'
    elif tp and fp: cat = 'Mixed -- inspect'
    else: cat = 'No rule signal'
    return tp, fp, cat

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--validate', action='store_true')
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()
    samp = load(SAMP)
    if a.validate:
        print('=== 30 LLM-IN sample rows: rule hits ===')
        tp_cov = fp_cov = fp_contam = 0
        for r in samp:
            if (r.get('llm_reason') or '') != 'in_scope':
                continue
            tp, fp, cat = analyze(r)
            fr = (r.get('on_scope') or '').strip()
            print('%-18s FR=%-3s TP=%-30s FP=%-45s' % (r['id'], fr, ','.join(tp) or '-', ','.join(fp) or '-'))
            if fr == 'IN':
                tp_cov += bool(tp); fp_contam += bool(fp)
            else:
                fp_cov += bool(fp)
        print('TP rows with TP-nexus: %d/15 | TP rows hitting FP-family: %d | FP rows hitting FP-family: %d/15' % (tp_cov, fp_contam, fp_cov))
    if a.apply:
        cand = load(CAND)
        known = {r['id']: (r.get('on_scope') or '').strip() for r in samp}
        cats, rows_out = Counter(), []
        for r in cand:
            tp, fp, cat = analyze(r)
            cats[cat] += 1
            rows_out.append({'id': r['id'], 'date': r['date'], 'term': r['term'],
                'subject': r['subject'], 'on_scope': (r.get('on_scope') or ''),
                'FR_notes': (r.get('FR_notes') or ''), 'llm_reason': r['llm_reason'],
                'known_fr_from_sample': known.get(r['id'], ''),
                'tp_hits': ','.join(tp), 'fp_hits': ','.join(fp), 'category': cat})
        with open(OUTC, 'w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows_out[0].keys()))
            w.writeheader(); w.writerows(rows_out)
        print('wrote', len(rows_out), '->', OUTC)
        print('categories:', dict(cats))
        kf = [r for r in rows_out if r['known_fr_from_sample'] == 'OUT']
        print('known FR=OUT rows still IN in candidates file (stale pre-fill):', len(kf))
        n = 0
        for r in rows_out:
            if r['category'] == 'Likely FP (rules)':
                print('  FP? %s | %s | [%s]' % (r['id'], r['subject'][:64], r['fp_hits']))
                n += 1
                if n >= 30: break

if __name__ == '__main__':
    main()
