import 'package:bodmediary/data/models/baby.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateBreastMilkMl', () {
    test('유축량 미설정이면 null', () {
      expect(
        estimateBreastMilkMl(const Duration(minutes: 20), null),
        isNull,
      );
    });

    test('20분 수유, 10분당 30ml → 60ml', () {
      expect(
        estimateBreastMilkMl(const Duration(minutes: 20), 30),
        60,
      );
    });

    test('15분 수유, 10분당 40ml → 60ml (반올림)', () {
      expect(
        estimateBreastMilkMl(const Duration(minutes: 15), 40),
        60,
      );
    });

    test('0분 → null', () {
      expect(estimateBreastMilkMl(Duration.zero, 50), isNull);
    });

    test('rate 0 또는 음수 → null', () {
      expect(estimateBreastMilkMl(const Duration(minutes: 10), 0), isNull);
      expect(estimateBreastMilkMl(const Duration(minutes: 10), -5), isNull);
    });
  });
}
