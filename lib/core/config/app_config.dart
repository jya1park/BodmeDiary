/// 앱 환경 상수.
class AppConfig {
  AppConfig._();

  /// Cloud Functions 리전. Firestore 와 동일 리전으로 통일.
  static const String functionsRegion = 'asia-northeast3';

  /// 기본 아기 타임존 (가족 생성 시 baby.timezone 으로 저장).
  static const String defaultBabyTimezone = 'Asia/Seoul';

  /// OCR 사용자 일별 쿼터 (Cloud Function 측에서도 동일 값 강제).
  static const int ocrDailyQuota = 20;

  /// 이미지 다운스케일 최대 변 길이 (픽셀).
  static const int ocrImageMaxEdge = 1600;
}
