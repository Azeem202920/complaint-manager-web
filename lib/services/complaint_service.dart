import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/complaint.dart';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String collectionPath = 'complaint-manager';
  
  final String _configCollection = 'config';
  final String _configDoc = 'app_settings';

  Stream<List<Complaint>> getAllComplaints() {
    return _db
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Complaint.fromFirestore(doc))
            .toList());
  }

  Stream<DocumentSnapshot> getChillerStatusStream() {
    return FirebaseFirestore.instance
        .collection('system_data')
        .doc('chiller_status')
        .snapshots();
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

  // --- DIAGNOSTIC & STATUS METHODS ---
  Future<void> testFirestoreConnection() async {
    try {
      await _db.collection(collectionPath).limit(1).get();
      debugPrint("Firestore connection test successful.");
    } catch (e) {
      debugPrint("Firestore connection test failed: $e");
    }
  }

  Future<void> updateComplaintAudit(
    String complaintId, {
    required String buildingName,
    required String flatNumber,
    required String complaintType,
    required String status,
    required String description,
    required String serviceReportNumber,
    required String materialsUsed,
  }) async {
    try {
      await _db.collection(collectionPath).doc(complaintId).update({
        'buildingName': buildingName,
        'flatNumber': flatNumber,
        'complaintType': complaintType,
        'status': status,
        'description': description,
        'serviceReportNumber': serviceReportNumber,
        'materialsUsed': materialsUsed,
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating complaint audit: $e");
      rethrow;
    }
  }

  Future<void> checkDatabaseExists() async {
    try {
      var snapshot = await _db.collection(collectionPath).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint("Database reachable. Documents found.");
      } else {
        debugPrint("Database reachable, but collection is empty.");
      }
    } catch (e) {
      debugPrint("Error checking database: $e");
    }
  }

  Future<void> updateLifecycleStatus(String complaintId, String newStatus) async {
    try {
      await _db.collection(collectionPath).doc(complaintId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating lifecycle status: $e");
    }
  }

  // --- STORAGE UPLOAD METHODS ---
  Future<String?> uploadComplaintImage(File imageFile, String complaintId, String imageType) async {
    try {
      final ref = _storage.ref().child('complaints/$complaintId/${imageType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<String?> uploadComplaintImageBytes(Uint8List bytes, String complaintId, String type) async {
    try {
      final ref = _storage.ref().child('complaints/$complaintId/${type}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putData(bytes);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image bytes: $e");
      return null;
    }
  }

  Future<String?> uploadSignatureBytes(Uint8List signatureBytes, String complaintId, String sigType) async {
    try {
      final ref = _storage.ref().child('complaints/$complaintId/${sigType}_${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(signatureBytes, SettableMetadata(contentType: 'image/png'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading signature: $e");
      return null;
    }
  }

  // --- CONFIG METHODS ---
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

  Future<void> deleteComplaint(String id, String reason) async {
    await _db.collection(collectionPath).doc(id).update({
      'isDeleted': true,
      'deleteRemarks': reason,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }
}