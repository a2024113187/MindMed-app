import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../main.dart'; // Para GlobalBackground

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final loaded = await StorageService().loadMedicationHistory();
    setState(() {
      history = loaded;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('History'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.primary,
          elevation: 0,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : history.isEmpty
            ? const Center(
          child: Text(
            'No history available.',
            style: TextStyle(fontSize: 18),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final med = history[index];
            final takenDays = Map<String, dynamic>.from(med['takenDays'] ?? {});
            final startDate = DateTime.tryParse(med['startDate'] ?? '') ?? DateTime.now();
            final endDate = DateTime.tryParse(med['endDate'] ?? '') ?? DateTime.now();

            List<DateTime> days = [];
            for (DateTime d = startDate; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
              days.add(d);
            }

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                title: Text(
                  med['name'] ?? 'Unknown',
                  style: theme.textTheme.titleLarge,
                ),
                subtitle: Text(
                  'Dosis: ${med['dose'] ?? '-'}',
                  style: theme.textTheme.bodyMedium,
                ),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      style: theme.textTheme.bodyMedium,
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
    );
  }
}
