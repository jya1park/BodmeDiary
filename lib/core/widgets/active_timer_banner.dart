import 'dart:async';

import 'package:flutter/material.dart';

import '../time/duration_format.dart';

/// 화면 상단에 떠있는 활성 타이머 배너 (수유중·잠자는중).
/// [pausedAt] 이 null 이면 동작중 (1초 ticker), null 이 아니면 일시정지 (얼어붙음).
/// [pauseAccumMs] 는 누적 일시정지 밀리초.
class ActiveTimerBanner extends StatefulWidget {
  const ActiveTimerBanner({
    required this.title,
    required this.startedAt,
    required this.startedByName,
    required this.color,
    required this.onStop,
    this.icon,
    this.pausedAt,
    this.pauseAccumMs = 0,
    this.onPause,
    this.onResume,
    super.key,
  });

  final String title;
  final DateTime startedAt;
  final String startedByName;
  final Color color;
  final IconData? icon;
  final VoidCallback onStop;

  // 일시정지 관련 (선택)
  final DateTime? pausedAt;
  final int pauseAccumMs;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  State<ActiveTimerBanner> createState() => _ActiveTimerBannerState();
}

class _ActiveTimerBannerState extends State<ActiveTimerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _restartTickerIfRunning();
  }

  @override
  void didUpdateWidget(covariant ActiveTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasPaused = oldWidget.pausedAt != null;
    final isPaused = widget.pausedAt != null;
    if (wasPaused != isPaused) {
      _restartTickerIfRunning();
    }
  }

  void _restartTickerIfRunning() {
    _ticker?.cancel();
    if (widget.pausedAt == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _effectiveElapsed() {
    final reference = widget.pausedAt ?? DateTime.now();
    final ms = reference.difference(widget.startedAt).inMilliseconds -
        widget.pauseAccumMs;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _effectiveElapsed();
    final paused = widget.pausedAt != null;
    final canTogglePause = widget.onPause != null && widget.onResume != null;

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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (paused) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '일시정지',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatTimer(elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${widget.startedByName}님 시작',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (canTogglePause) ...[
            IconButton(
              tooltip: paused ? '재개' : '일시정지',
              onPressed: paused ? widget.onResume : widget.onPause,
              icon: Icon(
                paused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            onPressed: widget.onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: widget.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('종료',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
