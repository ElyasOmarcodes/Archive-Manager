#!/usr/bin/env bash
# د نمونې آرشیف لپاره کوچني ریښتیني مېډیا فایلونه جوړوي.
# دا فایلونه قصداً ډېر کوچني دي (۱–۴ KB) ترڅو ZIP سپک وي.
set -euo pipefail
OUT="${1:-tool/sample-media}"
mkdir -p "$OUT"

python3 - "$OUT" <<'PY'
import zlib, struct, sys, os, math
out = sys.argv[1]

def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

# ۶ رنګین PNG (۱۶۰×۱۰۴)
pal = [((79,109,237),(124,92,255)), ((18,181,165),(53,214,164)),
       ((245,165,36),(255,122,69)), ((242,67,107),(155,92,246)),
       ((42,168,242),(79,109,237)), ((43,182,115),(18,181,165))]
for i, (a, b) in enumerate(pal, 1):
    w, h = 160, 104
    rows = b''
    for y in range(h):
        r = bytearray()
        for x in range(w):
            f = x / w * 0.7 + y / h * 0.3
            r += bytes((int(a[0]+(b[0]-a[0])*f), int(a[1]+(b[1]-a[1])*f),
                        int(a[2]+(b[2]-a[2])*f)))
        rows += b'\x00' + bytes(r)
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))
    open(os.path.join(out, f'img{i}.png'), 'wb').write(png)

# ۲ کوچني WAV (۰٫۲s)
for i, fq in enumerate([440, 330], 1):
    sr, n = 8000, 1600
    d = b''.join(struct.pack('<h', int(8000 * math.sin(2*math.pi*fq*t/sr) * (1-t/n)))
                 for t in range(n))
    hdr = (b'RIFF' + struct.pack('<I', 36+len(d)) + b'WAVEfmt '
           + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr*2, 2, 16)
           + b'data' + struct.pack('<I', len(d)))
    open(os.path.join(out, f'audio{i}.wav'), 'wb').write(hdr + d)

# یو ساده خو معتبر PDF
c = b"BT /F1 16 Tf 60 760 Td (Archive Manager - sample report) Tj ET"
objs = [b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        b"<< /Length %d >>\nstream\n" % len(c) + c + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
buf = b"%PDF-1.4\n"; offs = []
for i, o in enumerate(objs, 1):
    offs.append(len(buf)); buf += b"%d 0 obj\n" % i + o + b"\nendobj\n"
x = len(buf)
buf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs)+1)
for o in offs: buf += b"%010d 00000 n \n" % o
buf += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs)+1, x)
open(os.path.join(out, 'report.pdf'), 'wb').write(buf)
PY

# ۳ کوچنۍ MP4 (۱s، ۱۶۰×۹۰) — ffmpeg ته اړتیا لري
for i in 1 2 3; do
  ffmpeg -v error -y -f lavfi -i "testsrc2=size=160x90:rate=8:duration=1" \
     -c:v libx264 -preset veryslow -crf 45 -pix_fmt yuv420p -an \
     -movflags +faststart "$OUT/video$i.mp4"
done

printf 'کال,پانګونه,سیمه\n۱۴۰۳,۱۲۰,کابل\n۱۴۰۴,۱۸۰,کندهار\n۱۴۰۵,۲۴۰,هرات\n' > "$OUT/data.csv"
printf 'د پیښې لنډ یادښت — نمونه\n' > "$OUT/note.txt"
echo "✓ مېډیا جوړ شو: $OUT"
