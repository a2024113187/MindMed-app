

import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Aquí iría la lista de tomas pasadas
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Text(
          'Medication history will appear here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
