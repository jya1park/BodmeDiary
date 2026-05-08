import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/care_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/timer_repository.dart';

class FeedingStartModal extends ConsumerWidget {
  const FeedingStartModal({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    FeedingSide side,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (familyId == null || baby == null || user == null) return;

    final ok = await ref.read(timerRepositoryProvider).startTimer(
          familyId: familyId,
          baby: baby,
          type: CareEventType.feeding,
          startedByUid: user.uid,
          startedByName: user.displayName,
          feedingSide: side,
        );
    if (context.mounted) {
      Navigator.of(context).pop();
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 시작된 수유 타이머가 있어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = const [
      (FeedingSide.leftBreast, Icons.chevron_left, '왼쪽', Color(0xFFFFAFA3)),
      (FeedingSide.rightBreast, Icons.chevron_right, '오른쪽', Color(0xFFFF9183)),
      (FeedingSide.bottle, Icons.local_drink, '분유', Color(0xFFFFCD78)),
      (FeedingSide.pump, Icons.opacity, '유축', Color(0xFFB28BD9)),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '수유 종류 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (final o in options)
                  _SideTile(
                    icon: o.$2,
                    label: o.$3,
                    color: o.$4,
                    onTap: () => _start(context, ref, o.$1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
