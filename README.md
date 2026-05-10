# 유담's Diary

신생아 케어 기록을 가족과 함께 공유하는 한국어 앱. 수유 · 기저귀 · 잠을 한 손으로 빠르게 기록하고, 손글씨 일지는 사진 한 장으로 자동 디지털화합니다.

![앱 아이콘](assets/app_icon.png)

---

## 핵심 특징

| 특징 | 설명 |
|---|---|
| **한 손 조작** | 홈에 큰 버튼 3개(수유·기저귀·잠), 1탭 기록 |
| **가족 동기화** | Firestore 실시간 sync, 두 기기에서 동일 활성 타이머 표시 |
| **수유 게이지** | 어제 총량을 100% 로 두고 오늘 누적량을 하→상 채움 애니메이션 |
| **모유 추정** | 10분당 유축량 설정 → 모유 수유 시간으로 섭취량 자동 추정 |
| **사진 OCR** | OpenAI gpt-4o-mini Vision 으로 손글씨 일지 → 이벤트 자동 추출 |
| **수동 편집** | 버튼 길게 누르기 → 이벤트 목록 → 삭제 / 수동 추가 |
| **오프라인 OK** | Firestore 자동 캐시, 네트워크 복구 시 동기화 |

---

## 기술 스택

### 클라이언트 (Flutter)

- **Flutter** 3.22+ / **Dart** 3.4+
- **State**: `flutter_riverpod` (Provider/StreamProvider/NotifierProvider 직접 사용, 코드젠 없음)
- **Routing**: `go_router` 14.x (선언형 + auth/family redirect)
- **Charts**: `fl_chart` 0.68 (히스토리 막대그래프, 라벨 포함)
- **Camera**: `image_picker` 1.1
- **Time**: `timezone` 0.10 (Asia/Seoul 고정)
- **i18n**: `intl` 0.20

### 백엔드 (Firebase)

- **Authentication**: 이메일/비밀번호 (UI 는 아이디로 노출, 내부 `{id}@bodmediary.app` 매핑)
- **Cloud Firestore**: 실시간 sync + 보안 규칙
- **Cloud Functions** (TypeScript, 2nd gen): 초대코드 발급/사용, OCR
- **App Check**: Play Integrity (Android) / DeviceCheck (iOS)
- **Crashlytics**: 릴리스 빌드 크래시 수집
- **리전**: `asia-northeast3` (서울)
- **Storage**: 사용 안 함 — OCR 사진은 base64 인라인으로 함수 호출에 첨부, 분석 직후 메모리에서 폐기

### OCR

- **OpenAI gpt-4o-mini Vision** — Cloud Functions 에서 OPENAI_API_KEY 시크릿으로 호출
- 응답은 zod 로 검증, 파싱 실패 시 1회 재시도

---

## 디렉토리 구조

