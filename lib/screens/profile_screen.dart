import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mindmeds/services/storage_service.dart';

import '../main.dart'; // Importa GlobalBackground desde main.dart (ajusta ruta si es necesario)

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = 'No user logged in';
          isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(
          user.uid).get();

      if (doc.exists) {
        final data = doc.data(); // datos obtenidos
        setState(() {
          userData = data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'User data not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading user data: $e';
        isLoading = false;
      });
    }
  }


  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // Opcional: Navegar a login o pantalla inicial
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: colors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
            color: colors.onPrimary,
          ),
        ],
      ),
      body: GlobalBackground(
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : error != null
              ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error!,
              style: textTheme.bodyLarge?.copyWith(color: colors.error),
              textAlign: TextAlign.center,
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colors.primary,
                      backgroundImage: (_profileImagePath != null &&
                          File(_profileImagePath!).existsSync())
                          ? FileImage(File(_profileImagePath!))
                          : null,
                      child: (_profileImagePath == null ||
                          !File(_profileImagePath!).existsSync())
                          ? Icon(
                        Icons.person,
                        size: 60,
                        color: colors.onPrimary,
                      )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      userData?['userName'] ?? 'No User Name',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.email ?? 'No Email',
                      style: textTheme.bodyMedium?.copyWith(
                          color: colors.onBackground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(Icons.cake, 'Date of Birth',
                        _formatDate(userData?['birthDate']), colors, textTheme),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.info_outline, 'About Me',
                        userData?['aboutMe'] ?? 'No information provided',
                        colors, textTheme,
                        isMultiline: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      ColorScheme colors, TextTheme textTheme,
      {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: colors.secondary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Text(
                value,
                style: isMultiline
                    ? textTheme.bodyMedium?.copyWith(color: colors.onBackground)
                    : textTheme.bodyLarge?.copyWith(color: colors.onBackground),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Not set';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return 'Invalid date';
    }
  }
}
