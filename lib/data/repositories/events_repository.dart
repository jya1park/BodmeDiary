import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../core/time/day_boundary.dart';
import '../../core/utils/id.dart';
import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/baby.dart';
import '../models/care_event.dart';
import '../models/feeding_note.dart';
import 'family_repository.dart';

class EventsRepository {
  EventsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  /// 즉시 기록 (기저귀, 또는 OCR confirm).
  Future<String> addEvent({
    required String familyId,
    required Baby baby,
    required CareEvent event,
  }) async {
    final id = event.id.isEmpty ? newId() : event.id;
    final ref = _firestore.doc(FirestorePaths.event(familyId, baby.id, id));
    await ref.set(event.toCreateMap());
    return id;
  }

  /// 일괄 저장 (OCR confirm 등).
  Future<void> addEvents({
    required String familyId,
    required Baby baby,
    required List<CareEvent> events,
  }) async {
    final batch = _firestore.batch();
    for (final e in events) {
      final id = e.id.isEmpty ? newId() : e.id;
      batch.set(
        _firestore.doc(FirestorePaths.event(familyId, baby.id, id)),
        e.toCreateMap(),
      );
    }
    await batch.commit();
  }

  Future<void> deleteEvent({
    required String familyId,
    required String babyId,
    required String eventId,
  }) async {
    await _firestore.doc(FirestorePaths.event(familyId, babyId, eventId)).delete();
  }

  /// 기존 이벤트 수정. type 이 바뀌면 다른 타입의 nested 필드는 제거.
  /// createdByUid 는 갱신하지 않는다 (원작자 유지).
  Future<void> updateEvent({
    required String familyId,
    required String babyId,
    required CareEvent event,
  }) async {
    final m = <String, dynamic>{
      'type': event.type.name,
      'startAt': Timestamp.fromDate(event.startAt),
      'endAt': Timestamp.fromDate(event.endAt),
      'durationMs': event.durationMs,
      'localDayKey': event.localDayKey,
      'updatedAt': FieldValue.serverTimestamp(),
      // 비활성 타입은 명시적으로 제거 (type 변경 시 정리)
      'feeding': event.type == CareEventType.feeding
          ? {
              if (event.feedingAmountMl != null) 'amountMl': event.feedingAmountMl,
              if (event.note != null) 'note': event.note,
            }
          : FieldValue.delete(),
      'diaper': event.type == CareEventType.diaper
          ? {
              if (event.diaperKind != null) 'kind': event.diaperKind!.name,
              if (event.note != null) 'note': event.note,
            }
          : FieldValue.delete(),
      'sleep': event.type == CareEventType.sleep
          ? {
              if (event.note != null) 'note': event.note,
            }
          : FieldValue.delete(),
    };
    await _firestore
        .doc(FirestorePaths.event(familyId, babyId, event.id))
        .update(m);
  }

  /// 수유 이벤트 추가/병합. 마지막 수유 종료시각과 새 이벤트 시작시각 사이가
  /// [mergeWindow] 이내면 기존 이벤트의 endAt·durationMs·feeding.amountMl 를
  /// 확장하여 1회로 처리. 아니면 일반 추가.
  /// 반환: 결과 이벤트 ID (병합 시 기존 ID, 신규 시 새 ID).
  Future<String> addOrMergeFeeding({
    required String familyId,
    required Baby baby,
    required CareEvent event,
    Duration mergeWindow = const Duration(minutes: 30),
  }) async {
    assert(event.type == CareEventType.feeding,
        'addOrMergeFeeding 은 수유 이벤트만 처리합니다.');

    final recent = await _firestore
        .collection(FirestorePaths.events(familyId, baby.id))
        .where('type', isEqualTo: 'feeding')
        .orderBy('endAt', descending: true)
        .limit(1)
        .get();

    if (recent.docs.isNotEmpty) {
      final last = CareEvent.fromDoc(recent.docs.first);
      // 신규 이벤트가 마지막 수유 종료 후 mergeWindow 이내에 시작했을 때만 병합
      if (event.startAt.isAfter(last.endAt)) {
        final gap = event.startAt.difference(last.endAt);
        if (gap <= mergeWindow) {
          await _mergeFeedingInto(familyId, baby.id, last, event);
          return last.id;
        }
      }
    }
    return addEvent(familyId: familyId, baby: baby, event: event);
  }

  Future<void> _mergeFeedingInto(
    String familyId,
    String babyId,
    CareEvent existing,
    CareEvent incoming,
  ) async {
    final hasAnyAmount =
        existing.feedingAmountMl != null || incoming.feedingAmountMl != null;
    final mergedAmount =
        (existing.feedingAmountMl ?? 0) + (incoming.feedingAmountMl ?? 0);
    final mergedDurationMs = existing.durationMs + incoming.durationMs;
    final mergedNote = mergedFeedingNote(
      existingNote: existing.note,
      existingDurationMs: existing.durationMs,
      incomingNote: incoming.note,
      incomingDurationMs: incoming.durationMs,
    );
    await _firestore
        .doc(FirestorePaths.event(familyId, babyId, existing.id))
        .update({
      'endAt': Timestamp.fromDate(incoming.endAt),
      'durationMs': mergedDurationMs,
      'feeding': {
        if (hasAnyAmount) 'amountMl': mergedAmount,
        if (mergedNote != null) 'note': mergedNote,
      },
    });
  }

