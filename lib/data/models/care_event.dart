import 'package:cloud_firestore/cloud_firestore.dart';

enum CareEventType { feeding, diaper, sleep }

enum DiaperKind { pee, poop, both }

enum CareEventSource { manual, ocr, timer }

CareEventType _typeFrom(String s) =>
    CareEventType.values.firstWhere((e) => e.name == s,
        orElse: () => CareEventType.diaper);
DiaperKind? _diaperFrom(String? s) =>
    s == null ? null : DiaperKind.values.firstWhere((e) => e.name == s,
        orElse: () => DiaperKind.pee);
CareEventSource _sourceFrom(String? s) =>
    CareEventSource.values.firstWhere((e) => e.name == s,
        orElse: () => CareEventSource.manual);

/// Firestore `events/*` 단일 문서 모델. 타입에 따라 일부 필드만 의미를 가진다.
///
/// 수유는 좌/우 구분이 없고 시간(startAt~endAt) 만 기록한다. [feedingAmountMl]
/// 가 지정되면 분유 수유, 비어있으면 모유로 본다.
class CareEvent {
  const CareEvent({
    required this.id,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.localDayKey,
    required this.createdByUid,
    required this.source,
    this.feedingAmountMl,
    this.diaperKind,
    this.note,
    this.ocrPhotoPath,
  });

  final String id;
  final CareEventType type;
  final DateTime startAt;
  final DateTime endAt;
  final String localDayKey;
  final String createdByUid;
  final CareEventSource source;
  final int? feedingAmountMl;
  final DiaperKind? diaperKind;
  final String? note;
  final String? ocrPhotoPath;

  Duration get duration => endAt.difference(startAt);

  factory CareEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final feeding = (d['feeding'] as Map?)?.cast<String, dynamic>();
    final diaper = (d['diaper'] as Map?)?.cast<String, dynamic>();
    final sleep = (d['sleep'] as Map?)?.cast<String, dynamic>();
    return CareEvent(
      id: doc.id,
      type: _typeFrom((d['type'] as String?) ?? 'diaper'),
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate() ??
          (d['startAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      localDayKey: (d['localDayKey'] as String?) ?? '',
      createdByUid: (d['createdByUid'] as String?) ?? '',
      source: _sourceFrom(d['source'] as String?),
      feedingAmountMl: (feeding?['amountMl'] as num?)?.toInt(),
      diaperKind: _diaperFrom(diaper?['kind'] as String?),
      note: (diaper?['note'] ?? sleep?['note']) as String?,
      ocrPhotoPath: d['ocrPhotoPath'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    final m = <String, dynamic>{
      'type': type.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'durationMs': endAt.difference(startAt).inMilliseconds,
      'localDayKey': localDayKey,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'source': source.name,
      if (ocrPhotoPath != null) 'ocrPhotoPath': ocrPhotoPath,
    };
    if (type == CareEventType.feeding) {
      m['feeding'] = {
        if (feedingAmountMl != null) 'amountMl': feedingAmountMl,
      };
    } else if (type == CareEventType.diaper) {
      m['diaper'] = {
        if (diaperKind != null) 'kind': diaperKind!.name,
        if (note != null) 'note': note,
      };
    } else if (type == CareEventType.sleep) {
      m['sleep'] = {
        if (note != null) 'note': note,
      };
    }
    return m;
  }
}
