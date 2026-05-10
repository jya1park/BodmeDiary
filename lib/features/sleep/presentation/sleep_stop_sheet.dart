import 'package:flutter/material.dart';

import '../../../core/time/duration_format.dart';

/// 잠 종료 시 띄우는 바텀시트.
/// - 저장: SleepStopResult(action: save, note: ...)
/// - 취소: SleepStopResult(action: cancel)
/// - dismiss: null
class SleepStopSheet extends StatefulWidget {
  const SleepStopSheet({required this.startedAt, super.key});

  final DateTime startedAt;

  @override
  State<SleepStopSheet> createState() => _SleepStopSheetState();
}

class SleepStopResult {
  const SleepStopResult({required this.action, this.note});
  final SleepStopAction action;
  final String? note;
}

enum SleepStopAction { save, cancel }

class _SleepStopSheetState extends State<SleepStopSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('잠 기록을 취소할까요?'),
        content: const Text('이번 잠은 저장되지 않고 타이머만 종료됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context)
          .pop(const SleepStopResult(action: SleepStopAction.cancel));
    }
  }

  void _save() {
    final n = _note.text.trim();
    Navigator.of(context).pop(SleepStopResult(
      action: SleepStopAction.save,
      note: n.isEmpty ? null : n,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(widget.startedAt);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            '기상',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF7C8DBA).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '총 수면 시간',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatTimer(elapsed),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            maxLength: 200,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              hintText: '특이사항을 적어두세요',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirmCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('취소 (기록 안 함)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
