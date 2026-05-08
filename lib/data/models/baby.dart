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
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final BabyGender gender;
  final String timezone;
  final String? photoUrl;

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
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'birthDate': Timestamp.fromDate(birthDate),
        'gender': _genderTo(gender),
        'timezone': timezone,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
