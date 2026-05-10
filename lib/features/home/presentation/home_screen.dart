import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/routes.dart';
import '../../../core/time/day_boundary.dart';
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
import '../../sleep/presentation/sleep_stop_sheet.dart';

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
      builder: (_) => FeedingStopSheet(
        startedAt: active.startedAt,
        pausedAt: active.pausedAt,
        pauseAccumMs: active.pauseAccumMs,
      ),
    );
    if (result == null) return; // dismiss
    if (result.cancelled) {
      await ref.read(timerRepositoryProvider).cancelTimer(
            familyId: family,
            babyId: baby.id,
            type: CareEventType.feeding,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수유 기록이 취소되었습니다')),
        );
      }
      return;
    }
    if (!result.saved) return;

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
    final active = ref.read(activeSleepTimerProvider).value;
    if (family == null || baby == null || user == null || active == null) {
      return;
    }

    final action = await showModalBottomSheet<SleepStopAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => SleepStopSheet(startedAt: active.startedAt),
    );
    if (action == null) return; // dismiss
    if (action == SleepStopAction.cancel) {
      await ref.read(timerRepositoryProvider).cancelTimer(
            familyId: family,
            babyId: baby.id,
            type: CareEventType.sleep,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('잠 기록이 취소되었습니다')),
        );
      }
      return;
    }

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

  void _editRecords(BuildContext context) {
    context.push(Routes.manualRecords);
  }

  Future<void> _pauseFeeding(WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    if (family == null || baby == null) return;
    await ref.read(timerRepositoryProvider).pauseTimer(
          familyId: family,
          babyId: baby.id,
          type: CareEventType.feeding,
        );
  }

  Future<void> _resumeFeeding(WidgetRef ref) async {
    final family = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    if (family == null || baby == null) return;
    await ref.read(timerRepositoryProvider).resumeTimer(
          familyId: family,
          babyId: baby.id,
          type: CareEventType.feeding,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final baby = ref.watch(currentBabyProvider);
    final allRecent = ref.watch(todayEventsProvider).value ?? const [];
    final activeFeed = ref.watch(activeFeedingTimerProvider).value;
    final activeSleep = ref.watch(activeSleepTimerProvider).value;

    // 오늘 / 어제 (baby timezone 기준) 이벤트 분리
    final now = DateTime.now();
    final todayKey =
        baby == null ? null : localDayKey(now, baby.timezone);
    final yesterdayKey = baby == null
        ? null
        : localDayKey(now.subtract(const Duration(days: 1)), baby.timezone);
    final today = todayKey == null
        ? const <CareEvent>[]
        : allRecent.where((e) => e.localDayKey == todayKey).toList();
    final yesterday = yesterdayKey == null
        ? const <CareEvent>[]
        : allRecent.where((e) => e.localDayKey == yesterdayKey).toList();

    final lastFeed = today
        .where((e) => e.type == CareEventType.feeding)
        .sorted((a, b) => b.endAt.compareTo(a.endAt))
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

    // 누적 수유량: 모유는 유축량 기반 추정 포함
    final dailyMl = _computeDailyFeedingMl(today, baby);
    final yesterdayMl = _computeDailyFeedingMl(yesterday, baby);

    // 게이지 max = 어제 총량. 어제 데이터 없으면 기본 800ml.
    final hasYesterday = yesterdayMl > 0;
    final target =
        hasYesterday ? yesterdayMl : AppConfig.defaultDailyFeedingTargetMl;
    final progress = (dailyMl / target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(baby == null ? "유담's Diary" : '${baby.name} 의 하루'),
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
                  pausedAt: activeFeed.pausedAt,
                  pauseAccumMs: activeFeed.pauseAccumMs,
                  onPause: () => _pauseFeeding(ref),
                  onResume: () => _resumeFeeding(ref),
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
              progress: progress,
              onTap: () => activeFeed == null
                  ? _onFeeding(context, ref)
                  : _stopFeeding(context, ref),
              onLongPress: () => _editRecords(context),
              subtitle: _FeedingSubtitle(
                lastFeed: lastFeed,
                baby: baby,
                dailyMl: dailyMl,
                targetMl: target,
                hasYesterday: hasYesterday,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: '기저귀',
              icon: Icons.baby_changing_station,
              color: const Color(0xFFFFCD78),
              onTap: () => _onDiaper(context, ref),
              onLongPress: () => _editRecords(context),
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
              onLongPress: () => _editRecords(context),
              subtitle: ElapsedText(
                since: lastSleep?.endAt,
                prefix: '깬지 ',
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '버튼을 길게 누르면 기록 편집',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
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

/// 오늘 누적 수유량 계산. 분유는 입력값, 모유는 유축량 기반 추정값을 합산.
int _computeDailyFeedingMl(List<CareEvent> todayEvents, Baby? baby) {
  var total = 0;
  for (final e in todayEvents) {
    if (e.type != CareEventType.feeding) continue;
    if (e.feedingAmountMl != null) {
      total += e.feedingAmountMl!;
    } else {
      final est =
          estimateBreastMilkMl(e.duration, baby?.pumpRateMlPer10Min);
      if (est != null) total += est;
    }
  }
  return total;
}

class _FeedingSubtitle extends StatelessWidget {
  const _FeedingSubtitle({
    required this.lastFeed,
    required this.baby,
    required this.dailyMl,
    required this.targetMl,
    required this.hasYesterday,
  });

  final CareEvent? lastFeed;
  final Baby? baby;
  final int dailyMl;
  final int targetMl;
  final bool hasYesterday;

  String? _lastSuffix() {
    final feed = lastFeed;
    if (feed == null) return null;
    if (feed.feedingAmountMl != null) return '${feed.feedingAmountMl}ml';
    final est =
        estimateBreastMilkMl(feed.duration, baby?.pumpRateMlPer10Min);
    return est == null ? null : '약 ~${est}ml';
  }

  @override
  Widget build(BuildContext context) {
    final compareLabel = hasYesterday ? '어제' : '기본';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('오늘 ${dailyMl}ml · $compareLabel ${targetMl}ml'),
        ElapsedText(since: lastFeed?.endAt, suffix: _lastSuffix()),
      ],
    );
  }
}

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
