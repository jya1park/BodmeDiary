# BodmeDiary

신생아 관리 히스토리 앱 — **수유 · 기저귀 · 잠** 을 가족 구성원이 함께 기록·공유하고, 손글씨 종이 일지는 사진 한 장으로 자동 디지털화.

- **플랫폼**: Flutter (iOS + Android)
- **백엔드**: Firebase (Auth · Firestore · Storage · Cloud Functions, 리전 `asia-northeast3`)
- **OCR**: OpenAI Vision (`gpt-4o-mini`, Cloud Functions 경유)
- **로케일**: 한국어 (ko_KR)

## 핵심 기능

1. **홈** — 큰 버튼 3개 (수유·기저귀·잠) + 마지막 이벤트로부터 경과 시간 표시
2. **가족 공유** — 회원가입 시 본인 가족 자동 생성. 6자리 초대코드로 부모/조부모가 같은 아기 데이터 실시간 공유 (가입 시 코드 입력 또는 설정에서 코드 생성)
3. **타이머** — 수유·잠은 시작·종료 타이머. Firestore 트랜잭션 기반 mutex 로 동시 시작 충돌 방지
4. **히스토리** — 일/주/월 막대그래프 (수유 횟수·소변·배변·수면 시간)
5. **사진 OCR** — 손글씨 일지 촬영 → OpenAI Vision 분석 → 사용자 확인 → 일괄 저장

## 디렉토리 구조

```
lib/
├── main.dart, app.dart, firebase_options.dart
├── core/      # 테마, 라우팅, 시간 유틸, 공용 위젯
├── data/      # Firebase 프로바이더, 모델, 리포지토리
└── features/  # auth, onboarding, home, feeding, diaper, sleep,
              #  history, photo_ocr, settings, shell
functions/     # TypeScript Cloud Functions (invites, OCR)
firestore.rules, storage.rules, firestore.indexes.json
```

자세한 설계는 `/root/.claude/plans/linear-cooking-otter.md` 참조.

## 로컬 셋업

```bash
# 1. Flutter 의존성
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Firebase 프로젝트 연결
dart pub global activate flutterfire_cli
flutterfire configure
# → lib/firebase_options.dart 생성

# 3. Cloud Functions
cd functions
npm install
cd ..

# 4. OpenAI API 키 등록 (OCR 기능 사용 시 필수)
firebase functions:secrets:set OPENAI_API_KEY

# 5. 보안 규칙·함수 배포
firebase deploy --only firestore:rules,storage,functions

# 6. 실행
flutter run
```

## 빌드 단계 (Phase)

| Phase | 내용 |
|---|---|
| 0 | 프로젝트 부트스트랩 (이 커밋) |
| 1 | Auth (아이디/비밀번호) + 가족 자동 생성 + 아기 등록 |
| 2 | 기저귀 즉시 로그 |
| 3 | 수유·잠 라이브 타이머 (가족 동기화) |
| 4 | 히스토리 일/주/월 차트 |
| 5 | 가족 초대 코드 |
| 6 | 사진 OCR (OpenAI Vision · gpt-4o-mini) |
| 7 | 폴리시 (Crashlytics, 정리, 설정) |

## 라이선스

내부 프로젝트.