```
BodmeDiary/
├── android/, ios/                         # flutter create 산출물
├── assets/
│   └── app_icon.png                       # 앱 아이콘 + 스플래시 원본
├── lib/
│   ├── main.dart                          # Firebase init, App Check, runApp
│   ├── app.dart                           # MaterialApp.router
│   ├── firebase_options.dart              # flutterfire configure 자동 생성
│   │
│   ├── core/                              # 공용 (UI 와 데이터 모두에서 참조)
│   │   ├── config/app_config.dart         # 리전, 기본값, 쿼터
│   │   ├── localization/arb/app_ko.arb    # 한국어 문자열
│   │   ├── routing/
│   │   │   ├── app_router.dart            # GoRouter + 인증/가족 redirect
│   │   │   └── routes.dart                # 경로 상수
│   │   ├── theme.dart                     # 살구 파스텔 ColorScheme
│   │   ├── time/
│   │   │   ├── clock.dart                 # 테스트용 시간 추상화
│   │   │   ├── day_boundary.dart          # localDayKey · recentDayKeys
│   │   │   └── duration_format.dart       # "1시간 23분 전" 포맷
│   │   ├── widgets/                       # 재사용 위젯
│   │   │   ├── primary_action_button.dart # 홈 큰 버튼 (fill 게이지 포함)
│   │   │   ├── elapsed_text.dart          # 30초 자동 갱신 경과시간
│   │   │   └── active_timer_banner.dart   # 활성 타이머 배너
│   │   └── utils/{result,id}.dart
│   │
│   ├── data/                              # 데이터 계층 (UI 비의존)
│   │   ├── firebase/
│   │   │   ├── firebase_providers.dart    # Auth/Firestore/Functions Provider
│   │   │   └── firestore_paths.dart       # 모든 컬렉션 경로 일원화
│   │   ├── models/
│   │   │   ├── app_user.dart              # users/{uid}
│   │   │   ├── family.dart                # families/{id}
│   │   │   ├── baby.dart                  # families/{id}/babies/{id}
│   │   │   │                              #   (+ pumpRateMlPer10Min)
│   │   │   │                              #   + estimateBreastMilkMl 헬퍼
│   │   │   ├── care_event.dart            # events/{id}
│   │   │   │                              #   (feeding/diaper/sleep)
│   │   │   ├── active_timer.dart          # activeTimers/{type}
│   │   │   └── ocr_draft.dart             # OCR 응답 모델
│   │   └── repositories/
│   │       ├── auth_repository.dart       # 회원가입/로그인 + 가족 자동생성
│   │       ├── family_repository.dart     # 가족 CRUD + 초대코드
│   │       ├── baby_repository.dart       # 아기 CRUD + 유축량 갱신
│   │       ├── events_repository.dart     # 이벤트 CRUD + 일자별 쿼리
│   │       ├── timer_repository.dart      # 활성 타이머 트랜잭셔널 mutex
│   │       └── ocr_repository.dart        # base64 인코딩 후 callable 호출
│   │
│   └── features/                          # 기능별 화면 (UI 계층)
│       ├── auth/presentation/
│       │   ├── splash_screen.dart         # Image.asset + 인디케이터
│       │   └── sign_in_screen.dart        # 로그인 / 회원가입 탭
│       ├── onboarding/presentation/
│       │   └── add_baby_screen.dart       # 아기 등록 1회
│       ├── shell/
│       │   └── root_shell.dart            # BottomNav 3탭
│       ├── home/presentation/
│       │   └── home_screen.dart           # 큰 버튼 3개 + 게이지
│       ├── feeding/presentation/
│       │   └── feeding_stop_sheet.dart    # 수유 종료 시 양 입력
│       ├── diaper/presentation/
│       │   └── diaper_modal.dart          # 소변/배변/둘다
│       ├── manual/presentation/
│       │   ├── manual_records_screen.dart # 이벤트 목록 + 삭제
│       │   └── manual_record_form.dart    # 수동 추가 폼
│       ├── history/
│       │   ├── application/aggregation.dart
│       │   └── presentation/
│       │       ├── history_screen.dart    # 일/주/월 탭
│       │       └── widgets/history_charts.dart  # 라벨 포함 막대그래프
│       ├── photo_ocr/
│       │   ├── application/ocr_controller.dart
│       │   └── presentation/
│       │       ├── photo_capture_screen.dart
│       │       └── photo_review_screen.dart
│       └── settings/presentation/
│           ├── settings_screen.dart       # 가족·아기·유축량·로그아웃
│           └── family_invite_screen.dart  # 초대코드 생성·공유
│
├── test/                                  # flutter_test 단위테스트
│   ├── aggregation_test.dart              # 일자별 집계
│   └── baby_estimate_test.dart            # 모유 섭취량 추정
│
├── functions/                             # Cloud Functions (TypeScript)
│   └── src/
│       ├── index.ts                       # 4개 함수 export
│       ├── config.ts                      # REGION, OPENAI_API_KEY secret
│       ├── lib/
│       │   ├── auth.ts                    # assertAuth, assertFamilyMember
│       │   └── firestore.ts               # admin.firestore() 인스턴스
│       ├── invites/
│       │   ├── code.ts                    # 6자리 코드 생성
│       │   ├── createInvite.ts            # callable
│       │   └── redeemInvite.ts            # callable + 트랜잭션 + rate-limit
│       ├── ocr/
│       │   ├── prompt.ts                  # SYSTEM_PROMPT (응답 JSON 스키마)
│       │   ├── openaiClient.ts            # Chat Completions Vision 호출
│       │   └── parseHandwrittenLog.ts     # callable + zod 검증 + 일별 쿼터
│       └── maintenance/
│           └── pruneExpiredInvites.ts     # 일 1회 만료 코드 정리
│
├── firestore.rules                        # 가족 멤버 기반 권한 규칙
├── firestore.indexes.json                 # localDayKey + startAt 복합 인덱스
├── firebase.json, .firebaserc
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 데이터 계층 — Firestore 모델

```
users/{uid}                                     # 본인만 read/write
  displayName, email, familyId?, createdAt, updatedAt

