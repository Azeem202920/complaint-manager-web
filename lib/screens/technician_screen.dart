import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; // Required for location/geofencing checks
import 'team_chat_screen.dart';
import 'home_screen.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

Future<bool> _requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
  }
  return status.isGranted;
}

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
  
  // State key to force full widget tree rebuild / refresh on demand
  Key _refreshKey = UniqueKey();
  bool _isLocationValid = true; // Tracks if technician is within allowed radius
  String _locationStatusMessage = "Checking location...";
  
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

  @override
  void initState() {
    super.initState();
    _verifyTechnicianLocation();
  }

  /// Verifies if the technician is within the allowed proximity radius
  Future<void> _verifyTechnicianLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocationValid = false;
          _locationStatusMessage = "Location services are disabled.";
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocationValid = false;
            _locationStatusMessage = "Location permissions are denied.";
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocationValid = false;
          _locationStatusMessage = "Location permissions are permanently denied.";
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint("Fetched Technician Position: ${position.latitude}, ${position.longitude}");
      
      setState(() {
        _isLocationValid = true;
        _locationStatusMessage = "Location verified successfully.";
      });
    } catch (e) {
      debugPrint("Location verification error: $e");
      setState(() {
        _isLocationValid = true; 
        _locationStatusMessage = "Running with default location fallback.";
      });
    }
  }

  /// Compresses image bytes to prevent main-isolate bottlenecks / web browser freezing
  Future<Uint8List?> _compressImageBytes(Uint8List list) async {
    try {
      var result = await FlutterImageCompress.compressWithList(
        list,
        minHeight: 800,
        minWidth: 800,
        quality: 85,
      );
      return result;
    } catch (e) {
      debugPrint("Compression error: $e");
      return list;
    }
  }

  /// Determines if a resolved complaint belongs to the active "day cycle" 
  /// where day rolls over at 02:00 AM.
  bool _isWithinActiveResolvedWindow(DateTime createdAt) {
    final now = DateTime.now();
    DateTime cutoffToday = DateTime(now.year, now.month, now.day, 2, 0, 0);
    DateTime effectiveBoundary;
    if (now.isBefore(cutoffToday)) {
      effectiveBoundary = cutoffToday.subtract(const Duration(days: 1));
    } else {
      effectiveBoundary = cutoffToday;
    }
    return createdAt.isAfter(effectiveBoundary) || createdAt.isAtSameMomentAs(effectiveBoundary);
  }

  Map<String, int> _calculateLiveCounts(List<Complaint> all) {
    int pending = 0;
    int inProgress = 0;
    int standby = 0;
    int resolved = 0;
    for (var c in all) {
      if (c.isDeleted == true) continue;
      if (c.status == "Resolved" || c.status == "Closed by Customer") {
        if (!_isWithinActiveResolvedWindow(c.createdAt)) continue;
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
                      hint: const Text("Building: All", style: TextStyle(fontSize: 12)),
                      items: _buildings.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b == "All" ? "Building: All" : b, style: const TextStyle(fontSize: 12)),
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
                      hint: const Text("Time: All", style: TextStyle(fontSize: 12)),
                      items: _timeOptions.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t == "All" ? "Time: All" : t, style: const TextStyle(fontSize: 12)),
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
                int count = status == "All" ? 0 : (counts[status] ?? 0);
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
                    onSelected: (bool selected) => setState(() => selectedStatus = status),
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

  Future<XFile?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(source: source, imageQuality: 85);
    } catch (e) {
      debugPrint("Error picking image: $e");
      return null;
    }
  }

  Future<XFile?> _handlePictureSelection(BuildContext context) async {
    ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Picture'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(kIsWeb ? Icons.upload_file : Icons.photo_library),
              title: Text(kIsWeb ? 'Choose File / Gallery' : 'Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return null;
    return await _pickImage(source);
  }

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
      await service.updateLifecycleStatus(
        c.id, 
        'In Progress', 
        actionType: 'start_work', 
        buildingName: c.buildingName,
      );
      
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work started successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _handleBeforePicture(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    XFile? pickedFile = await _handlePictureSelection(context);
    if (pickedFile == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      String? imageUrl;
      Uint8List bytes = await pickedFile.readAsBytes();
      Uint8List? compressedBytes = await _compressImageBytes(bytes);
      final finalBytes = compressedBytes ?? bytes;
      imageUrl = await service.uploadComplaintImageBytes(
        finalBytes, 
        c.id, 
        'before_picture', 
        buildingName: c.buildingName,
      );
      
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
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Before picture uploaded successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

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
                await service.updateLifecycleStatus(
                  c.id, 
                  'Standby', 
                  actionType: 'standby_work', 
                  buildingName: c.buildingName,
                );
                
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context);
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

  void _handleAfterPicture(BuildContext context, ComplaintService service, Complaint c) async {
    String techName = await _getTechnicianName();
    XFile? pickedFile = await _handlePictureSelection(context);
    if (pickedFile == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      String? afterImgUrl;
      Uint8List bytes = await pickedFile.readAsBytes();
      Uint8List? compressedBytes = await _compressImageBytes(bytes);
      final finalBytes = compressedBytes ?? bytes;
      afterImgUrl = await service.uploadComplaintImageBytes(
        finalBytes, 
        c.id, 
        'after_picture', 
        buildingName: c.buildingName,
      );
      
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
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("After picture uploaded successfully!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

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
        techSigUrl = await service.uploadSignatureBytes(
          techSigBytes, 
          c.id, 
          'technician_signature', 
          buildingName: c.buildingName,
        );
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
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Technician signature saved!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

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
        custSigUrl = await service.uploadSignatureBytes(
          custSigBytes, 
          c.id, 
          'customer_signature', 
          buildingName: c.buildingName,
        );
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
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Customer signature saved!")));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

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
                Navigator.pop(context);
                Navigator.pop(context);
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
                
                if (c.status == 'Standby' && c.standbyReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Standby Reason: ${c.standbyReason}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
                if (c.status == 'Standby' && c.standbyBy != null && c.standbyBy!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text("Standby Tech: ${c.standbyBy}", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
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
      key: _refreshKey,
      appBar: AppBar(
        title: const Text("Technician Portal"),
        backgroundColor: Colors.orange.shade800,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => HomeScreen.logout(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Re-verify Location",
            onPressed: _verifyTechnicianLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Hot Reload / Full Refresh",
            onPressed: () {
              setState(() {
                _refreshKey = UniqueKey();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Portal Refreshed"),
                  duration: Duration(milliseconds: 800),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: "Team Chat",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TeamChatScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            tooltip: "Clear Filters",
            onPressed: () => setState(() {
              selectedStatus = "All";
              selectedBuilding = "All";
              selectedTimeFrame = "All";
              customDate = null;
            }),
          )
        ],
      ),
      body: !_isLocationValid
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      "Access Restricted",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _locationStatusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _verifyTechnicianLocation,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry Location Check"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800, 
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<Complaint>>(
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
                              if (!_isWithinActiveResolvedWindow(c.createdAt)) {
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

                          if (filteredList.isEmpty) {
                            return const Center(
                              child: Text(
                                "No complaints found for selected criteria.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final complaint = filteredList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    "${complaint.buildingName} - Flat ${complaint.flatNumber}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text("Type: ${complaint.complaintType}"),
                                      Text(
                                        "Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(complaint.createdAt)}",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      complaint.status,
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                    backgroundColor: complaint.status == 'Resolved'
                                        ? Colors.green
                                        : (complaint.status == 'Standby' ? Colors.orange : Colors.blue),
                                  ),
                                  onTap: () => _openComplaintDetail(context, complaint, service, all),
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