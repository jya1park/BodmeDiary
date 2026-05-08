import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/routes.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/baby_repository.dart';
import '../../../data/repositories/family_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAppUserProvider).valueOrNull;
    final family = ref.watch(currentFamilyStateProvider).valueOrNull;
    final baby = ref.watch(currentBabyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          if (me != null)
            ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    me.photoUrl == null ? null : NetworkImage(me.photoUrl!),
                child: me.photoUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(me.displayName),
              subtitle: Text(me.email),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('가족'),
            subtitle: Text(family?.family?.name ?? '-'),
          ),
          if (family?.family != null)
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('구성원'),
              subtitle: Text('${family!.family!.memberUids.length}명'),
            ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('초대코드 생성'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.familyInvite),
          ),
          const Divider(),
          if (baby != null) ...[
            ListTile(
              leading: const Icon(Icons.child_care),
              title: const Text('아기'),
              subtitle: Text(
                '${baby.name} · ${DateFormat('yyyy.MM.dd').format(baby.birthDate)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.opacity),
              title: const Text('10분당 유축량'),
              subtitle: Text(
                baby.pumpRateMlPer10Min == null
                    ? '미설정 — 입력하면 모유 수유 시간으로 섭취량 예측이 표시됩니다'
                    : '${baby.pumpRateMlPer10Min}ml / 10분',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _editPumpRate(context, ref, baby.id, baby.pumpRateMlPer10Min),
              isThreeLine: baby.pumpRateMlPer10Min == null,
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editPumpRate(
    BuildContext context,
    WidgetRef ref,
    String babyId,
    int? current,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;
    final controller =
        TextEditingController(text: current == null ? '' : '$current');

    final saved = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('10분당 유축량'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '유축할 때 10분 동안 평균적으로 짜내는 양을 ml 로 입력하세요. '
              '이 값을 기준으로 모유 수유 시간 → 섭취량을 추정합니다.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                suffixText: 'ml / 10분',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0), // 0 = 삭제 표식
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim();
              if (raw.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }
              final n = int.tryParse(raw);
              Navigator.of(ctx).pop(n);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (saved == null) return; // 취소
    final newValue = saved == 0 ? null : saved;
    await ref.read(babyRepositoryProvider).updatePumpRate(
          familyId: familyId,
          babyId: babyId,
          pumpRateMlPer10Min: newValue,
        );
  }
}
