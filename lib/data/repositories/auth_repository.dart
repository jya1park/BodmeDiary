import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/app_user.dart';

/// 아이디 + 비밀번호 로그인. Firebase Auth 는 email 만 지원하므로 내부적으로
/// `${username}@bodmediary.app` 으로 매핑한다. 이 도메인은 실제 메일 발송에
/// 쓰이지 않으며 외부에 노출되지 않는다.
class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._functions);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static final _usernameRegex = RegExp(r'^[a-z0-9_]{3,30}$');
  static const _internalDomain = '@bodmediary.app';

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// 회원가입 — 가족이 없으면 자동 생성, [inviteCode] 가 있으면 해당 가족에 합류.
  Future<void> signUpWithUsername({
    required String username,
    required String password,
    String? inviteCode,
  }) async {
    final id = username.trim().toLowerCase();
    _validateUsername(id);

    final email = '$id$_internalDomain';
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) throw FirebaseAuthException(code: 'unknown');

    await user.updateDisplayName(id);
    await _ensureUserDoc(user, displayName: id);

    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      await _functions
          .httpsCallable('redeemInvite')
          .call<Map<String, dynamic>>({'code': inviteCode.trim()});
    } else {
      await _autoCreateFamily(user.uid, id);
    }
  }

  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final id = username.trim().toLowerCase();
    _validateUsername(id);
    await _auth.signInWithEmailAndPassword(
      email: '$id$_internalDomain',
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  void _validateUsername(String id) {
    if (!_usernameRegex.hasMatch(id)) {
      throw FirebaseAuthException(
        code: 'invalid-username',
        message: '아이디는 영문 소문자/숫자/_ 3–30자여야 합니다.',
      );
    }
  }

  Future<void> _ensureUserDoc(User user, {required String displayName}) async {
    final ref = _firestore.doc(FirestorePaths.user(user.uid));
    final snap = await ref.get();
    if (snap.exists) return;
    final me = AppUser(
      uid: user.uid,
      displayName: displayName,
      email: user.email ?? '',
      photoUrl: null,
      familyId: null,
    );
    await ref.set(me.toCreateMap());
  }

  Future<void> _autoCreateFamily(String uid, String username) async {
    final familyRef = _firestore.collection(FirestorePaths.families).doc();
    final batch = _firestore.batch();
    batch.set(familyRef, {
      'name': '$username님의 가족',
      'ownerUid': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_firestore.doc(FirestorePaths.user(uid)), {
      'familyId': familyRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// 현재 로그인 사용자의 Firestore `users/{uid}` 도큐먼트를 스트리밍.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  final fs = ref.watch(firestoreProvider);
  return fs
      .doc(FirestorePaths.user(auth.uid))
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);
});
