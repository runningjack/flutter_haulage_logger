class Driver {
  final int id;
  final String name;

  Driver({required this.id, required this.name});

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  @override
  String toString() {
    return 'Driver(id: $id, name: $name)';
    //return 'Driver(id: $id, name: $name, email: $email, phone: $phone)';
  }
}
