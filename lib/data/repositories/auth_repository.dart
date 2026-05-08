import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/firebase_providers.dart';
import '../firebase/firestore_paths.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn();
    final account = await google.signIn();
    if (account == null) return; // 사용자 취소
    final googleAuth = await account.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final result = await _auth.signInWithCredential(cred);
    final user = result.user;
    if (user == null) return;
    await _ensureUserDoc(user);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.doc(FirestorePaths.user(user.uid));
    final snap = await ref.get();
    if (snap.exists) return;
    final me = AppUser(
      uid: user.uid,
      displayName: user.displayName ?? '사용자',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      familyId: null,
    );
    await ref.set(me.toCreateMap());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// 현재 로그인 사용자의 Firestore `users/{uid}` 도큐먼트를 스트리밍.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  final fs = ref.watch(firestoreProvider);
  return fs
      .doc(FirestorePaths.user(auth.uid))
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);
});