families/{familyId}                             # memberUids 의 모든 사용자만 read/write
  name, ownerUid, memberUids[], createdAt
  
  babies/{babyId}                               # 가족 구성원 모두
    name, birthDate, gender, timezone ('Asia/Seoul'),
    pumpRateMlPer10Min?, photoUrl?, createdAt
    
    events/{eventId}                            # 가족 구성원 모두
      type: 'feeding' | 'diaper' | 'sleep'
      startAt, endAt, durationMs
      localDayKey: 'YYYY-MM-DD'                 # 아기 timezone 기준
      createdByUid, createdAt
      source: 'manual' | 'ocr' | 'timer'
      feeding: { amountMl? }?
      diaper: { kind: 'pee'|'poop'|'both', note? }?
      sleep: { note? }?
    
    activeTimers/{timerType}                    # docId 가 type ('feeding'|'sleep')
      type, startedAt, startedByUid, startedByName, clientStartedAtMs
      # 자연 mutex — 같은 type 의 timer 는 동시에 1개만 존재
  
  inviteCodes/{code}                            # 가족 구성원 read, Function 만 write
    familyId, createdByUid, createdAt, expiresAt(+24h),
    used, usedByUid?, usedAt?

inviteCodeIndex/{code}                          # 서버 전용 (top-level lookup)
  familyId, expiresAt, used

ocrQuotas/{uid_YYYY-MM-DD}                      # 서버가 일별 OCR 횟수 추적
  count, updatedAt, expiresAt
```

### 보안 모델 핵심

- 모든 baby/event 접근은 `families/{id}.memberUids` 에 포함되어야 가능
- 이벤트 생성 시 `createdByUid == auth.uid` 강제
- `activeTimers/{type}` 은 update 금지 — create-then-delete 만 (mutex 보장)
- `users/{uid}.familyId` 변경은 한 번만 (`null → 값`) 가능
- 초대코드 발급/사용은 Cloud Function admin SDK 만

---

## 주요 흐름

### 1. 회원가입 → 가족 자동 생성

```
사용자: 아이디 'boomi_mom' + 비밀번호 입력 (+ 선택 초대코드)
  ↓
AuthRepository.signUpWithUsername()
  ├─ FirebaseAuth.createUserWithEmailAndPassword('boomi_mom@bodmediary.app')
  ├─ users/{uid} 도큐먼트 생성
  └─ 초대코드 있으면: redeemInvite (Cloud Function) 호출
     초대코드 없으면: families/{newId} + users/{uid}.familyId 배치 생성
  ↓
GoRouter redirect: 가족 OK + 아기 X → /onboarding/add-baby
```

### 2. 수유 타이머 (가족 동기화 + 동시성 안전)

```
[수유 시작] 탭
  ↓
TimerRepository.startTimer(type: feeding)
  ↓
Firestore Transaction:
  if (activeTimers/feeding 도큐먼트 존재) → 'already-exists' 예외 → false 반환
  else → tx.set(activeTimers/feeding, {startedAt, startedByUid, ...})
  ↓
