/// "1시간 23분", "45분", "방금 전" 등 한국어 친화 포맷.
String formatElapsed(Duration d) {
  if (d.inSeconds < 60) return '방금 전';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  final hours = d.inHours;
  final mins = d.inMinutes % 60;
  if (hours < 24) {
    return mins == 0 ? '$hours시간 전' : '$hours시간 $mins분 전';
  }
  final days = d.inDays;
  return '$days일 전';
}

/// 활성 타이머의 경과를 "12:34" 또는 "1:23:45" 로.
String formatTimer(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 차트 축 등에서 분→시간 변환 ("3.2시간").
String formatHours(Duration d) {
  final hours = d.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}시간';
}
