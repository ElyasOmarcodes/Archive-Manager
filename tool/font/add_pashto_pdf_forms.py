#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""د پښتو تورو تړل په PDF کې — د فونټ او جدول چمتو کول.

## ستونزه

د PDF کتابتون (او د هغه `bidi` کڅوړه) متن ته پخپله شکل ورکوي:
هر توری د خپل ګاونډ له مخې خپلې تړلې بڼې ته اړوي. خو د هغې
جدول **۷۸ عربي توري** پېژني — او د پښتو دا لس توري پکې نشته:

    ټ  ځ  څ  ډ  ړ  ږ  ښ  ګ  ڼ  ۍ

نو دا توري (او د هغو ګاونډیان) بې‌تړلې پاتې کیږي:

    چټک  →  چ ټ ک        پښتو  →  پ ښ تو        کټګوري  →  ک ټ ګوري

## حل — «د پور توری»

د هرې پښتو توري لپاره یو **پوروړی** عربي توری ټاکو چې:

  * د کتابتون جدول یې **پېژني**، او
  * د تړلو ډول یې هماغه وي (دواړه خوا / یوازې ښي), او
  * پښتو/دري یې **هیڅکله نه کاروي** (اردو یا سندي توري دي).

بیا په فونټ کې د **پوروړي د تړلو بڼو** کوډپوینټونه د **پښتو**
توري ګلیفونو ته ورګرځوو. نو:

    ټ  →  ٺ  →  کتابتون یې سم تړي  →  فونټ یې د ټ په بڼه رسموي

او د کاپي کولو لپاره؟ د PDF د `ToUnicode` جدول بېرته اصلي پښتو
توري ته اړوو (وګورئ `pdf_export.dart`) — نو له PDF نه کاپي شوی
متن ریښتینی پښتو وي، نه اردو.

## چلول

    python3 tool/font/add_pashto_pdf_forms.py
