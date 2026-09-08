@TestOn('linux || mac-os || windows')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/preview/export_bundle.dart';

/// **د ZIP بستې ازموینه.**
///
/// کاروونکي وویل: «د zip چې هم pdf لري داخل کې او هم ضمیمه شوي
/// فایلونه — مګر د میټا ډیټا فایلونه پکې نه وي، فقط یو رسمي zip
/// وي».
void main() {
  EventMetadata sample() => EventMetadata(
        id: 'zip-1',
        title: 'د کابل تړون',
        folderPath: '/archive/1405/06/kabul',
        date: TriDate.fromShamsi(1405, 6, 13),
        attachments: const [
          Attachment(
              name: 'v1.mp4',
              relativePath: 'attachments/v1.mp4',
              kind: MediaKind.video,
              sizeBytes: 9),
          Attachment(
              name: 'a1.wav',
              relativePath: 'attachments/a1.wav',
              kind: MediaKind.audio,
              sizeBytes: 4),
        ],
      );

  final pdf = Uint8List.fromList(List.filled(120, 7));

  Future<Uint8List> build(
    EventMetadata e, {
    Future<List<int>?> Function(String)? read,
  }) =>
      ExportBundle.build(
        event: e,
        pdf: pdf,
        pdfName: 'سند.pdf',
        readBytes: read ??
            (path) async => path.endsWith('.mp4')
                ? List.filled(9, 1)
                : List.filled(4, 2),
      );

  test('ZIP کې PDF او ټولې ضمیمې راځي', () async {
    final zip = await build(sample());
    final a = ZipDecoder().decodeBytes(zip);
    final names = a.files.map((f) => f.name).toList()..sort();

    expect(names, [
      'attachments/a1.wav',
      'attachments/v1.mp4',
      'سند.pdf',
    ]);

    final inPdf = a.files.firstWhere((f) => f.name == 'سند.pdf');
    expect(inPdf.content, pdf, reason: 'PDF باید بې‌بدلونه راشي');
  });

  test('د میټاډیټا فایلونه پکې نه راځي', () async {
    // پروګرام خپل ثبت فایلونه (`metadata.json`, `content.json`,
    // `index.html`) هیڅکله بستې ته نه ورکوي — بسته رسمي ده، نه
    // د پروګرام کاري پوښۍ. میټاډیټا پخپله د PDF **دننه** ده.
    final zip = await build(sample());
    final a = ZipDecoder().decodeBytes(zip);
    for (final f in a.files) {
      expect(f.name, isNot(endsWith('.json')));
      expect(f.name, isNot(contains('metadata')));
      expect(f.name, isNot(contains('index.html')));
    }
  });

  test('یو ورک فایل ټوله بسته نه ماتوي', () async {
    final zip = await build(sample(),
        read: (path) async => path.endsWith('.mp4') ? List.filled(9, 1) : null);
    final a = ZipDecoder().decodeBytes(zip);
    final names = a.files.map((f) => f.name).toSet();

    expect(names, contains('سند.pdf'));
    expect(names, contains('attachments/v1.mp4'));
    expect(names, isNot(contains('attachments/a1.wav')),
        reason: 'هغه ضمیمه چې ونه لوستل شوه، بس پرېښودل کیږي');
  });

  test('ناسم نسبي مسیر له پوښۍ بهر نه ځي', () async {
    // یوه ناسمه (یا بدنیته) `../` ضمیمه باید بسته له خپلې پوښۍ
    // بهر ونه باسي.
    final e = EventMetadata(
      id: 'x',
      title: 'ازموینه',
      folderPath: '/archive/x',
      date: TriDate.now(),
      attachments: const [
        Attachment(
            name: 'bad',
            relativePath: '../../etc/passwd',
            kind: MediaKind.other,
            sizeBytes: 3),
      ],
    );
    final zip = await build(e, read: (_) async => [1, 2, 3]);
    final a = ZipDecoder().decodeBytes(zip);
    expect(a.files.map((f) => f.name), ['سند.pdf']);
  });

  test('تشه پیښه هم سمه ZIP ورکوي', () async {
    final e = EventMetadata(
        id: 'e', title: 'تشه', folderPath: '/tmp/x', date: TriDate.now());
    final zip = await build(e);
    final a = ZipDecoder().decodeBytes(zip);
    expect(a.files.length, 1);
    expect(a.files.first.name, 'سند.pdf');
  });

  test('دوه اکسپورټ افشنونه شته', () {
    expect(ExportKind.values.length, 2);
    expect(ExportKind.pdf.label, contains('PDF'));
    expect(ExportKind.zip.label, contains('ZIP'));
  });
}
