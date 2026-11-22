/// Public user returned by the backend. Never includes a password hash.
class AuthUser {
  final String id;
  final String email;
  final String name;
  final String? framework;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.framework,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      framework: json['framework'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (framework != null) 'framework': framework,
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

/// Response from POST /api/auth/request-code.
///
/// `devCode` is only populated when the backend runs with AUTH_DEV_CODE enabled
/// (the default in development) because email/SMS delivery is not configured.
class AuthCodeRequest {
  final String email;
  final int expiresInSeconds;
  final String? devCode;

  const AuthCodeRequest({
    required this.email,
    required this.expiresInSeconds,
    this.devCode,
  });

  factory AuthCodeRequest.fromJson(Map<String, dynamic> json) {
    return AuthCodeRequest(
      email: json['email'] as String? ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 600,
      devCode: json['devCode'] as String?,
    );
  }
}

/// Data collected on the Create Account step and forwarded with the code request.
class AuthRegistrationDetails {
  final String name;
  final String email;
  final String framework;
  final String password;

  const AuthRegistrationDetails({
    required this.name,
    required this.email,
    required this.framework,
    required this.password,
  });

  AuthRegistrationDetails copyWith({
    String? name,
    String? email,
    String? framework,
    String? password,
  }) {
    return AuthRegistrationDetails(
      name: name ?? this.name,
      email: email ?? this.email,
      framework: framework ?? this.framework,
      password: password ?? this.password,
    );
  }
}
