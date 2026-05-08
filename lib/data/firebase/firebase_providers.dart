import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>((_) {
  final fs = FirebaseFirestore.instance;
  fs.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  return fs;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
);
