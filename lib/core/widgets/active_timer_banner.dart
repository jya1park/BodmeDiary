import 'dart:async';

import 'package:flutter/material.dart';

import '../time/duration_format.dart';

/// 화면 상단에 떠있는 활성 타이머 배너 (수유중·잠자는중).
/// [pausedAt] 이 null 이면 동작중 (1초 ticker), null 이 아니면 일시정지 (얼어붙음).
/// [pauseAccumMs] 는 누적 일시정지 밀리초.
///
/// 좁은 화면(갤럭시 플립 커버 등, 폭 < 320dp) 에서는 자동으로 세로 레이아웃
/// 으로 전환되어 [종료] 버튼이 항상 보이도록 함.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 320;
          return narrow
              ? _buildNarrow(context, elapsed, paused, canTogglePause)
              : _buildWide(context, elapsed, paused, canTogglePause);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 일반 폭: 좌(아이콘) – 중(타이틀·시계·시작자) – 우(일시정지·종료)
  // ─────────────────────────────────────────────────────
  Widget _buildWide(
    BuildContext context,
    Duration elapsed,
    bool paused,
    bool canTogglePause,
  ) {
    return Row(
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
              _titleRow(paused),
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
          _pauseResumeButton(paused),
          const SizedBox(width: 4),
        ],
        _stopButton(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // 좁은 폭 (Flip 커버 등): 상단 헤더(아이콘·라벨·뱃지·일시정지) + 큰 시계
  //   + 풀폭 [종료] 버튼 — 항상 보임
  // ─────────────────────────────────────────────────────
  Widget _buildNarrow(
    BuildContext context,
    Duration elapsed,
    bool paused,
    bool canTogglePause,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
            ],
            Expanded(child: _titleRow(paused)),
            if (canTogglePause) _pauseResumeButton(paused, compact: true),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            formatTimer(elapsed),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1.0,
            ),
          ),
        ),
        Center(
          child: Text(
            '${widget.startedByName}님 시작',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: widget.color,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('종료',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _titleRow(bool paused) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        if (paused) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _pauseResumeButton(bool paused, {bool compact = false}) {
    final size = compact ? 36.0 : 44.0;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: paused ? '재개' : '일시정지',
        onPressed: paused ? widget.onResume : widget.onPause,
        icon: Icon(
          paused ? Icons.play_arrow : Icons.pause,
          color: Colors.white,
          size: compact ? 20 : 24,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _stopButton() {
    return ElevatedButton(
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
    );
  }
}
