import 'package:cloud_firestore/cloud_firestore.dart';

import 'care_event.dart';

class ActiveTimer {
  const ActiveTimer({
    required this.type,
    required this.startedAt,
    required this.startedByUid,
    required this.startedByName,
    this.pausedAt,
    this.pauseAccumMs = 0,
    this.clientStartedAtMs,
  });

  final CareEventType type; // feeding | sleep
  final DateTime startedAt;
  final String startedByUid;
  final String startedByName;

  /// 현재 일시정지 시점. null 이면 동작 중.
  final DateTime? pausedAt;

  /// 누적 일시정지 시간(밀리초). 재개 시 직전 pausedAt~now 만큼 가산되어 갱신됨.
  final int pauseAccumMs;

  final int? clientStartedAtMs;

  bool get isPaused => pausedAt != null;

  /// 일시정지 시간을 제외한 실효 경과시간.
  /// - 동작 중: now - startedAt - pauseAccumMs
  /// - 일시정지 중: pausedAt - startedAt - pauseAccumMs (얼어붙음)
  Duration effectiveElapsed(DateTime now) {
    final base = (pausedAt ?? now).difference(startedAt);
    final ms = base.inMilliseconds - pauseAccumMs;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  factory ActiveTimer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ActiveTimer(
      type: (d['type'] as String?) == 'sleep'
          ? CareEventType.sleep
          : CareEventType.feeding,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(
              (d['clientStartedAtMs'] as num?)?.toInt() ?? 0),
      startedByUid: (d['startedByUid'] as String?) ?? '',
      startedByName: (d['startedByName'] as String?) ?? '',
      pausedAt: (d['pausedAt'] as Timestamp?)?.toDate(),
      pauseAccumMs: (d['pauseAccumMs'] as num?)?.toInt() ?? 0,
      clientStartedAtMs: (d['clientStartedAtMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'type': type.name,
        'startedAt': FieldValue.serverTimestamp(),
        'startedByUid': startedByUid,
        'startedByName': startedByName,
        'pauseAccumMs': 0,
        'clientStartedAtMs': DateTime.now().millisecondsSinceEpoch,
      };
}
