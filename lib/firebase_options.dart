// 이 파일은 `flutterfire configure` 실행 시 자동 생성됩니다.
// 아래 스텁은 빌드를 통과시키기 위한 placeholder 입니다.
// 실제 배포 전 반드시 flutterfire CLI 로 재생성하세요.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      // ignore: no_default_cases
      default:
        throw UnsupportedError(
          'flutterfire configure 를 실행해 firebase_options.dart 를 생성하세요.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'bodmediary',
    storageBucket: 'bodmediary.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'bodmediary',
    storageBucket: 'bodmediary.appspot.com',
    iosBundleId: 'com.bodme.bodmediary',
  );
}
