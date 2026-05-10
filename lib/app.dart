import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/routing/app_router.dart';
import 'core/theme.dart';
import 'data/models/active_timer.dart';
import 'data/repositories/timer_repository.dart';

class BodmeDiaryApp extends ConsumerWidget {
  const BodmeDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // 수유 활성 타이머가 있는 동안 화면이 꺼지지 않도록 wakelock 토글
    ref.listen<AsyncValue<ActiveTimer?>>(
      activeFeedingTimerProvider,
      (prev, next) {
        final wasActive = prev?.value != null;
        final isActive = next.value != null;
        if (wasActive == isActive) return;
        if (isActive) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      },
    );

    return MaterialApp.router(
      title: "유담's Diary",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
