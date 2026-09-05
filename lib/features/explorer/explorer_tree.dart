import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';

/// **د فولډرونو ونه** — د وینډوز اکسپلورر د څنګ پینل په څېر.
class ExplorerTree extends StatefulWidget {
  const ExplorerTree({
    super.key,
    required this.current,
    required this.onOpen,
  });

  final String current;
  final ValueChanged<String> onOpen;

  @override
  State<ExplorerTree> createState() => _ExplorerTreeState();
}

class _ExplorerTreeState extends State<ExplorerTree> {
  final Map<String, List<FsEntry>> _children = {};
  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  List<String> _roots = const [];

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  Future<void> _loadRoots() async {
    final s = context.read<AppState>();
    final drives = await s.backend.rootDrives();
    final archive = s.settings.archiveRoot;
    final roots = <String>[
      ?archive,
      ...drives.where((d) => d != archive),
    ];
    if (mounted) {
      setState(() => _roots = roots);
      if (archive != null) _toggle(archive);
    }
  }

  Future<void> _toggle(String path) async {
    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
      return;
    }
    setState(() {
      _expanded.add(path);
      if (!_children.containsKey(path)) _loading.add(path);
    });
    if (!_children.containsKey(path)) {
      final list =
          await context.read<AppState>().backend.listDirectory(path);
      if (mounted) {
        setState(() {
          _children[path] = list.where((e) => e.isDirectory).toList();
          _loading.remove(path);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 15, color: cs.primary),
                const SizedBox(width: AppTokens.s8),
                const Text('فولډرونه',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: _roots.isEmpty
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s8, vertical: AppTokens.s8),
                    children: [
                      for (final r in _roots) ..._node(r, 0, isRoot: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _node(String path, int depth, {bool isRoot = false}) {
    final cs = Theme.of(context).colorScheme;
    final name = isRoot
        ? path
        : path.split(RegExp(r'[/\\]')).where((e) => e.isNotEmpty).last;
    final open = _expanded.contains(path);
    final active = widget.current == path;
    final busy = _loading.contains(path);

    return [
      Padding(
        padding: EdgeInsets.only(right: depth * 13.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onOpen(path),
            borderRadius: AppTokens.brSm,
            child: AnimatedContainer(
              duration: AppTokens.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s6, vertical: 6),
              decoration: BoxDecoration(
                color: active ? cs.primary.withValues(alpha: 0.13) : null,
                borderRadius: AppTokens.brSm,
              ),
              child: Row(
                children: [
                  InkResponse(
                    onTap: () => _toggle(path),
                    radius: 12,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.6))
                          : AnimatedRotation(
                              duration: AppTokens.fast,
                              turns: open ? -0.25 : 0,
                              child: Icon(Icons.chevron_left_rounded,
                                  size: 15, color: cs.onSurfaceVariant),
                            ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isRoot
                        ? Icons.storage_rounded
                        : open
                            ? Icons.folder_open_rounded
                            : Icons.folder_rounded,
                    size: 15,
                    color: active ? cs.primary : AppTokens.amber,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? cs.primary : cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textDirection: isRoot
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (open)
        for (final c in _children[path] ?? const <FsEntry>[])
          ..._node(c.path, depth + 1),
      if (open && (_children[path]?.isEmpty ?? false))
        Padding(
          padding: EdgeInsets.only(right: (depth + 1) * 13.0 + 20, top: 2, bottom: 2),
          child: Text('تش',
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
        ),
    ];
  }
}
