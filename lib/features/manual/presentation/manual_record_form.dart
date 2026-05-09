import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../core/time/day_boundary.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/care_event.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';

/// 수동으로 이벤트를 추가하는 바텀시트.
/// 종류 (수유/기저귀/잠) 선택 → 시간/세부정보 입력 → 저장.
class ManualRecordForm extends ConsumerStatefulWidget {
  const ManualRecordForm({super.key});

  @override
  ConsumerState<ManualRecordForm> createState() => _ManualRecordFormState();
}

class _ManualRecordFormState extends ConsumerState<ManualRecordForm> {
  CareEventType _type = CareEventType.feeding;
  DiaperKind _diaperKind = DiaperKind.pee;
  late DateTime _startAt;
  late DateTime _endAt;
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startAt = now.subtract(const Duration(minutes: 20));
    _endAt = now;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = picked;
        if (_endAt.isBefore(_startAt)) _endAt = _startAt;
      } else {
        _endAt = picked;
        if (_endAt.isBefore(_startAt)) _startAt = _endAt;
      }
    });
  }

  Future<void> _save() async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    if (familyId == null || baby == null || user == null) return;

    setState(() => _saving = true);
    try {
      // 기저귀는 시작=종료
      final start = _startAt;
      final end = _type == CareEventType.diaper ? _startAt : _endAt;
      final amount = _amountCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_amountCtrl.text.trim());

      final event = CareEvent(
        id: newId(),
        type: _type,
        startAt: start,
        endAt: end,
        localDayKey: localDayKey(start, baby.timezone),
        createdByUid: user.uid,
        source: CareEventSource.manual,
        feedingAmountMl: _type == CareEventType.feeding ? amount : null,
        diaperKind: _type == CareEventType.diaper ? _diaperKind : null,
      );

      await ref.read(eventsRepositoryProvider).addEvent(
            familyId: familyId,
            baby: baby,
            event: event,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 추가되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.M.d (E) HH:mm', 'ko_KR');
    final isFeeding = _type == CareEventType.feeding;
    final isDiaper = _type == CareEventType.diaper;
    final isSleep = _type == CareEventType.sleep;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              '기록 추가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text('종류', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<CareEventType>(
              segments: const [
                ButtonSegment(
                    value: CareEventType.feeding,
                    icon: Icon(Icons.local_drink),
                    label: Text('수유')),
                ButtonSegment(
                    value: CareEventType.diaper,
                    icon: Icon(Icons.baby_changing_station),
                    label: Text('기저귀')),
                ButtonSegment(
                    value: CareEventType.sleep,
                    icon: Icon(Icons.bedtime),
                    label: Text('잠')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),

            // 기저귀: 종류 선택
            if (isDiaper) ...[
              const Text('기저귀 종류',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<DiaperKind>(
                segments: const [
                  ButtonSegment(value: DiaperKind.pee, label: Text('소변')),
                  ButtonSegment(value: DiaperKind.poop, label: Text('배변')),
                  ButtonSegment(value: DiaperKind.both, label: Text('둘 다')),
                ],
                selected: {_diaperKind},
                onSelectionChanged: (s) =>
                    setState(() => _diaperKind = s.first),
              ),
              const SizedBox(height: 20),
            ],

            // 시작 시간
            Text(isDiaper ? '시간' : '시작 시간',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(true),
              icon: const Icon(Icons.calendar_today),
              label: Text(fmt.format(_startAt)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                alignment: Alignment.centerLeft,
              ),
            ),

            // 종료 시간 (수유·잠만)
            if (isFeeding || isSleep) ...[
              const SizedBox(height: 16),
              const Text('종료 시간',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDateTime(false),
                icon: const Icon(Icons.calendar_today),
                label: Text(fmt.format(_endAt)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],

            // 분유 양 (수유만)
            if (isFeeding) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
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
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
