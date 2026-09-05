import '../models/models.dart';
import '../models/query.dart';
import '../platform/backend.dart';

/// **د لټون ماشین ګډ انټرفیس.**
///
/// دوه تطبیقونه لري چې دواړه باید **یو شان پایلې** ورکړي:
/// * `IndexDb` — SQLite + FTS5، د ډیسکټاپ ریښتینی ماشین
/// * `MemoryIndex` — بشپړ Dart، د ویب نندارې لپاره (هلته `dart:ffi` نشته)
///
/// د دې انټرفیس ګټه دا ده چې دواړه په یوه ازموینه کې پرتله کیږي —
/// نو که د SQL منطق کې تېروتنه راشي، ازموینه یې نیسي.
abstract class EventIndex {
  void upsert(EventMetadata e);
  void upsertAll(Iterable<EventMetadata> items);
  void remove(String id);
  void clear();

  List<EventMetadata> search(EventQuery q);
  int count(EventQuery q);
  EventMetadata? byId(String id);
  FacetCounts facets(EventQuery q);
  ArchiveStats stats();

  List<VocabTerm> vocab(VocabKind kind);
  void addVocab(VocabKind kind, VocabTerm t);
  void deleteVocabRow(VocabKind kind, String name);
  List<EventMetadata> eventsUsing(VocabKind kind, String name);

  void dispose();
}
