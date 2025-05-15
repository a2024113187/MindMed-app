import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../utils/medication_tile.dart';

import '../models/medication.dart';
import 'login_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Aquí iría la carga real desde StorageService, por ahora mock:
  final List<Medication> medications = [
    Medication(
      id: '1',
      name: 'Paracetamol',
      dose: '500 mg',
      frequencyPerDay: 3,
      time: DateTime.now().add(const Duration(hours: 1)),
      notes: 'Después de comer',
    ),
    Medication(
      id: '2',
      name: 'Ibuprofeno',
      dose: '200 mg',
      frequencyPerDay: 2,
      time: DateTime.now().add(const Duration(hours: 4)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindMeds Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: GlobalBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Welcome, ${user?.email ?? 'User'}!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: medications.isEmpty
                    ? Center(
                  child: Text(
                    'No medications yet. Add one!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
                    : ListView.builder(
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final med = medications[index];
                    return MedicationTile(
                      medication: med,
                      onTap: () {
                        // Aquí puedes navegar a detalle o editar medicamento
                      },
                      onDelete: () {
                        // Aquí la lógica para eliminar medicamento
                        setState(() {
                          medications.removeAt(index);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegar a pantalla para añadir medicamento
          Navigator.pushNamed(context, '/add_medication');
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Medication',
      ),
    );
  }
}
