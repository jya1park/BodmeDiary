import 'package:bodmediary/data/models/care_event.dart';
import 'package:bodmediary/features/history/application/aggregation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aggregateByDay', () {
    test('빈 이벤트는 모두 0', () {
      final agg = aggregateByDay(const [], ['2026-05-07', '2026-05-08']);
      expect(agg, hasLength(2));
      expect(agg.first.feedCount, 0);
      expect(agg.last.sleepHours, 0.0);
    });

    test('타입별로 정확히 카운트', () {
      final dt = DateTime(2026, 5, 7, 10);
      final events = [
        CareEvent(
          id: '1',
          type: CareEventType.feeding,
          startAt: dt,
          endAt: dt.add(const Duration(minutes: 15)),
          localDayKey: '2026-05-07',
          createdByUid: 'u',
          source: CareEventSource.manual,
        ),
        CareEvent(
          id: '2',
          type: CareEventType.diaper,
          startAt: dt,
          endAt: dt,
          localDayKey: '2026-05-07',
          createdByUid: 'u',
          source: CareEventSource.manual,
          diaperKind: DiaperKind.both,
        ),
        CareEvent(
          id: '3',
          type: CareEventType.sleep,
          startAt: dt,
          endAt: dt.add(const Duration(hours: 2, minutes: 30)),
          localDayKey: '2026-05-07',
          createdByUid: 'u',
          source: CareEventSource.timer,
        ),
      ];
      final agg = aggregateByDay(events, ['2026-05-07']);
      expect(agg.first.feedCount, 1);
      expect(agg.first.peeCount, 1, reason: 'both 은 pee 도 +1');
      expect(agg.first.poopCount, 1, reason: 'both 은 poop 도 +1');
      expect(agg.first.sleepHours, closeTo(2.5, 0.001));
    });
  });
}
