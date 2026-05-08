import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/widgets/active_timer_banner.dart';
import '../../../core/widgets/elapsed_since_chip.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../data/models/baby.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/timer_repository.dart';
import '../../diaper/presentation/diaper_modal.dart';
import '../../feeding/presentation/feeding_stop_sheet.dart';

/// 수유 칩의 부가 텍스트.
/// - 분유 (`feedingAmountMl != null`) → "120ml"
/// - 모유 + 유축량 설정 → "약 ~46ml" (예측)
/// - 그 외 → null (시간만 표시)
String? _feedTrailing(CareEvent? feed, Baby? baby) {
  if (feed == null) return null;
  if (feed.feedingAmountMl != null) return '${feed.feedingAmountMl}ml';
  final estimate = estimateBreastMilkMl(feed.duration, baby?.pumpRateMlPer10Min);
  return estimate == null ? null : '약 ~${estimate}ml';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _onFeeding(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (family == null || baby == null || user == null) return;

    final active = ref.read(activeFeedingTimerProvider).valueOrNull;
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
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (family == null || baby == null || user == null) return;

    final active = ref.read(activeSleepTimerProvider).valueOrNull;
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
    final user = ref.read(currentAppUserProvider).valueOrNull;
    final active = ref.read(activeFeedingTimerProvider).valueOrNull;
    if (family == null || baby == null || user == null || active == null) {
      return;
    }

    final result = await showModalBottomSheet<FeedingStopResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FeedingStopSheet(startedAt: active.startedAt),
    );
    if (result == null || !result.saved) return; // 사용자가 닫음 — 타이머 유지

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
    final user = ref.read(currentAppUserProvider).valueOrNull;
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
    final today = ref.watch(todayEventsProvider).valueOrNull ?? const [];
    final activeFeed = ref.watch(activeFeedingTimerProvider).valueOrNull;
    final activeSleep = ref.watch(activeSleepTimerProvider).valueOrNull;

    final lastFeed = today
        .where((e) => e.type == CareEventType.feeding)
        .sorted((a, b) => b.startAt.compareTo(a.startAt))
        .firstOrNull;
    final lastPee = today
        .where((e) =>
            e.type == CareEventType.diaper &&
            (e.diaperKind == DiaperKind.pee || e.diaperKind == DiaperKind.both))
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
        title: Text(baby == null ? '보미다이어리' : '${baby.name} 의 하루'),
        actions: [
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElapsedSinceChip(
                  label: '수유',
                  icon: Icons.local_drink,
                  since: lastFeed?.startAt,
                  trailing: _feedTrailing(lastFeed, baby),
                ),
                ElapsedSinceChip(
                  label: '소변',
                  icon: Icons.water_drop_outlined,
                  since: lastPee?.startAt,
                ),
                ElapsedSinceChip(
                  label: '배변',
                  icon: Icons.eco_outlined,
                  since: lastPoop?.startAt,
                ),
                ElapsedSinceChip(
                  label: '수면',
                  icon: Icons.bedtime,
                  since: lastSleep?.endAt,
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: activeFeed == null ? '수유 시작' : '수유 종료',
              icon: Icons.local_drink,
              color: const Color(0xFFFFAFA3),
              onTap: () => activeFeed == null
                  ? _onFeeding(context, ref)
                  : _stopFeeding(context, ref),
              subtitle: activeFeed == null
                  ? '버튼을 누르면 시간 카운트 시작'
                  : '종료 시 분유 양도 함께 기록 가능',
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: '기저귀',
              icon: Icons.baby_changing_station,
              color: const Color(0xFFFFCD78),
              onTap: () => _onDiaper(context, ref),
              subtitle: '소변 / 배변 / 둘다',
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: activeSleep == null ? '잠 시작' : '기상',
              icon: Icons.bedtime,
              color: const Color(0xFF7C8DBA),
              onTap: () => activeSleep == null
                  ? _onSleep(context, ref)
                  : _stopSleep(context, ref),
              subtitle: '시작–종료 타이머',
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
}
