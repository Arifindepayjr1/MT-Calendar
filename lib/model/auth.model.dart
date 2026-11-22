/// Public user returned by the backend. Never includes a password hash.
class AuthUser {
  final String id;
  final String email;
  final String name;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
      };
}

/// Response from POST /api/auth/signup and POST /api/auth/login.
class AuthSession {
  final String accessToken;
  final String tokenType;
  final String expiresIn;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as String? ?? '',
      user: AuthUser.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'tokenType': tokenType,
        'expiresIn': expiresIn,
        'user': user.toJson(),
      };
}
