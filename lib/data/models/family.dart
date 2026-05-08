import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final DateTime? createdAt;

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Family(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      ownerUid: (d['ownerUid'] as String?) ?? '',
      memberUids: ((d['memberUids'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
