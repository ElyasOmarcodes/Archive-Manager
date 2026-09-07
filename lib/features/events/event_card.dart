import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// د یوې پیښې کارت — د ګریډ ویو او ډاشبورډ لپاره.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.compact = false,
    this.onOpen,
  });

  final EventMetadata event;
  final bool compact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final media = event.mediaBreakdown;

    return AppCard(
      // د کارت پورتنی رنګ = د کاروونکي خپل «رنګ ټګ». معنا یې د
      // ماوس پر تېرېدو ښکاري.
      accentTooltip: event.colorTag == ColorTag.none
          ? null
          : '${event.colorTag.label} — ${event.colorTag.meaning}',
      accent: event.colorTag == ColorTag.none ? null : event.colorTag.color,
      padding: const EdgeInsets.all(AppTokens.s16),
      onTap: onOpen ?? () => s.openEditor(event, preview: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // سرلیک + کټګوري
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleMedium?.copyWith(height: 1.4),
                ),
              ),
              if (event.category.isNotEmpty) ...[
                const SizedBox(width: AppTokens.s8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    event.category,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppTokens.s8),

          // تاریخ + درجه
          Row(
            children: [
              Icon(Icons.event_rounded, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  s.dateText(event.date),
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.rating > 0) StarRating(value: event.rating, size: 13),
            ],
          ),

          if (!compact && event.summary.isNotEmpty) ...[
            const SizedBox(height: AppTokens.s12),
            Text(
              event.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ],

          const SizedBox(height: AppTokens.s12),

          // د فایلونو خلاصه
          if (media.isNotEmpty)
            Wrap(
              spacing: AppTokens.s6,
              runSpacing: AppTokens.s6,
              children: [
                for (final e in media.entries)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: mediaColor(e.key).withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mediaIcon(e.key),
                            size: 11, color: mediaColor(e.key)),
                        const SizedBox(width: 4),
                        Text(
                          '${e.value}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: mediaColor(e.key),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (event.totalBytes > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      humanBytes(event.totalBytes),
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),

          // کیورډونه
          if (!compact && event.keywords.isNotEmpty) ...[
            const SizedBox(height: AppTokens.s12),
            Wrap(
              spacing: AppTokens.s6,
              runSpacing: AppTokens.s6,
              children: [
                for (final k in event.keywords.take(4))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text('#$k',
                        style: TextStyle(
                            fontSize: 10.5, color: cs.onSurfaceVariant)),
                  ),
                if (event.keywords.length > 4)
                  Text('+${event.keywords.length - 4}',
                      style: TextStyle(
                          fontSize: 10.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ],

          // شخصیتونه
          if (!compact && event.persons.isNotEmpty) ...[
            const SizedBox(height: AppTokens.s8),
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    event.persons.join('، '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
