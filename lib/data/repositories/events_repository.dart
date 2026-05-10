import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../core/time/day_boundary.dart';
import '../../core/utils/id.dart';
import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/baby.dart';
import '../models/care_event.dart';
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
    await _firestore
        .doc(FirestorePaths.event(familyId, babyId, existing.id))
        .update({
      'endAt': Timestamp.fromDate(incoming.endAt),
      'durationMs': incoming.endAt.difference(existing.startAt).inMilliseconds,
      'feeding': {
        if (hasAnyAmount) 'amountMl': mergedAmount,
      },
    });
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
