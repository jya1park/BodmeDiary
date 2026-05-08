import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/id.dart';
import '../firebase/firebase_providers.dart';
import '../models/ocr_draft.dart';

class OcrRepository {
  OcrRepository(this._storage, this._functions);
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  /// 사진을 Storage 에 올리고 Cloud Function 호출.
  Future<OcrDraft> uploadAndParse({
    required String familyId,
    required String babyId,
    required File imageFile,
    String? assumedDateKey,
  }) async {
    final filename = '${newId()}.jpg';
    final path = 'families/$familyId/babies/$babyId/ocr/$filename';
    final ref = _storage.ref(path);
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final res = await _functions
        .httpsCallable('parseHandwrittenLog')
        .call<Map<String, dynamic>>({
      'familyId': familyId,
      'babyId': babyId,
      'storagePath': path,
      if (assumedDateKey != null) 'assumedDate': assumedDateKey,
    });
    return OcrDraft.fromMap(res.data);
  }
}

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepository(
    ref.watch(firebaseStorageProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});
