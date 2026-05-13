import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../core/time/day_boundary.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/care_event.dart';
import '../../../data/models/feeding_note.dart';
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
  final _noteCtrl = TextEditingController();
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
      // 수유는 세션 로그가 합쳐진 note 일 수 있으므로 사용자 메모만 분리해서 프리필
      if (existing.note != null) {
        if (existing.type == CareEventType.feeding) {
          final parts = parseFeedingNote(existing.note);
          if (parts.userNote != null) _noteCtrl.text = parts.userNote!;
        } else {
          _noteCtrl.text = existing.note!;
        }
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
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<bool?> _askMergeConfirmation(CareEvent candidate) async {
    final fmt = DateFormat('M월 d일 HH:mm');
    final candidateRange =
        '${fmt.format(candidate.startAt)} – ${DateFormat('HH:mm').format(candidate.endAt)}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('한 회로 합칠까요?'),
        content: Text(
          '30분 이내에 다음 수유 기록이 있습니다.\n\n'
          '$candidateRange\n\n'
          '합치면 두 기록이 하나로 묶이고, 메모에 각 세션 시간이 누적됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('별도 기록'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('합치기'),
          ),
        ],
      ),
    );
  }

  /// 시간만 변경 (날짜 유지). TimePicker.input 모드 → 키보드로 직접 HH:MM 입력.
  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startAt : _endAt;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (time == null) return;
    final picked = DateTime(
      initial.year,
      initial.month,
      initial.day,
      time.hour,
      time.minute,
    );
    _applyTimeChange(isStart, picked);
  }

  /// 날짜만 변경 (시간 유지).
  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
    _applyTimeChange(isStart, picked);
  }

  /// ±N분 빠른 조정.
  void _nudge(bool isStart, int minutes) {
    final base = isStart ? _startAt : _endAt;
    _applyTimeChange(isStart, base.add(Duration(minutes: minutes)));
  }

  void _applyTimeChange(bool isStart, DateTime newValue) {
    setState(() {
      if (isStart) {
        _startAt = newValue;
        if (_endAt.isBefore(_startAt)) _endAt = _startAt;
      } else {
        _endAt = newValue;
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
      final noteText = _noteCtrl.text.trim();
      final userNote = noteText.isEmpty ? null : noteText;

      // 수유 편집은 기존 세션 로그 + 새 사용자 메모로 다시 빌드
      String? note;
      if (_type == CareEventType.feeding && _isEdit) {
        final existingParts = parseFeedingNote(widget.existing!.note);
        note = buildFeedingNote(existingParts.sessions, userNote);
      } else {
        note = userNote;
      }

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
          note: note,
        );

        // 수유 편집 — 30분 안에 다른 수유 있으면 다이얼로그로 머지 확인
        if (_type == CareEventType.feeding) {
          final candidate =
              await ref.read(eventsRepositoryProvider).findFeedingMergeCandidate(
                    familyId: familyId,
                    babyId: baby.id,
                    event: updated,
                  );
          if (candidate != null && mounted) {
            final shouldMerge = await _askMergeConfirmation(candidate);
            if (shouldMerge == true) {
              // candidate 에 흡수 — updated 의 in-memory 값이 그대로 반영됨
              // (mergeTwoFeedings 가 absorbed 문서를 batch 삭제)
              await ref.read(eventsRepositoryProvider).mergeTwoFeedings(
                    familyId: familyId,
                    babyId: baby.id,
                    target: candidate,
                    absorbed: updated,
                  );
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('두 수유 기록이 합쳐졌습니다')),
                );
              }
              return;
            }
            // 아니오 → 일반 update 로 진행
          }
        }

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
          note: note,
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
            _TimeFieldRow(
              label: isDiaper ? '시간' : '시작 시간',
              value: _startAt,
              dateFormat: fmt,
              onTapTime: () => _pickTime(true),
              onTapDate: () => _pickDate(true),
              onNudge: (m) => _nudge(true, m),
            ),
            if (isFeeding || isSleep) ...[
              const SizedBox(height: 12),
              _TimeFieldRow(
                label: '종료 시간',
                value: _endAt,
                dateFormat: fmt,
                onTapTime: () => _pickTime(false),
                onTapDate: () => _pickDate(false),
                onNudge: (m) => _nudge(false, m),
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
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
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
            const SizedBox(height: 8),
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

/// 시간 입력 행: 라벨 + (시간 버튼 + 달력 아이콘) + (-5/-1/+1/+5분 빠른 조정).
class _TimeFieldRow extends StatelessWidget {
  const _TimeFieldRow({
    required this.label,
    required this.value,
    required this.dateFormat,
    required this.onTapTime,
    required this.onTapDate,
    required this.onNudge,
  });

  final String label;
  final DateTime value;
  final DateFormat dateFormat;
  final VoidCallback onTapTime;
  final VoidCallback onTapDate;
  final void Function(int minutes) onNudge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onTapTime,
                icon: const Icon(Icons.access_time),
                label: Text(
                  dateFormat.format(value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              height: 44,
              child: OutlinedButton(
                onPressed: onTapDate,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.calendar_month, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final m in const [-5, -1, 1, 5]) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onNudge(m),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    m > 0 ? '+$m분' : '$m분',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (m != 5) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}
