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
  /// 손글씨 OCR 정확도가 디테일에 매우 민감하므로 2400 으로 유지한다.
  /// base64 인라인 페이로드는 약 1.4MB — Cloud Functions 10MB 한도 한참 아래.
  static const int ocrImageMaxEdge = 2400;

  /// 수유 진척도 표시용 일일 목표량 (ml). 100% 채움 = 이 값에 도달.
  /// 신생아 표준 가이드 (~150ml/kg/day · 4kg 기준) 근처 라운드 값.
  static const int defaultDailyFeedingTargetMl = 800;
}
