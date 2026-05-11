import '../../core/time/day_boundary.dart';
import 'active_timer.dart';
import 'baby.dart';
import 'care_event.dart';

/// 활성 타이머의 ID 접두사. 이 접두사로 시작하면 가상 이벤트(아직 저장 안 됨).
const String activePseudoIdPrefix = 'active-';

/// 활성 타이머를 화면 표시용 가상 이벤트로 변환.
/// - 일시정지 시간을 제외한 실효 시간을 사용
/// - durationMs 는 실효 시간 (휴식 제외)
/// - endAt 은 wall clock 으로는 now 지만, durationMs 에는 일시정지 시간 미포함
CareEvent? activeTimerAsPseudoEvent(ActiveTimer? active, Baby baby) {
  if (active == null) return null;
  final now = DateTime.now();
  final effective = active.effectiveElapsed(now);
  return CareEvent(
    id: '$activePseudoIdPrefix${active.type.name}',
    type: active.type,
    startAt: active.startedAt,
    endAt: active.startedAt.add(effective),
    durationMs: effective.inMilliseconds,
    localDayKey: localDayKey(active.startedAt, baby.timezone),
    createdByUid: active.startedByUid,
    source: CareEventSource.timer,
  );
}

bool isPseudoActiveEvent(CareEvent e) => e.id.startsWith(activePseudoIdPrefix);
