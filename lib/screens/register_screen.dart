import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mindmeds/services/storage_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';




class GlobalBackground extends StatelessWidget {
  final Widget child;
  const GlobalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFF90CAF9),
            Color(0xFFFFC0CB),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _userNameController = TextEditingController();
  final _aboutMeController = TextEditingController();
  DateTime? _birthDate;
  bool _isLoading = false;

  File? _pickedImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
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
          });
        }
      } catch (e) {
        await _showErrorDialog('Failed to pick image: $e');
      }
    }
  }
  Future<String> saveImageLocally(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(imageFile.path);
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');
    return savedImage.path; // Retorna la ruta local
  }





  Future<void> _register() async {
    if (_userNameController.text.trim().isEmpty) {
      return _showErrorDialog('Please enter a User Name');
    }
    if (_birthDate == null) {
      return _showErrorDialog('Please select your Date of Birth');
    }
    if (_aboutMeController.text.trim().isEmpty) {
      return _showErrorDialog('Please enter information about yourself');
    }
    if (_emailController.text.trim().isEmpty) {
      return _showErrorDialog('Please enter your Email');
    }
    if (_passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      return _showErrorDialog('Please enter and confirm your Password');
    }
    if (_passwordController.text != _confirmController.text) {
      return _showErrorDialog('Passwords do not match');
    }


    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        // Upload image and get URL
        final localImagePath = await saveImageLocally(_pickedImage!);
        await StorageService().saveUserProfileImagePath(user.uid, localImagePath);

        if (localImagePath== null) {
          // Upload failed, stop registration
          setState(() => _isLoading = false);
          return;
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userName': _userNameController.text.trim(),
          'birthDate': _birthDate!.toIso8601String(),
          'aboutMe': _aboutMeController.text.trim(),
          'email': user.email,
          'photoUrl': localImagePath,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      await _showErrorDialog(e.message ?? 'Registration failed');
    } catch (e) {
      await _showErrorDialog('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _userNameController.dispose();
    _aboutMeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final birthDateText = _birthDate == null
        ? 'Select your birth date'
        : '${_birthDate!.toLocal()}'.split(' ')[0];

    return Scaffold(
      body: GlobalBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/logo.webp',
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile photo picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                        _pickedImage != null ? FileImage(_pickedImage!) : null,
                        child: _pickedImage == null
                            ? const Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Colors.white70,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    TextField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Birthdate
                    InkWell(
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
                            color: _birthDate == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // About me
                    TextField(
                      controller: _aboutMeController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'About Me',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                            color: Colors.white)
                            : const Text('Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
