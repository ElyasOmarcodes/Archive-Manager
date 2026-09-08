import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// **د فایلونو پټول — د وینډوز په خپله لار.**
///
/// کاروونکي وویل: «د میټاډیټا د دواړو فایلونو نوعه هیډین کړه ترڅو
/// عادي کاروونکی یې په داخلي او هم وینډوز اکسپلورر کې ونه شي
/// لیدلی، ترڅو کاروونکو ته محیط صفا وي».
///
/// نو `metadata.json` او `content.json` د وینډوز د **پټ** (hidden)
/// صفت سره نښه کیږي. دا:
///
/// * د وینډوز په خپل اکسپلورر کې یې پټوي (تر څو چې کاروونکی
///   «Hidden items» فعال نه کړي)
/// * زمونږ په داخلي اکسپلورر کې یې هم پټوي — او هلته د «پټ
///   فایلونه وښایه» افشن شته
///
/// **ولې FFI، نه `attrib.exe`؟** ځکه د ۵۰ زرو پیښو آرشیف کې دا
/// ۱۰۰ زره فایلونه دي: د هر یوه لپاره یو پروسه پیلول دقیقې نیسي،
/// خو یوه FFI بلنه میکروثانیې.
class FileHiding {
  FileHiding._();

  static const int _hidden = 0x2;
  static const int _invalid = 0xFFFFFFFF;

  static bool get _win => Platform.isWindows;

  static DynamicLibrary? _lib;
  static int Function(Pointer<Utf16>)? _get;
  static int Function(Pointer<Utf16>, int)? _set;

  static void _init() {
    if (_lib != null || !_win) return;
    try {
      final lib = DynamicLibrary.open('kernel32.dll');
      _get = lib.lookupFunction<Uint32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)>('GetFileAttributesW');
      _set = lib.lookupFunction<Int32 Function(Pointer<Utf16>, Uint32),
          int Function(Pointer<Utf16>, int)>('SetFileAttributesW');
      _lib = lib;
    } catch (_) {
      // که ونه چلیږي، پټول یوازې د نوم له مخې کار کوي — پروګرام
      // باید له همدې کبله ونه دریږي.
    }
  }

  /// یو فایل پټ کوي. که مخکې پټ وي، هیڅ نه کوي.
  static void hide(String path) {
    if (!_win) return;
    _init();
    final get = _get, set = _set;
    if (get == null || set == null) return;

    final ptr = path.toNativeUtf16();
    try {
      final attrs = get(ptr);
      if (attrs == _invalid || attrs & _hidden != 0) return;
      set(ptr, attrs | _hidden);
    } catch (_) {
      // پټول یو ښکلاییز کار دی — که ناکام شي، ډیټا خوندي ده.
    } finally {
      malloc.free(ptr);
    }
  }

  /// آیا دا فایل پټ دی؟
  ///
  /// پر وینډوز د صفت له مخې؛ پر نورو سیسټمونو د نوم له مخې
  /// (`.` پیل).
  static bool isHidden(String path, String name) {
    if (name.startsWith('.')) return true;
    if (!_win) return false;
    _init();
    final get = _get;
    if (get == null) return false;

    final ptr = path.toNativeUtf16();
    try {
      final attrs = get(ptr);
      return attrs != _invalid && attrs & _hidden != 0;
    } catch (_) {
      return false;
    } finally {
      malloc.free(ptr);
    }
  }
}
