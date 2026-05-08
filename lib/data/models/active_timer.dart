import 'package:cloud_firestore/cloud_firestore.dart';

import 'care_event.dart';

class ActiveTimer {
  const ActiveTimer({
    required this.type,
    required this.startedAt,
    required this.startedByUid,
    required this.startedByName,
    this.feedingSide,
    this.clientStartedAtMs,
  });

  final CareEventType type; // feeding | sleep
  final DateTime startedAt;
  final String startedByUid;
  final String startedByName;
  final FeedingSide? feedingSide;
  final int? clientStartedAtMs;

  factory ActiveTimer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final meta = (d['metadata'] as Map?)?.cast<String, dynamic>();
    final sideRaw = meta?['side'] as String?;
    return ActiveTimer(
      type: (d['type'] as String?) == 'sleep'
          ? CareEventType.sleep
          : CareEventType.feeding,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(
              (d['clientStartedAtMs'] as num?)?.toInt() ?? 0),
      startedByUid: (d['startedByUid'] as String?) ?? '',
      startedByName: (d['startedByName'] as String?) ?? '',
      feedingSide: sideRaw == null
          ? null
          : FeedingSide.values
              .firstWhere((e) => e.name == sideRaw, orElse: () => FeedingSide.bottle),
      clientStartedAtMs: (d['clientStartedAtMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'type': type.name,
        'startedAt': FieldValue.serverTimestamp(),
        'startedByUid': startedByUid,
        'startedByName': startedByName,
        'metadata': {
          if (feedingSide != null) 'side': feedingSide!.name,
        },
        'clientStartedAtMs': DateTime.now().millisecondsSinceEpoch,
      };
}