가족 모든 기기의 activeFeedingTimerProvider 가 새 데이터 emit
  → 활성 배너 표시 (1초마다 ticker)

[수유 종료] 탭
  ↓
FeedingStopSheet → 총 시간 + (선택) 분유 양 입력
  ↓
TimerRepository.stopTimer(feedingAmountMl)
  ↓
Firestore Transaction:
  read activeTimers/feeding (없으면 false)
  write events/{newId} {type:feeding, startAt, endAt, ...}
  delete activeTimers/feeding
```

### 3. 일일 수유 게이지 (어제 총량 = 100%)

```
홈 화면 build 마다:
  recentDayKeys(2, 'Asia/Seoul') → ['2026-05-09', '2026-05-10']
  todayEventsProvider → 두 일자 이벤트 스트림
  ↓
  today = events.where(localDayKey == today)
  yesterday = events.where(localDayKey == yesterday)
  ↓
  dailyMl = sum(분유 ml) + sum(estimateBreastMilkMl(모유 시간))
  yesterdayMl = 동일 계산
  target = yesterdayMl > 0 ? yesterdayMl : 800 (default)
  progress = clamp(dailyMl / target, 0, 1)
  ↓
PrimaryActionButton(progress: progress)
  → TweenAnimationBuilder 가 0 → progress 부드럽게 채움
  → FractionallySizedBox(heightFactor) 로 하→상 채움
```

### 4. 사진 OCR (Storage 미사용)

```
[사진 촬영] → image_picker.camera (1600px 다운스케일)
  ↓
File → readAsBytes → base64Encode
  ↓
parseHandwrittenLog(familyId, babyId, imageBase64, mimeType)  ← Callable
  ↓ Cloud Function
  assertFamilyMember + checkOcrQuota (uid 당 일 20회)
  ↓
  Buffer.from(base64) → callOpenAi(apiKey, bytes, mimeType)
  ↓ OpenAI Chat Completions Vision
  json_object response → zod 검증 → 실패 시 1회 재시도
  ↓ Cloud Function 응답
  {draftId, events[], warnings[], rawText?}
  ↓
PhotoReviewScreen:
  체크박스로 이벤트 선택 (confidence < 50% 또는 중복 의심은 기본 미체크)
  ↓
