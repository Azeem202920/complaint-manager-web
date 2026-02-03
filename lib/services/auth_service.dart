import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Add your authentication methods here
  Future<void> signInWithPhone(String phoneNumber) async {
    // Implement phone authentication
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}