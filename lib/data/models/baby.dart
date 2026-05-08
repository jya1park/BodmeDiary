import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_config.dart';

enum BabyGender { male, female, other }

BabyGender _genderFrom(String? s) {
  switch (s) {
    case 'male':
      return BabyGender.male;
    case 'female':
      return BabyGender.female;
    default:
      return BabyGender.other;
  }
}

String _genderTo(BabyGender g) => g.name;

class Baby {
  const Baby({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.timezone,
    this.photoUrl,
    this.pumpRateMlPer10Min,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final BabyGender gender;
  final String timezone;
  final String? photoUrl;

  /// 10분당 유축량 (ml). 모유 수유 시간 → 추정 섭취량 계산에 사용.
  /// null 이면 예측 표시를 숨긴다.
  final int? pumpRateMlPer10Min;

  factory Baby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Baby(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      birthDate:
          (d['birthDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: _genderFrom(d['gender'] as String?),
      timezone:
          (d['timezone'] as String?) ?? AppConfig.defaultBabyTimezone,
      photoUrl: d['photoUrl'] as String?,
      pumpRateMlPer10Min: (d['pumpRateMlPer10Min'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'birthDate': Timestamp.fromDate(birthDate),
        'gender': _genderTo(gender),
        'timezone': timezone,
        'photoUrl': photoUrl,
        if (pumpRateMlPer10Min != null)
          'pumpRateMlPer10Min': pumpRateMlPer10Min,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// 모유 수유 시간으로부터 아기가 먹은 양을 추정.
/// 유축 속도(10분당 ml) 기반의 단순 비례식: ml = duration * rate / 10min.
/// [pumpRatePer10Min] 이 null/0 이거나 [duration] 이 0 이면 null.
int? estimateBreastMilkMl(Duration duration, int? pumpRatePer10Min) {
  if (pumpRatePer10Min == null || pumpRatePer10Min <= 0) return null;
  final minutes = duration.inSeconds / 60.0;
  if (minutes <= 0) return null;
  final ml = (minutes / 10.0) * pumpRatePer10Min;
  return ml.round();
}
