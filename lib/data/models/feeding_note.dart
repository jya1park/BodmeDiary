/// 수유 노트 파싱 / 빌드 유틸.
///
/// 머지된 수유의 note 필드는 다음 형식을 가진다:
///
///   수유 06:00-06:10 (10분) / 06:20-06:30 (10분) / 06:55-07:00 (5분)
///   ──
///   [사용자가 적은 메모 내용]
///
/// - 첫 줄: 머지된 각 세션의 "시작-종료 (실효 시간)"
/// - 둘째 줄: `──` 구분자
/// - 그 이후: 사용자 메모 (선택)
///
/// 머지가 일어나지 않은 단일 수유는 세션 로그가 없고 사용자 메모만 저장된다.
///
/// 구 포맷 (시각 없이 분만) 도 backward-compat 로 파싱한다:
///   `수유 10분 / 15분`

const String _sessionSeparator = '\n──\n';
const String _sessionLogPrefix = '수유 ';

final RegExp _sessionWithTimes =
    RegExp(r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2})\s*\((\d+)분\)$');
final RegExp _sessionMinutesOnly = RegExp(r'^(\d+)분$');

class FeedingSession {
  const FeedingSession({
    required this.minutes,
    this.startTime,
    this.endTime,
  });

  /// "HH:mm" — 시각이 기록 안 된 구 포맷 세션은 null.
  final String? startTime;
  final String? endTime;
  final int minutes;

  bool get hasTimes => startTime != null && endTime != null;

  /// 노트 한 토막으로 직렬화.
  String toDisplay() {
    if (hasTimes) return '$startTime-$endTime (${minutes}분)';
    return '${minutes}분';
  }
}

/// note 를 (sessions, userNote) 로 분리.
({List<FeedingSession> sessions, String? userNote}) parseFeedingNote(
    String? note) {
  if (note == null || note.trim().isEmpty) {
    return (sessions: <FeedingSession>[], userNote: null);
  }

  final sepIdx = note.indexOf(_sessionSeparator);
  String head;
  String? tail;
  if (sepIdx >= 0) {
    head = note.substring(0, sepIdx);
    tail = note.substring(sepIdx + _sessionSeparator.length);
    if (tail.trim().isEmpty) tail = null;
  } else {
    if (note.startsWith(_sessionLogPrefix)) {
      head = note;
      tail = null;
    } else {
      return (sessions: <FeedingSession>[], userNote: note);
    }
  }

  if (!head.startsWith(_sessionLogPrefix)) {
    return (sessions: <FeedingSession>[], userNote: note);
  }
  final body = head.substring(_sessionLogPrefix.length);
  final sessions = <FeedingSession>[];
  for (final raw in body.split('/')) {
    final part = raw.trim();
    final m1 = _sessionWithTimes.firstMatch(part);
    if (m1 != null) {
      sessions.add(FeedingSession(
        startTime: m1.group(1),
        endTime: m1.group(2),
        minutes: int.parse(m1.group(3)!),
      ));
      continue;
    }
    final m2 = _sessionMinutesOnly.firstMatch(part);
    if (m2 != null) {
      sessions.add(FeedingSession(minutes: int.parse(m2.group(1)!)));
    }
  }
  return (sessions: sessions, userNote: tail);
}

/// sessions + userNote → note 문자열 (둘 다 비면 null).
String? buildFeedingNote(List<FeedingSession> sessions, String? userNote) {
  final user = userNote?.trim();
  if (sessions.isEmpty) {
    return (user == null || user.isEmpty) ? null : user;
  }
  final log =
      '$_sessionLogPrefix${sessions.map((s) => s.toDisplay()).join(' / ')}';
  if (user == null || user.isEmpty) return log;
  return '$log$_sessionSeparator$user';
}

String _hhmm(DateTime t) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(t.hour)}:${two(t.minute)}';
}

FeedingSession _toSession({
  required DateTime start,
  required DateTime end,
  required int durationMs,
}) {
  return FeedingSession(
    startTime: _hhmm(start),
    endTime: _hhmm(end),
    minutes: (durationMs / 60000).round(),
  );
}

/// 머지 시 합쳐진 note 생성.
/// - existing 이 단일 수유였다면 existingStart/End/DurationMs 로 첫 세션을 만들고
///   이미 세션 로그가 있다면 그대로 보존
/// - incoming 도 동일하게 처리
String? mergedFeedingNote({
  required String? existingNote,
  required DateTime existingStart,
  required DateTime existingEnd,
  required int existingDurationMs,
  required String? incomingNote,
  required DateTime incomingStart,
  required DateTime incomingEnd,
  required int incomingDurationMs,
}) {
  final ex = parseFeedingNote(existingNote);
  final inc = parseFeedingNote(incomingNote);
  final exSessions = ex.sessions.isEmpty
      ? [
          _toSession(
            start: existingStart,
            end: existingEnd,
            durationMs: existingDurationMs,
          )
        ]
      : List<FeedingSession>.from(ex.sessions);
  final incSessions = inc.sessions.isEmpty
      ? [
          _toSession(
            start: incomingStart,
            end: incomingEnd,
            durationMs: incomingDurationMs,
          )
        ]
      : List<FeedingSession>.from(inc.sessions);
  final allSessions = [...exSessions, ...incSessions];
  final user = [
    if (ex.userNote != null && ex.userNote!.isNotEmpty) ex.userNote,
    if (inc.userNote != null && inc.userNote!.isNotEmpty) inc.userNote,
  ].join('\n').trim();
  return buildFeedingNote(allSessions, user.isEmpty ? null : user);
}
