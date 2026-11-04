class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? certificateUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.certificateUrl,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      certificateUrl: json['certificate_url'] as String?,
    );
  }

  AppUser copyWith({String? certificateUrl}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      certificateUrl: certificateUrl ?? this.certificateUrl,
    );
  }
}