"""

import unicodedata
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = sorted((ROOT / 'assets/fonts').glob('Vazirmatn-*.ttf'))
OUT_DART = ROOT / 'lib/core/text/pashto_pdf_forms.g.dart'

# پښتو توری → پوروړی توری
#
# د تړلو ډول دواړو کې یو شان دی، ګنې کلمه بیا هم ماتیږي.
DONORS = {
    0x067C: (0x067A, 'ټ', 'ٺ'),   # دواړه خوا (ت کورنۍ)
    0x0681: (0x0683, 'ځ', 'ڃ'),   # دواړه خوا (ح کورنۍ)
    0x0685: (0x0684, 'څ', 'ڄ'),   # دواړه خوا (ح کورنۍ)
    0x0689: (0x0688, 'ډ', 'ڈ'),   # یوازې ښي (د کورنۍ)
    0x0693: (0x0691, 'ړ', 'ڑ'),   # یوازې ښي (ر کورنۍ)
    0x0696: (0x068D, 'ږ', 'ڍ'),   # یوازې ښي (د کورنۍ)
    0x069A: (0x06A6, 'ښ', 'ڦ'),   # دواړه خوا (ف کورنۍ)
    0x06AB: (0x06AD, 'ګ', 'ڭ'),   # دواړه خوا (ک کورنۍ)
    0x06BC: (0x06BB, 'ڼ', 'ڻ'),   # دواړه خوا (ن کورنۍ)
    0x06CD: (0x06D2, 'ۍ', 'ے'),   # یوازې ښي (ی کورنۍ)
}

# هغه پښتو توري چې کتابتون یې **پېژني**، خو ډېر فونټونه یې زړې
# بڼې نه لري. دلته یوازې د فونټ cmap ته کرښې ورزیاتوو.
DIRECT = [0x06D0, 0x06C0]  # ې ، ۀ

TAGS = [('isolated', None), ('final', 'fina'),
        ('initial', 'init'), ('medial', 'medi')]


def unicode_forms():
    """base → {tag: codepoint} (له یونیکوډ څخه)."""
    out = {}
    for cp in range(0xFB50, 0xFF00):
        d = unicodedata.decomposition(chr(cp))
        if not d.startswith('<'):
            continue
        tag, rest = d[1:].split('>', 1)
        parts = rest.split()
        if len(parts) == 1:
            out.setdefault(int(parts[0], 16), {})[tag] = cp
    return out


def single_subs(font, tag):
    """د یوه فیچر ټول یو‑په‑یو بدلونونه.

    **پام:** ډېر فونټونه دا بدلونونه په «extension» (ډول ۷) کې
    تړي، نو بهرنی ډول ۷ وي او دننه یې ۱ — نو هر هغه فرعي جدول
    اخلو چې `mapping` ولري.
    """
    if 'GSUB' not in font:
        return {}
    gsub = font['GSUB'].table
    idx = []
    for rec in gsub.FeatureList.FeatureRecord:
        if rec.FeatureTag == tag:
            idx.extend(rec.Feature.LookupListIndex)
    subs = {}
    for i in idx:
        for st in gsub.LookupList.Lookup[i].SubTable:
            mapping = getattr(st, 'mapping', None)
            if mapping:
                subs.update(mapping)
    return subs


def plan(font):
    """راګرځوي: (cmap کرښې چې ورزیاتیږي، د ToUnicode بېرته‑جدول)."""
    cmap = font.getBestCmap()
    uni = unicode_forms()
    gs = {t: single_subs(font, t) for t in ('fina', 'init', 'medi')}
    add, back = {}, {}

    def glyph(base, tag):
        g0 = cmap.get(base)
        if g0 is None:
            return None
        return g0 if tag is None else gs[tag].get(g0)

    # ۱) پوروړي: د هغوی د بڼو کوډپوینټونه → د پښتو ګلیفونه
    for pashto, (donor, _, _) in DONORS.items():
        # **د پوروړي خپل کوډپوینټ هم.** کله چې توری یوازې (بې
        # ګاونډه) وي، کتابتون یې اصلي بڼه پرېږدي — نو فونټ باید
        # هغه هم وپېژني، ګنې «Unable to find a font to draw» راځي.
        g0 = glyph(pashto, None)
        if g0 is not None:
            add[donor] = g0
            back[donor] = pashto
        for utag, otag in TAGS:
            cp = uni.get(donor, {}).get(utag)
            if cp is None:
                continue
            g = glyph(pashto, otag)
            if g is None:
                continue
            add[cp] = g
            back[cp] = pashto

    # ۲) هغه توري چې کتابتون یې پېژني، خو فونټ یې بڼې نه لري
    for base in DIRECT:
        for utag, otag in TAGS:
            cp = uni.get(base, {}).get(utag)
            if cp is None or cp in cmap:
                continue
            g = glyph(base, otag)
            if g is not None:
                add[cp] = g
    return add, back


def write_dart(back):
    L = []
    L.append('// **جوړ شوی فایل — په لاس یې مه بدلوه.**')
    L.append('//')
    L.append('// سرچینه: tool/font/add_pashto_pdf_forms.py')
    L.append('library;')
    L.append('')
    L.append('/// **پښتو توری → پوروړی توری.**')
    L.append('///')
    L.append('/// د PDF کتابتون د پښتو دا توري نه پېژني، نو نه یې تړي.')
    L.append('/// پرځای یې یو پوروړی عربي توری ورکوو چې کتابتون یې')
    L.append('/// پېژني او د تړلو ډول یې هماغه دی؛ فونټ بیا د پوروړي د')
    L.append('/// بڼو پر ځای د پښتو ګلیفونه رسموي.')
    L.append('const Map<int, int> kPashtoDonor = {')
    for p, (d, pc, dc) in sorted(DONORS.items()):
        L.append('  0x%04X: 0x%04X, // %s → %s' % (p, d, pc, dc))
    L.append('};')
    L.append('')
    L.append('/// **د پوروړي بڼه → اصلي پښتو توری.**')
    L.append('///')
    L.append('/// د PDF د `ToUnicode` جدول سمولو لپاره — نو له دوسیې')
    L.append('/// کاپي شوی متن ریښتینی پښتو وي.')
    L.append('const Map<int, int> kDonorFormToPashto = {')
    for cp in sorted(back):
        L.append('  0x%04X: 0x%04X, // %s' % (cp, back[cp], chr(back[cp])))
    L.append('};')
    OUT_DART.write_text('\n'.join(L) + '\n', encoding='utf-8')


def main():
    if not FONTS:
        raise SystemExit('هیڅ فونټ ونه موندل شو')

    _, back = plan(TTFont(str(FONTS[0])))
    write_dart(back)
    print(f'✓ {OUT_DART.relative_to(ROOT)}: {len(back)} بڼې')

    for p in FONTS:
        font = TTFont(str(p))
        add, _ = plan(font)
        glyphs = set(font.getGlyphOrder())
        real = {cp: g for cp, g in add.items() if g in glyphs}
        for t in font['cmap'].tables:
            if t.isUnicode():
                t.cmap.update(real)
        font.save(str(p))
        print(f'✓ {p.name}: {len(real)} cmap کرښې')


if __name__ == '__main__':
    main()
