import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/tts_service.dart';  // 1. Importa TTS service
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    TtsService().init();  // 2. Inicializa TTS

    // Lee mensaje de bienvenida al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService().speak("Welcome to MindMeds. Please login to continue.");
    });
  }

  Future<void> _showErrorDialog(String message) async {
    await TtsService().speak("Error. $message");

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              TtsService().speak("OK");
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      await _showErrorDialog("Please fill in all fields");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      await _showErrorDialog(e.message ?? "An unknown error occurred");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para leer texto (por comodidad)
  void _speak(String text) {
    TtsService().speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlobalBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _speak("MindMeds logo"),
                  child: Image.asset('assets/icons/logo.webp', height: 120),
                ),

                const SizedBox(height: 40),

                Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) _speak("Email input field");
                  },
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                      labelStyle: textTheme.labelMedium,
                      prefixIconColor: colors.primary,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: textTheme.bodyMedium,
                  ),
                ),

                const SizedBox(height: 16),

                Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) _speak("Password input field");
                  },
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      labelStyle: textTheme.labelMedium,
                      prefixIconColor: colors.primary,
                    ),
                    autofillHints: const [AutofillHints.password],
                    style: textTheme.bodyMedium,
                  ),
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _speak("Forgot password");
                      // TODO: Implementar recuperación de contraseña
                    },
                    child: Text(
                      'Forgot password?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    _speak("Login button");
                    _login();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login'),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Divider(color: colors.onBackground.withOpacity(0.3)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "or",
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Divider(color: colors.onBackground.withOpacity(0.3)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                OutlinedButton(
                  onPressed: () {
                    _speak("Register button");
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(color: colors.primary),
                    foregroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Register',
                    style: TextStyle(color: colors.primary),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
