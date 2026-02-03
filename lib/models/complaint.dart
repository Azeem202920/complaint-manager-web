import 'dart:convert';

class Complaint {
  final String id;
  final String customerName;
  final String customerPhone;
  final String address;
  final String problemDescription;
  final String category;
  final DateTime createdAt;
  final String status;
  final String? technicianId;
  final String? technicianName;
  final String? notes;
  final List<String>? imageUrls;
  final String? estimatedCost;
  final String? actualCost;
  final DateTime? updatedAt;
  final String? priority;
  
  // New fields to match RegisterComplaintScreen
  final String? flatNumber;
  final String? buildingName;
  final String? complaintType;
  final String? description;

  Complaint({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.problemDescription,
    required this.category,
    required this.createdAt,
    this.status = 'Pending',
    this.technicianId,
    this.technicianName,
    this.notes,
    this.imageUrls,
    this.estimatedCost,
    this.actualCost,
    this.updatedAt,
    this.priority = 'Medium',
    this.flatNumber,
    this.buildingName,
    this.complaintType,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': address,
      'problemDescription': problemDescription,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'notes': notes,
      'imageUrls': imageUrls,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'updatedAt': updatedAt?.toIso8601String(),
      'priority': priority,
      'flatNumber': flatNumber,
      'buildingName': buildingName,
      'complaintType': complaintType,
      'description': description,
    };
  }

  factory Complaint.fromMap(Map<String, dynamic> map, String id) {
    // Helper to handle date parsing safely
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      try {
        return DateTime.parse(date.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    return Complaint(
      id: id,
      customerName: map['customerName'] ?? 'Unknown Customer',
      customerPhone: map['customerPhone'] ?? '',
      address: map['address'] ?? '',
      problemDescription: map['problemDescription'] ?? '',
      category: map['category'] ?? 'Other',
      createdAt: parseDate(map['createdAt']),
      status: map['status'] ?? 'Pending',
      technicianId: map['technicianId'],
      technicianName: map['technicianName'],
      notes: map['notes'],
      imageUrls: map['imageUrls'] != null ? List<String>.from(map['imageUrls']) : null,
      estimatedCost: map['estimatedCost'],
      actualCost: map['actualCost'],
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : null,
      priority: map['priority'] ?? 'Medium',
      flatNumber: map['flatNumber'],
      buildingName: map['buildingName'],
      complaintType: map['complaintType'],
      description: map['description'],
    );
  }

  Complaint copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? address,
    String? problemDescription,
    String? category,
    DateTime? createdAt,
    String? status,
    String? technicianId,
    String? technicianName,
    String? notes,
    List<String>? imageUrls,
    String? estimatedCost,
    String? actualCost,
    DateTime? updatedAt,
    String? priority,
    String? flatNumber,
    String? buildingName,
    String? complaintType,
    String? description,
  }) {
    return Complaint(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      address: address ?? this.address,
      problemDescription: problemDescription ?? this.problemDescription,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      flatNumber: flatNumber ?? this.flatNumber,
      buildingName: buildingName ?? this.buildingName,
      complaintType: complaintType ?? this.complaintType,
      description: description ?? this.description,
    );
  }

  String toJson() => json.encode(toMap());
  factory Complaint.fromJson(String source) => Complaint.fromMap(json.decode(source), '');
}