  /// 편집된 수유 이벤트의 30분 머지 후보 검색. 자기 자신은 제외.
  /// - predecessor: endAt < [event].startAt 인 가장 최근 수유 (gap ≤ window)
  /// - successor: startAt > [event].endAt 인 가장 이른 수유 (gap ≤ window)
  /// 두 후보가 모두 있으면 더 가까운 쪽을 반환.
  Future<CareEvent?> findFeedingMergeCandidate({
    required String familyId,
    required String babyId,
    required CareEvent event,
    Duration window = const Duration(minutes: 30),
  }) async {
    final col = _firestore.collection(FirestorePaths.events(familyId, babyId));

    // 직전 수유 후보
    final predSnap = await col
        .where('type', isEqualTo: 'feeding')
        .where('endAt', isLessThan: Timestamp.fromDate(event.startAt))
        .orderBy('endAt', descending: true)
        .limit(3)
        .get();
    CareEvent? predecessor;
    for (final doc in predSnap.docs) {
      if (doc.id == event.id) continue;
      final cand = CareEvent.fromDoc(doc);
      if (event.startAt.difference(cand.endAt) <= window) predecessor = cand;
      break;
    }

    // 직후 수유 후보
    final succSnap = await col
        .where('type', isEqualTo: 'feeding')
        .where('startAt', isGreaterThan: Timestamp.fromDate(event.endAt))
        .orderBy('startAt')
        .limit(3)
        .get();
    CareEvent? successor;
    for (final doc in succSnap.docs) {
      if (doc.id == event.id) continue;
      final cand = CareEvent.fromDoc(doc);
      if (cand.startAt.difference(event.endAt) <= window) successor = cand;
      break;
    }

    if (predecessor == null) return successor;
    if (successor == null) return predecessor;
    // 둘 다 있으면 더 가까운 쪽
    final predGap = event.startAt.difference(predecessor.endAt);
    final succGap = successor.startAt.difference(event.endAt);
    return predGap <= succGap ? predecessor : successor;
  }

  /// 두 수유 이벤트를 합침. [target] 에 [absorbed] 가 흡수됨.
  /// - startAt = min, endAt = max
  /// - durationMs 는 두 실효 시간의 합
  /// - feedingAmountMl 은 둘 중 하나라도 있으면 합산
  /// - note 는 둘 중 하나라도 있으면 합쳐서 보존 (개행 구분)
  /// [absorbed] 는 삭제됨.
  Future<void> mergeTwoFeedings({
    required String familyId,
    required String babyId,
    required CareEvent target,
    required CareEvent absorbed,
  }) async {
    final newStart =
        target.startAt.isBefore(absorbed.startAt) ? target.startAt : absorbed.startAt;
    final newEnd =
        target.endAt.isAfter(absorbed.endAt) ? target.endAt : absorbed.endAt;
    final newDurationMs = target.durationMs + absorbed.durationMs;
    final hasAnyAmount =
        target.feedingAmountMl != null || absorbed.feedingAmountMl != null;
    final mergedAmount =
        (target.feedingAmountMl ?? 0) + (absorbed.feedingAmountMl ?? 0);
    final mergedNote = mergedFeedingNote(
      existingNote: target.note,
      existingDurationMs: target.durationMs,
      incomingNote: absorbed.note,
      incomingDurationMs: absorbed.durationMs,
    );

    final batch = _firestore.batch();
    batch.update(
      _firestore.doc(FirestorePaths.event(familyId, babyId, target.id)),
      {
        'startAt': Timestamp.fromDate(newStart),
        'endAt': Timestamp.fromDate(newEnd),
        'durationMs': newDurationMs,
        'localDayKey': target.localDayKey,
        'feeding': {
          if (hasAnyAmount) 'amountMl': mergedAmount,
          if (mergedNote != null) 'note': mergedNote,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.delete(
      _firestore.doc(FirestorePaths.event(familyId, babyId, absorbed.id)),
    );
    await batch.commit();
  }

  /// 특정 [dayKeys] 범위의 이벤트 스트림 (시작순 정렬).
  Stream<List<CareEvent>> watchEventsByDayKeys({
    required String familyId,
    required String babyId,
    required List<String> dayKeys,
  }) {
    if (dayKeys.isEmpty) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.events(familyId, babyId))
        .where('localDayKey', whereIn: dayKeys)
        .orderBy('localDayKey')
        .orderBy('startAt')
        .snapshots()
        .map((q) => q.docs.map(CareEvent.fromDoc).toList(growable: false));
  }

  /// 마지막 N개 이벤트 (최신순).
  Stream<List<CareEvent>> watchRecent({
    required String familyId,
    required String babyId,
    int limit = 50,
  }) {
    return _firestore
        .collection(FirestorePaths.events(familyId, babyId))
        .orderBy('startAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(CareEvent.fromDoc).toList(growable: false));
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(firestoreProvider)),
);

/// 오늘 이벤트 스트림 (마지막 X 칩에 사용).
final todayEventsProvider = StreamProvider<List<CareEvent>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  final baby = ref.watch(currentBabyProvider);
  if (familyId == null || baby == null) return Stream.value(const []);

  // 오늘 + 어제 (24시간 이내 마지막 이벤트가 어제일 수 있음)
  final keys = recentDayKeys(2, baby.timezone);
  return ref.read(eventsRepositoryProvider).watchEventsByDayKeys(
        familyId: familyId,
        babyId: baby.id,
        dayKeys: keys,
      );
});
