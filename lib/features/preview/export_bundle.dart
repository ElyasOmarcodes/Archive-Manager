import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../data/models/models.dart';

/// **د اکسپورټ ډولونه.**
enum ExportKind {
  /// یوازې یوه PDF دوسیه.
  pdf('یوازې PDF', 'یوه دوسیه — د چاپ او لېږلو لپاره'),

  /// یوه ZIP چې PDF او **اصلي ضمیمې** پکې وي.
  zip('ZIP — PDF + ضمیمې',
      'PDF له اصلي ویډیو، غږ او انځورونو سره یوځای');

  const ExportKind(this.label, this.hint);
  final String label;
  final String hint;
}

/// **د ZIP بستې جوړونکی.**
///
/// ## څه پکې راځي؟
///
/// ```
///   د کابل او چین تړون.zip
///   ├── د کابل او چین تړون.pdf
///   └── attachments/
///       ├── v1.mp4
///       ├── a1.wav
///       └── sanad.pdf
/// ```
///
/// **او څه پکې نه راځي؟** `metadata.json`، `content.json` او
/// `index.html` — یعنې د پروګرام خپل ثبت فایلونه. کاروونکي
/// وویل: «فقط یو رسمي zip وي، چې pdf او ضمیمه فایلونه پکې وي».
///
/// دا د میټاډیټا له لاسه ورکول نه دي: PDF پخپله میټاډیټا **دننه**
/// لري — د XMP په بڼه، د PDF د ضمیمو په بڼه، او د وروستۍ پاڼې پر
/// جدول. نو بسته هم پاکه ده، هم بشپړه.
class ExportBundle {
  ExportBundle._();

  /// د ZIP بایټونه جوړوي.
  ///
  /// [readBytes] هغه فعالیت دی چې د یوه **مطلق** مسیر بایټونه
  /// راوړي — نو دا کلاس له فایل سیسټم څخه خپلواک پاتې کیږي او
  /// په ازموینه کې هم چلیږي.
  ///
  /// هغه ضمیمه چې ونه لوستل شي، بس پرېښودل کیږي — یو ورک فایل
  /// باید ټوله بسته ونه ماتوي.
  static Future<Uint8List> build({
    required EventMetadata event,
    required Uint8List pdf,
    required String pdfName,
    required Future<List<int>?> Function(String absolutePath) readBytes,
  }) async {
    final archive = Archive();
    archive.addFile(ArchiveFile(pdfName, pdf.length, pdf));

    final seen = <String>{};
    for (final a in event.attachments) {
      // د پوښۍ دننه پاتې شي — یو ناسم نسبي مسیر (`../`) باید
      // بسته له خپلې پوښۍ بهر ونه باسي.
      final rel = p.normalize(a.relativePath).replaceAll('\\', '/');
      if (rel.startsWith('..') || p.isAbsolute(rel)) continue;
      if (!seen.add(rel)) continue;

      final bytes = await readBytes(p.join(event.folderPath, a.relativePath));
      if (bytes == null) continue;
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }

    final out = ZipEncoder().encode(archive);
    return Uint8List.fromList(out);
  }
}
