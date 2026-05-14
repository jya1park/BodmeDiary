import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/care_event.dart';
import '../models/ocr_draft.dart';

/// review 화면에서 확정 저장된 이벤트들의 (sourceText → 분류) 패턴을 user 문서에
/// 누적. 다음 OCR 호출에서 함수가 이 패턴을 읽어 프롬프트 보강에 사용한다.
///
/// 데이터 형태: users/{uid}.ocrLearnings.patterns: Array<Pattern>
/// 같은 key (sourceText + type + 서브필드) 가 다시 확정되면 confirmedCount += 1.
class OcrLearningsRepository {
  OcrLearningsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  /// 최대 누적 패턴 수 — 초과 시 confirmedCount 낮은 것부터 제거.
  static const _maxPatterns = 40;

  Future<void> recordConfirmed({
    required String uid,
    required List<LearningEntry> entries,
  }) async {
    if (entries.isEmpty) return;
    final ref = _firestore.doc(FirestorePaths.user(uid));
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final existing = (snap.data()?['ocrLearnings'] as Map?)
                ?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final patternsRaw = (existing['patterns'] as List?) ?? const [];

        final byKey = <String, Map<String, dynamic>>{};
        for (final raw in patternsRaw.whereType<Map>()) {
          final m = raw.cast<String, dynamic>();
          final key = _patternKey(m);
          if (key != null) byKey[key] = m;
        }

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final e in entries) {
          final p = e.toMap();
          final key = _patternKey(p);
          if (key == null) continue;
          final cur = byKey[key];
          if (cur != null) {
            cur['confirmedCount'] = (cur['confirmedCount'] as int? ?? 0) + 1;
            cur['lastSeenMs'] = nowMs;
            if (e.amountMl != null) cur['amountMl'] = e.amountMl;
            if (e.note != null && e.note!.isNotEmpty) cur['note'] = e.note;
          } else {
            p['confirmedCount'] = 1;
            p['lastSeenMs'] = nowMs;
            byKey[key] = p;
          }
        }

        final merged = byKey.values.toList()
          ..sort((a, b) {
            final ca = a['confirmedCount'] as int? ?? 0;
            final cb = b['confirmedCount'] as int? ?? 0;
            return cb.compareTo(ca);
          });
        final clamped = merged.take(_maxPatterns).toList();

        tx.set(
          ref,
          {
            'ocrLearnings': {
              'patterns': clamped,
              'updatedAt': FieldValue.serverTimestamp(),
            }
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      // 학습 실패는 핵심 흐름을 막지 않음.
    }
  }

  /// 같은 sourceText + 활동 종류라도 method/kind 가 다르면 별개 패턴으로 취급.
  static String? _patternKey(Map<String, dynamic> m) {
    final src = (m['sourceText'] as String?)?.trim();
    final type = m['type'] as String?;
    if (src == null || src.isEmpty || type == null) return null;
    final method = (m['method'] as String?) ?? '-';
    final kind = (m['kind'] as String?) ?? '-';
    return '$src|$type|$method|$kind';
  }
}

/// review 화면이 만드는 입력 형태. sourceText + 최종 확정 분류.
class LearningEntry {
  LearningEntry({
    required this.sourceText,
    required this.type,
    this.method,
    this.kind,
    this.amountMl,
    this.note,
  });

  final String sourceText;
  final CareEventType type;
  final String? method;
  final DiaperKind? kind;
  final int? amountMl;
  final String? note;

  Map<String, dynamic> toMap() => {
        'sourceText': sourceText,
        'type': type.name,
        if (method != null) 'method': method,
        if (kind != null) 'kind': kind!.name,
        if (amountMl != null) 'amountMl': amountMl,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

/// OcrParsedEvent + 저장된 CareEvent → 학습 항목. sourceText 가 없는 항목은 무시.
LearningEntry? buildLearningEntry({
  required OcrParsedEvent ocr,
  required CareEvent saved,
}) {
  final src = ocr.sourceText?.trim();
  if (src == null || src.isEmpty) return null;
  // method (breast/formula) 는 현재 CareEvent 모델에 없어 보존되지 않음.
  // 다음 호출에서 모델이 컬럼 어휘로부터 추론하도록 method=null 로 둠.
  return LearningEntry(
    sourceText: src,
    type: saved.type,
    method: null,
    kind: saved.diaperKind,
    amountMl: saved.feedingAmountMl,
    note: saved.note,
  );
}

final ocrLearningsRepositoryProvider = Provider<OcrLearningsRepository>(
  (ref) => OcrLearningsRepository(ref.watch(firestoreProvider)),
);
