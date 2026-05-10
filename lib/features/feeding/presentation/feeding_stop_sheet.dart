import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/time/duration_format.dart';

/// 수유 종료 시 띄우는 바텀시트.
///
/// 총 수유 시간을 보여주고 (선택) 분유 양을 입력받는다. 비워두면 모유.
/// - 저장: [FeedingStopResult] saved=true (이벤트 생성)
/// - 취소: [FeedingStopResult] cancelled=true (활성 타이머만 삭제, 기록 X)
/// - 사용자가 dismiss(스와이프): null 반환 → 호출부에서 무시 (타이머 유지)
class FeedingStopSheet extends StatefulWidget {
  const FeedingStopSheet({required this.startedAt, super.key});

  final DateTime startedAt;

  @override
  State<FeedingStopSheet> createState() => _FeedingStopSheetState();
}

class FeedingStopResult {
  const FeedingStopResult({
    required this.saved,
    required this.cancelled,
    this.amountMl,
  });

  factory FeedingStopResult.save({int? amountMl}) =>
      FeedingStopResult(saved: true, cancelled: false, amountMl: amountMl);
  factory FeedingStopResult.cancel() =>
      const FeedingStopResult(saved: false, cancelled: true);

  final bool saved;
  final bool cancelled;
  final int? amountMl;
}

class _FeedingStopSheetState extends State<FeedingStopSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final raw = _amount.text.trim();
    final ml = raw.isEmpty ? null : int.tryParse(raw);
    Navigator.of(context).pop(FeedingStopResult.save(amountMl: ml));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수유 기록을 취소할까요?'),
        content: const Text('이번 수유는 저장되지 않고 타이머만 종료됩니다.'),
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
      Navigator.of(context).pop(FeedingStopResult.cancel());
    }
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
            '수유 종료',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFAFA3).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '총 수유 시간',
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
          const SizedBox(height: 20),
          TextField(
            controller: _amount,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: '분유 양 (ml)',
              helperText: '모유였으면 비워두세요',
              suffixText: 'ml',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_drink),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
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
