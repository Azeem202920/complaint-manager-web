import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkerActivityScreen extends StatefulWidget {
  const WorkerActivityScreen({super.key});

  @override
  State<WorkerActivityScreen> createState() => _WorkerActivityScreenState();
}

class _WorkerActivityScreenState extends State<WorkerActivityScreen> {
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023), // Extended back to allow easy year/month navigation
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange ?? 
          DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      helpText: 'Select Date Range for Activity',
      confirmText: 'FILTER',
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Technicians & Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by Date Range',
            onPressed: () => _selectDateRange(context),
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Date Filter',
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Date Filter: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Technician Name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaint-manager')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No records found in complaint-manager.'));
                }

                // Ensure all unique technicians are caught across all fields
                final Map<String, List<Map<String, dynamic>>> techMap = {};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final techName = data['technicianName']?.toString();
                  if (techName != null && techName.trim().isNotEmpty) {
                    techMap.putIfAbsent(techName.trim(), () => []).add(data);
                  }
                  
                  // Also check timeline logs userName to prevent missing any staff who performed actions
                  final logs = data['timelineLogs'] as List<dynamic>? ?? [];
                  for (var log in logs) {
                    final uName = log['userName']?.toString();
                    if (uName != null && uName.trim().isNotEmpty) {
                      techMap.putIfAbsent(uName.trim(), () => []).add(data);
                    }
                  }
                }

                final techList = techMap.keys.where((name) {
                  return name.toLowerCase().contains(_searchQuery);
                }).toList()..sort();

                if (techList.isEmpty) {
                  return const Center(child: Text('No technicians found.'));
                }

                return ListView.builder(
                  itemCount: techList.length,
                  itemBuilder: (context, index) {
                    final workerName = techList[index];
                    final complaints = techMap[workerName]!;

                    return WorkerActivityCard(
                      workerName: workerName,
                      complaints: complaints,
                      dateRange: _selectedDateRange,
                      onTap: () {
                        _showTechnicianDetailModal(context, workerName, complaints, _selectedDateRange);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTechnicianDetailModal(
      BuildContext context, String workerName, List<Map<String, dynamic>> complaints, DateTimeRange? dateRange) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<DateTime> sessionTimestamps = [];
    String currentBuilding = 'Not Assigned';
    String lastLocation = 'Unknown';
    DateTime? lastSyncTime;

    final filteredComplaints = complaints.where((comp) {
      if (dateRange == null) return true;
      final createdAt = comp['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final dt = createdAt.toDate();
      return dt.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(dateRange.end.add(const Duration(days: 1)));
    }).toList();

    for (var comp in filteredComplaints) {
      final status = comp['status']?.toString();
      if (status == 'Standby') continue;

      final bName = comp['buildingName']?.toString();
      final flat = comp['flatNumber']?.toString() ?? '';
      if (bName != null && bName.isNotEmpty) {
        currentBuilding = '$bName ($flat)';
        lastLocation = comp['address'] ?? bName;
      }

      final logs = comp['timelineLogs'] as List<dynamic>? ?? [];
      for (var log in logs) {
        final tsStr = log['timestamp']?.toString();
        if (tsStr != null) {
          final dt = DateTime.tryParse(tsStr);
          if (dt != null) {
            if (lastSyncTime == null || dt.isAfter(lastSyncTime)) {
              lastSyncTime = dt;
            }
            if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
              sessionTimestamps.add(dt);
            }
          }
        }
      }
    }

    sessionTimestamps.sort();
    final timeIn = sessionTimestamps.isNotEmpty ? DateFormat('hh:mm a').format(sessionTimestamps.first) : 'N/A';
    final timeOut = sessionTimestamps.length > 1 ? DateFormat('hh:mm a').format(sessionTimestamps.last) : 'N/A';
    final formattedLastSync = lastSyncTime != null ? DateFormat('yyyy-MM-dd hh:mm a').format(lastSyncTime) : 'Never';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const CircleAvatar(radius: 24, child: Icon(Icons.person, size: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(workerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Last Sync: $formattedLastSync', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Time-In: $timeIn', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Time-Out: $timeOut', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Current Building: $currentBuilding', style: const TextStyle(fontSize: 13)),
                        Text('Last Location: $lastLocation', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Active Complaints & Activity Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: filteredComplaints.length,
                      itemBuilder: (context, index) {
                        final comp = filteredComplaints[index];
                        final status = comp['status']?.toString();
                        if (status == 'Standby') return const SizedBox.shrink();

                        final category = comp['category'] ?? comp['complaintType'] ?? 'General';
                        final building = comp['buildingName'] ?? 'Unknown Building';
                        final flat = comp['flatNumber'] ?? '';
                        final logs = comp['timelineLogs'] as List<dynamic>? ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            title: Text('$category ($building $flat)'),
                            subtitle: Text('Status: $status'),
                            children: logs.map((log) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.history, size: 16),
                                title: Text(log['remarks'] ?? 'Action performed'),
                                subtitle: Text('Status: ${log['status']}'),
                                trailing: Text(
                                  log['timestamp'] != null ? log['timestamp'].toString().substring(11, 16) : '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class WorkerActivityCard extends StatelessWidget {
  final String workerName;
  final List<Map<String, dynamic>> complaints;
  final DateTimeRange? dateRange;
  final VoidCallback onTap;

  const WorkerActivityCard({
    super.key,
    required this.workerName,
    required this.complaints,
    this.dateRange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<DateTime> sessionTimestamps = [];
    String currentBuilding = 'Not Assigned';
    String lastLocation = 'Unknown';
    List<String> resolvedFlatNumbers = [];
    DateTime? lastSyncTime;

    // Filter complaints based on date range if active
    final filteredComplaints = complaints.where((comp) {
      if (dateRange == null) return true;
      final createdAt = comp['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final dt = createdAt.toDate();
      return dt.isAfter(dateRange!.start.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(dateRange!.end.add(const Duration(days: 1)));
    }).toList();

    for (var comp in filteredComplaints) {
      final status = comp['status']?.toString();
      if (status == 'Standby') continue;

      final bName = comp['buildingName']?.toString();
      final flat = comp['flatNumber']?.toString() ?? '';
      if (bName != null && bName.isNotEmpty) {
        currentBuilding = '$bName ($flat)';
        lastLocation = comp['address'] ?? bName;
      }

      final completedAt = comp['completedAt'] as Timestamp?;
      if ((status == 'Completed' || status == 'Resolved') && completedAt != null) {
        final compDate = completedAt.toDate();
        if (dateRange == null) {
          if (DateFormat('yyyy-MM-dd').format(compDate) == todayStr) {
            resolvedFlatNumbers.add('$bName - $flat');
          }
        } else {
          resolvedFlatNumbers.add('$bName - $flat');
        }
      }

      final logs = comp['timelineLogs'] as List<dynamic>? ?? [];
      for (var log in logs) {
        final tsStr = log['timestamp']?.toString();
        if (tsStr != null) {
          final dt = DateTime.tryParse(tsStr);
          if (dt != null) {
            if (lastSyncTime == null || dt.isAfter(lastSyncTime)) {
              lastSyncTime = dt;
            }
            if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
              sessionTimestamps.add(dt);
            }
          }
        }
      }
    }

    sessionTimestamps.sort();
    
    // Connected/Online logic: Considered online if he synced within the last 30 minutes, or has active connection/sync record today
    final isOnline = lastSyncTime != null && DateTime.now().difference(lastSyncTime).inMinutes < 30;
    
    final timeIn = sessionTimestamps.isNotEmpty ? DateFormat('hh:mm a').format(sessionTimestamps.first) : 'N/A';
    final timeOut = sessionTimestamps.length > 1 ? DateFormat('hh:mm a').format(sessionTimestamps.last) : 'N/A';
    
    // Full date and time for last sync shown on the card
    final formattedLastSync = lastSyncTime != null ? DateFormat('yyyy-MM-dd hh:mm a').format(lastSyncTime) : 'Never';

    final totalAssigned = filteredComplaints.length;
    final totalCompleted = filteredComplaints.where((c) => c['status'] == 'Completed' || c['status'] == 'Resolved').length;
    final progressValue = totalAssigned > 0 ? totalCompleted / totalAssigned : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        Text(
                          'Last Sync: $formattedLastSync',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: isOnline ? Colors.green : Colors.grey,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('In: $timeIn | Out: $timeOut', style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.business, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(currentBuilding, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Location: $lastLocation', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Resolved Flats: ${resolvedFlatNumbers.isEmpty ? "None" : resolvedFlatNumbers.join(", ")}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress: $totalCompleted / $totalAssigned Completed', style: const TextStyle(fontSize: 12)),
                  Text('${(progressValue * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}