import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../core/time/duration_format.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import 'manual_record_form.dart';

class ManualRecordsScreen extends ConsumerWidget {
  const ManualRecordsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ManualRecordForm(),
    );
  }

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
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    if (familyId == null || baby == null) return;

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
          babyId: baby.id,
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
    final familyId = ref.watch(currentFamilyIdProvider);
    final baby = ref.watch(currentBabyProvider);

    if (familyId == null || baby == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('기록 편집')),
        body: const Center(child: Text('아기 정보 로드 중...')),
      );
    }

    final stream = ref.watch(_recentEventsProvider((familyId, baby.id)));

    return Scaffold(
      appBar: AppBar(title: const Text('기록 편집')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('수동 기록'),
      ),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Text('아직 기록이 없어요\n우측 하단의 + 버튼으로 추가하세요',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = events[i];
              return Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _delete(context, ref, e);
                  return false; // 다이얼로그가 처리하므로 자동 dismiss 안 함
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
        },
      ),
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
        final dur = e.duration;
        return '잠 — ${formatTimer(dur)}';
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

/// 최근 100개 이벤트 (편집 목록).
final _recentEventsProvider =
    StreamProvider.autoDispose.family<List<CareEvent>, (String, String)>(
  (ref, args) {
    final (familyId, babyId) = args;
    return ref.read(eventsRepositoryProvider).watchRecent(
          familyId: familyId,
          babyId: babyId,
          limit: 100,
        );
  },
);
