import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint.dart';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collectionPath = 'complaint-manager';

  // --- STREAM METHODS ---

  Stream<List<Complaint>> getAllComplaints() {
    return _db
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Complaint.fromFirestore(doc))
            .toList());
  }

  Stream<List<Complaint>> getComplaintsByPhone(String phone) {
    return _db
        .collection(collectionPath)
        .where('customerPhone', isEqualTo: phone.trim())
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList());
  }

  Stream<List<Complaint>> getAdminFullHistory() {
    return _db
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList());
  }

  // --- WRITE METHODS ---

  Future<void> addComplaintWithId(Complaint complaint) async {
    await _db
        .collection(collectionPath)
        .doc(complaint.id)
        .set(complaint.toMap());
    notifyListeners();
  }

  Future<void> updateComplaint(Complaint complaint) async {
    await _db
        .collection(collectionPath)
        .doc(complaint.id)
        .update(complaint.toMap());
    notifyListeners();
  }

  /// USE THIS for Lifecycle changes in the Technician Screen
  /// Forces tracking of WHO performed the action and WHEN.
  Future<void> updateLifecycleStatus({
    required String id,
    required String status,
    required String userName, // Pass the logged-in technician's name
    String? reason,           // Standby or Closing remarks
    String? serialNo,         // Serial number for closing
    bool isStarting = false,
    bool isStandby = false,
    bool isClosing = false,
  }) async {
    Map<String, dynamic> updates = {'status': status};

    if (isStarting) {
      updates['startTime'] = FieldValue.serverTimestamp();
      updates['technicianName'] = userName; 
    }
    if (isStandby) {
      updates['standbyTime'] = FieldValue.serverTimestamp();
      updates['standbyReason'] = reason;   
      updates['technicianName'] = userName; 
    }
    if (isClosing) {
      updates['completedAt'] = FieldValue.serverTimestamp();
      updates['closedBy'] = userName;      
      updates['standbyReason'] = reason;   // Re-used for final remarks
      updates['serviceReportNumber'] = serialNo;
    }

    await _db.collection(collectionPath).doc(id).update(updates);
    notifyListeners();
  }

  Future<void> deleteComplaint(String id, String reason) async {
    await _db.collection(collectionPath).doc(id).update({
      'isDeleted': true,
      'deleteRemarks': reason,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  // --- DEBUG METHODS ---

  Future<void> testFirestoreConnection() async {
    try {
      await _db.collection('connection_test').doc('ping').set({
        'last_ping': Timestamp.now(),
      });
      debugPrint("Firestore Connection: Success");
    } catch (e) {
      debugPrint("Firestore Connection: Failed -> $e");
    }
  }

  Future<void> checkDatabaseExists() async {
    try {
      final snapshot = await _db.collection(collectionPath).limit(1).get();
      debugPrint("DB Check: ${snapshot.docs.isNotEmpty ? "Data found" : "Collection empty"}");
    } catch (e) {
      debugPrint("DB Check: Error -> $e");
    }
  }
}