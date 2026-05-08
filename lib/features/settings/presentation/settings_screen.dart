import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/routes.dart';
import '../../../data/repositories/auth_repository.dart';
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
          if (baby != null)
            ListTile(
              leading: const Icon(Icons.child_care),
              title: const Text('아기'),
              subtitle: Text(
                '${baby.name} · ${DateFormat('yyyy.MM.dd').format(baby.birthDate)}',
              ),
            ),
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
}
