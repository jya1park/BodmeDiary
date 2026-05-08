import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/day_boundary.dart';
import '../../core/utils/id.dart';
import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/active_timer.dart';
import '../models/baby.dart';
import '../models/care_event.dart';
import 'family_repository.dart';

/// 활성 타이머 시작/종료를 트랜잭션으로 처리. `activeTimers/{type}` 도큐먼트가
/// 자연 mutex 역할을 한다.
class TimerRepository {
  TimerRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<ActiveTimer?> watchActiveTimer({
    required String familyId,
    required String babyId,
    required CareEventType type,
  }) {
    return _firestore
        .doc(FirestorePaths.activeTimer(familyId, babyId, type.name))
        .snapshots()
        .map((doc) => doc.exists ? ActiveTimer.fromDoc(doc) : null);
  }

  /// 시작 — 이미 동일 type 의 타이머가 있으면 false 반환 (호출부에서 안내).
  Future<bool> startTimer({
    required String familyId,
    required Baby baby,
    required CareEventType type,
    required String startedByUid,
    required String startedByName,
  }) async {
    final ref =
        _firestore.doc(FirestorePaths.activeTimer(familyId, baby.id, type.name));
    try {
      await _firestore.runTransaction<void>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          throw FirebaseException(plugin: 'cloud_firestore', code: 'already-exists');
        }
        tx.set(
          ref,
          ActiveTimer(
            type: type,
            startedAt: DateTime.now(),
            startedByUid: startedByUid,
            startedByName: startedByName,
          ).toCreateMap(),
        );
      });
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'already-exists') return false;
      rethrow;
    }
  }

  /// 종료 — 트랜잭션으로 활성타이머 → CareEvent 로 변환 후 활성문서 삭제.
  /// 이미 다른 사람이 종료해서 활성문서가 없으면 false.
  Future<bool> stopTimer({
    required String familyId,
    required Baby baby,
    required CareEventType type,
    required String stoppedByUid,
    int? feedingAmountMl,
    String? note,
  }) async {
    final activeRef =
        _firestore.doc(FirestorePaths.activeTimer(familyId, baby.id, type.name));
    final eventId = newId();
    final eventRef =
        _firestore.doc(FirestorePaths.event(familyId, baby.id, eventId));

    return _firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(activeRef);
      if (!snap.exists) return false;
      final active = ActiveTimer.fromDoc(snap);
      final endAt = DateTime.now();
      final event = CareEvent(
        id: eventId,
        type: type,
        startAt: active.startedAt,
        endAt: endAt,
        localDayKey: localDayKey(active.startedAt, baby.timezone),
        createdByUid: stoppedByUid,
        source: CareEventSource.timer,
        feedingAmountMl: feedingAmountMl,
        note: note,
      );
      tx.set(eventRef, event.toCreateMap());
      tx.delete(activeRef);
      return true;
    });
  }

  /// 강제 취소 — 이벤트 저장 없이 활성타이머 삭제 (잘못 시작했을 때).
  Future<void> cancelTimer({
    required String familyId,
    required String babyId,
    required CareEventType type,
  }) async {
    await _firestore
        .doc(FirestorePaths.activeTimer(familyId, babyId, type.name))
        .delete();
  }
}

final timerRepositoryProvider = Provider<TimerRepository>(
  (ref) => TimerRepository(ref.watch(firestoreProvider)),
);

final activeFeedingTimerProvider = StreamProvider<ActiveTimer?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  final baby = ref.watch(currentBabyProvider);
  if (familyId == null || baby == null) return Stream.value(null);
  return ref.read(timerRepositoryProvider).watchActiveTimer(
        familyId: familyId,
        babyId: baby.id,
        type: CareEventType.feeding,
      );
});

final activeSleepTimerProvider = StreamProvider<ActiveTimer?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  final baby = ref.watch(currentBabyProvider);
  if (familyId == null || baby == null) return Stream.value(null);
  return ref.read(timerRepositoryProvider).watchActiveTimer(
        familyId: familyId,
        babyId: baby.id,
        type: CareEventType.sleep,
      );
});
