import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/baby.dart';

class BabyRepository {
  BabyRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Future<String> createBaby({
    required String familyId,
    required String name,
    required DateTime birthDate,
    required BabyGender gender,
    String timezone = AppConfig.defaultBabyTimezone,
  }) async {
    final ref = _firestore.collection(FirestorePaths.babies(familyId)).doc();
    final baby = Baby(
      id: ref.id,
      name: name,
      birthDate: birthDate,
      gender: gender,
      timezone: timezone,
    );
    await ref.set(baby.toCreateMap());
    return ref.id;
  }
}

final babyRepositoryProvider = Provider<BabyRepository>(
  (ref) => BabyRepository(ref.watch(firestoreProvider)),
);
