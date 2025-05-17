class Medication {
  final String id;
  final String name;
  final String dose;
  final int frequencyPerDay;
  final DateTime time;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  bool taken;



  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequencyPerDay,
    required this.time,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.taken = false
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'frequencyPerDay': frequencyPerDay,
      'time': time.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    // Mantener para uso interno, lanza excepción si falta algo
    if (map['id'] == null ||
        map['name'] == null ||
        map['dose'] == null ||
        map['frequencyPerDay'] == null ||
        map['time'] == null ||
        map['startDate'] == null ||
        map['endDate'] == null) {
      throw Exception('Missing required Medication fields in map: $map');
    }

    return Medication(
      id: map['id'] as String,
      name: map['name'] as String,
      dose: map['dose'] as String,
      frequencyPerDay: map['frequencyPerDay'] is int
          ? map['frequencyPerDay'] as int
          : int.tryParse(map['frequencyPerDay'].toString()) ?? 1,
      time: DateTime.parse(map['time'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      notes: map['notes'] as String?,
    );
  }




  /// Método seguro que devuelve null si hay error en el mapa
  static Medication? tryFromMap(Map<String, dynamic> map) {
    try {
      if (map['id'] == null ||
          map['name'] == null ||
          map['dose'] == null ||
          map['frequencyPerDay'] == null ||
          map['time'] == null ||
          map['startDate'] == null ||
          map['endDate'] == null) {
        return null;
      }

      return Medication(
        id: map['id'] as String,
        name: map['name'] as String,
        dose: map['dose'] as String,
        frequencyPerDay: map['frequencyPerDay'] is int
            ? map['frequencyPerDay'] as int
            : int.tryParse(map['frequencyPerDay'].toString()) ?? 1,
        time: DateTime.parse(map['time'] as String),
        startDate: DateTime.parse(map['startDate'] as String),
        endDate: DateTime.parse(map['endDate'] as String),
        notes: map['notes'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
