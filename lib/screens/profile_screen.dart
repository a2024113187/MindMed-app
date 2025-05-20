import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mindmeds/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';


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

  bool _isEditing = false;

  final _userNameController = TextEditingController();
  final _aboutMeController = TextEditingController();
  DateTime? _birthDate;
  File? _pickedImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _aboutMeController.dispose();
    super.dispose();
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

      String? localImagePath = await StorageService().getUserProfileImagePath(
          user.uid);

      if (doc.exists) {
        final data = doc.data(); // datos obtenidos
        setState(() {
          userData = data;
          _profileImagePath = localImagePath;
          _userNameController.text = data?['userName'] ?? '';
          _aboutMeController.text = data?['aboutMe'] ?? '';
          if (data?['birthDate'] != null) {
            _birthDate = DateTime.tryParse(data!['birthDate']);
          }
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a Photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
    );

    if (source != null) {
      try {
        final pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          setState(() {
            _pickedImage = File(pickedFile.path);
            _profileImagePath =
            null; // para mostrar la nueva imagen seleccionada
          });
        }
      } catch (e) {
        _showErrorDialog('Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
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

  Future<void> _saveChanges() async {
    if (_userNameController.text
        .trim()
        .isEmpty) {
      return _showErrorDialog('Please enter a User Name');
    }
    if (_birthDate == null) {
      return _showErrorDialog('Please select your Date of Birth');
    }
    if (_aboutMeController.text
        .trim()
        .isEmpty) {
      return _showErrorDialog('Please enter information about yourself');
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = 'No user logged in';
          isLoading = false;
        });
        return;
      }

      String? imagePathToSave = _profileImagePath;

      if (_pickedImage != null) {
        // Guardar imagen localmente y en SharedPreferences
        final localImagePath = await StorageService().saveImageLocally(
            _pickedImage!);
        await StorageService().saveUserProfileImagePath(
            user.uid, localImagePath);
        imagePathToSave = localImagePath;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
          {
            'userName': _userNameController.text.trim(),
            'birthDate': _birthDate!.toIso8601String(),
            'aboutMe': _aboutMeController.text.trim(),
            'photoUrl': imagePathToSave,
          });

      setState(() {
        _profileImagePath = imagePathToSave;
        _pickedImage = null;
        _isEditing = false;
        isLoading = false;
        userData = {
          ...?userData,
          'userName': _userNameController.text.trim(),
          'birthDate': _birthDate!.toIso8601String(),
          'aboutMe': _aboutMeController.text.trim(),
          'photoUrl': imagePathToSave,
        };
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK')),
            ],
          ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
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

    final birthDateText = _birthDate == null
        ? 'Select your birth date'
        : '${_birthDate!.day.toString().padLeft(2, '0')}/'
        '${_birthDate!.month.toString().padLeft(2, '0')}/'
        '${_birthDate!.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: colors.primary,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              color: colors.onPrimary,
            ),
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save Changes',
              onPressed: isLoading ? null : _saveChanges,
              color: colors.onPrimary,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _pickedImage = null;
                  // Reset controllers to original data
                  _userNameController.text = userData?['userName'] ?? '';
                  _aboutMeController.text = userData?['aboutMe'] ?? '';
                  if (userData?['birthDate'] != null) {
                    _birthDate = DateTime.tryParse(userData!['birthDate']);
                  } else {
                    _birthDate = null;
                  }
                });
              },
              color: colors.onPrimary,
            ),
          ],
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
                    GestureDetector(
                      onTap: _isEditing ? _pickImage : null,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: colors.primary,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (_profileImagePath != null &&
                            File(_profileImagePath!).existsSync())
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: (_pickedImage == null &&
                            (_profileImagePath == null ||
                                !File(_profileImagePath!).existsSync()))
                            ? Icon(
                          Icons.person,
                          size: 60,
                          color: colors.onPrimary,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Username
                    _isEditing
                        ? TextField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    )
                        : Text(
                      userData?['userName'] ?? 'No User Name',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Email (no editable)
                    Text(
                      user?.email ?? 'No Email',
                      style: textTheme.bodyMedium?.copyWith(
                          color: colors.onBackground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),

                    // Birthdate
                    _isEditing
                        ? InkWell(
                      onTap: _pickBirthDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Birth Date',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          birthDateText,
                          style: TextStyle(
                            fontSize: 16,
                            color: _birthDate == null ? Colors.grey : Colors
                                .black87,
                          ),
                        ),
                      ),
                    )
                        : _buildInfoRow(Icons.cake, 'Date of Birth',
                        _formatDate(userData?['birthDate']), colors, textTheme),
                    const SizedBox(height: 16),

                    // About me
                    _isEditing
                        ? TextField(
                      controller: _aboutMeController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'About Me',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    )
                        : _buildInfoRow(Icons.info_outline, 'About Me',
                        userData?['aboutMe'] ?? 'No information provided',
                        colors, textTheme, isMultiline: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon,
      String label,
      String value,
      ColorScheme colors,
      TextTheme textTheme, {
        bool isMultiline = false,
        bool isEditing = false,
        TextEditingController? controller,
        VoidCallback? onTap, // para campos como birthDate que abren un selector
      }) {
    return Row(
      crossAxisAlignment:
      isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: colors.secondary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: isEditing && controller != null
              ? TextField(
            controller: controller,
            maxLines: isMultiline ? null : 1,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            style: isMultiline
                ? textTheme.bodyMedium?.copyWith(color: colors.onBackground)
                : textTheme.bodyLarge?.copyWith(color: colors.onBackground),
          )
              : InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: isMultiline
                      ? textTheme.bodyMedium?.copyWith(
                      color: colors.onBackground)
                      : textTheme.bodyLarge?.copyWith(
                      color: colors.onBackground),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}