import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'dart:io' as io;
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'home_screen.dart';

class TechnicianScreen extends StatefulWidget {
  const TechnicianScreen({super.key});

  @override
  State<TechnicianScreen> createState() => _TechnicianScreenState();
}

class _TechnicianScreenState extends State<TechnicianScreen> {
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  DateTime? customDate;

  final List<String> _timeOptions = const ["All", "Today", "Yesterday", "Select Date"];
  
  final List<String> _quickMaterials = const [
    "Capacitor 55uF", "Contactor 3P 220v", "Capacitor 5uF", "Contactor 2P 220v", 
    "Refrigerant R410a", "Refrigerant R22", "Breaker", "Filter", "Fan Motor", "Relay"
  ];
  
  final List<String> _buildings = [
    "All", "Expo Tower", "Gate Tower 1", "Gate Tower 2", "Al Khor Tower C",
    "Rital & Rinad", "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5", "Naseem",
    "Hala Building", "Nada building", "Al Tameer", "Tallah Mall", "Al Khor Mall",
    "Mazaya", "Yasmeen Tower", "Ajman Club", "Salah Ud Din", "Sara Plaza 3", "Jurf 2",
    "Flower Shop", "Amina Hospital", "Villas", "Sharjah", "Rashdiya", "Galleria Mall",
    "N/A", "Others"
  ];
  
  final List<String> _statusOptions = ["All", "Pending", "In Progress", "Standby", "Resolved"];

