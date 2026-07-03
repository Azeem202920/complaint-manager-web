import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint.dart';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collectionPath = 'complaint-manager';
  
  // New Config Path
  final String _configCollection = 'config';
  final String _configDoc = 'app_settings';

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

  // --- CONFIG METHODS (NEW) ---

  Future<void> updateConfigList(String fieldName, List<String> newList) async {
    await _db.collection(_configCollection).doc(_configDoc).set({
      fieldName: newList,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getConfig() async {
    var doc = await _db.collection(_configCollection).doc(_configDoc).get();
    return doc.data() ?? {};
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

  Future<void> updateLifecycleStatus({
    required String id,
    required String status,
    required String userName, 
    String? reason,          
    String? serialNo,
    String? materials,
    bool isStarting = false,
    bool isStandby = false,
    bool isClosing = false,
  }) async {
    Map<String, dynamic> updates = {
      'status': status,
      'lastUpdatedBy': userName, 
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (isStarting) {
      updates['startTime'] = FieldValue.serverTimestamp();
      updates['technicianName'] = userName; 
      updates['startedBy'] = userName;
    }
    
    if (isStandby) {
      updates['standbyTime'] = FieldValue.serverTimestamp();
      updates['standbyReason'] = reason;   
      updates['standbyBy'] = userName;
    }
    
    if (isClosing) {
      updates['completedAt'] = FieldValue.serverTimestamp();
      updates['closedBy'] = userName; 
      updates['finalRemarks'] = reason; 
      updates['serviceReportNumber'] = serialNo;
      updates['materialsUsed'] = materials ?? ''; 
      
      if (status == "Resolved") {
        updates['technicianName'] = userName;
      }
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
      if (snapshot.docs.isNotEmpty) {
        debugPrint("DB Check: Data found in '$collectionPath'");
      } else {
        debugPrint("DB Check: Collection '$collectionPath' is empty.");
      }
    } catch (e) {
      debugPrint("DB Check: Error accessing collection -> $e");
    }
  }
}