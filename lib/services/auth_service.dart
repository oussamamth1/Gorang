import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = AppUser(
      uid: cred.user!.uid,
      fullName: fullName,
      email: email,
      phone: phone,
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(
      userCredential.user!,
      fullName: googleUser.displayName,
      email: googleUser.email,
      photoUrl: googleUser.photoUrl,
    );
  }

  Future<void> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success) return;
    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);
    final userCredential = await _auth.signInWithCredential(credential);
    final fbData = await FacebookAuth.instance
        .getUserData(fields: 'name,email,picture.width(400)');
    await _ensureUserDocument(
      userCredential.user!,
      fullName: fbData['name'] as String?,
      email: fbData['email'] as String?,
      photoUrl: (fbData['picture'] as Map?)?['data']?['url'] as String?,
    );
  }

  Future<void> _ensureUserDocument(
    User firebaseUser, {
    String? fullName,
    String? email,
    String? photoUrl,
  }) async {
    final doc =
        await _db.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) return;
    await _db.collection('users').doc(firebaseUser.uid).set(
          AppUser(
            uid: firebaseUser.uid,
            fullName: fullName ?? firebaseUser.displayName ?? '',
            email: email ?? firebaseUser.email ?? '',
            phone: '',
            photoUrl: photoUrl ?? firebaseUser.photoURL,
          ).toMap(),
        );
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }
}
