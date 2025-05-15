import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationTile extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MedicationTile({
    Key? key,
    required this.medication,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeFormatted = TimeOfDay.fromDateTime(medication.time).format(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Dose: ${medication.dose}\nTime: $timeFormatted\nFreq: ${medication.frequencyPerDay}x/day'),
        isThreeLine: true,
        trailing: onDelete != null
            ? IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDelete,
        )
            : null,
        onTap: onTap,
      ),
    );
  }
}
