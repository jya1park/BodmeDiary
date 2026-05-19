import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // duplicate-app 예외가 날 수 있다. 그 경우는 이미 초기화된 것이라 무시.
  // iOS 는 명시 호출이 필요하므로 try 안에서 그대로 호출.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // [DIAG] Firebase Auth 캐시 상태를 부팅 직후 한 번 출력 — 세션 영속화 진단용.
  // adb logcat 에 'BodmeDiary' 태그로 잡힘.
  final cachedUser = FirebaseAuth.instance.currentUser;
  developer.log(
    'auth boot: currentUser=${cachedUser?.uid ?? 'null'} '
    'email=${cachedUser?.email ?? '-'}',
    name: 'BodmeDiary',
  );
  FirebaseAuth.instance.authStateChanges().listen((u) {
    developer.log(
      'auth state change: ${u?.uid ?? 'null'}',
      name: 'BodmeDiary',
    );
  });
  FirebaseAuth.instance.idTokenChanges().listen((u) {
    developer.log(
      'idToken change: ${u?.uid ?? 'null'}',
      name: 'BodmeDiary',
    );
  });

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
