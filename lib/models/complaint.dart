import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String customerPhone;
  final String customerName;
  final String address;
  final String category;
  final DateTime createdAt;
  final String status;
  final String priority;
  final String flatNumber;
  final String buildingName;
  final String complaintType;
  final String description;
  final String standbyReason;
  final String? technicianName;
  final String? serviceReportNumber;
  final List<String> imageUrls;
  final bool isDeleted;
  
  // Lifecycle & Audit Fields
  final DateTime? startTime;
  final DateTime? standbyTime;
  final DateTime? completedAt;
  final String? standbyBy;
  final String? closedBy;
  final String? deleteRemarks;
  final String finalRemarks;

  Complaint({
    required this.id,
    required this.customerPhone,
    required this.customerName,
    required this.address,
    required this.category,
    required this.createdAt,
    required this.status,
    required this.priority,
    required this.flatNumber,
    required this.buildingName,
    required this.complaintType,
    required this.description,
    required this.standbyReason,
    this.technicianName,
    this.serviceReportNumber,
    this.imageUrls = const [],
    this.isDeleted = false,
    this.startTime,
    this.standbyTime,
    this.completedAt,
    this.standbyBy,
    this.closedBy,
    this.deleteRemarks,
    this.finalRemarks = '',
  });

  /// Master copyWith: Updated to include technicianName and finalRemarks
  Complaint copyWith({
    String? id,
    String? buildingName,
    String? flatNumber,
    String? complaintType,
    String? description,
    String? status,
    String? standbyReason,
    String? technicianName,
    DateTime? startTime,
    DateTime? standbyTime,
    DateTime? completedAt,
    String? standbyBy,
    String? closedBy,
    String? serviceReportNumber,
    bool? isDeleted,
    String? deleteRemarks,
    String? finalRemarks,
    List<String>? imageUrls,
  }) {
    return Complaint(
      id: id ?? this.id,
      customerPhone: this.customerPhone,
      customerName: this.customerName,
      address: this.address,
      category: this.category,
      createdAt: this.createdAt,
      priority: this.priority,
      imageUrls: imageUrls ?? this.imageUrls,
      buildingName: buildingName ?? this.buildingName,
      flatNumber: flatNumber ?? this.flatNumber,
      complaintType: complaintType ?? this.complaintType,
      description: description ?? this.description,
      status: status ?? this.status,
      standbyReason: standbyReason ?? this.standbyReason,
      technicianName: technicianName ?? this.technicianName, // Corrected logic
      startTime: startTime ?? this.startTime,
      standbyTime: standbyTime ?? this.standbyTime,
      completedAt: completedAt ?? this.completedAt,
      standbyBy: standbyBy ?? this.standbyBy,
      closedBy: closedBy ?? this.closedBy,
      serviceReportNumber: serviceReportNumber ?? this.serviceReportNumber,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteRemarks: deleteRemarks ?? this.deleteRemarks,
      finalRemarks: finalRemarks ?? this.finalRemarks,
    );
  }

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Robust parser to handle Timestamps or ISO8601 Strings
    DateTime? parseFlexibleDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Complaint(
      id: doc.id,
      customerPhone: data['customerPhone'] ?? '',
      customerName: data['customerName'] ?? '',
      address: data['address'] ?? '',
      category: data['category'] ?? '',
      createdAt: parseFlexibleDate(data['createdAt']) ?? DateTime.now(),
      status: data['status'] ?? 'Pending',
      priority: data['priority'] ?? 'Medium',
      flatNumber: data['flatNumber'] ?? '',
      buildingName: data['buildingName'] ?? '',
      complaintType: data['complaintType'] ?? '',
      description: data['description'] ?? '',
      standbyReason: data['standbyReason'] ?? '',
      technicianName: data['technicianName'],
      serviceReportNumber: data['serviceReportNumber'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isDeleted: data['isDeleted'] ?? false,
      startTime: parseFlexibleDate(data['startTime']),
      standbyTime: parseFlexibleDate(data['standbyTime']),
      completedAt: parseFlexibleDate(data['completedAt']),
      standbyBy: data['standbyBy'],
      closedBy: data['closedBy'],
      deleteRemarks: data['deleteRemarks'],
      finalRemarks: data['finalRemarks'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerPhone': customerPhone,
      'customerName': customerName,
      'address': address,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'priority': priority,
      'flatNumber': flatNumber,
      'buildingName': buildingName,
      'complaintType': complaintType,
      'description': description,
      'standbyReason': standbyReason,
      'technicianName': technicianName,
      'serviceReportNumber': serviceReportNumber,
      'imageUrls': imageUrls,
      'isDeleted': isDeleted,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'standbyTime': standbyTime != null ? Timestamp.fromDate(standbyTime!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'standbyBy': standbyBy,
      'closedBy': closedBy,
      'deleteRemarks': deleteRemarks,
      'finalRemarks': finalRemarks,
    };
  }
}