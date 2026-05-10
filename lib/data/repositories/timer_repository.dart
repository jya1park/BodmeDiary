import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

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
  /// 수유 type 일 때 마지막 수유 종료시각과의 간격이 [feedingMergeWindow]
  /// 이내면 기존 이벤트를 확장 (1회로 통합).
  /// 이미 다른 사람이 종료해서 활성문서가 없으면 false.
  Future<bool> stopTimer({
    required String familyId,
    required Baby baby,
    required CareEventType type,
    required String stoppedByUid,
    int? feedingAmountMl,
    String? note,
    Duration feedingMergeWindow = const Duration(minutes: 30),
  }) async {
    final activeRef = _firestore
        .doc(FirestorePaths.activeTimer(familyId, baby.id, type.name));

    // 수유면 병합 후보 미리 조회 (트랜잭션 내에서 query 불가, doc read 만 가능)
    DocumentReference<Map<String, dynamic>>? mergeRef;
    if (type == CareEventType.feeding) {
      final recent = await _firestore
          .collection(FirestorePaths.events(familyId, baby.id))
          .where('type', isEqualTo: 'feeding')
          .orderBy('endAt', descending: true)
          .limit(1)
          .get();
      if (recent.docs.isNotEmpty) {
        final lastEnd =
            (recent.docs.first.data()['endAt'] as Timestamp?)?.toDate();
        if (lastEnd != null &&
            DateTime.now().difference(lastEnd) <= feedingMergeWindow) {
          mergeRef = _firestore.doc(FirestorePaths.event(
              familyId, baby.id, recent.docs.first.id));
        }
      }
    }

    return _firestore.runTransaction<bool>((tx) async {
      final activeSnap = await tx.get(activeRef);
      if (!activeSnap.exists) return false;
      final active = ActiveTimer.fromDoc(activeSnap);
      final now = DateTime.now();
      // 일시정지 시간을 제외한 실효 종료시각.
      // 일시정지 중에 종료하면 pausedAt 시점이 사실상 마지막 동작 시점.
      final effective = active.effectiveElapsed(now);
      final endAt = active.startedAt.add(effective);

      // 병합 분기 — 후보가 아직 존재하고 시간 조건이 그대로면 합침
      if (mergeRef != null) {
        final existingSnap = await tx.get(mergeRef);
        if (existingSnap.exists) {
          final existing = CareEvent.fromDoc(existingSnap);
          if (active.startedAt.isAfter(existing.endAt) &&
              active.startedAt.difference(existing.endAt) <=
                  feedingMergeWindow) {
            final hasAny = existing.feedingAmountMl != null ||
                feedingAmountMl != null;
            tx.update(mergeRef, {
              'endAt': Timestamp.fromDate(endAt),
              'durationMs':
                  endAt.difference(existing.startAt).inMilliseconds,
              'feeding': {
                if (hasAny)
                  'amountMl':
                      (existing.feedingAmountMl ?? 0) + (feedingAmountMl ?? 0),
              },
            });
            tx.delete(activeRef);
            return true;
          }
        }
      }

      // 신규 이벤트 생성 (병합 안 함)
      final eventId = newId();
      final eventRef = _firestore
          .doc(FirestorePaths.event(familyId, baby.id, eventId));
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

  /// 일시정지 — pausedAt 을 현재 시각으로 설정. 이미 일시정지면 무시.
  Future<void> pauseTimer({
    required String familyId,
    required String babyId,
    required CareEventType type,
  }) async {
    final ref = _firestore
        .doc(FirestorePaths.activeTimer(familyId, babyId, type.name));
    await _firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final active = ActiveTimer.fromDoc(snap);
      if (active.isPaused) return; // 이미 일시정지
      tx.update(ref, {
        'pausedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 재개 — pauseAccumMs 에 (now - pausedAt) 가산 후 pausedAt 제거.
  Future<void> resumeTimer({
    required String familyId,
    required String babyId,
    required CareEventType type,
  }) async {
    final ref = _firestore
        .doc(FirestorePaths.activeTimer(familyId, babyId, type.name));
    await _firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final active = ActiveTimer.fromDoc(snap);
      final pausedAt = active.pausedAt;
      if (pausedAt == null) return; // 이미 동작중
      final pausedFor =
          DateTime.now().difference(pausedAt).inMilliseconds;
      tx.update(ref, {
        'pausedAt': FieldValue.delete(),
        'pauseAccumMs': active.pauseAccumMs + (pausedFor < 0 ? 0 : pausedFor),
      });
    });
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
