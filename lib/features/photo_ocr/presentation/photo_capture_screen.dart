import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/routes.dart';
import '../application/ocr_controller.dart';

class PhotoCaptureScreen extends ConsumerWidget {
  const PhotoCaptureScreen({super.key});

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: AppConfig.ocrImageMaxEdge.toDouble(),
      maxHeight: AppConfig.ocrImageMaxEdge.toDouble(),
      imageQuality: 95,
    );
    if (file == null) return;
    await ref.read(ocrControllerProvider.notifier).uploadAndParse(File(file.path));
    if (context.mounted) {
      final state = ref.read(ocrControllerProvider);
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 실패: ${state.error}')),
        );
        return;
      }
      if (state.draft != null) context.push(Routes.photoReview);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ocrControllerProvider).busy;
    return Scaffold(
      appBar: AppBar(title: const Text('사진 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(Icons.photo_camera, size: 80, color: Color(0xFFFFAFA3)),
            const SizedBox(height: 16),
            const Text(
              '손글씨 일지를 촬영하세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'AI 가 수유·기저귀·잠 기록을 자동으로 추출해\n사용자가 확인 후 저장합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const _CaptureTip(
              icon: Icons.wb_sunny_outlined,
              text: '밝은 곳에서 촬영하세요',
            ),
            const SizedBox(height: 8),
            const _CaptureTip(
              icon: Icons.crop_free,
              text: '한 페이지가 화면에 꽉 차게',
            ),
            const SizedBox(height: 8),
            const _CaptureTip(
              icon: Icons.lightbulb_outline,
              text: '그림자가 글자를 가리지 않게',
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy ? null : () => _pick(context, ref, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: Text(busy ? '분석 중...' : '카메라로 촬영'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  busy ? null : () => _pick(context, ref, ImageSource.gallery),
              icon: const Icon(Icons.image),
              label: const Text('갤러리에서 선택'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CaptureTip extends StatelessWidget {
  const _CaptureTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
