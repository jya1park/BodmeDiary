import 'care_event.dart';

/// Cloud Function `parseHandwrittenLog` 응답을 그대로 표현.
class OcrDraft {
  const OcrDraft({
    required this.draftId,
    required this.events,
    required this.warnings,
    this.rawText,
  });

  final String draftId;
  final List<OcrParsedEvent> events;
  final List<String> warnings;
  final String? rawText;

  factory OcrDraft.fromMap(Map<String, dynamic> m) => OcrDraft(
        draftId: (m['draftId'] as String?) ?? '',
        events: ((m['events'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => OcrParsedEvent.fromMap(e.cast<String, dynamic>()))
            .toList(growable: false),
        warnings: ((m['warnings'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        rawText: m['rawText'] as String?,
      );
}

class OcrParsedEvent {
  OcrParsedEvent({
    required this.id,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.localDayKey,
    required this.confidence,
    this.feedingSide,
    this.feedingAmountMl,
    this.diaperKind,
    this.note,
    this.sourceText,
    this.suspectedDuplicate = false,
  });

  final String id;
  final CareEventType type;
  DateTime startAt;
  DateTime endAt;
  String localDayKey;
  final double confidence;

  FeedingSide? feedingSide;
  int? feedingAmountMl;
  DiaperKind? diaperKind;
  String? note;
  final String? sourceText;
  bool suspectedDuplicate;

  factory OcrParsedEvent.fromMap(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? 'diaper';
    final startStr = (m['startTime'] as String?) ?? '00:00';
    final endStr = m['endTime'] as String?;
    final dateStr = (m['date'] as String?) ?? _todayKey();

    final startAt = _parseDateTime(dateStr, startStr);
    final endAt = endStr == null
        ? startAt
        : _parseDateTime(dateStr, endStr).isBefore(startAt)
            ? _parseDateTime(dateStr, endStr).add(const Duration(days: 1))
            : _parseDateTime(dateStr, endStr);

    final feeding = (m['feeding'] as Map?)?.cast<String, dynamic>();
    final diaper = (m['diaper'] as Map?)?.cast<String, dynamic>();
    final sleep = (m['sleep'] as Map?)?.cast<String, dynamic>();

    return OcrParsedEvent(
      id: (m['id'] as String?) ?? '',
      type: CareEventType.values
          .firstWhere((e) => e.name == type, orElse: () => CareEventType.diaper),
      startAt: startAt,
      endAt: endAt,
      localDayKey: dateStr,
      confidence: ((m['confidence'] as num?) ?? 0).toDouble(),
      feedingSide: _parseSide(feeding?['side'] as String?),
      feedingAmountMl: (feeding?['amountMl'] as num?)?.toInt(),
      diaperKind: _parseDiaper(diaper?['kind'] as String?),
      note: (diaper?['note'] ?? sleep?['note']) as String?,
      sourceText: m['sourceText'] as String?,
    );
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDateTime(String date, String time) {
    final dp = date.split('-');
    final tp = time.split(':');
    return DateTime(
      int.parse(dp[0]),
      int.parse(dp[1]),
      int.parse(dp[2]),
      int.parse(tp[0]),
      int.parse(tp[1]),
    );
  }

  static FeedingSide? _parseSide(String? s) =>
      s == null ? null : FeedingSide.values.firstWhere(
          (e) => e.name == s, orElse: () => FeedingSide.bottle);

  static DiaperKind? _parseDiaper(String? s) =>
      s == null ? null : DiaperKind.values.firstWhere(
          (e) => e.name == s, orElse: () => DiaperKind.pee);
}
