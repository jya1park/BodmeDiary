import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/time/day_boundary.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/care_event.dart';
import '../../../data/models/ocr_draft.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../../manual/presentation/manual_record_form.dart';
import '../application/ocr_controller.dart';

class PhotoReviewScreen extends ConsumerStatefulWidget {
  const PhotoReviewScreen({super.key});

  @override
  ConsumerState<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

/// 정자(正) 그룹 키: 같은 (type, diaperKind, localDayKey) 끼리 묶는다.
String _tallyGroupKey(OcrParsedEvent e) =>
    '${e.type.name}|${e.diaperKind?.name ?? '-'}|${e.localDayKey}';

class _TallyGroupState {
  bool included = true;

  /// null = 06-24시 균등 분산. non-null = 모두 같은 시각.
  TimeOfDay? singleTime;
}

class _PhotoReviewScreenState extends ConsumerState<PhotoReviewScreen> {
  final _selected = <String>{};
  final _tallyGroups = <String, _TallyGroupState>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(ocrControllerProvider).draft;
    if (draft == null) return;

    // 시각이 있는 일반 이벤트 중 confidence >= 0.5 만 기본 체크.
    _selected.addAll(
      draft.events
          .where((e) => !e.tallyNoTime && e.confidence >= 0.5)
          .map((e) => e.id),
    );

    // 정자(正) 그룹 초기화. 시각 미상이라 기본은 included=true / 분산.
    for (final e in draft.events.where((e) => e.tallyNoTime)) {
      _tallyGroups.putIfAbsent(_tallyGroupKey(e), () => _TallyGroupState());
    }
  }

