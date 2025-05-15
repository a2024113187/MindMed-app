class Medication {
  final String id;           // id único, por ejemplo UUID o timestamp
  final String name;         // nombre del medicamento
  final String dose;         // dosis (ej: "500 mg", "2 pastillas")
  final int frequencyPerDay; // veces al día que se debe tomar
  final DateTime time;       // hora aproximada para tomar el medicamento
  final String? notes;       // notas opcionales

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequencyPerDay,
    required this.time,
    this.notes,
  });

  // Convertir a Map para almacenamiento local o JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'frequencyPerDay': frequencyPerDay,
      'time': time.toIso8601String(),
      'notes': notes,
    };
  }

  // Crear instancia desde Map
  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'],
      name: map['name'],
      dose: map['dose'],
      frequencyPerDay: map['frequencyPerDay'],
      time: DateTime.parse(map['time']),
      notes: map['notes'],
    );
  }
}
