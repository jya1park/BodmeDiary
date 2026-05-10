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

/// 수동 기록 추가/편집 바텀시트.
/// [existing] 이 있으면 편집 모드 (기존 값으로 프리필 + updateEvent 호출).
/// 없으면 신규 추가 모드 (수유는 30분 머지 윈도우 적용).
class ManualRecordForm extends ConsumerStatefulWidget {
  const ManualRecordForm({super.key, this.existing});

  final CareEvent? existing;

  @override
  ConsumerState<ManualRecordForm> createState() => _ManualRecordFormState();
}

class _ManualRecordFormState extends ConsumerState<ManualRecordForm> {
  late CareEventType _type;
  late DiaperKind _diaperKind;
  late DateTime _startAt;
  late DateTime _endAt;
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _type = existing.type;
      _startAt = existing.startAt;
      _endAt = existing.endAt;
      _diaperKind = existing.diaperKind ?? DiaperKind.pee;
      if (existing.feedingAmountMl != null) {
        _amountCtrl.text = '${existing.feedingAmountMl}';
      }
    } else {
      _type = CareEventType.feeding;
      _diaperKind = DiaperKind.pee;
      final now = DateTime.now();
      _startAt = now.subtract(const Duration(minutes: 20));
      _endAt = now;
    }
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
      final start = _startAt;
      final end = _type == CareEventType.diaper ? _startAt : _endAt;
      final amount = _amountCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_amountCtrl.text.trim());

      if (_isEdit) {
        // 편집 — 동일 ID 유지
        final updated = CareEvent(
          id: widget.existing!.id,
          type: _type,
          startAt: start,
          endAt: end,
          localDayKey: localDayKey(start, baby.timezone),
          createdByUid: widget.existing!.createdByUid,
          source: widget.existing!.source,
          feedingAmountMl: _type == CareEventType.feeding ? amount : null,
          diaperKind: _type == CareEventType.diaper ? _diaperKind : null,
        );
        await ref.read(eventsRepositoryProvider).updateEvent(
              familyId: familyId,
              babyId: baby.id,
              event: updated,
            );
      } else {
        // 신규 — 수유는 30분 머지 윈도우 적용
        final created = CareEvent(
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
        if (_type == CareEventType.feeding) {
          await ref.read(eventsRepositoryProvider).addOrMergeFeeding(
                familyId: familyId,
                baby: baby,
                event: created,
              );
        } else {
          await ref.read(eventsRepositoryProvider).addEvent(
                familyId: familyId,
                baby: baby,
                event: created,
              );
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? '수정되었습니다' : '기록이 추가되었습니다')),
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
            Text(
              _isEdit ? '기록 편집' : '기록 추가',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              child: Text(_saving
                  ? '저장 중...'
                  : (_isEdit ? '수정' : '저장')),
            ),
          ],
        ),
      ),
    );
  }
}
