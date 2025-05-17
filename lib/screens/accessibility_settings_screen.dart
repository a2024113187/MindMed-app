import 'package:flutter/material.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends State<AccessibilitySettingsScreen> {
  bool _useHighContrast = false;
  bool _enableTts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('High Contrast UI'),
            value: _useHighContrast,
            onChanged: (v) => setState(() => _useHighContrast = v),
          ),
          SwitchListTile(
            title: const Text('Enable Text-to-Speech'),
            value: _enableTts,
            onChanged: (v) => setState(() => _enableTts = v),
          ),
          // Aquí más opciones de accesibilidad...
        ],
      ),
    );
  }
}
