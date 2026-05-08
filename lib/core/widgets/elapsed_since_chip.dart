import 'dart:async';

import 'package:flutter/material.dart';

import '../time/duration_format.dart';

/// "마지막 수유 1시간 23분 전" 처럼 1초 단위로 자동 갱신되는 칩.
class ElapsedSinceChip extends StatefulWidget {
  const ElapsedSinceChip({
    required this.label,
    required this.since,
    this.icon,
    super.key,
  });

  final String label;
  final DateTime? since;
  final IconData? icon;

  @override
  State<ElapsedSinceChip> createState() => _ElapsedSinceChipState();
}

class _ElapsedSinceChipState extends State<ElapsedSinceChip> {
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
    final scheme = Theme.of(context).colorScheme;
    final text = since == null
        ? '기록 없음'
        : formatElapsed(DateTime.now().difference(since));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
