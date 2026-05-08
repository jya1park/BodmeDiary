import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/day_boundary.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';

class DiaperModal extends ConsumerWidget {
  const DiaperModal({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    DiaperKind kind,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (familyId == null || baby == null || user == null) return;

    final now = DateTime.now();
    final event = CareEvent(
      id: newId(),
      type: CareEventType.diaper,
      startAt: now,
      endAt: now,
      localDayKey: localDayKey(now, baby.timezone),
      createdByUid: user.uid,
      source: CareEventSource.manual,
      diaperKind: kind,
    );
    await ref.read(eventsRepositoryProvider).addEvent(
          familyId: familyId,
          baby: baby,
          event: event,
        );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '기저귀 종류 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF82B4FF),
              label: '소변',
              onTap: () => _save(context, ref, DiaperKind.pee),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.eco_outlined,
              color: const Color(0xFFB48656),
              label: '배변',
              onTap: () => _save(context, ref, DiaperKind.poop),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.swap_horiz,
              color: const Color(0xFFFFCD78),
              label: '둘 다',
              onTap: () => _save(context, ref, DiaperKind.both),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
