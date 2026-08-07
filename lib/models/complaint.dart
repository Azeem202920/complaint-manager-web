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
  final String materialsUsed;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> timelineLogs;
  final bool isDeleted;
  
  // Media & Signature URLs
  final String? beforeImageUrl;
  final String? standbyImageUrl;
  final String? afterImageUrl;
  final String? technicianSignatureUrl;
  final String? customerSignatureUrl;
  
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
    this.materialsUsed = '',
    this.imageUrls = const [],
    this.timelineLogs = const [],
    this.isDeleted = false,
    this.beforeImageUrl,
    this.standbyImageUrl,
    this.afterImageUrl,
    this.technicianSignatureUrl,
    this.customerSignatureUrl,
    this.startTime,
    this.standbyTime,
    this.completedAt,
    this.standbyBy,
    this.closedBy,
    this.deleteRemarks,
    this.finalRemarks = '',
  });
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
    String? materialsUsed,
    bool? isDeleted,
    String? deleteRemarks,
    String? finalRemarks,
    List<String>? imageUrls,
    List<Map<String, dynamic>>? timelineLogs,
    String? beforeImageUrl,
    String? standbyImageUrl,
    String? afterImageUrl,
    String? technicianSignatureUrl,
    String? customerSignatureUrl,
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
      timelineLogs: timelineLogs ?? this.timelineLogs,
      buildingName: buildingName ?? this.buildingName,
      flatNumber: flatNumber ?? this.flatNumber,
      complaintType: complaintType ?? this.complaintType,
      description: description ?? this.description,
      status: status ?? this.status,
      standbyReason: standbyReason ?? this.standbyReason,
      technicianName: technicianName ?? this.technicianName,
      startTime: startTime ?? this.startTime,
      standbyTime: standbyTime ?? this.standbyTime,
      completedAt: completedAt ?? this.completedAt,
      standbyBy: standbyBy ?? this.standbyBy,
      closedBy: closedBy ?? this.closedBy,
      serviceReportNumber: serviceReportNumber ?? this.serviceReportNumber,
      materialsUsed: materialsUsed ?? this.materialsUsed,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteRemarks: deleteRemarks ?? this.deleteRemarks,
      finalRemarks: finalRemarks ?? this.finalRemarks,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      standbyImageUrl: standbyImageUrl ?? this.standbyImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      technicianSignatureUrl: technicianSignatureUrl ?? this.technicianSignatureUrl,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
    );
  }
  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    DateTime? parseFlexibleDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }
    List<Map<String, dynamic>> parsedTimelineLogs = [];
    if (data['timelineLogs'] != null) {
      parsedTimelineLogs = List<Map<String, dynamic>>.from(
        (data['timelineLogs'] as List).map((item) => Map<String, dynamic>.from(item)),
      );
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
      materialsUsed: data['materialsUsed'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      timelineLogs: parsedTimelineLogs,
      isDeleted: data['isDeleted'] ?? false,
      beforeImageUrl: data['beforeImageUrl'],
      standbyImageUrl: data['standbyImageUrl'],
      afterImageUrl: data['afterImageUrl'],
      technicianSignatureUrl: data['technicianSignatureUrl'],
      customerSignatureUrl: data['customerSignatureUrl'],
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
      'materialsUsed': materialsUsed,
      'imageUrls': imageUrls,
      'timelineLogs': timelineLogs,
      'isDeleted': isDeleted,
      'beforeImageUrl': beforeImageUrl,
      'standbyImageUrl': standbyImageUrl,
      'afterImageUrl': afterImageUrl,
      'technicianSignatureUrl': technicianSignatureUrl,
      'customerSignatureUrl': customerSignatureUrl,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'standbyTime': standbyTime != null ? Timestamp.fromDate(standbyTime!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'standbyBy': standbyBy,
      'closedBy': closedBy,
      'deleteRemarks': deleteRemarks,
      'finalRemarks': finalRemarks,
    };
  }
  Map<String, dynamic> toJson() => toMap();
}