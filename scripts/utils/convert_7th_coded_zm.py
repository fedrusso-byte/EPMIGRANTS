#!/usr/bin/env python3
"""Convert the 7th-term minority coding received from Zeynep (xlsx) into the
canonical UTF-8 CSVs used by the merge step (TO_DO.txt, sezione 1, Step 2).

Fonte canonica : data/minorities7th_coded_zm.xlsx  (v2: 15 colonne, valori 0/1,
                 note di Zeynep; classificazioni identiche alla v1)
Superseded     : data/minorities7th_coded.csv / .xlsx (v1: VERO/FALSO, 13 colonne,
                 senza note — servono solo per tracciabilita')

Outputs (relative al root del repo EPmigrants):
- data/minorities7th_coded_final.csv    468 righe x 15 colonne, UTF-8, LF
- data/minorities7th_coding_sources.csv sidecar audit: tutte le righe minority=1
  (16) + tutte le righe minority=0 con nota (30 "casi di dubbio") = 46 righe;
  colonne: parliamentary_id,name,country,minority,doubt_case,notes,link

QA automatico (exit!=0 se fallisce):
- header atteso (15 colonne), 468 righe dati, parliamentary_id unici non vuoti;
- minority/active_* solo '0'/'1' (nessun residuo VERO/FALSO nel workbook);
- confronto completo con la v1: stessi id, stesse classificazioni;
- report copertura notes/link (incl. Le Brun 105849 senza nota).

Solo stdlib: l'xlsx viene letto come zip di XML (zipfile + ElementTree).
Uso: python3 scripts/utils/convert_7th_coded_zm.py
"""

import csv
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parents[2]
SRC_XLSX = REPO / "data" / "minorities7th_coded_zm.xlsx"
V1_CSV = REPO / "data" / "minorities7th_coded.csv"
OUT_FINAL = REPO / "data" / "minorities7th_coded_final.csv"
OUT_SOURCES = REPO / "data" / "minorities7th_coding_sources.csv"

EXPECTED_HEADER = [
    "parliamentary_id", "name", "country", "gender", "birth_year", "birth_place",
    "national_party_in_term", "party_group_in_term", "committee_in_term",
    "group_membership_raw", "active_2004_2009", "active_2009_2014",
    "minority", "notes", "link",
]
BOOL_COLS = ("minority", "active_2004_2009", "active_2009_2014")
LE_BRUN_ID = "105849"  # minority=1 senza nota (gap segnalato a Zeynep)

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
RNS = "{http://schemas.openxmlformats.org/package/2006/relationships}"
OD = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def col_index(ref):
    """'AB12' -> indice di colonna 0-based della parte letterale."""
    letters = "".join(ch for ch in (ref or "") if ch.isalpha())
    if not letters:
        return None
    idx = 0
    for ch in letters.upper():
        idx = idx * 26 + ord(ch) - 64
    return idx - 1

def read_xlsx(path):
    """Restituisce (header, lista righe) del PRIMO foglio del workbook."""
    with zipfile.ZipFile(path) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.iter(NS + "si"):
                shared.append("".join(t.text or "" for t in si.iter(NS + "t")))

        wb = ET.fromstring(z.read("xl/workbook.xml"))
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        relmap = {r.get("Id"): r.get("Target") for r in rels.iter(RNS + "Relationship")}
        sheets = [(s.get("name"), relmap.get(s.get(OD + "id"), ""))
                  for s in wb.iter(NS + "sheet")]
        if len(sheets) > 1:
            print(f"warning: il workbook ha {len(sheets)} fogli; uso il primo: '{sheets[0][0]}'")

        def read_sheet(target):
            # normalizza il path del foglio (relmap puo' dare '/xl/...' o parziale)
            if target.startswith("/"):
                target = target.lstrip("/")
            elif not target.startswith("xl/"):
                target = "xl/" + target
            root = ET.fromstring(z.read(target))
            rows = []
            for row in root.iter(NS + "row"):
                cells = {}
                for c in row.iter(NS + "c"):
                    i = col_index(c.get("r", ""))
                    if i is None:
                        continue
                    t = c.get("t", "")
                    if t == "s":
                        v = c.find(NS + "v")
                        val = shared[int(v.text)] if v is not None else ""
                    elif t == "inlineStr":
                        e = c.find(NS + "is")
                        val = ("".join(x.text or "" for x in e.iter(NS + "t"))
                               if e is not None else "")
                    else:
                        v = c.find(NS + "v")
                        val = v.text if v is not None else ""
                    cells[i] = str(val or "").strip()
                if cells:
                    width = max(cells) + 1
                    rows.append([cells.get(k, "") for k in range(width)])
            return rows

        rows = read_sheet(sheets[0][1])

    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    header = [h.strip() for h in rows[0]]
    data = [r for r in rows[1:] if any(c for c in r)]
    return header, data

def norm_bool(value):
    """VERO/FALSO (v1) o '1'/'0' -> '1'/'0'; None se non e' un booleano riconosciuto."""
    v = (value or "").strip().upper()
    if v in ("VERO", "V", "TRUE", "1"):
        return "1"
    if v in ("FALSO", "F", "FALSE", "0"):
        return "0"
    return None


def read_v1(path):
    """Legge la v1 (utf-8 o latin-1) -> dict id -> minority normalizzato."""
    raw = None
    for enc in ("utf-8-sig", "latin-1"):
        try:
            raw = path.read_text(encoding=enc)
            break
        except UnicodeDecodeError:
            continue
    if raw is None:
        raise RuntimeError(f"impossibile decodificare {path}")
    lines = [ln for ln in csv.reader(raw.splitlines()) if any(f.strip() for f in ln)]
    header = [h.strip() for h in lines[0]]
    i_id, i_min = header.index("parliamentary_id"), header.index("minority")
    return {row[i_id].strip(): norm_bool(row[i_min]) for row in lines[1:]}

