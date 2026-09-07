#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""د PDF لپاره فونټ ته د پښتو د پیشکش‌بڼو (presentation forms) ورزیاتول.

## ستونزه

د `pdf` کتابتون خپل عربي شکل‌ورکوونکی لري: هره توری د خپل ځای له
مخې (یوازې / پای / پیل / منځ) په یوه **Arabic Presentation Form**
بدلوي — لکه ب → U+FE91. بیا هماغه کوډپوینټ په فونټ کې لټوي.

عصري فونټونه (Vazirmatn هم) دا زړې بڼې نه ساتي — دوی OpenType
(`init`/`medi`/`fina`) کاروي. نو کله چې کوډپوینټ ونه موندل شي،
د فونټ لومړی ګلیف (`.notdef` یا یو بې‌ربطه توری) رسمیږي.

**پایله:** په PDF کې «کې» → «کA»، «ضمیمې» → «ضمیمA»، «یې» → «یA».
د پښتو تر ټولو عامه توری **ې (U+06D0)** بیخي ماته وه.

## حل

فونټ ته یوازې د **cmap** نوې کرښې ورزیاتوو: FBE4…FBE7 → هماغه
ګلیفونه چې OpenType یې د `init`/`medi`/`fina` لپاره کاروي. ګلیفونه
لا دمخه په فونټ کې شته — یوازې نوم یې نه و ورکړل شوی.

نو:
  * د فونټ حجم عملاً نه بدلیږي (یوازې څو کرښې cmap)،
  * د فلټر رسمول هیڅ نه بدلیږي (هغه دا کوډپوینټونه نه کاروي)،
  * او PDF سم پښتو رسموي.

## چلول

    python3 tool/font/add_pashto_pdf_forms.py

پایله یې مستقیم پر `assets/fonts/*.ttf` لیکل کیږي. که فونټ نوی
شي (اپډیټ)، دا سکریپټ بیا وچلوه.
"""

import re
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = sorted((ROOT / 'assets/fonts').glob('Vazirmatn-*.ttf'))

# د `pdf` کتابتون جدول: base -> [isolated, final, initial, medial]
ARABIC_TABLE_DART = (
    Path.home()
    / '.pub-cache/hosted/pub.dev/pdf-3.13.0/lib/src/pdf/font/arabic.dart'
)

# که د کتابتون فایل ونه موندل شو، لږ تر لږه د پښتو اړینې توري.
FALLBACK = {
    0x06D0: [0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7],  # ې
    0x06C0: [0xFBA4, 0xFBA5],                  # ۀ
    0x06C1: [0xFBA6, 0xFBA7, 0xFBA8, 0xFBA9],  # ہ
}

# د بڼو ترتیب د پورته جدول مطابق
ORDER = ['isol', 'fina', 'init', 'medi']


def read_table():
    if not ARABIC_TABLE_DART.exists():
        return FALLBACK
    src = ARABIC_TABLE_DART.read_text(encoding='utf-8')
    out = {}
    for m in re.finditer(r'0x([0-9A-Fa-f]{4}):\s*<int>\[([^\]]*)\]', src, re.S):
        base = int(m.group(1), 16)
        forms = [int(x.strip(), 0) for x in m.group(2).split(',') if x.strip()]
        if forms:
            out[base] = forms
    return out or FALLBACK


def single_subs(font, tag):
    """د یوه فیچر (init/medi/fina) ټول یو-په-یو بدلونونه."""
    if 'GSUB' not in font:
        return {}
    gsub = font['GSUB'].table
    idx = []
    for rec in gsub.FeatureList.FeatureRecord:
        if rec.FeatureTag == tag:
            idx.extend(rec.Feature.LookupListIndex)
    subs = {}
    for i in idx:
        lk = gsub.LookupList.Lookup[i]
        for st in lk.SubTable:
            if getattr(st, 'LookupType', lk.LookupType) == 1 or lk.LookupType == 1:
                mapping = getattr(st, 'mapping', None)
                if mapping:
                    subs.update(mapping)
    return subs


def patch(path: Path, table) -> int:
    font = TTFont(str(path))
    base_cmap = font.getBestCmap()
    forms = {
        'isol': {},
        'fina': single_subs(font, 'fina'),
        'init': single_subs(font, 'init'),
        'medi': single_subs(font, 'medi'),
    }
    glyphs = set(font.getGlyphOrder())

    added = {}
    for base, codes in table.items():
        g0 = base_cmap.get(base)
        if not g0:
            continue
        for pos, code in enumerate(codes):
            if code in base_cmap or code == base:
                continue  # لا دمخه شته
            tag = ORDER[pos] if pos < len(ORDER) else 'isol'
            # که د دې بڼې ځانګړی ګلیف نه وي، اصلي ګلیف بهتر دی
            # تر یوه بې‌ربطه توري.
            g = forms[tag].get(g0, g0)
            if g in glyphs:
                added[code] = g

    if not added:
        return 0

    for t in font['cmap'].tables:
        # یوازې هغه جدولونه چې ټول یونیکوډ نیسي (BMP یا بشپړ)
        if t.isUnicode():
            t.cmap.update(added)
    font.save(str(path))
    return len(added)


def main():
    table = read_table()
    total = 0
    for p in FONTS:
        if not p.exists():
            print(f'… {p.name} نشته — پرېښودل شو')
            continue
        n = patch(p, table)
        total += n
        print(f'✓ {p.name}: {n} نوې cmap کرښې')
    if total == 0:
        print('هیڅ بدلون نه و پکار — فونټونه لا دمخه بشپړ دي.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
