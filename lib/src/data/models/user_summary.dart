class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.roleName,
    required this.roleId,
  });

  final int id;
  final String name;
  final String email;
  final String roleName;
  final int roleId;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    String roleName = 'Unknown';
    if (json['role'] is String && (json['role'] as String).isNotEmpty) {
      roleName = json['role'] as String;
    } else if (json['moonshine_user_role'] is Map<String, dynamic>) {
      final role = json['moonshine_user_role'] as Map<String, dynamic>;
      final value = role['name'];
      if (value is String && value.isNotEmpty) {
        roleName = value;
      }
    }

    final roleId = json['role_id'] as int? ??
        json['moonshine_user_role_id'] as int? ??
        0;
    return UserSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      roleName: roleName,
      roleId: roleId,
    );
  }
}
