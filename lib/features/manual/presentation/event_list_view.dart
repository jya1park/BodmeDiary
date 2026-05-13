import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../core/time/duration_format.dart';
import '../../../data/models/active_event_synthesizer.dart';
import '../../../data/models/care_event.dart';
import '../../../data/models/feeding_note.dart';
import '../../../data/repositories/events_repository.dart';
import 'manual_record_form.dart';

/// 이벤트 목록 — 탭하면 편집 폼, 휴지통 클릭/스와이프로 삭제.
/// 기록 편집 화면과 히스토리 일 탭에서 공용으로 사용.
/// 날짜가 바뀌는 지점마다 가로선 + 날짜 라벨을 삽입한다.
class EventListView extends ConsumerWidget {
  const EventListView({
    required this.events,
    required this.familyId,
    required this.babyId,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 96),
    this.emptyText = '아직 기록이 없어요',
    super.key,
  });

  final List<CareEvent> events;
  final String familyId;
  final String babyId;
  final EdgeInsets padding;
  final String emptyText;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CareEvent event,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ManualRecordForm(existing: event),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CareEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 기록을 삭제할까요?'),
        content: Text(_describe(event)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(eventsRepositoryProvider).deleteEvent(
          familyId: familyId,
          babyId: babyId,
          eventId: event.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록이 삭제되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return Center(
        child: Text(emptyText, textAlign: TextAlign.center),
      );
    }
    final items = _buildItems(events);
    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _DateHeader) {
          return _DateDivider(date: item.date);
        }
        final eItem = item as _EventItem;
        return _buildEventTile(context, ref, eItem.event);
      },
    );
  }

  Widget _buildEventTile(
    BuildContext context,
    WidgetRef ref,
    CareEvent e,
  ) {
    final isPseudo = isPseudoActiveEvent(e);
    if (isPseudo) {
      return Container(
        color: _colorFor(e.type).withValues(alpha: 0.08),
        child: ListTile(
          leading: Icon(_iconFor(e.type), color: _colorFor(e.type)),
          title: Row(
            children: [
              Expanded(child: Text(_describe(e))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorFor(e.type),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '진행중',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(_subtitle(e)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('진행 중인 기록은 종료 후 편집할 수 있어요'),
              ),
            );
          },
        ),
      );
    }

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(context, ref, e);
        return false;
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Icon(_iconFor(e.type), color: _colorFor(e.type)),
        title: Text(_describe(e)),
        subtitle: Text(_buildSubtitle(e), maxLines: 5),
        isThreeLine: e.note != null,
        onTap: () => _edit(context, ref, e),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _delete(context, ref, e),
        ),
      ),
    );
  }

  /// 인접 이벤트의 localDayKey 가 바뀌는 지점마다 _DateHeader 를 삽입.
  List<_ListItem> _buildItems(List<CareEvent> events) {
    final out = <_ListItem>[];
    String? lastKey;
    for (final e in events) {
      if (e.localDayKey != lastKey) {
        out.add(_DateHeader(date: e.startAt));
        lastKey = e.localDayKey;
      }
      out.add(_EventItem(e));
    }
    return out;
  }

  String _describe(CareEvent e) {
    switch (e.type) {
      case CareEventType.feeding:
        if (e.feedingAmountMl != null) return '수유 (분유 ${e.feedingAmountMl}ml)';
        final dur = e.duration.inMinutes;
        return '수유 (모유 $dur분)';
      case CareEventType.diaper:
        switch (e.diaperKind) {
          case DiaperKind.pee:
            return '기저귀 — 소변';
          case DiaperKind.poop:
            return '기저귀 — 배변';
          case DiaperKind.both:
            return '기저귀 — 둘 다';
          case null:
            return '기저귀';
        }
      case CareEventType.sleep:
        return '잠 — ${formatTimer(e.duration)}';
    }
  }

  String _subtitle(CareEvent e) {
    final fmt = DateFormat('M월 d일 HH:mm');
    if (e.startAt == e.endAt) return fmt.format(e.startAt);
    return '${fmt.format(e.startAt)} – ${DateFormat('HH:mm').format(e.endAt)}';
  }

  /// 시간 + 세션로그(수유만) + 사용자 메모를 줄바꿈으로 합쳐 표시.
  String _buildSubtitle(CareEvent e) {
    final lines = <String>[_subtitle(e)];
    if (e.type == CareEventType.feeding && e.note != null) {
      final parts = parseFeedingNote(e.note);
      if (parts.sessions.isNotEmpty) {
        lines.add(
          '⏱ ${parts.sessions.map((s) => s.toDisplay()).join(' / ')}',
        );
      }
      if (parts.userNote != null && parts.userNote!.isNotEmpty) {
        lines.add('📝 ${parts.userNote}');
      }
    } else if (e.note != null) {
      lines.add('📝 ${e.note}');
    }
    return lines.join('\n');
  }

  IconData _iconFor(CareEventType t) => switch (t) {
        CareEventType.feeding => Icons.local_drink,
        CareEventType.diaper => Icons.baby_changing_station,
        CareEventType.sleep => Icons.bedtime,
      };

  Color _colorFor(CareEventType t) => switch (t) {
        CareEventType.feeding => const Color(0xFFFFAFA3),
        CareEventType.diaper => const Color(0xFFFFCD78),
        CareEventType.sleep => const Color(0xFF7C8DBA),
      };
}

sealed class _ListItem {
  const _ListItem();
}

class _DateHeader extends _ListItem {
  const _DateHeader({required this.date});
  final DateTime date;
}

class _EventItem extends _ListItem {
  const _EventItem(this.event);
  final CareEvent event;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(date),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  static const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

  static String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    final weekday = _weekdayKo[date.weekday - 1];
    final formatted = DateFormat('M월 d일').format(date);
    if (diff == 0) return '오늘 · $formatted ($weekday)';
    if (diff == 1) return '어제 · $formatted ($weekday)';
    return '$formatted ($weekday)';
  }
}
