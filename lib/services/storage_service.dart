import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/medicine.dart';

class StorageService extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _loaded = false;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  bool get isLoaded => _loaded;

  int get expiredCount => _medicines.where((m) => m.isExpired).length;

  List<String> get allAssignees {
    final names = <String>{};
    for (final m in _medicines) {
      names.addAll(m.assignedTo);
    }
    names.remove('ALL');
    return names.toList()..sort();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/medicines.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file;
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final list = json['medicines'] as List<dynamic>? ?? [];
        _medicines = list.map((m) => Medicine.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading medicines: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = await _file;
    final json = jsonEncode({
      'medicines': _medicines.map((m) => m.toJson()).toList(),
    });
    await file.writeAsString(json);
    notifyListeners();
  }

  Future<void> add(Medicine medicine) async {
    _medicines.add(medicine);
    await _save();
  }

  Future<void> update(Medicine updated) async {
    final idx = _medicines.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _medicines[idx] = updated;
      await _save();
    }
  }

  Future<void> delete(String id) async {
    _medicines.removeWhere((m) => m.id == id);
    await _save();
  }

  List<Medicine> filterByAssignee(String name) {
    if (name == 'ALL' || name == 'Tutti') {
      return _medicines;
    }
    return _medicines.where((m) => m.isForAll || m.assignedTo.contains(name)).toList();
  }
}