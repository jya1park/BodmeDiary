import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/config/app_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 는 google-services 플러그인이 네이티브에서 자동 초기화하므로
  // 중복 호출 가드. iOS 는 명시 호출 필요.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  // 한국어 단일 로케일 앱이므로 타임존도 Asia/Seoul 고정.
  // device timezone 자동 감지(flutter_timezone) 는 Android 에서 jni 네이티브
  // 빌드를 요구하기에 의도적으로 사용하지 않음.
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConfig.defaultBabyTimezone));

  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  runApp(const ProviderScope(child: BodmeDiaryApp()));
}
