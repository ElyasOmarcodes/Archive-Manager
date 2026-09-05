@TestOn('linux || mac-os || windows')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive_manager/data/platform/backend.dart';
import 'package:archive_manager/features/explorer/thumbnail.dart';

/// یو کوچنی ریښتینی PNG (۱×۱ پکسل، سور).
final _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

Widget host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: child),
      ),
    );

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('thumb_'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('a real image file renders as an image, not an icon', (t) async {
    final f = File(p.join(dir.path, 'photo.png'))..writeAsBytesSync(_png);

    await t.pumpWidget(host(FileThumb(
      entry: FsEntry(
        name: 'photo.png',
        path: f.path,
        isDirectory: false,
        sizeBytes: f.lengthSync(),
      ),
      size: 46,
    )));
    await t.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a folder renders an icon, never an image', (t) async {
    await t.pumpWidget(host(const FileThumb(
      entry: FsEntry(name: 'x', path: '/tmp/x', isDirectory: true),
      size: 46,
    )));
    await t.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
  });

  testWidgets('an event folder gets its own icon', (t) async {
    await t.pumpWidget(host(const FileThumb(
      entry: FsEntry(
          name: 'ev', path: '/tmp/ev', isDirectory: true, isEventFolder: true),
      size: 46,
    )));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.auto_awesome_mosaic_rounded), findsOneWidget);
  });

  testWidgets('a missing file falls back to an icon instead of throwing',
      (t) async {
    await t.pumpWidget(host(FileThumb(
      entry: FsEntry(
        name: 'gone.jpg',
        path: p.join(dir.path, 'gone.jpg'),
        isDirectory: false,
        sizeBytes: 5000,
      ),
      size: 46,
    )));
    await t.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a corrupt image degrades to an icon', (t) async {
    final f = File(p.join(dir.path, 'broken.png'))
      ..writeAsBytesSync(List.filled(200, 0x41));

    await t.pumpWidget(host(FileThumb(
      entry: FsEntry(
        name: 'broken.png',
        path: f.path,
        isDirectory: false,
        sizeBytes: f.lengthSync(),
      ),
      size: 46,
    )));
    await t.pumpAndSettle();

    // errorBuilder باید آیکن راوړي، نه چې پروګرام ودروي
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);
  });

  testWidgets('a huge image is skipped so memory stays bounded', (t) async {
    await t.pumpWidget(host(const FileThumb(
      entry: FsEntry(
        name: 'huge.jpg',
        path: '/tmp/huge.jpg',
        isDirectory: false,
        sizeBytes: 200 * 1024 * 1024, // ۲۰۰MB
      ),
      size: 46,
    )));
    await t.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);
  });

  testWidgets('a video file shows the video icon', (t) async {
    await t.pumpWidget(host(const FileThumb(
      entry: FsEntry(
        name: 'clip.mp4',
        path: '/tmp/clip.mp4',
        isDirectory: false,
        sizeBytes: 1000,
      ),
      size: 46,
    )));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.movie_rounded), findsOneWidget);
  });
}
