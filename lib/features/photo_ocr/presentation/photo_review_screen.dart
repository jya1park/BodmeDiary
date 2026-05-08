import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/time/day_boundary.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/care_event.dart';
import '../../../data/models/ocr_draft.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/family_repository.dart';
import '../application/ocr_controller.dart';

class PhotoReviewScreen extends ConsumerStatefulWidget {
  const PhotoReviewScreen({super.key});

  @override
  ConsumerState<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends ConsumerState<PhotoReviewScreen> {
  final _selected = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(ocrControllerProvider).draft;
    if (draft != null) {
      _selected.addAll(
        draft.events.where((e) => e.confidence >= 0.5).map((e) => e.id),
      );
    }
  }

  Future<void> _save(OcrDraft draft) async {
    final familyId = ref.read(currentFamilyIdProvider);
    final baby = ref.read(currentBabyProvider);
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (familyId == null || baby == null || user == null) return;
    setState(() => _saving = true);

    final picked =
        draft.events.where((e) => _selected.contains(e.id)).toList();
    final events = [
      for (final e in picked)
        CareEvent(
          id: newId(),
          type: e.type,
          startAt: e.startAt,
          endAt: e.endAt,
          localDayKey: localDayKey(e.startAt, baby.timezone),
          createdByUid: user.uid,
          source: CareEventSource.ocr,
          feedingSide: e.feedingSide,
          feedingAmountMl: e.feedingAmountMl,
          diaperKind: e.diaperKind,
          note: e.note,
        ),
    ];
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(ocrControllerProvider).draft;
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('확인')),
        body: const Center(child: Text('분석 결과가 없습니다')),
      );
    }

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
            child: ListView.builder(
              itemCount: draft.events.length,
              itemBuilder: (_, i) {
                final e = draft.events[i];
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
                      ? const Icon(Icons.warning_amber, color: Colors.orange)
                      : Icon(_iconFor(e.type)),
                  tileColor: low ? Colors.amber.withOpacity(0.06) : null,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving || _selected.isEmpty
                    ? null
                    : () => _save(draft),
                child: Text(_saving ? '저장 중...' : '${_selected.length}개 저장'),
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
        final side = switch (e.feedingSide) {
          FeedingSide.leftBreast => '왼쪽',
          FeedingSide.rightBreast => '오른쪽',
          FeedingSide.bottle => '분유',
          FeedingSide.pump => '유축',
          null => '수유',
        };
        return '수유 — $side${e.feedingAmountMl == null ? '' : ' ${e.feedingAmountMl}ml'}';
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
