import 'package:flutter/material.dart';

/// 홈 화면의 큰 액션 버튼 (수유·기저귀·잠).
/// [onLongPress] 가 있으면 길게 누르기로 추가 동작 (예: 기록 편집).
/// [progress] (0.0–1.0) 가 있으면 하→상 으로 채움 애니메이션 (예: 오늘 누적 진척도).
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
        // progress 가 있을 때는 본체를 흐리게 → 채워진 부분이 진하게 대비
        color: color.withValues(alpha: filled == null ? 1.0 : 0.45),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // 1) 하→상 세로 채움
              if (filled != null && filled > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: filled),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => FractionallySizedBox(
                        heightFactor: v,
                        widthFactor: 1.0,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ),
                ),
              // 2) 콘텐츠
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 40, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 8),
                            DefaultTextStyle(
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.white, size: 32),
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
