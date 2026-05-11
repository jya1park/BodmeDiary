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
///
/// [durationMs] 는 명시적 실효 시간(밀리초). null 로 생성하면 endAt-startAt 로
/// 자동 계산되지만, 30분 머지 윈도우로 합쳐진 수유의 경우 startAt~endAt 의
/// 전체 span 이 아니라 실제 수유 시간만의 합이 저장된다.
class CareEvent {
  CareEvent({
    required this.id,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.localDayKey,
    required this.createdByUid,
    required this.source,
    int? durationMs,
    this.feedingAmountMl,
    this.diaperKind,
    this.note,
  }) : durationMs = durationMs ?? endAt.difference(startAt).inMilliseconds;

  final String id;
  final CareEventType type;
  final DateTime startAt;
  final DateTime endAt;
  final String localDayKey;
  final String createdByUid;
  final CareEventSource source;
  final int durationMs;
  final int? feedingAmountMl;
  final DiaperKind? diaperKind;
  final String? note;

  Duration get duration => Duration(milliseconds: durationMs);

  factory CareEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final feeding = (d['feeding'] as Map?)?.cast<String, dynamic>();
    final diaper = (d['diaper'] as Map?)?.cast<String, dynamic>();
    final sleep = (d['sleep'] as Map?)?.cast<String, dynamic>();
    final start =
        (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final end = (d['endAt'] as Timestamp?)?.toDate() ?? start;
    return CareEvent(
      id: doc.id,
      type: _typeFrom((d['type'] as String?) ?? 'diaper'),
      startAt: start,
      endAt: end,
      localDayKey: (d['localDayKey'] as String?) ?? '',
      createdByUid: (d['createdByUid'] as String?) ?? '',
      source: _sourceFrom(d['source'] as String?),
      durationMs: (d['durationMs'] as num?)?.toInt(),
      feedingAmountMl: (feeding?['amountMl'] as num?)?.toInt(),
      diaperKind: _diaperFrom(diaper?['kind'] as String?),
      note: (feeding?['note'] ?? diaper?['note'] ?? sleep?['note']) as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    final m = <String, dynamic>{
      'type': type.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'durationMs': durationMs,
      'localDayKey': localDayKey,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'source': source.name,
    };
    if (type == CareEventType.feeding) {
      m['feeding'] = {
        if (feedingAmountMl != null) 'amountMl': feedingAmountMl,
        if (note != null) 'note': note,
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
