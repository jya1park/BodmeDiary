import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/time/duration_format.dart';

/// 수유 종료 시 띄우는 바텀시트.
///
/// 총 수유 시간을 보여주고 (선택) 분유 양을 입력받는다. 비워두면 모유.
/// 사용자가 [Navigator.pop] 으로 닫으면 [FeedingStopResult.cancelled] 반환,
/// 저장 버튼을 누르면 [FeedingStopResult.saved] 와 입력한 ml 값을 반환한다.
class FeedingStopSheet extends StatefulWidget {
  const FeedingStopSheet({required this.startedAt, super.key});

  final DateTime startedAt;

  @override
  State<FeedingStopSheet> createState() => _FeedingStopSheetState();
}

class FeedingStopResult {
  const FeedingStopResult({required this.saved, this.amountMl});
  final bool saved;
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
    Navigator.of(context).pop(FeedingStopResult(saved: true, amountMl: ml));
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
              color: const Color(0xFFFFAFA3).withOpacity(0.12),
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
          FilledButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
