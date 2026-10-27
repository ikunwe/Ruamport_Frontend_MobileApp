class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.usernameLoginEnabled = false,
  });
  final String id, email;
  final String? username, fullName, avatarUrl;
  final bool usernameLoginEnabled;

  String get displayName => username ?? fullName ?? email;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final profile = json['profile'] as Map<String, dynamic>?;
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;
    return AppUser(
      id: user['id'] as String,
      email: user['email'] as String,
      username: text(profile?['username']),
      fullName: text(profile?['full_name']),
      avatarUrl: text(profile?['avatar_url']),
      usernameLoginEnabled: json['usernameLoginEnabled'] == true,
    );
  }
}