def main():
    problems = []

    header, data = read_xlsx(SRC_XLSX)
    j = {name: i for i, name in enumerate(EXPECTED_HEADER)}

    # --- header, righe, chiavi -------------------------------------------
    if header != EXPECTED_HEADER:
        problems.append(f"header inatteso: {header}")
    if len(data) != 468:
        problems.append(f"righe dati = {len(data)} (attese 468)")
    ids = [r[0] for r in data]
    if any(not x for x in ids):
        problems.append("presenti parliamentary_id vuoti")
    if len(set(ids)) != len(ids):
        problems.append("presenti parliamentary_id duplicati")
    if any(not r[1].strip() for r in data):
        problems.append("presenti name vuoti")

    # --- encoding booleano -------------------------------------------------
    for col in BOOL_COLS:
        bad = sorted({r[j[col]] for r in data if norm_bool(r[j[col]]) is None})
        if bad:
            problems.append(f"{col}: valori non 0/1 -> {bad[:10]}")
    n_vero = sum(1 for r in data for c in r if c.strip().upper() in ("VERO", "FALSO"))
    if n_vero:
        problems.append(f"residui VERO/FALSO nel workbook: {n_vero} celle")

    minority = [norm_bool(r[j["minority"]]) for r in data]
    n_min1, n_min0 = minority.count("1"), minority.count("0")
    notes = [r[j["notes"]] for r in data]
    links = [r[j["link"]] for r in data]
    n_notes, n_links = sum(1 for n in notes if n), sum(1 for n in links if n)

    print(f"[xlsx] righe={len(data)}  minority=1: {n_min1}  minority=0: {n_min0}")
    print(f"[xlsx] notes non vuote: {n_notes}  link non vuoti: {n_links}")
    a4 = [norm_bool(r[j["active_2004_2009"]]) for r in data]
    print(f"[xlsx] active_2004_2009=1: {a4.count('1')} (=0: {a4.count('0')})")

    lebrun = next((r for r in data if r[0] == LE_BRUN_ID), None)
    if lebrun is None:
        problems.append(f"manca la riga attesa {LE_BRUN_ID} (Le Brun)")
    elif norm_bool(lebrun[j["minority"]]) == "1":
        if lebrun[j["notes"]]:
            print(f"[info] Le Brun ({LE_BRUN_ID}) ha oramai una nota: '{lebrun[j['notes']][:60]}...'")
        else:
            print(f"[gap] Le Brun ({LE_BRUN_ID}): minority=1 SENZA nota (gap noto, chiesto a Zeynep)")

    # --- confronto completo con la v1 --------------------------------------
    v1 = read_v1(V1_CSV)
    v1.pop("parliamentary_id", None)
    min_by_id = {r[0]: norm_bool(r[j["minority"]]) for r in data}
    only_a = sorted(set(min_by_id) - set(v1), key=int)
    only_b = sorted(set(v1) - set(min_by_id), key=int)
    changed = sorted([i for i in set(min_by_id) & set(v1) if min_by_id[i] != v1[i]], key=int)
    print(f"[diff v1] id solo nel nuovo: {len(only_a)}  id solo nella v1: {len(only_b)}  "
          f"classificazioni cambiate: {len(changed)}")
    if only_a or only_b:
        problems.append(f"id-set diverso dalla v1: only_new={only_a[:5]} only_old={only_b[:5]}")
    if changed:
        problems.append(f"classificazioni diverse dalla v1: {changed[:10]}")

    # --- csv canonico --------------------------------------------------------
    with OUT_FINAL.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(EXPECTED_HEADER)
        w.writerows(data)
    print(f"[out] {OUT_FINAL.name}  ({len(data)} righe x {len(EXPECTED_HEADER)} colonne)")

    # --- sidecar fonti/audit -------------------------------------------------
    sidecar_rows = []
    for r in data:
        m = norm_bool(r[j["minority"]])
        if m == "1" or r[j["notes"]]:
            sidecar_rows.append([r[0], r[1], r[2], m,
                                 "0" if m == "1" else "1", r[j["notes"]], r[j["link"]]])
    with OUT_SOURCES.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["parliamentary_id", "name", "country", "minority",
                    "doubt_case", "notes", "link"])
        w.writerows(sidecar_rows)
    doubts = sum(1 for r in sidecar_rows if r[4] == "1")
    pos = sum(1 for r in sidecar_rows if r[3] == "1")
    noted_min1 = sum(1 for r in data if norm_bool(r[j["minority"]]) == "1" and r[j["notes"]])
    expected = n_min1 + (n_notes - noted_min1)
    if len(sidecar_rows) != expected or doubts != n_notes - noted_min1:
        problems.append(f"conteggi sidecar inattesi: rows={len(sidecar_rows)} "
                        f"(attese {expected}), doubts={doubts} (attesi {n_notes - noted_min1})")
    print(f"[out] {OUT_SOURCES.name}  ({len(sidecar_rows)} righe: {pos} minority=1, "
          f"{doubts} casi di dubbio minority=0)")

    if n_links:
        print(f"[info] presenti {n_links} link non vuoti (da rivedere)")
    else:
        print("[gap] colonna 'link' vuota ovunque: fonti/URL da Zeynep ancora attese")

    if problems:
        print("\nQA FALLITO:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("\nQA OK: encoding 0/1, id unici e completi, classificazioni identiche alla v1.")
    print("File pronti per il merge (TO_DO sezione 1, Step 2).")
    return 0


if __name__ == "__main__":
    sys.exit(main())