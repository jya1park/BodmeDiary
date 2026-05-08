import 'package:timezone/timezone.dart' as tz;

/// 주어진 [moment] 가 [timezoneName] 의 어느 로컬 일자에 속하는지 `YYYY-MM-DD` 로 반환.
///
/// 자정 넘는 수면(예: 23:50→01:30) 은 호출부에서 `startAt` 의 키를 쓰면 시작일 기준
/// 으로 묶인다.
String localDayKey(DateTime moment, String timezoneName) {
  final loc = tz.getLocation(timezoneName);
  final local = tz.TZDateTime.from(moment, loc);
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// [days] 일 전부터 오늘까지의 `localDayKey` 리스트 (오름차순).
List<String> recentDayKeys(int days, String timezoneName, {DateTime? now}) {
  final loc = tz.getLocation(timezoneName);
  final today = tz.TZDateTime.from(now ?? DateTime.now(), loc);
  final base = tz.TZDateTime(loc, today.year, today.month, today.day);
  return List.generate(days, (i) {
    final d = base.subtract(Duration(days: days - 1 - i));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  });
}

/// 주어진 일자 문자열의 시작/끝 instant (UTC `DateTime`).
({DateTime startUtc, DateTime endUtc}) dayKeyToUtcRange(
  String dayKey,
  String timezoneName,
) {
  final parts = dayKey.split('-');
  final loc = tz.getLocation(timezoneName);
  final start = tz.TZDateTime(
    loc,
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final end = start.add(const Duration(days: 1));
  return (startUtc: start.toUtc(), endUtc: end.toUtc());
}
