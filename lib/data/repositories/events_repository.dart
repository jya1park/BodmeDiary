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
