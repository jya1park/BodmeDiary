/// 테스트 가능한 시간 추상화. 프로덕션에서는 [SystemClock] 을 주입.
abstract class Clock {
  DateTime now();

  const Clock();
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
