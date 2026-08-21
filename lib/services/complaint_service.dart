import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/complaint.dart';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final String collectionPath = 'complaint-manager';
  final String _configCollection = 'config';
  final String _configDoc = 'app_settings';

  // --- TECHNICIAN LOGIN WITH FIREBASE AUTH & FULL PROFILE AUTO-CREATION ---
  Future<bool> loginTechnician(String emailOrId, String password) async {
    try {
      String email = emailOrId;
      if (!email.contains('@')) {
        email = 'tech_$emailOrId@complaintmanager.com';
      }
      // 1. Authenticate using Firebase Auth
      if (_auth == null) throw Exception("Firebase Auth not initialized.");
      UserCredential cred = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      String uid = cred.user!.uid;
      // 2. Fetch technician metadata document from Firestore
      DocumentSnapshot techDoc = await _db.collection('technicians').doc(uid).get();
      if (!techDoc.exists) {
        QuerySnapshot query = await _db
            .collection('technicians')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          techDoc = query.docs.first;
        } else {
          // AUTO-CREATE FULL PROFILE under 'technicians' collection
          await _db.collection('technicians').doc(uid).set({
            'technicianId': emailOrId,
            'companyId': 'COMP-${DateTime.now().year}-${emailOrId.toUpperCase()}',
            'name': emailOrId,
            'email': email,
            'contactNumber': '',
            'status': 'present',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          techDoc = await _db.collection('technicians').doc(uid).get();
        }
      }
      var data = techDoc.data() as Map<String, dynamic>;
      bool isActive = data['isActive'] ?? true;
      String status = data['status'] ?? 'absent';
      String techName = data['name'] ?? emailOrId;
      // 3. Enforce access checks
      if (!isActive) {
        await _auth!.signOut();
        throw Exception("Account is deactivated. Contact administrator.");
      }
      if (status.toLowerCase() != 'present') {
        await _auth!.signOut();
        throw Exception("Access restricted: You are marked as Absent today.");
      }
      // 4. Log successful login action
      await _fetchAndLogTechnicianAction('login', techUid: uid, technicianName: techName);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  // --- LOGOUT METHOD ---
  Future<void> logoutTechnician() async {
    try {
      String uid = _auth?.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        await _fetchAndLogTechnicianAction('logout', techUid: uid);
      }
      if (_auth != null) {
        await _auth!.signOut();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  // --- HISTORICAL LOGGING & SINGLE-COLLECTION LOCATION HELPER ---
  Future<Position?> _fetchAndLogTechnicianAction(
    String actionContext, {
    String? techUid,
    String? technicianName,
    String? buildingName,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String activeUid = techUid ?? _auth?.currentUser?.uid ?? '';
      if (activeUid.isEmpty) return null;
      String activeName = technicianName ?? _auth?.currentUser?.email ?? 'unknown_technician';

      String resolvedBuilding = buildingName ?? 'N/A';
      // 1. SAVE ALL ENTRIES: Add historical log inside the technician's subcollection with building name
      await _db.collection('technicians').doc(activeUid).collection('activity_logs').add({
        'technicianName': activeName,
        'actionType': actionContext,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'buildingName': resolvedBuilding,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // 2. UPDATE LATEST STATE: Merge latest state directly into main technician document
      await _db.collection('technicians').doc(activeUid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'buildingName': resolvedBuilding,
        'lastAction': actionContext,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("Logged action '$actionContext' for technician '$activeName' at '$resolvedBuilding'");
      return position;
    } catch (e) {
      debugPrint("Error fetching/logging action location: $e");
      return null;
    }
  }

  // --- BUILDING RANGE VERIFICATION ---
  Future<bool> verifyBuildingRange(String buildingName, {double allowedRadiusMeters = 200.0}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return true;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return true;
      }
      Position currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      QuerySnapshot buildingQuery = await _db
          .collection('buildings')
          .where('buildingName', isEqualTo: buildingName)
          .limit(1)
          .get();
      if (buildingQuery.docs.isEmpty) {
        DocumentSnapshot doc = await _db.collection('buildings').doc(buildingName).get();
        if (!doc.exists) return true;
        buildingQuery = doc as QuerySnapshot;
      }
      var data = buildingQuery.docs.first.data() as Map<String, dynamic>;
      double buildingLat = data['latitude'] ?? data['lat'] ?? 0.0;
      double buildingLng = data['longitude'] ?? data['lng'] ?? 0.0;
      if (buildingLat == 0.0 || buildingLng == 0.0) return true;
      double distanceInMeters = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        buildingLat,
        buildingLng,
      );
      return distanceInMeters <= allowedRadiusMeters;
    } catch (e) {
      debugPrint("Range verification error: $e");
      return true;
    }
  }

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

  Stream<List<Complaint>> getComplaintsStream() {
    return _db.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList();
    });
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

  // UPDATED METHOD: Accepts optional named parameters including finalRemarks and standbyReason
  Future<void> updateComplaintAudit(
    String complaintId, {
    String? buildingName,
    String? flatNumber,
    String? complaintType,
    String? status,
    String? description,
    String? serviceReportNumber,
    String? materialsUsed,
    String? finalRemarks,
    String? standbyReason,
    String actionType = 'update_complaint',
  }) async {
    try {
      if (buildingName != null) {
        bool inRange = await verifyBuildingRange(buildingName);
        if (!inRange) {
          throw Exception("Access Restricted: You are outside the designated range for building $buildingName.");
        }
      }

      final Map<String, dynamic> updateData = {};
      if (buildingName != null) updateData['buildingName'] = buildingName;
      if (flatNumber != null) updateData['flatNumber'] = flatNumber;
      if (complaintType != null) updateData['complaintType'] = complaintType;
      if (status != null) updateData['status'] = status;
      if (description != null) updateData['description'] = description;
      if (serviceReportNumber != null) updateData['serviceReportNumber'] = serviceReportNumber;
      if (materialsUsed != null) updateData['materialsUsed'] = materialsUsed;
      if (finalRemarks != null) updateData['finalRemarks'] = finalRemarks;
      if (standbyReason != null) updateData['standbyReason'] = standbyReason;
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection(collectionPath).doc(complaintId).update(updateData);
      await _fetchAndLogTechnicianAction(actionType, buildingName: buildingName);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating complaint audit: $e");
      rethrow;
    }
  }

  Future<void> updateLifecycleStatus(String complaintId, String newStatus, {required String actionType, String? buildingName}) async {
    try {
      if (buildingName != null) {
        bool inRange = await verifyBuildingRange(buildingName);
        if (!inRange) {
          throw Exception("Access Restricted: Out of range to update status at $buildingName.");
        }
      }
      await _db.collection(collectionPath).doc(complaintId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _fetchAndLogTechnicianAction(actionType, buildingName: buildingName);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating lifecycle status: $e");
      rethrow;
    }
  }

  Future<String?> uploadComplaintImage(File imageFile, String complaintId, String imageType, {String? buildingName}) async {
    try {
      if (buildingName != null) {
        bool inRange = await verifyBuildingRange(buildingName);
        if (!inRange) {
          throw Exception("Access Restricted: Out of range to attach documents.");
        }
      }
      final ref = _storage.ref().child('complaints/$complaintId/${imageType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      await _fetchAndLogTechnicianAction(imageType, buildingName: buildingName);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<String?> uploadComplaintImageBytes(Uint8List bytes, String complaintId, String type, {String? buildingName}) async {
    try {
      if (buildingName != null) {
        bool inRange = await verifyBuildingRange(buildingName);
        if (!inRange) {
          throw Exception("Access Restricted: Out of range to attach documents.");
        }
      }
      final ref = _storage.ref().child('complaints/$complaintId/${type}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putData(bytes);
      await _fetchAndLogTechnicianAction(type, buildingName: buildingName);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image bytes: $e");
      return null;
    }
  }

  Future<String?> uploadSignatureBytes(Uint8List signatureBytes, String complaintId, String sigType, {String? buildingName}) async {
    try {
      if (buildingName != null) {
        bool inRange = await verifyBuildingRange(buildingName);
        if (!inRange) {
          throw Exception("Access Restricted: Out of range to attach signature.");
        }
      }
      final ref = _storage.ref().child('complaints/$complaintId/${sigType}_${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(signatureBytes, SettableMetadata(contentType: 'image/png'));
      await _fetchAndLogTechnicianAction(sigType, buildingName: buildingName);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading signature: $e");
      return null;
    }
  }

  Future<void> updateConfigList(String fieldName, List<String> newList) async {
    await _db.collection(_configCollection).doc(_configDoc).set({
      fieldName: newList,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getConfig() async {
    var doc = await _db.collection(_configCollection).doc(_configDoc).get();
    return doc.data() ?? {};
  }

  Future<void> addComplaintWithId(Complaint complaint, {String actionType = 'add_complaint'}) async {
    bool inRange = await verifyBuildingRange(complaint.buildingName);
    if (!inRange) {
      throw Exception("Access Restricted: Cannot add complaint outside building range.");
    }
    await _db.collection(collectionPath).doc(complaint.id).set(complaint.toMap());
    await _fetchAndLogTechnicianAction(actionType, buildingName: complaint.buildingName);
    notifyListeners();
  }

  Future<void> updateComplaint(Complaint complaint, {String actionType = 'update_complaint'}) async {
    bool inRange = await verifyBuildingRange(complaint.buildingName);
    if (!inRange) {
      throw Exception("Access Restricted: Cannot update complaint outside building range.");
    }
    await _db.collection(collectionPath).doc(complaint.id).update(complaint.toMap());
    await _fetchAndLogTechnicianAction(actionType, buildingName: complaint.buildingName);
    notifyListeners();
  }

  Future<void> deleteComplaint(String id, String reason, {String actionType = 'delete_complaint'}) async {
    await _db.collection(collectionPath).doc(id).update({
      'isDeleted': true,
      'deleteRemarks': reason,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    await _fetchAndLogTechnicianAction(actionType);
    notifyListeners();
  }

  // --- WORKER / TECHNICIAN ACTIVITY & ATTENDANCE METHODS ---
  Stream<List<Map<String, dynamic>>> getAllTechniciansStream() {
    return _db.collection('technicians').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getTechnicianActivityLogs(
    String techUid, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('technicians')
        .doc(techUid)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true);
    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['logId'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<List<Complaint>> getComplaintsForTechnicianInRange(
    String technicianName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _db
        .collection(collectionPath)
        .where('technicianName', isEqualTo: technicianName)
        .get();
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEndExclusive =
        DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
    return snapshot.docs
        .map((doc) => Complaint.fromFirestore(doc))
        .where((c) =>
            c.createdAt.isAfter(rangeStart.subtract(const Duration(milliseconds: 1))) &&
            c.createdAt.isBefore(rangeEndExclusive))
        .toList();
  }

  Future<Map<String, int>> getTechnicianProductivitySummary(
    String technicianName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final complaints =
        await getComplaintsForTechnicianInRange(technicianName, startDate, endDate);
    int resolved = 0;
    int standby = 0;
    int pendingOrInProgress = 0;
    for (var c in complaints) {
      if (c.status == 'Resolved' || c.status == 'Closed by Customer') {
        resolved++;
      } else if (c.status == 'Standby') {
        standby++;
      } else {
        pendingOrInProgress++;
      }
    }
    return {
      'total': complaints.length,
      'resolved': resolved,
      'standby': standby,
      'pendingOrInProgress': pendingOrInProgress,
    };
  }

  Future<Map<String, DateTime?>> getTechnicianTimeInOut(
    String techUid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final snapshot = await _db
        .collection('technicians')
        .doc(techUid)
        .collection('activity_logs')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
        .orderBy('timestamp', descending: false)
        .get();
    DateTime? timeIn;
    DateTime? timeOut;
    if (snapshot.docs.isNotEmpty) {
      final firstDoc = snapshot.docs.first.data();
      final lastDoc = snapshot.docs.last.data();

      if (firstDoc['timestamp'] is Timestamp) {
        timeIn = (firstDoc['timestamp'] as Timestamp).toDate();
      }
      if (lastDoc['timestamp'] is Timestamp) {
        timeOut = (lastDoc['timestamp'] as Timestamp).toDate();
      }
    }
    return {'timeIn': timeIn, 'timeOut': timeOut};
  }
}