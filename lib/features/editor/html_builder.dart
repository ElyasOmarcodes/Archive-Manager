import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_text.dart';
import '../../data/models/models.dart';

/// **د `index.html` جوړونکی.**
///
/// یوه بشپړه، خپلواکه ویب پاڼه جوړوي چې:
/// * هیڅ بهرني فایل ته اړتیا نه لري (CSS/JS دننه دي) — نو په هر کمپیوټر
///   کې پرانیستل کیږي، آن که انټرنیټ نه وي
/// * ښي‌څخه‌کیڼ (RTL) پښتو ده
/// * سپین/تیاره تیم لري چې کاروونکی یې بدلولی شي
/// * انځورونه فول‌سکرین کوي، ویډیو/غږ پکې پلې کیږي
/// * ټول متن ښي/کیڼ لور ته او فایلونه منځ ته تنظیمیږي
String buildEventHtml(EventMetadata e, {String? title, String? fontDir}) {
  final b = StringBuffer();

  b.writeln('<!DOCTYPE html>');
  b.writeln('<html lang="ps" dir="rtl">');
  b.writeln('<head>');
  b.writeln('<meta charset="utf-8">');
  b.writeln('<meta name="viewport" content="width=device-width,initial-scale=1">');
  b.writeln('<title>${_esc(title ?? e.title)}</title>');

  // د لټون ماشینونو او د بیا لوستلو لپاره میټاډیټا
  b.writeln('<meta name="description" content="${_esc(e.summary)}">');
  if (e.keywords.isNotEmpty) {
    b.writeln('<meta name="keywords" content="${_esc(e.keywords.join(', '))}">');
  }
  b.writeln('<meta name="event-id" content="${_esc(e.id)}">');
  b.writeln('<meta name="event-date-shamsi" content="${_esc(e.date.shamsiText)}">');
  b.writeln('<meta name="event-date-qamari" content="${_esc(e.date.qamariText)}">');
  b.writeln('<meta name="event-date-miladi" content="${_esc(e.date.miladiText)}">');

  b.writeln('<style>${_fontFace(fontDir)}${_css()}</style>');
  b.writeln('</head>');
  b.writeln('<body>');

  _header(b, e);
  b.writeln('<main class="page">');

  for (final block in e.blocks) {
    _block(b, block);
  }

  b.writeln('</main>');
  _footer(b, e);

  // د انځور فول‌سکرین کتونکی
  b.writeln('''
<div class="lightbox" id="lb" role="dialog" aria-label="بشپړ انځور">
  <button class="lb-close" onclick="closeLb()" aria-label="بند کړه">&times;</button>
  <img id="lb-img" alt="">
  <p class="lb-cap" id="lb-cap"></p>
</div>''');

  b.writeln('<script>${_js()}</script>');
  b.writeln('</body>');
  b.writeln('</html>');
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  برخې
// ═══════════════════════════════════════════════════════════

void _header(StringBuffer b, EventMetadata e) {
  b.writeln('<header class="hdr">');
  b.writeln('  <div class="hdr-in">');
  b.writeln('    <div class="brand">');
  b.writeln('      <span class="brand-dot"></span>');
  b.writeln('      <span class="brand-name">د آرشیف چټک مدیر</span>');
  b.writeln('    </div>');
  b.writeln('    <div class="hdr-meta">');
  if (e.category.isNotEmpty) {
    b.writeln('      <span class="pill">${_esc(e.category)}</span>');
  }
  if (e.rating > 0) {
    b.writeln('      <span class="stars" title="درجه: ${e.rating}">'
        '${'★' * e.rating}<span class="dim">${'☆' * (5 - e.rating)}</span></span>');
  }
  b.writeln('      <button class="theme-btn" onclick="toggleTheme()" '
      'aria-label="تیم بدل کړه" title="سپین / تیاره">◐</button>');
  b.writeln('    </div>');
  b.writeln('  </div>');
  b.writeln('</header>');

  // د پیښې سرلیک برخه
  b.writeln('<section class="hero">');
  b.writeln('  <h1 class="hero-title">${_esc(e.title)}</h1>');
  if (e.summary.isNotEmpty) {
    b.writeln('  <p class="hero-sum">${_esc(e.summary)}</p>');
  }
  b.writeln('  <div class="dates">');
  for (final d in [
    ('هجري لمریز', e.date.shamsiText),
    ('هجري قمري', e.date.qamariText),
    ('میلادي', e.date.miladiText),
  ]) {
    b.writeln('    <div class="date-chip">'
        '<span class="date-lbl">${_esc(d.$1)}</span>'
        '<span class="date-val">${_esc(d.$2)}</span></div>');
  }
  b.writeln('  </div>');

  if (e.persons.isNotEmpty || e.keywords.isNotEmpty) {
    b.writeln('  <div class="tags">');
    for (final p in e.persons) {
      b.writeln('    <span class="tag tag-person">👤 ${_esc(p)}</span>');
    }
    for (final k in e.keywords) {
      b.writeln('    <span class="tag">#${_esc(k)}</span>');
    }
    b.writeln('  </div>');
  }
  b.writeln('</section>');
}

void _footer(StringBuffer b, EventMetadata e) {
  b.writeln('<footer class="ftr">');
  b.writeln('  <div class="ftr-in">');
  b.writeln('    <span>${_esc(e.title)}</span>');
  b.writeln('    <span class="sep">·</span>');
  b.writeln('    <span>${_esc(e.date.shamsiText)}</span>');
  if (e.attachments.isNotEmpty) {
    b.writeln('    <span class="sep">·</span>');
    b.writeln('    <span>${PashtoDigits.to(e.attachments.length)} فایلونه</span>');
  }
  b.writeln('  </div>');
  b.writeln('  <div class="ftr-note">دا پاڼه د آرشیف چټک مدیر لخوا جوړه شوې</div>');
  b.writeln('</footer>');
}

void _block(StringBuffer b, Block bl) {
  final align = switch (bl.align) {
    'right' => 'text-align:right',
    'left' => 'text-align:left',
    _ => 'text-align:center',
  };

  switch (bl.kind) {
    case BlockKind.heading:
      final lvl = bl.level.clamp(1, 4);
      // عنوانونه او متن ښي لور ته — د پښتو د لوستلو طبیعي لور.
      b.writeln('<h$lvl class="blk h$lvl reveal">${_esc(bl.text)}</h$lvl>');

    case BlockKind.paragraph:
      b.writeln('<p class="blk para reveal">${_linkedHtml(bl.text)}</p>');

    case BlockKind.quote:
      b.writeln('<blockquote class="blk quote reveal">');
      b.writeln('  <div class="quote-mark">”</div>');
      b.writeln('  <p>${_linkedHtml(bl.text)}</p>');
      if (bl.author.isNotEmpty) {
        b.writeln('  <cite>— ${_esc(bl.author)}</cite>');
      }
      b.writeln('</blockquote>');

    case BlockKind.divider:
      b.writeln('<hr class="blk rule reveal">');

    case BlockKind.image:
      if (bl.source.isEmpty) {
        b.writeln('<div class="blk missing reveal">انځور نه دی ټاکل شوی</div>');
        return;
      }
      b.writeln('<figure class="blk media reveal" style="$align">');
      b.writeln('  <img src="${_esc(bl.source)}" alt="${_esc(bl.caption)}" '
          'loading="lazy" onclick="openLb(this)">');
      if (bl.caption.isNotEmpty) {
        b.writeln('  <figcaption>${_esc(bl.caption)}</figcaption>');
      }
      b.writeln('</figure>');

    case BlockKind.video:
      if (bl.source.isEmpty) {
        b.writeln('<div class="blk missing reveal">ویډیو نه ده ټاکل شوې</div>');
        return;
      }
      b.writeln('<figure class="blk media reveal" style="$align">');
      b.writeln('  <video controls preload="metadata" playsinline>');
      b.writeln('    <source src="${_esc(bl.source)}">');
      b.writeln('    ستاسو براوزر دا ویډیو نه پلې کوي.');
      b.writeln('  </video>');
      if (bl.caption.isNotEmpty) {
        b.writeln('  <figcaption>${_esc(bl.caption)}</figcaption>');
      }
      b.writeln('</figure>');

    case BlockKind.audio:
      if (bl.source.isEmpty) {
        b.writeln('<div class="blk missing reveal">صوتي فایل نه دی ټاکل شوی</div>');
        return;
      }
      b.writeln('<figure class="blk media audio reveal">');
      b.writeln('  <div class="audio-wrap">');
      b.writeln('    <div class="audio-icon">🎙</div>');
      b.writeln('    <div class="audio-body">');
      if (bl.caption.isNotEmpty) {
        b.writeln('      <div class="audio-title">${_esc(bl.caption)}</div>');
      }
      b.writeln('      <audio controls preload="metadata">');
      b.writeln('        <source src="${_esc(bl.source)}">');
      b.writeln('      </audio>');
      b.writeln('    </div>');
      b.writeln('  </div>');
      b.writeln('</figure>');

    case BlockKind.file:
      if (bl.source.isEmpty) {
        b.writeln('<div class="blk missing reveal">فایل نه دی ټاکل شوی</div>');
        return;
      }
      final name = bl.source.split('/').last;
      final kind = MediaKind.ofPath(name);
      final icon = switch (kind) {
        MediaKind.sheet => '📊',
        MediaKind.document => '📄',
        MediaKind.archive => '🗜',
        _ => '📎',
      };
      // نور فایلونه: وهل یې د سیستم په خپل پروګرام کې پرانیزي.
      b.writeln('<a class="blk file-card reveal" href="${_esc(bl.source)}" '
          'target="_blank" rel="noopener">');
      b.writeln('  <span class="file-icon">$icon</span>');
      b.writeln('  <span class="file-body">');
      b.writeln('    <span class="file-name">'
          '${_esc(bl.caption.isEmpty ? name : bl.caption)}</span>');
      b.writeln('    <span class="file-hint">'
          'د پرانیستلو لپاره یې ووهئ — ${_esc(kind.label)}</span>');
      b.writeln('  </span>');
      b.writeln('  <span class="file-arrow">←</span>');
      b.writeln('</a>');
  }
}

// ═══════════════════════════════════════════════════════════
//  ښکلا
// ═══════════════════════════════════════════════════════════

/// د وزیر متن فونټ د یوه نسبي مسیر څخه راولي.
///
/// فونټونه یو ځل د آرشیف ریښې کې ساتل کیږي (`_arvitch/fonts/`)، نه په
/// هره پاڼه کې — نو زرګونه پیښې هم یوازې یو ځل ~۲۰۰KB نیسي، او پاڼې
/// پرته له انټرنیټه هم سم فونټ ښیي.
String _fontFace(String? dir) {
  if (dir == null || dir.isEmpty) return '';
  const weights = [
    (400, 'Regular'),
    (600, 'SemiBold'),
    (700, 'Bold'),
    (800, 'ExtraBold'),
  ];
  final b = StringBuffer();
  for (final (weight, name) in weights) {
    b.writeln('@font-face{'
        'font-family:Vazirmatn;'
        'src:url("$dir/Vazirmatn-$name.woff2") format("woff2");'
        'font-weight:$weight;font-style:normal;font-display:swap;}');
  }
  return b.toString();
}

String _css() => '''
:root{
  --bg:#fbfcfe; --surface:#ffffff; --surface-2:#f1f4f9;
  --text:#15181f; --muted:#5a6270; --line:#e3e8f0;
  --brand:#4f6bed; --brand-2:#7c5cff; --amber:#f5a524;
  --shadow:0 4px 24px rgba(11,18,32,.07);
  --radius:18px;
}
html[data-theme="dark"]{
  --bg:#0e1116; --surface:#171c24; --surface-2:#1e242e;
  --text:#e6eaf2; --muted:#a7b0c0; --line:#262d39;
  --brand:#8aa0ff; --brand-2:#c2a0ff;
  --shadow:0 4px 28px rgba(0,0,0,.5);
}
@media (prefers-color-scheme:dark){
  html:not([data-theme="light"]){
    --bg:#0e1116; --surface:#171c24; --surface-2:#1e242e;
    --text:#e6eaf2; --muted:#a7b0c0; --line:#262d39;
    --brand:#8aa0ff; --brand-2:#c2a0ff;
    --shadow:0 4px 28px rgba(0,0,0,.5);
  }
}
*{box-sizing:border-box}
body{
  margin:0; background:var(--bg); color:var(--text);
  font-family:Vazirmatn,"Segoe UI",Tahoma,sans-serif;
  line-height:1.85; font-size:16px;
  transition:background .3s ease,color .3s ease;
}

/* ── هډبار ── */
.hdr{
  position:sticky; top:0; z-index:50;
  background:color-mix(in srgb,var(--surface) 88%,transparent);
  backdrop-filter:blur(14px);
  border-bottom:1px solid var(--line);
}
.hdr-in{
  max-width:920px; margin:0 auto; padding:12px 24px;
  display:flex; align-items:center; gap:14px;
}
.brand{display:flex;align-items:center;gap:9px}
.brand-dot{
  width:26px;height:26px;border-radius:9px;
  background:linear-gradient(135deg,var(--brand),var(--brand-2));
  box-shadow:0 3px 12px color-mix(in srgb,var(--brand) 45%,transparent);
}
.brand-name{font-size:13px;font-weight:700}
.hdr-meta{margin-inline-start:auto;display:flex;align-items:center;gap:10px}
.pill{
  font-size:11.5px;font-weight:600;padding:4px 11px;border-radius:999px;
  background:color-mix(in srgb,var(--brand) 13%,transparent); color:var(--brand);
}
.stars{color:var(--amber);font-size:14px;letter-spacing:1px}
.stars .dim{opacity:.28}
.theme-btn{
  border:1px solid var(--line); background:var(--surface-2); color:var(--text);
  width:30px;height:30px;border-radius:9px;cursor:pointer;font-size:14px;
  transition:transform .2s ease,background .2s ease;
}
.theme-btn:hover{transform:rotate(180deg);background:var(--brand);color:#fff}

/* ── سرلیک برخه ── */
.hero{
  max-width:920px; margin:0 auto; padding:56px 24px 30px; text-align:center;
}
.hero-title{
  margin:0 0 14px; font-size:clamp(26px,4.4vw,44px); font-weight:800;
  line-height:1.35;
  background:linear-gradient(120deg,var(--text),var(--brand));
  -webkit-background-clip:text; background-clip:text; color:transparent;
}
.hero-sum{margin:0 auto;max-width:640px;color:var(--muted);font-size:16px}
.dates{
  display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-top:26px;
}
.date-chip{
  background:var(--surface); border:1px solid var(--line); border-radius:12px;
  padding:9px 15px; display:flex; flex-direction:column; gap:1px;
  transition:transform .22s ease,box-shadow .22s ease;
}
.date-chip:hover{transform:translateY(-2px);box-shadow:var(--shadow)}
.date-lbl{font-size:10px;color:var(--muted);font-weight:600}
.date-val{font-size:13px;font-weight:700}
.tags{
  display:flex;flex-wrap:wrap;gap:7px;justify-content:center;margin-top:20px;
}
.tag{
  font-size:11.5px;padding:4px 11px;border-radius:999px;
  background:var(--surface-2); color:var(--muted); border:1px solid var(--line);
}
.tag-person{
  background:color-mix(in srgb,var(--brand) 11%,transparent);
  color:var(--brand); border-color:transparent;
}

/* ── بدنه ── */
.page{max-width:820px;margin:0 auto;padding:24px 24px 72px}
.blk{margin:0 0 30px}

.h1,.h2,.h3,.h4{
  font-weight:800; line-height:1.45; text-align:right; margin:44px 0 16px;
  position:relative; padding-inline-start:14px;
}
.h1{font-size:31px} .h2{font-size:25px} .h3{font-size:20px} .h4{font-size:17px}
.h1::before,.h2::before,.h3::before,.h4::before{
  content:""; position:absolute; inset-inline-start:0; top:.22em; bottom:.22em;
  width:4px; border-radius:999px;
  background:linear-gradient(var(--brand),var(--brand-2));
}
.para{text-align:right;font-size:16px;color:var(--text)}

.quote{
  background:var(--surface); border:1px solid var(--line);
  border-inline-start:4px solid var(--brand);
  border-radius:var(--radius); padding:26px 30px; position:relative;
  text-align:right; box-shadow:var(--shadow);
  transition:transform .25s ease;
}
.quote:hover{transform:translateY(-3px)}
.quote-mark{
  position:absolute; top:-4px; inset-inline-end:22px; font-size:60px;
  color:var(--brand); opacity:.17; line-height:1; font-weight:800;
}
.quote p{margin:0;font-size:17.5px;font-weight:500;line-height:1.9}
.quote cite{
  display:block;margin-top:14px;font-size:13px;color:var(--muted);
  font-style:normal;font-weight:600;
}

.rule{
  border:0;height:1px;margin:44px auto;max-width:180px;
  background:linear-gradient(90deg,transparent,var(--line),transparent);
}

/* ── فایلونه: تل منځ ته ── */
.media{text-align:center;margin:34px 0}
.media img,.media video{
  max-width:100%; height:auto; border-radius:var(--radius);
  box-shadow:var(--shadow); display:block; margin:0 auto;
  transition:transform .3s ease;
}
.media img{cursor:zoom-in}
.media img:hover{transform:scale(1.012)}
.media figcaption{
  margin-top:11px;font-size:12.5px;color:var(--muted);text-align:center;
}

.audio-wrap{
  display:flex;align-items:center;gap:16px;background:var(--surface);
  border:1px solid var(--line); border-radius:var(--radius); padding:18px 20px;
  box-shadow:var(--shadow); max-width:600px; margin:0 auto; text-align:right;
}
.audio-icon{
  font-size:24px; width:48px; height:48px; flex:none; border-radius:14px;
  display:grid; place-items:center;
  background:color-mix(in srgb,var(--brand-2) 15%,transparent);
}
.audio-body{flex:1;min-width:0}
.audio-title{font-size:13.5px;font-weight:600;margin-bottom:7px}
.audio-body audio{width:100%}

.file-card{
  display:flex;align-items:center;gap:15px;text-decoration:none;color:inherit;
  background:var(--surface); border:1px solid var(--line);
  border-radius:var(--radius); padding:16px 20px; max-width:600px;
  margin:0 auto; box-shadow:var(--shadow);
  transition:transform .22s ease,border-color .22s ease;
}
.file-card:hover{transform:translateY(-2px);border-color:var(--brand)}
.file-icon{font-size:26px;flex:none}
.file-body{flex:1;min-width:0;text-align:right}
.file-name{display:block;font-size:14px;font-weight:600}
.file-hint{display:block;font-size:11px;color:var(--muted)}
.file-arrow{color:var(--brand);font-size:18px;transition:transform .22s ease}
.file-card:hover .file-arrow{transform:translateX(-4px)}

.missing{
  text-align:center;color:var(--muted);font-size:13px;padding:26px;
  border:1.5px dashed var(--line);border-radius:var(--radius);
}

/* ── باټم بار ── */
.ftr{
  border-top:1px solid var(--line); background:var(--surface);
  padding:26px 24px; text-align:center;
}
.ftr-in{
  display:flex;flex-wrap:wrap;gap:9px;justify-content:center;
  font-size:12.5px;color:var(--muted);
}
.sep{opacity:.4}
.ftr-note{margin-top:7px;font-size:11px;color:var(--muted);opacity:.65}

/* ── فول سکرین ── */
.lightbox{
  position:fixed;inset:0;z-index:100;display:none;
  background:rgba(6,9,15,.94); backdrop-filter:blur(6px);
  align-items:center;justify-content:center;flex-direction:column;
  padding:36px; animation:fade .25s ease;
}
.lightbox.on{display:flex}
.lightbox img{
  max-width:94vw;max-height:84vh;border-radius:12px;
  animation:zoom .3s cubic-bezier(.2,0,0,1);
}
.lb-cap{color:#cfd6e4;font-size:13px;margin-top:14px;text-align:center}
.lb-close{
  position:absolute;top:20px;inset-inline-end:24px;
  background:rgba(255,255,255,.12);color:#fff;border:0;
  width:40px;height:40px;border-radius:50%;font-size:24px;cursor:pointer;
  transition:background .2s ease;
}
.lb-close:hover{background:rgba(255,255,255,.26)}
@keyframes fade{from{opacity:0}to{opacity:1}}
@keyframes zoom{from{transform:scale(.93);opacity:0}to{transform:scale(1);opacity:1}}

/* ── د سکرول انیمیشن ── */
.reveal{opacity:0;transform:translateY(16px);transition:opacity .6s ease,transform .6s cubic-bezier(.2,0,0,1)}
.reveal.in{opacity:1;transform:none}
@media (prefers-reduced-motion:reduce){
  .reveal{opacity:1;transform:none;transition:none}
  *{animation:none!important}
}
@media(max-width:640px){
  .hero{padding:34px 18px 20px}
  .page{padding:16px 18px 50px}
  .quote{padding:20px 22px}
}
''';

String _js() => '''
// د تیم بدلون — کاروونکي انتخاب ساتل کیږي
function toggleTheme(){
  var h=document.documentElement;
  var cur=h.getAttribute('data-theme');
  if(!cur){
    cur=matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light';
  }
  var next=cur==='dark'?'light':'dark';
  h.setAttribute('data-theme',next);
  try{localStorage.setItem('arv-theme',next);}catch(e){}
}
try{
  var saved=localStorage.getItem('arv-theme');
  if(saved) document.documentElement.setAttribute('data-theme',saved);
}catch(e){}

// د انځور فول‌سکرین
function openLb(img){
  var lb=document.getElementById('lb');
  document.getElementById('lb-img').src=img.src;
  var cap=img.closest('figure');
  cap=cap?cap.querySelector('figcaption'):null;
  document.getElementById('lb-cap').textContent=cap?cap.textContent:'';
  lb.classList.add('on');
  document.body.style.overflow='hidden';
}
function closeLb(){
  document.getElementById('lb').classList.remove('on');
  document.body.style.overflow='';
}
document.getElementById('lb').addEventListener('click',function(e){
  if(e.target===this) closeLb();
});
document.addEventListener('keydown',function(e){
  if(e.key==='Escape') closeLb();
});

// یوازې یوه ویډیو/غږ په یو وخت کې پلې شي
document.querySelectorAll('video,audio').forEach(function(m){
  m.addEventListener('play',function(){
    document.querySelectorAll('video,audio').forEach(function(o){
      if(o!==m) o.pause();
    });
  });
});

// د سکرول پر مهال نرم ښکارېدل
var io=new IntersectionObserver(function(es){
  es.forEach(function(en){ if(en.isIntersecting){
    en.target.classList.add('in'); io.unobserve(en.target);
  }});
},{threshold:.08,rootMargin:'0px 0px -40px 0px'});
document.querySelectorAll('.reveal').forEach(function(el){io.observe(el);});
''';

// ═══════════════════════════════════════════════════════════
//  ابزارونه
// ═══════════════════════════════════════════════════════════

/// **د HTML د زرق‌کولو مخنیوی.**
///
/// د کاروونکي هر متن له دې لارې تېریږي — نو که څوک د پیښې په نوم یا
/// نقل‌قول کې `<script>` ولیکي، هغه یوازې متن پاتې کیږي، نه کوډ.
String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// د نوې کرښې نښې `<br>` ته اړوي (تر تېښتې وروسته).
String _nl2br(String s) => s.replaceAll('\n', '<br>');

/// **ساده متن → HTML، له اتوماتو لینکونو سره.**
///
/// هر څه لومړی تېښته کیږي (`_esc`) او بیا یوازې هغه برخې چې
/// ریښتیا لینک دي په `<a>` کې تړل کیږي. نو د کاروونکي متن هیڅکله
/// د HTML په توګه نه چلیږي — که څوک `<script>` ولیکي، لکه متن
/// ښکاري. پته هم د `isSafeUrl` له خوا څېړل کیږي، نو
/// `javascript:` هیڅکله نه ننوځي.
String _linkedHtml(String text) {
  final b = StringBuffer();
  for (final c in linkify(text)) {
    if (c.isLink && isSafeUrl(c.url!)) {
      b.write('<a href="${_esc(c.url!)}" target="_blank" '
          'rel="noopener noreferrer">${_nl2br(_esc(c.text))}</a>');
    } else {
      b.write(_nl2br(_esc(c.text)));
    }
  }
  return b.toString();
}
