import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../firebase/firebase_providers.dart';
import '../models/ocr_draft.dart';

/// 사진을 Storage 에 보관하지 않는다. 클라이언트에서 base64 인코딩 후
/// `parseHandwrittenLog` callable 에 인라인으로 전달 → 함수는 OpenAI 호출 후
/// 메모리에서 폐기.
class OcrRepository {
  OcrRepository(this._functions);
  final FirebaseFunctions _functions;

  Future<OcrDraft> uploadAndParse({
    required String familyId,
    required String babyId,
    required File imageFile,
    String? assumedDateKey,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final encoded = base64Encode(bytes);

    final res = await _functions
        .httpsCallable('parseHandwrittenLog')
        .call<Map<String, dynamic>>({
      'familyId': familyId,
      'babyId': babyId,
      'imageBase64': encoded,
      'mimeType': 'image/jpeg',
      if (assumedDateKey != null) 'assumedDate': assumedDateKey,
    });
    return OcrDraft.fromMap(res.data);
  }
}

final ocrRepositoryProvider = Provider<OcrRepository>(
  (ref) => OcrRepository(ref.watch(firebaseFunctionsProvider)),
);
