import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/day_boundary.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../application/aggregation.dart';
import 'widgets/history_charts.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  static const _ranges = [1, 7, 30];
  static const _labels = ['일', '주', '월'];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(currentFamilyIdProvider);
    final baby = ref.watch(currentBabyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('히스토리'),
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final l in _labels) Tab(text: l)],
        ),
      ),
      body: (familyId == null || baby == null)
          ? const Center(child: Text('아기 정보를 불러오는 중...'))
          : TabBarView(
              controller: _tab,
              children: [
                for (final days in _ranges)
                  _RangeView(
                    familyId: familyId,
                    babyId: baby.id,
                    timezone: baby.timezone,
                    days: days,
                  ),
              ],
            ),
    );
  }
}

class _RangeView extends ConsumerWidget {
  const _RangeView({
    required this.familyId,
    required this.babyId,
    required this.timezone,
    required this.days,
  });
  final String familyId;
  final String babyId;
  final String timezone;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayKeys = recentDayKeys(days, timezone);
    final stream = ref.watch(_rangeEventsProvider(_RangeArgs(
      familyId: familyId,
      babyId: babyId,
      dayKeys: dayKeys,
    )));

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (events) {
        final agg = aggregateByDay(events, dayKeys);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HistoryChartCard(
              title: '수유 횟수',
              color: const Color(0xFFFFAFA3),
              data: [for (final a in agg) (a.dayKey, a.feedCount.toDouble())],
            ),
            const SizedBox(height: 12),
            HistoryChartCard(
              title: '소변 횟수',
              color: const Color(0xFF82B4FF),
              data: [for (final a in agg) (a.dayKey, a.peeCount.toDouble())],
            ),
            const SizedBox(height: 12),
            HistoryChartCard(
              title: '배변 횟수',
              color: const Color(0xFFB48656),
              data: [for (final a in agg) (a.dayKey, a.poopCount.toDouble())],
            ),
            const SizedBox(height: 12),
            HistoryChartCard(
              title: '수면 시간 (시간)',
              color: const Color(0xFF7C8DBA),
              data: [for (final a in agg) (a.dayKey, a.sleepHours)],
            ),
          ],
        );
      },
    );
  }
}

class _RangeArgs {
  const _RangeArgs({
    required this.familyId,
    required this.babyId,
    required this.dayKeys,
  });
  final String familyId;
  final String babyId;
  final List<String> dayKeys;

  @override
  bool operator ==(Object other) =>
      other is _RangeArgs &&
      other.familyId == familyId &&
      other.babyId == babyId &&
      other.dayKeys.length == dayKeys.length &&
      other.dayKeys.first == dayKeys.first &&
      other.dayKeys.last == dayKeys.last;

  @override
  int get hashCode =>
      Object.hash(familyId, babyId, dayKeys.length, dayKeys.first, dayKeys.last);
}

final _rangeEventsProvider = StreamProvider.family.autoDispose(
  (ref, _RangeArgs args) {
    return ref.read(eventsRepositoryProvider).watchEventsByDayKeys(
          familyId: args.familyId,
          babyId: args.babyId,
          dayKeys: args.dayKeys,
        );
  },
);
