import 'package:flutter/material.dart';

/// 홈 화면의 큰 액션 버튼 (수유·기저귀·잠).
/// [onLongPress] 가 있으면 길게 누르기로 추가 동작 (예: 기록 편집).
/// [progress] (0.0–1.0) 가 있으면 좌→우 채움 애니메이션 (예: 오늘 누적 진척도).
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.subtitle,
    this.progress,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Widget? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final filled = progress?.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: color.withValues(alpha: filled == null ? 1.0 : 0.55),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              if (filled != null && filled > 0)
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment.centerLeft,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: MediaQuery.of(context).size.width * filled,
                      color: color,
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            DefaultTextStyle(
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.white, size: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
