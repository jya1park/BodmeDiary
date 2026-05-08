import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/baby.dart';
import '../models/family.dart';
import 'auth_repository.dart';

class FamilyRepository {
  FamilyRepository(this._firestore, this._functions);
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// 가족 생성 — 본인이 owner & 단독 멤버. users/{uid}.familyId 도 갱신.
  Future<String> createFamily({
    required String uid,
    required String familyName,
  }) async {
    final ref = _firestore.collection(FirestorePaths.families).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': familyName,
      'ownerUid': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_firestore.doc(FirestorePaths.user(uid)), {
      'familyId': ref.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  /// 6자리 초대코드 생성 (Cloud Function `createInvite`).
  Future<({String code, DateTime expiresAt})> createInviteCode(
      String familyId) async {
    final res = await _functions
        .httpsCallable('createInvite')
        .call<Map<String, dynamic>>({'familyId': familyId});
    final code = res.data['code'] as String;
    final expiresMs = (res.data['expiresAt'] as num).toInt();
    return (
      code: code,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresMs)
    );
  }

  /// 초대코드로 가족 합류 (Cloud Function `redeemInvite`).
  Future<String> joinFamily(String code) async {
    final res = await _functions
        .httpsCallable('redeemInvite')
        .call<Map<String, dynamic>>({'code': code});
    return res.data['familyId'] as String;
  }

  Stream<Family?> watchFamily(String familyId) {
    return _firestore
        .doc(FirestorePaths.family(familyId))
        .snapshots()
        .map((doc) => doc.exists ? Family.fromDoc(doc) : null);
  }

  Stream<List<Baby>> watchBabies(String familyId) {
    return _firestore
        .collection(FirestorePaths.babies(familyId))
        .orderBy('createdAt')
        .snapshots()
        .map((q) => q.docs.map(Baby.fromDoc).toList(growable: false));
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

/// 라우터 분기에 사용하는 통합 가족 상태.
class FamilyState {
  const FamilyState({this.familyId, this.family, this.babies = const []});
  final String? familyId;
  final Family? family;
  final List<Baby> babies;
}

final currentFamilyStateProvider = StreamProvider<FamilyState>((ref) async* {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me?.familyId == null) {
    yield const FamilyState();
    return;
  }
  final familyId = me!.familyId!;
  final repo = ref.watch(familyRepositoryProvider);
  await for (final family in repo.watchFamily(familyId)) {
    if (family == null) {
      yield FamilyState(familyId: familyId);
      continue;
    }
    final babies = await repo.watchBabies(familyId).first;
    yield FamilyState(familyId: familyId, family: family, babies: babies);
  }
});

/// MVP — 가족의 첫 번째 아기를 활성 아기로 사용.
final currentBabyProvider = Provider<Baby?>((ref) {
  final state = ref.watch(currentFamilyStateProvider).valueOrNull;
  if (state == null || state.babies.isEmpty) return null;
  return state.babies.first;
});

final currentFamilyIdProvider = Provider<String?>((ref) {
  return ref.watch(currentFamilyStateProvider).valueOrNull?.familyId;
});
