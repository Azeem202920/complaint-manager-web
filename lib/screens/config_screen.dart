import 'package:flutter/material.dart';

class ConfigurationScreen extends StatefulWidget {
  final List<String> initialBuildings;
  final List<String> initialTypes;
  final Function(List<String> b, List<String> t) onSave;

  const ConfigurationScreen({super.key, required this.initialBuildings, required this.initialTypes, required this.onSave});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  late List<String> _buildings;
  late List<String> _types;

  @override
  void initState() {
    super.initState();
    _buildings = List.from(widget.initialBuildings.where((e) => e != "All" && e != "Others"));
    _types = List.from(widget.initialTypes);
  }

  void _addItem(List<String> list, Function(List<String>) update) {
    TextEditingController ctrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Add New Item"),
      content: TextField(controller: ctrl),
      actions: [TextButton(onPressed: () {
        update([...list, ctrl.text]);
        Navigator.pop(context);
      }, child: const Text("Add"))]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Configuration")),
      body: ListView(
        children: [
          _buildSection("Buildings", _buildings, (val) => setState(() => _buildings = val)),
          _buildSection("Complaint Types", _types, (val) => setState(() => _types = val)),
          ElevatedButton(onPressed: () => widget.onSave(_buildings, _types), child: const Text("Save All Changes"))
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, Function(List<String>) update) => ExpansionTile(
    title: Text(title),
    children: [
      ...items.map((item) => ListTile(title: Text(item), trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => update(items.where((i) => i != item).toList()),
      ))),
      IconButton(icon: const Icon(Icons.add), onPressed: () => _addItem(items, update))
    ],
  );
}