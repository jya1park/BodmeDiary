import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/family_repository.dart';

class FamilyInviteScreen extends ConsumerStatefulWidget {
  const FamilyInviteScreen({super.key});

  @override
  ConsumerState<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _FamilyInviteScreenState extends ConsumerState<FamilyInviteScreen> {
  String? _code;
  DateTime? _expiresAt;
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(familyRepositoryProvider).createInviteCode(familyId);
      setState(() {
        _code = res.code;
        _expiresAt = res.expiresAt;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: const Text('초대코드')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              if (code == null) ...[
                const Text(
                  '6자리 코드를 만들어 가족에게 공유하세요. 24시간 동안 유효해요.',
                  style: TextStyle(fontSize: 15),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _generate,
                  child: Text(_busy ? '생성 중...' : '코드 생성'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ] else ...[
                Center(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_expiresAt != null)
                  Center(
                    child: Text(
                      '${_expiresAt!.toLocal()} 까지 유효',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('복사되었습니다')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('복사'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Share.share(
                          '보미다이어리 가족 초대코드: $code\n'
                          '앱에서 [초대코드 입력] 으로 합류하세요.',
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('공유'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
