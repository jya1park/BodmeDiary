import 'dart:async';

import 'package:flutter/material.dart';

import '../time/duration_format.dart';

/// 30초마다 자동 갱신되는 "X 전" 텍스트.
/// [since] 가 null 이면 [emptyText] (기본: "기록 없음") 표시.
class ElapsedText extends StatefulWidget {
  const ElapsedText({
    required this.since,
    this.prefix = '마지막 ',
    this.suffix,
    this.emptyText = '기록 없음',
    super.key,
  });

  final DateTime? since;
  final String prefix;
  final String? suffix;
  final String emptyText;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    if (since == null) return Text(widget.emptyText);
    final base =
        widget.prefix + formatElapsed(DateTime.now().difference(since));
    final suffix = widget.suffix;
    return Text(suffix == null ? base : '$base · $suffix');
  }
}
