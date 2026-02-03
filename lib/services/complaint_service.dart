import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/complaint.dart';

class ComplaintService with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'complaint-manager';

  // Add a complaint with a specific ID
  Future<void> addComplaintWithId(Complaint complaint) async {
    await _db.collection(_collection).doc(complaint.id).set(complaint.toMap());
    notifyListeners();
  }

  // Update an existing complaint
  Future<void> updateComplaint(Complaint complaint) async {
    await _db.collection(_collection).doc(complaint.id).update(complaint.toMap());
    notifyListeners();
  }

  // REPLACEMENT FOR getComplaints: matches HomeScreen call
  Stream<List<Complaint>> getAllComplaints() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Complaint.fromMap(doc.data(), doc.id))
            .toList());
  }

  // REPLACEMENT FOR getCustomerComplaints: matches CustomerScreen call
  Stream<List<Complaint>> getComplaintsByPhone(String phone) {
    return _db
        .collection(_collection)
        .where('customerPhone', isEqualTo: phone)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Complaint.fromMap(doc.data(), doc.id))
            .toList());
  }

  // REQUIRED BY TECHNICIAN SCREEN (keep this name too just in case)
  Stream<List<Complaint>> getComplaints() => getAllComplaints();

  // DIAGNOSTIC: Test if we can write to Firestore
  Future<void> testFirestoreConnection() async {
    try {
      await _db.collection('connection_test').doc('test').set({
        'last_checked': DateTime.now().toIso8601String(),
        'status': 'connected'
      });
      debugPrint('✅ Firestore Connection Test Successful');
    } catch (e) {
      debugPrint('❌ Firestore Connection Test Failed: $e');
    }
  }

  // DIAGNOSTIC: Check if the collection exists/is accessible
  Future<void> checkDatabaseExists() async {
    try {
      var snapshot = await _db.collection(_collection).limit(1).get();
      debugPrint('✅ Database access check: ${snapshot.docs.isNotEmpty ? "Data found" : "Collection empty but accessible"}');
    } catch (e) {
      debugPrint('❌ Database access check failed: $e');
    }
  }
}