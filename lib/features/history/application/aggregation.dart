import '../../../data/models/care_event.dart';

/// 일별 집계 결과. 차트의 한 막대.
class DayAggregate {
  const DayAggregate({
    required this.dayKey,
    required this.feedCount,
    required this.peeCount,
    required this.poopCount,
    required this.sleepHours,
  });

  final String dayKey;
  final int feedCount;
  final int peeCount;
  final int poopCount;
  final double sleepHours;
}

/// [events] 를 [dayKeys] 순서대로 집계. 누락된 날은 0 으로 채움.
/// 자정을 넘는 수면(예: 23:50→01:30)은 startAt 기준 일자에 누적된다.
List<DayAggregate> aggregateByDay(
  List<CareEvent> events,
  List<String> dayKeys,
) {
  final map = {for (final k in dayKeys) k: _Bucket()};

  for (final e in events) {
    final b = map[e.localDayKey];
    if (b == null) continue;
    switch (e.type) {
      case CareEventType.feeding:
        b.feed += 1;
      case CareEventType.diaper:
        if (e.diaperKind == DiaperKind.pee || e.diaperKind == DiaperKind.both) {
          b.pee += 1;
        }
        if (e.diaperKind == DiaperKind.poop ||
            e.diaperKind == DiaperKind.both) {
          b.poop += 1;
        }
      case CareEventType.sleep:
        b.sleepMinutes += e.duration.inMinutes;
    }
  }

  return [
    for (final k in dayKeys)
      DayAggregate(
        dayKey: k,
        feedCount: map[k]!.feed,
        peeCount: map[k]!.pee,
        poopCount: map[k]!.poop,
        sleepHours: map[k]!.sleepMinutes / 60.0,
      ),
  ];
}

class _Bucket {
  int feed = 0;
  int pee = 0;
  int poop = 0;
  int sleepMinutes = 0;
}
