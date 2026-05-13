/// 수유 노트 파싱 / 빌드 유틸.
///
/// 머지된 수유의 note 필드는 다음 형식을 가진다:
///
///   수유 10분 / 10분 / 15분
///   ──
///   [사용자가 적은 메모 내용]
///
/// - 첫 줄: 머지된 각 세션의 실효 시간 (분 단위)
/// - 둘째 줄: `──` 구분자
/// - 그 이후: 사용자 메모 (선택)
///
/// 머지가 일어나지 않은 단일 수유는 세션 로그가 없고 사용자 메모만 저장된다.

const String _sessionSeparator = '\n──\n';
const String _sessionLogPrefix = '수유 ';

/// note 를 (sessions, userNote) 로 분리.
({List<int> sessions, String? userNote}) parseFeedingNote(String? note) {
  if (note == null || note.trim().isEmpty) {
    return (sessions: <int>[], userNote: null);
  }

  final sepIdx = note.indexOf(_sessionSeparator);
  String head;
  String? tail;
  if (sepIdx >= 0) {
    head = note.substring(0, sepIdx);
    tail = note.substring(sepIdx + _sessionSeparator.length);
    if (tail.trim().isEmpty) tail = null;
  } else {
    // 구분자 없음 — 전체가 세션 로그이거나 사용자 메모
    if (note.startsWith(_sessionLogPrefix)) {
      head = note;
      tail = null;
    } else {
      return (sessions: <int>[], userNote: note);
    }
  }

  if (!head.startsWith(_sessionLogPrefix)) {
    return (sessions: <int>[], userNote: note);
  }
  final body = head.substring(_sessionLogPrefix.length);
  final sessions = <int>[];
  for (final part in body.split('/')) {
    final trimmed = part.trim().replaceAll('분', '').trim();
    final n = int.tryParse(trimmed);
    if (n != null) sessions.add(n);
  }
  return (sessions: sessions, userNote: tail);
}

/// sessions + userNote → note 문자열 (둘 다 비면 null).
String? buildFeedingNote(List<int> sessions, String? userNote) {
  final user = userNote?.trim();
  if (sessions.isEmpty) {
    return (user == null || user.isEmpty) ? null : user;
  }
  final log =
      '$_sessionLogPrefix${sessions.map((m) => '$m분').join(' / ')}';
  if (user == null || user.isEmpty) return log;
  return '$log$_sessionSeparator$user';
}

/// 머지 시 합쳐진 note 생성.
/// - existingNote/incomingNote 가 각각 단일 수유였다면 그 durationMs 가 첫 세션
/// - 이미 세션 로그가 있으면 거기에 추가
String? mergedFeedingNote({
  required String? existingNote,
  required int existingDurationMs,
  required String? incomingNote,
  required int incomingDurationMs,
}) {
  final ex = parseFeedingNote(existingNote);
  final inc = parseFeedingNote(incomingNote);
  final exSessions = ex.sessions.isEmpty
      ? [(existingDurationMs / 60000).round()]
      : List<int>.from(ex.sessions);
  final incSessions = inc.sessions.isEmpty
      ? [(incomingDurationMs / 60000).round()]
      : List<int>.from(inc.sessions);
  final allSessions = [...exSessions, ...incSessions];
  final user = [
    if (ex.userNote != null && ex.userNote!.isNotEmpty) ex.userNote,
    if (inc.userNote != null && inc.userNote!.isNotEmpty) inc.userNote,
  ].join('\n').trim();
  return buildFeedingNote(allSessions, user.isEmpty ? null : user);
}
