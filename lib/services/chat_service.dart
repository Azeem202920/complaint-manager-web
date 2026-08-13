import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatMessage {
  final String id;
  final String senderName;
  final String senderId;
  final String text;
  final String? imageUrl;
  final String? linkedComplaintId;
  final String? linkedComplaintTitle;
  final String? replyToMessageId;
  final String? replyToText;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.linkedComplaintId,
    this.linkedComplaintTitle,
    this.replyToMessageId,
    this.replyToText,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'senderName': senderName,
    'senderId': senderId,
    'text': text,
    'imageUrl': imageUrl,
    'linkedComplaintId': linkedComplaintId,
    'linkedComplaintTitle': linkedComplaintTitle,
    'replyToMessageId': replyToMessageId,
    'replyToText': replyToText,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderName: data['senderName'] ?? 'Unknown',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      linkedComplaintId: data['linkedComplaintId'],
      linkedComplaintTitle: data['linkedComplaintTitle'],
      replyToMessageId: data['replyToMessageId'],
      replyToText: data['replyToText'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatGroup {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  ChatGroup({required this.id, required this.name, required this.createdBy, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory ChatGroup.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatGroup(
      id: doc.id,
      name: data['name'] ?? 'General Team',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all active chat groups
  Stream<List<ChatGroup>> getGroups() {
    return _firestore.collection('chat_groups').orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => ChatGroup.fromDoc(doc)).toList(),
    );
  }

  // Create a new group
  Future<void> createGroup(String name, String userName) async {
    await _firestore.collection('chat_groups').add({
      'name': name,
      'createdBy': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a group
  Future<void> deleteGroup(String groupId) async {
    // Delete sub-messages first or let them orphan (better practice: delete collection)
    var messages = await _firestore.collection('chat_groups').doc(groupId).collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('chat_groups').doc(groupId).delete();
  }

  // Stream messages for a specific group
  Stream<List<ChatMessage>> getMessages(String groupId) {
    return _firestore
        .collection('chat_groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessage.fromDoc(doc)).toList());
  }

  // Send a message
  Future<void> sendMessage(String groupId, ChatMessage message) async {
    await _firestore
        .collection('chat_groups')
        .doc(groupId)
        .collection('messages')
        .add(message.toMap());
  }
}