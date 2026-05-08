import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/ocr_draft.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/ocr_repository.dart';

/// 캡처된 사진 → OCR draft. UI 가 이 상태를 구독하고 Review 화면으로 넘긴다.
class OcrState {
  const OcrState({this.busy = false, this.draft, this.error});
  final bool busy;
  final OcrDraft? draft;
  final String? error;
}

class OcrController extends Notifier<OcrState> {
  @override
  OcrState build() => const OcrState();

  Future<void> uploadAndParse(File image, {String? assumedDateKey}) async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    if (familyId == null || baby == null) {
      state = const OcrState(error: '가족·아기 정보가 필요합니다.');
      return;
    }
    state = const OcrState(busy: true);
    try {
      final draft = await ref.read(ocrRepositoryProvider).uploadAndParse(
            familyId: familyId,
            babyId: baby.id,
            imageFile: image,
            assumedDateKey: assumedDateKey,
          );
      state = OcrState(draft: draft);
    } catch (e) {
      state = OcrState(error: '$e');
    }
  }

  void clear() => state = const OcrState();
}

final ocrControllerProvider =
    NotifierProvider<OcrController, OcrState>(OcrController.new);
