import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> setString(String key, String value) async {
    if (_prefs == null) await init();
    return await _prefs!.setString(key, value);
  }

  String? getString(String key) {
    if (_prefs == null) return null;
    return _prefs!.getString(key);
  }

  Future<bool> remove(String key) async {
    if (_prefs == null) await init();
    return await _prefs!.remove(key);
  }

  Future<bool> saveMedications(List<Medication> medications) async {
    try {
      final medsJson = medications.map((m) => m.toMap()).toList();
      final jsonString = jsonEncode(medsJson);
      return await setString('medications', jsonString);
    } catch (e) {
      // Puedes loguear el error aquí si quieres
      return false;
    }
  }

  Future<List<Medication>> loadMedications() async {
    if (_prefs == null) await init();

    final jsonString = _prefs!.getString('medications');
    if (jsonString == null) return [];

    try {
      final List<dynamic> medsJson = jsonDecode(jsonString);
      final meds = medsJson
          .map((m) => m is Map<String, dynamic> ? Medication.tryFromMap(m) : null)
          .whereType<Medication>()
          .toList();
      return meds;
    } catch (e) {
      // Puedes loguear el error aquí si quieres
      return [];
    }
  }
}
