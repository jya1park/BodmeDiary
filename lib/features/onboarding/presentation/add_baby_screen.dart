import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';

import '../../../data/models/baby.dart';
import '../../../data/repositories/baby_repository.dart';
import '../../../data/repositories/family_repository.dart';

class AddBabyScreen extends ConsumerStatefulWidget {
  const AddBabyScreen({super.key});

  @override
  ConsumerState<AddBabyScreen> createState() => _AddBabyScreenState();
}

class _AddBabyScreenState extends ConsumerState<AddBabyScreen> {
  final _name = TextEditingController();
  DateTime _birth = DateTime.now();
  BabyGender _gender = BabyGender.other;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      helpText: '출생일 선택',
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final familyId = ref.read(currentFamilyIdProvider);
    if (name.isEmpty || familyId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(babyRepositoryProvider).createBaby(
            familyId: familyId,
            name: name,
            birthDate: _birth,
            gender: _gender,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아기 등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy년 M월 d일', 'ko_KR').format(_birth);

    return Scaffold(
      appBar: AppBar(title: const Text('아기 등록')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text('이름', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: '예: 보미',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('출생일', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(dateText),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 24),
              const Text('성별', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<BabyGender>(
                segments: const [
                  ButtonSegment(value: BabyGender.male, label: Text('남아')),
                  ButtonSegment(value: BabyGender.female, label: Text('여아')),
                  ButtonSegment(value: BabyGender.other, label: Text('비공개')),
                ],
                selected: {_gender},
                onSelectionChanged: (s) => setState(() => _gender = s.first),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '저장 중...' : '시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