  // --- HELPER METHODS FOR ADMIN FILTER SECTION ---
  Map<String, int> _calculateLiveCounts(List<Complaint> all) {
    int pending = 0;
    int inProgress = 0;
    int standby = 0;
    int resolved = 0;

    for (var c in all) {
      if (c.isDeleted == true) continue;
      if (c.status == "Resolved" || c.status == "Closed by Customer") {
        if (!_isSameDay(c.createdAt, DateTime.now())) {
          continue;
        }
      }
      
      bool matchBuilding = selectedBuilding == "All" || c.buildingName == selectedBuilding;
      bool matchTime = true;
      if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
      if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
      if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);

      if (matchBuilding && matchTime) {
        if (c.status == "Pending") pending++;
        if (c.status == "In Progress") inProgress++;
        if (c.status == "Standby") standby++;
        if (c.status == "Resolved" || c.status == "Closed by Customer") resolved++;
      }
    }
    return {
      "Pending": pending,
      "In Progress": inProgress,
      "Standby": standby,
      "Resolved": resolved,
    };
  }

  Widget _buildFilterBar(Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBuilding,
                      isExpanded: true,
                      items: _buildings.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (val) => setState(() => selectedBuilding = val ?? "All"),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTimeFrame,
                      isExpanded: true,
                      items: _timeOptions.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (val) async {
                        if (val == "Select Date") {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: customDate ?? DateTime.now(),
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedTimeFrame = val!;
                              customDate = picked;
                            });
                          }
                        } else {
                          setState(() {
                            selectedTimeFrame = val!;
                            if (val != "Select Date") customDate = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (selectedTimeFrame == "Select Date" && customDate != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => setState(() {
                    selectedTimeFrame = "All";
                    customDate = null;
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((status) {
                bool isSelected = selectedStatus == status;
                int count = 0;
                if (status != "All") {
                  count = counts[status] ?? 0;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      status == "All" ? "All" : "$status ($count)",
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.orange.shade800,
                    backgroundColor: Colors.white,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedStatus = status;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getTechnicianName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? "Unknown Tech";
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  // --- SAFE IMAGE PICKER FOR WEB & MOBILE ---
  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
  }

  // --- INDIVIDUAL ACTIONS ---
  // 1. Start Work
  void _handleStartWorkOnly(BuildContext context, ComplaintService service, Complaint c) async {
    bool isCompleted = c.status == 'Resolved' || c.status == 'Closed by Customer';
    if (isCompleted) return;
    String techName = await _getTechnicianName();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
      updatedLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'In Progress',
        'userName': techName,
        'remarks': 'Work started'
      });
      Complaint updated = c.copyWith(
        status: "In Progress",
        technicianName: techName,
        startTime: DateTime.now(),
        timelineLogs: updatedLogs,
      );
      
      await service.updateComplaint(updated);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loader
      Navigator.pop(context); // Pop details screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work started successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 2. Before Picture
  void _handleBeforePicture(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    XFile? pickedFile = await _pickImage();
    if (pickedFile == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      String? imageUrl;
      if (kIsWeb) {
        Uint8List bytes = await pickedFile.readAsBytes();
        imageUrl = await service.uploadComplaintImageBytes(bytes, c.id, 'before');
      } else {
        imageUrl = await service.uploadComplaintImage(io.File(pickedFile.path), c.id, 'before');
      }
      List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
      updatedLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'status': c.status,
        'userName': techName,
        'remarks': 'Before picture attached'
      });
      Complaint updated = c.copyWith(
        beforeImageUrl: imageUrl,
        timelineLogs: updatedLogs,
      );
      
      await service.updateComplaint(updated);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loader
      Navigator.pop(context); // Pop details screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Before picture uploaded successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 3. Standby
  void _handleStandbyOnly(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Put Complaint on Standby"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for putting this complaint on standby:"),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Standby Reason", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
                return;
              }
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              try {
                List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
                updatedLogs.add({
                  'timestamp': DateTime.now().toIso8601String(),
                  'status': 'Standby',
                  'userName': techName,
                  'remarks': 'Standby: ${reasonController.text.trim()}'
                });
                Complaint updated = c.copyWith(
                  status: "Standby",
                  technicianName: techName,
                  standbyBy: techName,
                  standbyTime: DateTime.now(),
                  standbyReason: reasonController.text.trim(),
                  timelineLogs: updatedLogs,
                );
                
                await service.updateComplaint(updated);
                
                if (!context.mounted) return;
                Navigator.pop(context); // Pop loader
                Navigator.pop(context); // Pop details screen
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complaint marked as Standby")));
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Confirm Standby"),
          ),
        ],
      ),
    );
  }

  // 4. After Picture
  void _handleAfterPicture(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    XFile? pickedFile = await _pickImage();
    if (pickedFile == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      String? afterImgUrl;
      if (kIsWeb) {
        Uint8List bytes = await pickedFile.readAsBytes();
        afterImgUrl = await service.uploadComplaintImageBytes(bytes, c.id, 'after');
      } else {
        afterImgUrl = await service.uploadComplaintImage(io.File(pickedFile.path), c.id, 'after');
      }
      List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
      updatedLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'status': c.status,
        'userName': techName,
        'remarks': 'After picture attached'
      });
      Complaint updated = c.copyWith(
        afterImageUrl: afterImgUrl,
        timelineLogs: updatedLogs,
      );
      
      await service.updateComplaint(updated);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loader
      Navigator.pop(context); // Pop details screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("After picture uploaded successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 5. Technician Signature
  void _handleTechSignature(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    final SignatureController techSigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool? techSigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Technician Signature"),
        content: SizedBox(
          width: 400,
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: Signature(controller: techSigController, backgroundColor: Colors.white),
                ),
              ),
              TextButton(onPressed: () => techSigController.clear(), child: const Text("Clear"))
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm Signature")),
        ],
      ),
    );
    if (techSigned != true || techSigController.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final techSigBytes = await techSigController.toPngBytes();
      String? techSigUrl;
      if (techSigBytes != null) {
        techSigUrl = await service.uploadSignatureBytes(techSigBytes, c.id, 'tech_sig');
      }
      List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
      updatedLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'status': c.status,
        'userName': techName,
        'remarks': 'Technician signature added'
      });
      Complaint updated = c.copyWith(
        technicianSignatureUrl: techSigUrl,
        timelineLogs: updatedLogs,
      );
      
      await service.updateComplaint(updated);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loader
      Navigator.pop(context); // Pop details screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Technician signature saved!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 6. Customer Signature
  void _handleCustSignature(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    final SignatureController custSigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool? custSigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Customer Signature"),
        content: SizedBox(
          width: 400,
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: Signature(controller: custSigController, backgroundColor: Colors.white),
                ),
              ),
              TextButton(onPressed: () => custSigController.clear(), child: const Text("Clear"))
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm Signature")),
        ],
      ),
    );
    if (custSigned != true || custSigController.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final custSigBytes = await custSigController.toPngBytes();
      String? custSigUrl;
      if (custSigBytes != null) {
        custSigUrl = await service.uploadSignatureBytes(custSigBytes, c.id, 'cust_sig');
      }
      List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
      updatedLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'status': c.status,
        'userName': techName,
        'remarks': 'Customer signature added'
      });
      Complaint updated = c.copyWith(
        customerSignatureUrl: custSigUrl,
        timelineLogs: updatedLogs,
      );
      
      await service.updateComplaint(updated);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loader
      Navigator.pop(context); // Pop details screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Customer signature saved!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 7. Complete Task
  void _handleCompleteTask(BuildContext context, ComplaintService service, Complaint c) async {
    final materialsController = TextEditingController(text: c.materialsUsed);
    final remarksController = TextEditingController(text: c.finalRemarks);
    final reportNoController = TextEditingController(text: c.serviceReportNumber ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Complete & Close Task"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: reportNoController,
                  decoration: const InputDecoration(labelText: "Service Report # / Serial No *", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: materialsController,
                  decoration: const InputDecoration(labelText: "Materials Used", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _quickMaterials.map((m) => ActionChip(
                    label: Text(m, style: const TextStyle(fontSize: 10)),
                    onPressed: () {
                      String current = materialsController.text;
                      materialsController.text = current.isEmpty ? m : "$current, $m";
                    },
                  )).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: "Closing Remarks", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (reportNoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter service report number")));
                return;
              }
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              try {
                String techName = await _getTechnicianName();
                List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
                String nowIso = DateTime.now().toIso8601String();
                
                if (c.afterImageUrl != null && !updatedLogs.any((l) => l['remarks'] == 'After picture attached')) {
                  updatedLogs.add({
                    'timestamp': nowIso,
                    'status': 'Resolved',
                    'userName': techName,
                    'remarks': 'After picture attached'
                  });
                }
                if (c.technicianSignatureUrl != null && !updatedLogs.any((l) => l['remarks'] == 'Technician signature added')) {
                  updatedLogs.add({
                    'timestamp': nowIso,
                    'status': 'Resolved',
                    'userName': techName,
                    'remarks': 'Technician signature added'
                  });
                }
                if (c.customerSignatureUrl != null && !updatedLogs.any((l) => l['remarks'] == 'Customer signature added')) {
                  updatedLogs.add({
                    'timestamp': nowIso,
                    'status': 'Resolved',
                    'userName': techName,
                    'remarks': 'Customer signature added'
                  });
                }
                
                updatedLogs.add({
                  'timestamp': nowIso,
                  'status': 'Resolved',
                  'userName': techName,
                  'remarks': remarksController.text.trim()
                });
                Complaint updated = c.copyWith(
                  status: "Resolved",
                  technicianName: techName,
                  completedAt: DateTime.now(),
                  serviceReportNumber: reportNoController.text.trim(),
                  materialsUsed: materialsController.text.trim(),
                  finalRemarks: remarksController.text.trim(),
                  timelineLogs: updatedLogs,
                  beforeImageUrl: c.beforeImageUrl,
                  afterImageUrl: c.afterImageUrl,
                  standbyImageUrl: c.standbyImageUrl,
                  technicianSignatureUrl: c.technicianSignatureUrl,
                  customerSignatureUrl: c.customerSignatureUrl,
                );
                
                await service.updateComplaint(updated);
                
                if (!context.mounted) return;
                Navigator.pop(context); // Loader
                Navigator.pop(context); // Detail Screen
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task completed successfully!")));
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Save & Complete"),
          ),
        ],
      ),
    );
  }

  // --- FLAT HISTORY DIALOG ---
  void _showFlatHistoryDialog(BuildContext context, Complaint currentComplaint, List<Complaint> allComplaints) {
    final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
    final flatHistory = allComplaints.where((c) {
      if (c.isDeleted == true) return false;
      if (c.id == currentComplaint.id) return false;
      
      bool sameBuilding = c.buildingName.trim().toLowerCase() == currentComplaint.buildingName.trim().toLowerCase();
      bool sameFlat = c.flatNumber.trim().toLowerCase() == currentComplaint.flatNumber.trim().toLowerCase();
      bool withinTwoYears = c.createdAt.isAfter(twoYearsAgo);
      return sameBuilding && sameFlat && withinTwoYears;
    }).toList();
    flatHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("History: ${currentComplaint.buildingName} - ${currentComplaint.flatNumber}", style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: flatHistory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No previous complaint history found for this flat in the past 2 years.", textAlign: TextAlign.center),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: flatHistory.length,
                  itemBuilder: (context, index) {
                    final h = flatHistory[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(h.complaintType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(h.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: h.status == "Resolved" ? Colors.green : Colors.orange)),
                              ],
                            ),
                            if (h.description.isNotEmpty)
                              Text("Remarks: ${h.description}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            if (h.finalRemarks != null && h.finalRemarks!.isNotEmpty)
                              Text("Tech Notes: ${h.finalRemarks}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(h.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  // --- OPEN DETAIL VIEW (ACTION SHEET) ---
  void _openComplaintDetail(BuildContext context, Complaint c, ComplaintService service, List<Complaint> allComplaints) {
    final bool isCompleted = c.status == 'Resolved' || c.status == 'Closed by Customer';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${c.buildingName} - Flat ${c.flatNumber}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            minimumSize: const Size(0, 28),
                            side: BorderSide(color: Colors.orange.shade800),
                          ),
                          icon: Icon(Icons.history, size: 14, color: Colors.orange.shade800),
                          label: Text("Flat History", style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                          onPressed: () => _showFlatHistoryDialog(context, c, allComplaints),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(c.status, style: const TextStyle(color: Colors.white)),
                          backgroundColor: c.status == 'Resolved' ? Colors.green : (c.status == 'Standby' ? Colors.orange : Colors.blue),
                        ),
                      ],
                    )
                  ],
                ),
                const Divider(),
                Text("Issue Type: ${c.complaintType}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("Description: ${c.description.isNotEmpty ? c.description : 'No description provided'}"),
                
                if (c.status == 'In Progress' || c.status == 'Standby' || isCompleted) ...[
                  const SizedBox(height: 6),
                  Text("Technician: ${c.technicianName != null && c.technicianName!.isNotEmpty ? c.technicianName : 'Unassigned'}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
                if (c.status == 'Standby' && c.standbyReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Standby Reason: ${c.standbyReason}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
                if (isCompleted && c.finalRemarks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Closing Remarks: ${c.finalRemarks}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
                if (isCompleted && c.serviceReportNumber != null && c.serviceReportNumber!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Service Report #: ${c.serviceReportNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                if (isCompleted && c.materialsUsed != null && c.materialsUsed!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Materials Used: ${c.materialsUsed}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                
                const SizedBox(height: 20),
                
                if (!isCompleted) ...[
                  const Text("Actions & Requirements", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 10),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _handleStartWorkOnly(context, service, c),
                      label: const Text("1. Start Work"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _handleBeforePicture(context, service, c),
                      label: const Text("2. Before Picture"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.pause_circle_filled),
                      onPressed: () => _handleStandbyOnly(context, service, c),
                      label: const Text("3. Standby"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.photo_camera),
                      onPressed: () => _handleAfterPicture(context, service, c),
                      label: const Text("4. After Picture"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.edit),
                      onPressed: () => _handleTechSignature(context, service, c),
                      label: const Text("5. Technician Signature"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.edit_note),
                      onPressed: () => _handleCustSignature(context, service, c),
                      label: const Text("6. Customer Signature"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.check_circle),
                      onPressed: () => _handleCompleteTask(context, service, c),
                      label: const Text("7. Complete Task"),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Technician Portal"),
        backgroundColor: Colors.orange.shade800,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => HomeScreen.logout(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () => setState(() {
              selectedStatus = "All";
              selectedBuilding = "All";
              selectedTimeFrame = "All";
              customDate = null;
            }),
          )
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: service.getAdminFullHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          Map<String, int> counts = _calculateLiveCounts(all);
          
          return Column(
            children: [
              _buildFilterBar(counts),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final filteredList = all.where((c) {
                      if (c.isDeleted == true) return false;
                      if (c.status == "Resolved" || c.status == "Closed by Customer") {
                        if (!_isSameDay(c.createdAt, DateTime.now())) {
                          return false;
                        }
                      }
                      bool matchStatus = selectedStatus == "All" || c.status == selectedStatus;
                      bool matchBuilding = selectedBuilding == "All" || c.buildingName == selectedBuilding;
                      
                      bool matchTime = true;
                      if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
                      if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
                      if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);
                      return matchStatus && matchBuilding && matchTime;
                    }).toList();
                    if (filteredList.isEmpty) return const Center(child: Text("No tasks found."));
                    
                    return ListView.builder(
                      itemCount: filteredList.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final c = filteredList[index];
                        final bool isCompleted = c.status == 'Resolved' || c.status == 'Closed by Customer';
                        final bool isStandby = c.status == "Standby";
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _openComplaintDetail(context, c, service, all),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text("${c.buildingName} - Flat ${c.flatNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Issue: ${c.complaintType}"),
                                    if (c.description.isNotEmpty) 
                                      Text("Details: ${c.description}", 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis, 
                                        style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12, fontStyle: FontStyle.italic)
                                      ),
                                    if (c.status != "Pending" && c.status != "Resolved" && c.status != "Closed by Customer")
                                       Text("Tech: ${c.technicianName ?? c.standbyBy ?? 'Assigned'}", 
                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (isStandby) Text("Reason: ${c.standbyReason}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (isCompleted && c.finalRemarks.isNotEmpty)
                                      Text("Remarks: ${c.finalRemarks}", style: const TextStyle(color: Colors.green, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(DateFormat('dd MMM, hh:mm a').format(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                            minimumSize: const Size(0, 28),
                                            side: BorderSide(color: Colors.orange.shade800),
                                          ),
                                          icon: Icon(Icons.history, size: 14, color: Colors.orange.shade800),
                                          label: Text("Flat History", style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                                          onPressed: () => _showFlatHistoryDialog(context, c, all),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCompleted ? Colors.grey.shade200 : (isStandby ? Colors.orange.shade100 : Colors.blue.shade100),
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text(c.status, style: TextStyle(
                                    color: isCompleted ? Colors.grey.shade700 : (isStandby ? Colors.orange.shade900 : Colors.blue.shade900),
                                    fontWeight: FontWeight.bold, fontSize: 11
                                  )),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}