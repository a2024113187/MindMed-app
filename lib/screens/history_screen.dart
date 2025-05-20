import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mindmeds/main.dart';
import 'package:mindmeds/screens/history_screen.dart';
import 'package:mindmeds/services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum TakenFilter { all, missed, confirmed }

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> filteredHistory = [];
  bool isLoading = true;
  bool? _takenFilter;
  String _searchText = '';


  String searchQuery = '';
  DateTime? selectedDate;
  String statusFilter = 'All'; // 'All', 'Taken', 'Missed'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        history = [];
        filteredHistory = [];
        isLoading = false;
      });
      return;
    }
    final uid = user.uid;

    final loaded = await StorageService().loadMedicationHistory(uid);
    setState(() {
      history = loaded;
      _applyFilters();
      isLoading = false;
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = history;

    // Filtrar por búsqueda de nombre
    if (searchQuery.isNotEmpty) {
      temp = temp.where((med) {
        final name = (med['name'] ?? '').toString().toLowerCase();
        return name.contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Filtrar por fecha seleccionada
    if (selectedDate != null) {
      final dateKey = selectedDate!.toIso8601String().split('T')[0];
      temp = temp.where((med) {
        final takenDays = Map<String, dynamic>.from(med['takenDays'] ?? {});
        return takenDays.containsKey(dateKey);
      }).toList();
    }

    // Filtrar por estado
    if (statusFilter != 'All') {
      temp = temp.where((med) {
        final takenDays = Map<String, dynamic>.from(med['takenDays'] ?? {});
        if (selectedDate == null) {
          // Si no hay fecha seleccionada, chequeamos si hay al menos un día con estado
          if (statusFilter == 'Taken') {
            return takenDays.values.any((v) => v == true);
          } else {
            return takenDays.values.any((v) => v == false);
          }
        } else {
          final dateKey = selectedDate!.toIso8601String().split('T')[0];
          final taken = takenDays[dateKey];
          if (taken == null) return false;
          if (statusFilter == 'Taken') return taken == true;
          if (statusFilter == 'Missed') return taken == false;
          return false;
        }
      }).toList();
    }

    setState(() {
      filteredHistory = temp;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _applyFilters();
    }
  }

  void _clearDate() {
    setState(() {
      selectedDate = null;
    });
    _applyFilters();
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
    _applyFilters();
  }

  void _onStatusFilterChanged(String? value) {
    if (value == null) return;
    setState(() {
      statusFilter = value;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Filtrar historial según filtros activos
    List<Map<String, dynamic>> filteredHistory = history.where((med) {
      final name = med['name']?.toString().toLowerCase() ?? '';

      // Filtro por texto de búsqueda (nombre o fecha)
      if (_searchText.isNotEmpty) {
        final startDateStr = med['startDate'] ?? '';
        final endDateStr = med['endDate'] ?? '';
        final startDateFormatted = startDateStr.isNotEmpty
            ? DateTime.tryParse(startDateStr)?.toLocal().toString().split(
            ' ')[0] ?? ''
            : '';
        final endDateFormatted = endDateStr.isNotEmpty
            ? DateTime.tryParse(endDateStr)?.toLocal().toString().split(
            ' ')[0] ?? ''
            : '';

        final searchLower = _searchText.toLowerCase();
        if (!name.contains(searchLower) &&
            !startDateFormatted.contains(searchLower) &&
            !endDateFormatted.contains(searchLower)) {
          return false;
        }
      }

      // Filtro por takenFilter (null = no filtrar)
      if (_takenFilter != null) {
        final takenDays = Map<String, dynamic>.from(med['takenDays'] ?? {});
        final hasTaken = takenDays.values.any((v) => v == true);
        if (_takenFilter == true && !hasTaken) return false;
        if (_takenFilter == false && hasTaken) return false;
      }

      return true;
    }).toList();

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('History'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.primary,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search by medication or date',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchText = val.trim();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Taken filter buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _takenFilter == null,
                    onSelected: (_) {
                      setState(() {
                        _takenFilter = null;
                      });
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _takenFilter == null
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Taken'),
                    selected: _takenFilter == true,
                    onSelected: (_) {
                      setState(() {
                        _takenFilter = true;
                      });
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _takenFilter == true
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Missed'),
                    selected: _takenFilter == false,
                    onSelected: (_) {
                      setState(() {
                        _takenFilter = false;
                      });
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _takenFilter == false
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Expanded list
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredHistory.isEmpty
                    ? Center(
                  child: Text(
                    'No history available.',
                    style: textTheme.bodyLarge,
                  ),
                )
                    : ListView.builder(
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final med = filteredHistory[index];
                    final takenDays = Map<String, dynamic>.from(
                        med['takenDays'] ?? {});
                    final startDate = DateTime.tryParse(
                        med['startDate'] ?? '') ?? DateTime.now();
                    final endDate = DateTime.tryParse(med['endDate'] ?? '') ??
                        DateTime.now();

                    List<DateTime> days = [];
                    for (DateTime d = startDate; !d.isAfter(endDate);
                    d = d.add(const Duration(days: 1))) {
                      days.add(d);
                    }

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius
                          .circular(14)),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        title: Text(
                          med['name'] ?? 'Unknown',
                          style: textTheme.titleLarge,
                        ),
                        subtitle: Text(
                          'Dose: ${med['dose'] ?? '-'}',
                          style: textTheme.bodyMedium,
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        children: days.map((day) {
                          final dayKey = day.toIso8601String().split('T')[0];
                          final taken = takenDays[dayKey] ?? false;
                          return ListTile(
                            leading: Icon(
                              taken ? Icons.check_circle : Icons.cancel,
                              color: taken ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              dayKey,
                              style: textTheme.bodyMedium,
                            ),
                            trailing: Text(
                              taken ? 'Taken' : 'Skipped',
                              style: TextStyle(
                                color: taken ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
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
        ),
      ),
    );
  }
}