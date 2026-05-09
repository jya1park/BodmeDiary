import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/widgets/active_timer_banner.dart';
import '../../../core/widgets/elapsed_text.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../data/models/baby.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/timer_repository.dart';
import '../../diaper/presentation/diaper_modal.dart';
import '../../feeding/presentation/feeding_stop_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _onFeeding(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    if (family == null || baby == null || user == null) return;

    final active = ref.read(activeFeedingTimerProvider).value;
    if (active != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 수유중이에요')),
      );
      return;
    }
    final ok = await ref.read(timerRepositoryProvider).startTimer(
          familyId: family,
          baby: baby,
          type: CareEventType.feeding,
          startedByUid: user.uid,
          startedByName: user.displayName,
        );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 가족이 막 시작했어요')),
      );
    }
  }

  Future<void> _onDiaper(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const DiaperModal(),
    );
  }

  Future<void> _onSleep(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    if (family == null || baby == null || user == null) return;

    final active = ref.read(activeSleepTimerProvider).value;
    if (active != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 잠자는 중이에요')),
      );
      return;
    }
    final ok = await ref.read(timerRepositoryProvider).startTimer(
          familyId: family,
          baby: baby,
          type: CareEventType.sleep,
          startedByUid: user.uid,
          startedByName: user.displayName,
        );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 가족이 막 시작했어요')),
      );
    }
  }

  Future<void> _stopFeeding(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    final active = ref.read(activeFeedingTimerProvider).value;
    if (family == null || baby == null || user == null || active == null) {
      return;
    }

    final result = await showModalBottomSheet<FeedingStopResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FeedingStopSheet(startedAt: active.startedAt),
    );
    if (result == null || !result.saved) return;

    final ok = await ref.read(timerRepositoryProvider).stopTimer(
          familyId: family,
          baby: baby,
          type: CareEventType.feeding,
          stoppedByUid: user.uid,
          feedingAmountMl: result.amountMl,
        );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 종료된 타이머예요')),
      );
    }
  }

  Future<void> _stopSleep(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    if (family == null || baby == null || user == null) return;
    final ok = await ref.read(timerRepositoryProvider).stopTimer(
          familyId: family,
          baby: baby,
          type: CareEventType.sleep,
          stoppedByUid: user.uid,
        );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 종료된 타이머예요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final baby = ref.watch(currentBabyProvider);
    final today = ref.watch(todayEventsProvider).value ?? const [];
    final activeFeed = ref.watch(activeFeedingTimerProvider).value;
    final activeSleep = ref.watch(activeSleepTimerProvider).value;

    final lastFeed = today
        .where((e) => e.type == CareEventType.feeding)
        .sorted((a, b) => b.startAt.compareTo(a.startAt))
        .firstOrNull;
    final lastPee = today
        .where((e) =>
            e.type == CareEventType.diaper &&
            (e.diaperKind == DiaperKind.pee ||
                e.diaperKind == DiaperKind.both))
        .sorted((a, b) => b.startAt.compareTo(a.startAt))
        .firstOrNull;
    final lastPoop = today
        .where((e) =>
            e.type == CareEventType.diaper &&
            (e.diaperKind == DiaperKind.poop ||
                e.diaperKind == DiaperKind.both))
        .sorted((a, b) => b.startAt.compareTo(a.startAt))
        .firstOrNull;
    final lastSleep = today
        .where((e) => e.type == CareEventType.sleep)
        .sorted((a, b) => b.endAt.compareTo(a.endAt))
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(baby == null ? "유담's Diary" : '${baby.name} 의 하루'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: '기록 편집',
            onPressed: () => context.push(Routes.manualRecords),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (activeFeed != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActiveTimerBanner(
                  title: '수유중',
                  startedAt: activeFeed.startedAt,
                  startedByName: activeFeed.startedByName,
                  color: const Color(0xFFFFAFA3),
                  icon: Icons.local_drink,
                  onStop: () => _stopFeeding(context, ref),
                ),
              ),
            if (activeSleep != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActiveTimerBanner(
                  title: '잠자는 중',
                  startedAt: activeSleep.startedAt,
                  startedByName: activeSleep.startedByName,
                  color: const Color(0xFF7C8DBA),
                  icon: Icons.bedtime,
                  onStop: () => _stopSleep(context, ref),
                ),
              ),
            const SizedBox(height: 4),
            PrimaryActionButton(
              label: activeFeed == null ? '수유 시작' : '수유 종료',
              icon: Icons.local_drink,
              color: const Color(0xFFFFAFA3),
              onTap: () => activeFeed == null
                  ? _onFeeding(context, ref)
                  : _stopFeeding(context, ref),
              subtitle: ElapsedText(
                since: lastFeed?.startAt,
                suffix: _feedAmountSuffix(lastFeed, baby),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: '기저귀',
              icon: Icons.baby_changing_station,
              color: const Color(0xFFFFCD78),
              onTap: () => _onDiaper(context, ref),
              subtitle: _DiaperMeta(
                lastPee: lastPee?.startAt,
                lastPoop: lastPoop?.startAt,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: activeSleep == null ? '잠 시작' : '기상',
              icon: Icons.bedtime,
              color: const Color(0xFF7C8DBA),
              onTap: () => activeSleep == null
                  ? _onSleep(context, ref)
                  : _stopSleep(context, ref),
              subtitle: ElapsedText(
                since: lastSleep?.endAt,
                prefix: '깬지 ',
                emptyText: '기록 없음',
              ),
            ),
            const SizedBox(height: 24),
            if (baby == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '아기 정보 로드 중...',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _feedAmountSuffix(CareEvent? feed, Baby? baby) {
    if (feed == null) return null;
    if (feed.feedingAmountMl != null) return '${feed.feedingAmountMl}ml';
    final estimate = estimateBreastMilkMl(feed.duration, baby?.pumpRateMlPer10Min);
    return estimate == null ? null : '약 ~${estimate}ml';
  }
}

/// 기저귀 버튼 안에 들어갈 "소변 X 전 / 배변 Y 전" 두 줄 텍스트.
class _DiaperMeta extends StatelessWidget {
  const _DiaperMeta({this.lastPee, this.lastPoop});
  final DateTime? lastPee;
  final DateTime? lastPoop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElapsedText(since: lastPee, prefix: '소변 ', emptyText: '소변 기록 없음'),
        ElapsedText(since: lastPoop, prefix: '배변 ', emptyText: '배변 기록 없음'),
      ],
    );
  }
}
