import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/json_helpers.dart';
import '../models/user_data.dart';

/// Email/password authentication plus the Firestore profile document.
///
/// Passwords are handled only by Firebase Authentication. They are never
/// written to Firestore.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Emits on sign-in, sign-out, token refresh and profile reloads
  /// (so `emailVerified` updates after `reload()`).
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String gender,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(fullName.trim());

      // Profile only. No password, no scores (those are server-managed).
      await _db.collection('users').doc(user.uid).set({
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.replaceAll(RegExp(r'[\s\-]'), ''),
        'gender': gender,
        'preferredLanguage': 'en',
        'dailyGoal': 5,
        'acceptedTermsAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    } on FirebaseException catch (e) {
      throw AppException(_firestoreMessage(e));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  Future<void> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  /// Reloads the user so `emailVerified` is up to date. Returns the new value.
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();

  /// Confirms the password before deleting the account (Firebase requires a
  /// recent sign-in for this). Call [finishDeleteAuthUser] afterwards.
  Future<void> reauthenticate({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  Future<void> finishDeleteAuthUser() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  // ---- Profile -----------------------------------------------------------

  Stream<UserProfile?> watchProfile(String uid) =>
      _db.collection('users').doc(uid).snapshots().map(
            (d) => d.exists ? UserProfile.fromMap(uid, d.data()!) : null,
          );

  Future<void> updateProfile(
    String uid, {
    required String fullName,
    required String phone,
    required String gender,
  }) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fullName': fullName.trim(),
        'phone': phone.replaceAll(RegExp(r'[\s\-]'), ''),
        'gender': gender,
      });
      await _auth.currentUser?.updateDisplayName(fullName.trim());
    } on FirebaseException catch (e) {
      throw AppException(_firestoreMessage(e));
    }
  }

  Future<void> updateSettings(String uid, {String? preferredLanguage, int? dailyGoal}) async {
    final data = <String, Object?>{
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (dailyGoal != null) 'dailyGoal': dailyGoal,
    };
    if (data.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).update(data);
    } on FirebaseException catch (e) {
      throw AppException(_firestoreMessage(e));
    }
  }

  // ---- Error messages ----------------------------------------------------

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'requires-recent-login':
        return 'Please sign in again, then retry.';
      default:
        return 'Authentication failed (${e.code}).';
    }
  }

  static String _firestoreMessage(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
        return 'No internet connection. Please try again.';
      case 'permission-denied':
        return 'You do not have permission to do that.';
      default:
        return 'Could not save your data (${e.code}).';
    }
  }
}
