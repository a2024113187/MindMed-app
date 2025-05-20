import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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

  Future<bool> saveMedications(List<Medication> medications, String userId) async {
    try {
      final medsJson = medications.map((m) => m.toMap()).toList();
      final jsonString = jsonEncode(medsJson);
      return await setString('medications_$userId', jsonString);
    } catch (e) {
      return false;
    }
  }

  Future<List<Medication>> loadMedications(String userId) async {


    if (_prefs == null) await init();

    final jsonString = _prefs!.getString('medications_$userId');
    if (jsonString == null) return [];

    try {
      final List<dynamic> medsJson = jsonDecode(jsonString);
      final meds = medsJson
          .map((m) => m is Map<String, dynamic> ? Medication.tryFromMap(m) : null)
          .whereType<Medication>()
          .toList();
      return meds;
    } catch (e) {
      return [];
    }
  }
  Future<String> saveImageLocally(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(imageFile.path);
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');
    return savedImage.path; // Retorna la ruta local
  }
  Future<bool> saveUserProfileImagePath(String userId, String imagePath) async {
    return await setString('profile_image_path_$userId', imagePath);
  }

  Future<String?> getUserProfileImagePath(String userId) async {
    return getString('profile_image_path_$userId');
  }


  Future<bool> saveTakenMedicationsByDate(Map<String, List<String>> data, String userId) async {
    try {
      final jsonString = jsonEncode(data);
      return await setString('takenMedicationsByDate_$userId', jsonString);
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, List<String>>> loadTakenMedicationsByDate(String userId) async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString('takenMedicationsByDate_$userId');
    if (jsonString == null) return {};
    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      return map.map((key, value) => MapEntry(key, List<String>.from(value)));
    } catch (e) {
      return {};
    }
  }

  Future<bool> saveMedicationHistory(List<Map<String, dynamic>> history, String userId) async {
    try {
      final jsonString = jsonEncode(history);
      return await setString('medicationHistory_$userId', jsonString);
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadMedicationHistory(String userId) async {
    if (_prefs == null) await init();
    final jsonString = _prefs!.getString('medicationHistory_$userId');
    if (jsonString == null) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}

