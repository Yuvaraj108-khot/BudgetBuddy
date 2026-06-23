class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final bool hasPin;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.hasPin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      hasPin: json['has_pin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'has_pin': hasPin,
    };
  }
}
