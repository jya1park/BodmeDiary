import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../../data/models/care_event.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import 'event_list_view.dart';
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
        data: (events) => EventListView(
          events: events,
          familyId: familyId,
          babyId: baby.id,
          emptyText: '아직 기록이 없어요\n우측 하단의 + 버튼으로 추가하세요',
        ),
      ),
    );
  }
}

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
