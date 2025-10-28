class UserRoleInfo {
  const UserRoleInfo({required this.id, required this.name});

  final int id;
  final String name;

  factory UserRoleInfo.fromJson(Map<String, dynamic> json) {
    return UserRoleInfo(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}
