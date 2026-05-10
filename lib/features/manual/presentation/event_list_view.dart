import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../core/time/duration_format.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/events_repository.dart';
import 'manual_record_form.dart';

/// 이벤트 목록 — 탭하면 편집 폼, 휴지통 클릭/스와이프로 삭제.
/// 기록 편집 화면과 히스토리 일 탭에서 공용으로 사용.
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
    return ListView.separated(
      padding: padding,
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = events[i];
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
            subtitle: Text(
              e.note == null
                  ? _subtitle(e)
                  : '${_subtitle(e)}\n📝 ${e.note}',
              maxLines: 3,
            ),
            isThreeLine: e.note != null,
            onTap: () => _edit(context, ref, e),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _delete(context, ref, e),
            ),
          ),
        );
      },
    );
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
