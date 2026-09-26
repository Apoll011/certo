import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/medication.dart';

/// Holds the app's working state (medications, today's taken set, active tab).
class AppState extends ChangeNotifier {
  AppState() : medications = List.of(mockMedications);

  final List<Medication> medications;

  /// Medication ids marked as taken for today.
  final Set<String> takenIds = {};

  String userName = demoUserName;
  int selectedTabIndex = 0;

  Medication? medicationById(String id) {
    for (final m in medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Medications ordered by most-recently added first.
  List<Medication> get recentMedications {
    final list = List<Medication>.of(medications);
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<Medication> medicationsWithStatus(MedicationStatus? status) {
    if (status == null) return medications;
    return medications.where((m) => m.status == status).toList();
  }

  bool isTaken(String id) => takenIds.contains(id);

  void toggleTaken(String id) {
    if (!takenIds.add(id)) {
      takenIds.remove(id);
    }
    notifyListeners();
  }

  void markTaken(String id) {
    takenIds.add(id);
    notifyListeners();
  }

  void setTab(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }
}
