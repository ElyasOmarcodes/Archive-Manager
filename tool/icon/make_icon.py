"""د پروګرام ایکن جوړونکی.

**ولې کوډ، نه یو ثابت انځور؟** ځکه چې هر پلیټ‌فارم بېلې اندازې
غواړي (وینډوز .ico کې شپږ، ویب کې درې)، او که یو ځل رنګ بدل شو،
باید ټول له سره جوړ شي. دلته یې یوه سرچینه ده.

ډیزاین: د آرشیف د دوسیې بڼه — درې پرتې (پوښ + دوه پاڼې) چې د
«یو له بل سره ټولې شوې پیښې» معنا ورکوي، او پر مخ یې د لټون
عدسیه. رنګونه د پروګرام له برانډ سره یو شان دي.

چلول:  python3 tool/icon/make_icon.py
"""
import math
from PIL import Image, ImageDraw

# د پروګرام برانډ رنګونه (lib/core/theme/tokens.dart سره یو شان)
BRAND      = (79, 70, 229)     # #4F46E5
BRAND_ALT  = (124, 58, 237)    # #7C3AED
SHEET_TOP  = (255, 255, 255)
SHEET_MID  = (226, 232, 240)
GLASS      = (255, 255, 255)

S = 1024  # په لوړه کچه رسموو، بیا یې کوچنی کوو — نو څنډې نرمې وي


def rounded(size, radius, fill):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=fill)
    return img


def gradient(size, c1, c2):
    """له پورته‑ښي څخه ښکته‑چپ ته."""
    g = Image.new('RGBA', (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = (x / size * 0.45 + y / size * 0.55)
            px[x, y] = (
                int(c1[0] + (c2[0] - c1[0]) * t),
                int(c1[1] + (c2[1] - c1[1]) * t),
                int(c1[2] + (c2[2] - c1[2]) * t),
                255,
            )
    return g


def build():
    # ── شالید: د برانډ ګرادیانت په ګرده مربع کې ──
    base = rounded(S, int(S * 0.225), (255, 255, 255, 255))
    grad = gradient(S, BRAND_ALT, BRAND)
    icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    icon.paste(grad, (0, 0), base)

    d = ImageDraw.Draw(icon, 'RGBA')

    # ── درې پرتې: د آرشیف «ټولې شوې پیښې» ──
    #
    # لاندې دوه پاڼې لږ څه ښکته او څنګ ته دي، نو ژورتیا ښیي.
    def sheet(cx, cy, w, h, r, fill, alpha=255):
        x0, y0 = cx - w / 2, cy - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r,
                            fill=fill + (alpha,))

    sheet(S * 0.50, S * 0.620, S * 0.42, S * 0.30, S * 0.042, SHEET_MID, 130)
    sheet(S * 0.50, S * 0.548, S * 0.49, S * 0.32, S * 0.048, SHEET_MID, 195)
    sheet(S * 0.50, S * 0.468, S * 0.56, S * 0.34, S * 0.055, SHEET_TOP, 255)

    # د پورتنۍ پاڼې پر مخ درې کرښې — «محتوا»
    for i, (wf, yf) in enumerate([(0.34, 0.395), (0.28, 0.455), (0.20, 0.515)]):
        w = S * wf
        y = S * yf
        d.rounded_rectangle(
            [S * 0.5 - w / 2, y, S * 0.5 + w / 2, y + S * 0.026],
            radius=S * 0.013,
            fill=(148, 163, 184, 190 - i * 30),
        )

    # ── د لټون عدسیه — د پروګرام اصلي معنا: «په ثانیو کې موندل» ──
    cx, cy, r = S * 0.670, S * 0.660, S * 0.150
    a = math.radians(48)

    # **لاستی لومړی رسمیږي، بیا حلقه** — نو د لاستي سر د حلقې
    # لاندې پټ شي او دواړه یو جسم ښکاره شي، نه دوه بېل ټوټې.
    x1 = cx + math.cos(a) * r * 0.75
    y1 = cy + math.sin(a) * r * 0.75
    x2 = cx + math.cos(a) * (r + S * 0.150)
    y2 = cy + math.sin(a) * (r + S * 0.150)
    # سپین پوښ (چې له شالید سره یې توپیر وي)
    d.line([x1, y1, x2, y2], fill=(255, 255, 255, 255),
           width=int(S * 0.070))
    d.line([x1, y1, x2, y2], fill=BRAND + (255,), width=int(S * 0.036))

    # حلقه: سپینه څنډه + د برانډ کړۍ + سپینه عدسیه
    d.ellipse([cx - r - S * 0.030, cy - r - S * 0.030,
               cx + r + S * 0.030, cy + r + S * 0.030],
              fill=(255, 255, 255, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRAND + (255,))
    d.ellipse([cx - r * 0.58, cy - r * 0.58, cx + r * 0.58, cy + r * 0.58],
              fill=(255, 255, 255, 255))
    # د عدسیې ځلا — یو نری روښانه قوس پورته‑چپ کې
    d.arc([cx - r * 0.40, cy - r * 0.40, cx + r * 0.40, cy + r * 0.40],
          start=200, end=290, fill=(203, 213, 225, 255),
          width=int(S * 0.012))

    return icon


def main():
    icon = build()

    # ── وینډوز .ico ──
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [icon.resize((s, s), Image.LANCZOS) for s in sizes]
    frames[-1].save('windows/runner/resources/app_icon.ico',
                    format='ICO', sizes=[(s, s) for s in sizes])
    print('✓ windows/runner/resources/app_icon.ico')

    # ── ویب ──
    for name, s in [('Icon-192.png', 192), ('Icon-512.png', 512),
                    ('Icon-maskable-192.png', 192),
                    ('Icon-maskable-512.png', 512)]:
        icon.resize((s, s), Image.LANCZOS).save(f'web/icons/{name}')
        print(f'✓ web/icons/{name}')

    icon.resize((32, 32), Image.LANCZOS).save('web/favicon.png')
    print('✓ web/favicon.png')

    # ── د سندونو لپاره ──
    icon.resize((256, 256), Image.LANCZOS).save('docs/app-icon.png')
    print('✓ docs/app-icon.png')


if __name__ == '__main__':
    main()
