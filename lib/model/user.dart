// 用户类定义
class User {
  final int userID;
  final String name;
  final String email;
  final int? role;
  final int? state;
  final String? created_at;
  final String? updated_at;

  User({
    required this.userID,
    required this.name,
    required this.email,
    this.role,
    this.state,
    this.created_at,
    this.updated_at,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as int?,
      state: json['state'] as int?,
      created_at: json['created_at']?.toString(),
      updated_at: json['updated_at']?.toString(),
    );
  }

  static String getUserRole(int role) {
    switch (role) {
      case 0:
        return 'user';
      case 1:
        return 'admin';
      case 2:
        return 'QualityInspection';
      default:
        return '';
    }
  }
    static int getUserInt(String role) {
    switch (role) {
      case 'user':
        return 0;
      case 'admin':
        return 1;
      case 'QualityInspection':
        return 2;
      default:
        return -1;
    }
  }

  static String getUserState(int state) {
    switch (state) {
      case 0:
        return '正常';
      case 1:
        return '禁用';
      default:
        return '';
    }
  }
}
