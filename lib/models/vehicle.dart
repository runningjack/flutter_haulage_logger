class Vehicle {
  final int id;
  final String name;
  final String? license_plate;

  Vehicle({required this.id, required this.name, this.license_plate});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Safely parse licensePlate:
    // If json['license_plate'] is null, 'false' (boolean), or not a string,
    // it will resolve to null. Otherwise, it will be cast to String.
    String? parsedLicensePlate;
    if (json['license_plate'] is String) {
      parsedLicensePlate = json['license_plate'] as String;
    } else if (json['license_plate'] == false ||
        json['license_plate'] == null) {
      parsedLicensePlate = null; // Treat Odoo's 'false' or null as Dart's null
    } else {
      // Fallback for unexpected types, though String and bool are most common
      print(
        'Warning: Unexpected type for license_plate: ${json['license_plate'].runtimeType}',
      );
      parsedLicensePlate = json['license_plate']
          .toString(); // Try to convert to string as a last resort
    }

    return Vehicle(
      id: json['id'] as int,
      name: json['name'] as String,
      license_plate: parsedLicensePlate,
    );
  }
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'license_plate': license_plate};
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, name: $name, licensePlate: $license_plate)';
  }
}
