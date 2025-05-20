// lib/screens/accessibility_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:mindmeds/services/storage_service.dart';
import 'package:mindmeds/services/tts_service.dart';
import '../main.dart'; // Para GlobalBackground

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
  bool _enableSubtitles = false;
  bool _invertColors = false;
  bool _easyReadMode = false;

  double _ttsSpeed = 1.0;

  // Opciones de tamaño de fuente
  String _fontSize = 'Medium';
  final List<String> _fontSizeOptions = ['Small', 'Medium', 'Large'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storedUseHighContrast = StorageService().getString('use_high_contrast');
    final storedEnableTts = StorageService().getString('enable_tts');
    final storedTtsSpeed = StorageService().getString('tts_speed');
    final storedEnableSubtitles = StorageService().getString('enable_subtitles');
    final storedInvertColors = StorageService().getString('invert_colors');
    final storedEasyReadMode = StorageService().getString('easy_read_mode');
    final storedFontSize = StorageService().getString('font_size');

    setState(() {
      _useHighContrast = storedUseHighContrast?.toLowerCase() == 'true';
      _enableTts = storedEnableTts?.toLowerCase() == 'true' ?? true;
      _ttsSpeed = storedTtsSpeed != null ? double.tryParse(storedTtsSpeed) ?? 1.0 : 1.0;
      _enableSubtitles = storedEnableSubtitles?.toLowerCase() == 'true';
      _invertColors = storedInvertColors?.toLowerCase() == 'true';
      _easyReadMode = storedEasyReadMode?.toLowerCase() == 'true';
      _fontSize = storedFontSize ?? 'Medium';
    });

    await TtsService().setSpeechRate(_ttsSpeed);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    await StorageService().setString(key, value.toString());
  }

  Future<void> _saveStringSetting(String key, String value) async {
    await StorageService().setString(key, value);
  }

  Future<void> _saveDoubleSetting(String key, double value) async {
    await StorageService().setString(key, value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: GlobalBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('High Contrast UI'),
              subtitle: const Text('Improve visibility with high contrast colors'),
              value: _useHighContrast,
              onChanged: (v) async {
                setState(() => _useHighContrast = v);
                await _saveBoolSetting('use_high_contrast', v);
              },
            ),
            SwitchListTile(
              title: const Text('Invert Colors'),
              subtitle: const Text('Invert colors for better readability'),
              value: _invertColors,
              onChanged: (v) async {
                setState(() => _invertColors = v);
                await _saveBoolSetting('invert_colors', v);
              },
            ),
            SwitchListTile(
              title: const Text('Enable Text-to-Speech (TTS)'),
              value: _enableTts,
              onChanged: (v) async {
                setState(() => _enableTts = v);
                await _saveBoolSetting('enable_tts', v);
              },
            ),
            if (_enableTts)
              ListTile(
                title: const Text('TTS Speed'),
                subtitle: Slider(
                  value: _ttsSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: _ttsSpeed.toStringAsFixed(1),
                  onChanged: (v) async {
                    setState(() => _ttsSpeed = v);
                    await _saveDoubleSetting('tts_speed', v);
                    await TtsService().setSpeechRate(v);
                  },
                ),
              ),
            SwitchListTile(
              title: const Text('Enable Subtitles'),
              subtitle: const Text('Show subtitles for audio content'),
              value: _enableSubtitles,
              onChanged: (v) async {
                setState(() => _enableSubtitles = v);
                await _saveBoolSetting('enable_subtitles', v);
              },
            ),
            SwitchListTile(
              title: const Text('Easy Read Mode'),
              subtitle: const Text('Simplify text and layout for easier reading'),
              value: _easyReadMode,
              onChanged: (v) async {
                setState(() => _easyReadMode = v);
                await _saveBoolSetting('easy_read_mode', v);
              },
            ),
            ListTile(
              title: const Text('Font Size'),
              subtitle: Text(_fontSize),
              trailing: DropdownButton<String>(
                value: _fontSize,
                items: _fontSizeOptions
                    .map((size) => DropdownMenuItem(
                  value: size,
                  child: Text(size),
                ))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() => _fontSize = value);
                    await _saveStringSetting('font_size', value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
