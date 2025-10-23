class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleId,
    required this.isSuperUser,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int roleId;
  final bool isSuperUser;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      roleId: json['role_id'] as int,
      isSuperUser: json['is_super_user'] as bool? ?? false,
    );
  }
}
