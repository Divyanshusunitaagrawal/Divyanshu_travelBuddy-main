import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      notifyListeners();
      return result;
    } on FirebaseAuthException catch (e) {
      throw _getReadableAuthError(e);
    }
  }
  
  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
  required String name,
  required String email,
  required String password,
}) async {
  try {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create user document in Firestore
    await _createUserDocument(result.user!, name);
    
    // Remove this line to skip email verification
    // await result.user?.sendEmailVerification();
    
    notifyListeners();
    return result;
  } on FirebaseAuthException catch (e) {
    throw _getReadableAuthError(e);
  }
}
  
  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String name) async {
    await _firestore.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': false,
      'profilePic': null,
      'bio': '',
      'phone': '',
      'interest': '',
      'latitude': null,
      'longitude': null,
      'lastLocationUpdate': null,
    });
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
  
  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getReadableAuthError(e);
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (currentUser != null) {
        await currentUser!.updateDisplayName(displayName);
        await currentUser!.updatePhotoURL(photoURL);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (currentUser != null) {
        await currentUser!.updatePassword(newPassword);
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      throw _getReadableAuthError(e);
    }
  }
  
  // Get readable error message from Firebase Auth Exception
  String _getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}