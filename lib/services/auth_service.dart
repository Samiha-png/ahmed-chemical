import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(fullName);
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'fullName': fullName,
        'role': 'super_admin',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Is email se koi account nahi mila';
      case 'wrong-password':
        return 'Password ghalat hai';
      case 'invalid-email':
        return 'Email sahi nahi hai';
      case 'user-disabled':
        return 'Yeh account band kar diya gaya hai';
      case 'too-many-requests':
        return 'Bohat zyada koshishein. Thori der baad try karein';
      case 'email-already-in-use':
        return 'Yeh email pehle se registered hai';
      case 'weak-password':
        return 'Password kamzor hai (6+ characters)';
      case 'network-request-failed':
        return 'Internet connection check karein';
      default:
        return e.message ?? 'Kuch ghalat ho gaya';
    }
  }
}
