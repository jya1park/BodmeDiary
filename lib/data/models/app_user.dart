import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.familyId,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? familyId;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      displayName: (d['displayName'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      photoUrl: d['photoUrl'] as String?,
      familyId: d['familyId'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'familyId': familyId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
