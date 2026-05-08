import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/add_baby_screen.dart';
import '../../features/photo_ocr/presentation/photo_capture_screen.dart';
import '../../features/photo_ocr/presentation/photo_review_screen.dart';
import '../../features/settings/presentation/family_invite_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/root_shell.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final familyState = ref.watch(currentFamilyStateProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Auth 상태 로딩 중에는 splash 유지
      if (auth.isLoading) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      final user = auth.value;
      final isSignedIn = user != null;

      if (!isSignedIn) {
        return loc == Routes.signIn ? null : Routes.signIn;
      }

      // 로그인 됨 — family 는 회원가입 시 자동 생성됨. 아직 도착 전이면 splash 유지.
      final family = familyState.value;
      if (family == null) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      if (family.familyId == null) {
        // 자동 생성 실패 등으로 가족이 없음 — splash 에 머물러 재시도/오류 표시
        return loc == Routes.splash ? null : Routes.splash;
      }

      // 가족 있음 + 아기 없음 → 아기 등록
      if (family.babies.isEmpty) {
        return loc == Routes.onboardingAddBaby
            ? null
            : Routes.onboardingAddBaby;
      }

      // 정상 사용자가 splash/signin/onboarding 으로 가면 홈으로
      if (loc == Routes.splash ||
          loc == Routes.signIn ||
          loc.startsWith('/onboarding/')) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: Routes.onboardingAddBaby,
        builder: (_, __) => const AddBabyScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: Routes.history,
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: Routes.photo,
            builder: (_, __) => const PhotoCaptureScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.photoReview,
        builder: (_, __) => const PhotoReviewScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.familyInvite,
        builder: (_, __) => const FamilyInviteScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('경로 오류: ${state.uri}')),
    ),
  );
});

/// authState 와 familyState 를 GoRouter refresh 로 변환.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentFamilyStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