  Future<void> _save(OcrDraft draft) async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).value;
    if (familyId == null || baby == null || user == null) return;
    setState(() => _saving = true);

    final events = <CareEvent>[];

    // 1) 시각이 명확한 일반 이벤트들.
    final picked = draft.events
        .where((e) => !e.tallyNoTime && _selected.contains(e.id))
        .toList();
    for (final e in picked) {
      events.add(
        CareEvent(
          id: newId(),
          type: e.type,
          startAt: e.startAt,
          endAt: e.endAt,
          localDayKey: localDayKey(e.startAt, baby.timezone),
          createdByUid: user.uid,
          source: CareEventSource.ocr,
          feedingAmountMl: e.feedingAmountMl,
          diaperKind: e.diaperKind,
          note: e.note,
        ),
      );
    }

    // 2) 정자(正) 그룹: 시각을 분산하거나 같은 시각으로 일괄 저장.
    final tallyByGroup = <String, List<OcrParsedEvent>>{};
    for (final e in draft.events.where((e) => e.tallyNoTime)) {
      tallyByGroup.putIfAbsent(_tallyGroupKey(e), () => []).add(e);
    }
    for (final entry in tallyByGroup.entries) {
      final state = _tallyGroups[entry.key];
      if (state == null || !state.included) continue;
      final list = entry.value;
      final n = list.length;
      for (var i = 0; i < n; i++) {
        final src = list[i];
        final base = DateTime(
          src.startAt.year,
          src.startAt.month,
          src.startAt.day,
        );
        DateTime when;
        if (state.singleTime != null) {
          when = base.add(Duration(
            hours: state.singleTime!.hour,
            minutes: state.singleTime!.minute,
          ));
        } else {
          // 06:00~23:00 (17시간 = 1020분) 사이 균등 분산.
          final minutes = n == 1 ? 720 : (360 + (1020 * i) ~/ (n - 1));
          when = base.add(Duration(minutes: minutes));
        }
        events.add(
          CareEvent(
            id: newId(),
            type: src.type,
            startAt: when,
            endAt: when,
            localDayKey: localDayKey(when, baby.timezone),
            createdByUid: user.uid,
            source: CareEventSource.ocr,
            feedingAmountMl: src.feedingAmountMl,
            diaperKind: src.diaperKind,
            note: src.note,
          ),
        );
      }
    }

    if (events.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 기록이 선택되지 않았어요')),
      );
      return;
    }

    try {
      await ref
          .read(eventsRepositoryProvider)
          .addEvents(familyId: familyId, baby: baby, events: events);
      ref.read(ocrControllerProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${events.length}개 이벤트를 저장했습니다')),
        );
        context.pop();
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

  Future<void> _openManualForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ManualRecordForm(),
    );
  }

  int _plannedSaveCount(OcrDraft draft) {
    var n = _selected.length;
    final tallyByGroup = <String, int>{};
    for (final e in draft.events.where((e) => e.tallyNoTime)) {
      tallyByGroup.update(_tallyGroupKey(e), (v) => v + 1, ifAbsent: () => 1);
    }
    for (final entry in tallyByGroup.entries) {
      if (_tallyGroups[entry.key]?.included ?? false) n += entry.value;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(ocrControllerProvider).draft;
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('확인')),
        body: const Center(child: Text('분석 결과가 없습니다')),
      );
    }

    final tally = draft.events.where((e) => e.tallyNoTime).toList();
    final regular = draft.events.where((e) => !e.tallyNoTime).toList();
    final isEmpty = draft.events.isEmpty;
    final saveCount = _plannedSaveCount(draft);

    return Scaffold(
      appBar: AppBar(title: const Text('인식 결과 확인')),
      body: Column(
        children: [
          if (draft.warnings.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: Text('⚠ ${draft.warnings.join(", ")}'),
            ),
          Expanded(
            child: isEmpty
                ? _EmptyResult(
                    rawText: draft.rawText,
                    onManual: _openManualForm,
                    onRetake: () => context.pop(),
                  )
                : ListView(
                    children: [
                      if (tally.isNotEmpty)
                        _TallySection(
                          events: tally,
                          groupState: _tallyGroups,
                          groupKey: _tallyGroupKey,
                          onChanged: () => setState(() {}),
                        ),
                      ...regular.map((e) {
                        final low = e.confidence < 0.5;
                        return CheckboxListTile(
                          value: _selected.contains(e.id),
                          onChanged: (v) => setState(() {
                            if (v ?? false) {
                              _selected.add(e.id);
                            } else {
                              _selected.remove(e.id);
                            }
                          }),
                          title: Text(_describe(e)),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(e.startAt)}'
                            '${e.endAt == e.startAt ? '' : ' – ${DateFormat('HH:mm').format(e.endAt)}'}'
                            ' · 신뢰도 ${(e.confidence * 100).round()}%',
                          ),
                          secondary: low
                              ? const Icon(Icons.warning_amber,
                                  color: Colors.orange)
                              : Icon(_iconFor(e.type)),
                          tileColor: low ? Colors.amber.withOpacity(0.06) : null,
                        );
                      }),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isEmpty
                  ? const SizedBox.shrink()
                  : FilledButton(
                      onPressed: _saving || saveCount == 0
                          ? null
                          : () => _save(draft),
                      child: Text(_saving ? '저장 중...' : '$saveCount개 저장'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _describe(OcrParsedEvent e) {
    switch (e.type) {
      case CareEventType.feeding:
        return e.feedingAmountMl == null
            ? '수유 (모유)'
            : '수유 (분유 ${e.feedingAmountMl}ml)';
      case CareEventType.diaper:
        final kind = switch (e.diaperKind) {
          DiaperKind.pee => '소변',
          DiaperKind.poop => '배변',
          DiaperKind.both => '둘 다',
          null => '기저귀',
        };
        return '기저귀 — $kind';
      case CareEventType.sleep:
        return '잠';
    }
  }

  IconData _iconFor(CareEventType t) => switch (t) {
        CareEventType.feeding => Icons.local_drink,
        CareEventType.diaper => Icons.baby_changing_station,
        CareEventType.sleep => Icons.bedtime,
      };
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({
    required this.rawText,
    required this.onManual,
    required this.onRetake,
  });

  final String? rawText;
  final VoidCallback onManual;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final hasRaw = rawText != null && rawText!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '추출된 이벤트가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hasRaw
                ? '사진에서 글자는 읽혔지만 수유/기저귀/잠 기록으로\n인식되지 않았어요. 직접 기록하거나 다시 촬영해보세요.'
                : '사진이 흐릿하거나 글자가 잘 안 보일 수 있어요.\n다시 촬영하거나 직접 기록하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasRaw) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '사진에서 읽힌 글자',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    rawText!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.edit_note),
            label: const Text('직접 기록 추가'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetake,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 촬영'),
          ),
        ],
      ),
    );
  }
}

class _TallySection extends StatelessWidget {
  const _TallySection({
    required this.events,
    required this.groupState,
    required this.groupKey,
    required this.onChanged,
  });

  final List<OcrParsedEvent> events;
  final Map<String, _TallyGroupState> groupState;
  final String Function(OcrParsedEvent) groupKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OcrParsedEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(groupKey(e), () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '정자(正)로 횟수만 적힌 기록',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '시각이 없어서 추정으로 분산 저장합니다. 필요하면 같은 시각으로도 일괄 저장할 수 있어요.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final entry in groups.entries)
          _TallyGroupCard(
            label: _groupLabel(entry.value.first, entry.value.length),
            sourceText: entry.value.first.sourceText,
            state: groupState[entry.key]!,
            onChanged: onChanged,
          ),
        const Divider(height: 24),
      ],
    );
  }

  String _groupLabel(OcrParsedEvent sample, int count) {
    switch (sample.type) {
      case CareEventType.feeding:
        return '수유 $count회';
      case CareEventType.diaper:
        final kind = switch (sample.diaperKind) {
          DiaperKind.pee => '소변',
          DiaperKind.poop => '배변',
          DiaperKind.both => '둘 다',
          null => '기저귀',
        };
        return '기저귀($kind) $count회';
      case CareEventType.sleep:
        return '잠 $count회';
    }
  }
}

class _TallyGroupCard extends StatelessWidget {
  const _TallyGroupCard({
    required this.label,
    required this.sourceText,
    required this.state,
    required this.onChanged,
  });

  final String label;
  final String? sourceText;
  final _TallyGroupState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final timeStr = state.singleTime == null
        ? '06–23시 균등 분산'
        : '모두 ${state.singleTime!.format(context)}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: state.included,
              onChanged: (v) {
                state.included = v ?? false;
                onChanged();
              },
              title: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(timeStr),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (state.included) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('균등 분산'),
                      selected: state.singleTime == null,
                      onSelected: (_) {
                        state.singleTime = null;
                        onChanged();
                      },
                    ),
                    ChoiceChip(
                      label: Text(state.singleTime == null
                          ? '같은 시각으로'
                          : '시각: ${state.singleTime!.format(context)}'),
                      selected: state.singleTime != null,
                      onSelected: (_) async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: state.singleTime ??
                              const TimeOfDay(hour: 12, minute: 0),
                        );
                        if (picked != null) {
                          state.singleTime = picked;
                          onChanged();
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (sourceText != null && sourceText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '원문: $sourceText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