[전체 저장] → events 배치 write (source: 'ocr')
```

### 5. 라우팅 / Redirect 로직

```dart
// app_router.dart
redirect: (context, state) {
  if (auth.isLoading) return splash;
  if (user == null) return signIn;
  if (family.familyId == null) return splash;       // 자동 생성 진행 중
  if (family.babies.isEmpty) return addBaby;
  // 정상 사용자
  if (loc in [splash, signIn, /onboarding/*]) return home;
  return null;  // 현재 위치 유지
}
```

GoRouter `refreshListenable` 이 `authStateProvider` 와 `currentFamilyStateProvider` 변화를 listen 해서 자동 redirect.

---

## 화면 구조

```
                   ┌─────────────┐
                   │   Splash    │  Image.asset(app_icon) + 인디케이터
                   └──────┬──────┘
              ┌───────────┼───────────┐
        미인증│                       │인증됨
              ▼                       ▼
       ┌──────────┐             ┌──────────┐
       │ Sign In  │             │ AddBaby  │ (아기 X)
       │ ┌──┬───┐ │             └────┬─────┘
       │ │로│회원││                  │
       │ │그│가입││                  ▼
       │ │인│   ││             ┌────────────┐
       │ └──┴───┘ │             │ Bottom Nav │
       └──────────┘             │  Shell     │
                                └─┬───┬───┬──┘
                                  │   │   │
                          ┌───────┘   │   └──────┐
                          ▼           ▼          ▼
                       ┌─────┐   ┌──────┐  ┌──────┐
                       │ 홈  │   │히스토│  │사진  │
                       │     │   │ 리   │  │      │
                       └──┬──┘   └──────┘  └──┬───┘
                          │                   ▼
              ┌───────────┴───────┐      ┌────────┐
              │ 길게누르기/⚙ 설정 │      │ 인식   │
              ▼                   ▼      │ 결과   │
         ┌──────────┐        ┌────────┐  │ 확인   │
         │ 기록편집 │        │ 설정    │  └────────┘
         │ FAB +    │        │ ⤷ 초대 │
         └──────────┘        │ ⤷ 유축 │
                             └────────┘
```

---

## 셋업 — 처음 빌드까지

### 1. 도구 설치

```bash
brew install --cask flutter
npm install -g firebase-tools
dart pub global activate flutterfire_cli
flutter doctor                              # 모두 ✓
firebase login
```

### 2. Firebase 콘솔 설정 (1회)

1. 프로젝트 생성 (이름 `bodmediary`)
2. 요금제 → **Blaze 종량제** 로 업그레이드 (외부 API 호출 필수)
3. 결제 → 예산 알림 $1, $5, $10 권장
4. Authentication → **이메일/비밀번호** 활성화
5. Firestore Database 생성, 리전 `asia-northeast3 (Seoul)`
6. App Check → 앱 등록

### 3. 로컬 셋업

```bash
cd BodmeDiary
flutter create . --platforms=android,ios --org com.bodme
flutter pub get
flutterfire configure --project=bodmediary
cd functions && npm install && cd ..

# 앱 아이콘 + 네이티브 스플래시 자동 생성
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### 4. 플랫폼 권한

**Android** `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdkVersion 23
}
```

**iOS** `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>손글씨 일지 촬영에 사용합니다</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>일지 사진 선택에 사용합니다</string>
```

### 5. OpenAI 키 등록

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

### 6. 배포 + 실행

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
flutter run
```

첫 실행 시 콘솔의 **App Check 디버그 토큰** 을 [App Check 콘솔](https://console.firebase.google.com/project/bodmediary/appcheck/apps) 에 등록.

---

## 자주 마주치는 빌드 이슈 (Windows)

| 증상 | 원인 → 해결 |
|---|---|
| `intl` 버전 충돌 | Flutter 3.24+ 의 `flutter_localizations` 가 `intl 0.20` 강제 → pubspec 에서 `intl: ^0.20.0` |
| `riverpod_generator` ↔ `riverpod_annotation` 충돌 | 우리 코드는 `@riverpod` 미사용 — 두 패키지 dev_dependencies 에서 제거 |
| `Family` import 충돌 | Riverpod 3.x 가 `Family` export → `import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;` |
| `valueOrNull isn't defined` | Riverpod 3 에서 제거됨 → `.value` (nullable 반환) 사용 |
| `flutter_timezone` 의 jni 빌드 차단 | Defender 가 clang.exe 차단. `flutter_timezone` 제거하고 `Asia/Seoul` 하드코딩 |
| `gen_snapshot.exe` 액세스 거부 | OneDrive 동기화 폴더에 프로젝트 위치 → `C:\dev\BodmeDiary` 로 이동 + Defender 예외 |
| `[core/duplicate-app]` | google-services 자동 초기화 + Dart `initializeApp` 중복 → try/catch 로 `duplicate-app` 무시 |

---

## 테스트

```bash
flutter test
```

- `test/aggregation_test.dart`: 일자별 카운팅 (수유/소변/배변/수면 시간)
- `test/baby_estimate_test.dart`: 모유 섭취량 추정 함수

---

## Firebase 비용 예상

가족 1팀 (일 100~300 이벤트) 기준 무료 한도 내 → **$0/월**

- Cloud Functions 무료: 200만 호출/월 (실사용 ~3,000)
- Firestore 무료: 일 50K read · 20K write · 1GB (실사용 ~200/100)
- OpenAI gpt-4o-mini: 사진 1장당 ~$0.001

OpenAI 호출만 별도 결제 필요 (사용자당 일 20회 쿼터로 어뷰징 차단).

---

## 라이선스

내부 프로젝트.
