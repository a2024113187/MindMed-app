import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.person, size: 80),
            const SizedBox(height: 16),
            Text('Email: ${user?.email ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('User ID: ${user?.uid ?? 'Unknown'}'),
            // Aquí más datos de perfil...
          ],
        ),
      ),
    );
  }
}
