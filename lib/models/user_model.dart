class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role; // 'customer', 'technician', 'admin'
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'customer',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}