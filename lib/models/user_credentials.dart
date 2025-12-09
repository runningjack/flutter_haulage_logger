// lib/models/user_credentials.dart
class UserCredentials {
  final String username;
  final String password;
  final int uid; // Add this property

  UserCredentials({
    required this.username,
    required this.password,
    required this.uid, // Initialize uid
  });

  // Optional: Add fromJson/toMap methods if you store/retrieve credentials
  factory UserCredentials.fromJson(Map<String, dynamic> json) {
    return UserCredentials(
      username: json['username'],
      password: json['password'],
      uid: json['uid'], // Make sure to parse uid
    );
  }

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password, 'uid': uid};
  }
}
