import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../services/chat_service.dart';

class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({super.key});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final ChatService _chatService = ChatService();
  final ComplaintService _complaintService = ComplaintService();
  final TextEditingController _msgController = TextEditingController();
  
  String? currentUserId;
  String currentUserName = "Loading...";
  String selectedGroupId = "general";
  String selectedGroupName = "General Team Chat";
  
  ChatMessage? replyingTo;
  Complaint? attachedComplaint;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('user_id') ?? prefs.getString('user_name') ?? "tech_user";
      currentUserName = prefs.getString('user_name') ?? "Team Member";
    });
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create New Chat Group"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Group Name (e.g. Gate 1 & 2)", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await _chatService.createGroup(nameController.text.trim(), currentUserName);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showLinkComplaintDialog() async {
    List<Complaint>? complaints = await _complaintService.getAdminFullHistory().first;
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Link a Complaint"),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final c = complaints[index];
              return ListTile(
                title: Text("${c.buildingName} - Flat ${c.flatNumber}"),
                subtitle: Text("Issue: ${c.complaintType} (${c.status})"),
                onTap: () {
                  setState(() {
                    attachedComplaint = c;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ],
      ),
    );
  }

  void _send({String? imageUrl}) async {
    if (_msgController.text.trim().isEmpty && imageUrl == null && attachedComplaint == null) return;
    
    ChatMessage message = ChatMessage(
      id: '',
      senderName: currentUserName,
      senderId: currentUserId ?? 'unknown',
      text: _msgController.text.trim(),
      imageUrl: imageUrl,
      linkedComplaintId: attachedComplaint?.id,
      linkedComplaintTitle: attachedComplaint != null ? "${attachedComplaint!.buildingName} - Flat ${attachedComplaint!.flatNumber}" : null,
      replyToMessageId: replyingTo?.id,
      replyToText: replyingTo?.text,
      timestamp: DateTime.now(),
    );

    await _chatService.sendMessage(selectedGroupId, message);
    
    _msgController.clear();
    setState(() {
      replyingTo = null;
      attachedComplaint = null;
    });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile == null) return;

    // Use standard storage upload if available, or convert bytes
    // For simplicity, we can upload using the ComplaintService helper or handle directly
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      String? imageUrl;
      if (kIsWeb) {
        Uint8List bytes = await pickedFile.readAsBytes();
        imageUrl = await _complaintService.uploadComplaintImageBytes(bytes, 'chat_img_${DateTime.now().millisecondsSinceEpoch}', 'chat');
      } else {
        imageUrl = await _complaintService.uploadComplaintImage(io.File(pickedFile.path), 'chat_img_${DateTime.now().millisecondsSinceEpoch}', 'chat');
      }
      if (!mounted) return;
      Navigator.pop(context); // Pop loader
      _send(imageUrl: imageUrl);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Team Chat: $selectedGroupName"),
        backgroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "Create Group",
            onPressed: _showCreateGroupDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (groupId) {
              if (groupId == "general") {
                setState(() {
                  selectedGroupId = "general";
                  selectedGroupName = "General Team Chat";
                });
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(value: "general", child: Text("General Team Chat")),
              ];
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Group Selection Horizontal Bar
          Container(
            height: 50,
            color: Colors.grey.shade100,
            child: StreamBuilder<List<ChatGroup>>(
              stream: _chatService.getGroups(),
              builder: (context, snapshot) {
                List<ChatGroup> groups = [ChatGroup(id: 'general', name: 'General', createdBy: 'System', createdAt: DateTime.now())];
                if (snapshot.hasData) {
                  groups.addAll(snapshot.data!);
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    bool isSelected = selectedGroupId == g.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: ChoiceChip(
                        label: Text(g.name),
                        selected: isSelected,
                        selectedColor: Colors.orange,
                        onSelected: (_) {
                          setState(() {
                            selectedGroupId = g.id;
                            selectedGroupName = g.name;
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Messages List View
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(selectedGroupId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text("No messages here yet. Start the conversation!"));
                }
                
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    bool isMe = m.senderId == currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(m.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange.shade900)),
                            
                            // Reply context preview if any
                            if (m.replyToText != null)
                              Container(
                                padding: const EdgeInsets.all(4),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                                child: Text("Replying to: ${m.replyToText}", style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                              ),

                            // Linked Complaint Widget if any
                            if (m.linkedComplaintId != null)
                              Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text("Complaint: ${m.linkedComplaintTitle}", style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),

                            // Image Attachment if any
                            if (m.imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(m.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                                ),
                              ),

                            if (m.text.isNotEmpty)
                              Text(m.text, style: const TextStyle(fontSize: 14)),
                            
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(DateFormat('hh:mm a').format(m.timestamp), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => replyingTo = m),
                                  child: const Text("Reply", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Active Reply / Attachment Preview Bar
          if (replyingTo != null || attachedComplaint != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      replyingTo != null ? "Replying to: ${replyingTo!.text}" : "Linked: ${attachedComplaint!.buildingName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      replyingTo = null;
                      attachedComplaint = null;
                    }),
                  )
                ],
              ),
            ),

          // Message Input Box
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.grey),
                  onPressed: _pickAndSendImage,
                ),
                IconButton(
                  icon: const Icon(Icons.link, color: Colors.grey),
                  tooltip: "Link Complaint",
                  onPressed: _showLinkComplaintDialog,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: "Type team message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: () => _send(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}