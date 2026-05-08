import 'dart:async';

import 'package:flutter/material.dart';

import '../time/duration_format.dart';

/// 화면 상단에 떠있는 활성 타이머 배너 (수유중·잠자는중).
class ActiveTimerBanner extends StatefulWidget {
  const ActiveTimerBanner({
    required this.title,
    required this.startedAt,
    required this.startedByName,
    required this.color,
    required this.onStop,
    this.icon,
    super.key,
  });

  final String title;
  final DateTime startedAt;
  final String startedByName;
  final Color color;
  final IconData? icon;
  final VoidCallback onStop;

  @override
  State<ActiveTimerBanner> createState() => _ActiveTimerBannerState();
}

class _ActiveTimerBannerState extends State<ActiveTimerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Container(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${formatTimer(elapsed)} · ${widget.startedByName}님 시작',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: widget.onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: widget.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('종료', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
