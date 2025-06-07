class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String username;
  final String profileImage;
  final int coins;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.username,
    required this.profileImage,
    this.coins = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'username': username,
      'profile_image': profileImage,
      'coins': coins,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      passwordHash: map['password_hash'],
      username: map['username'],
      profileImage: map['profile_image'],
      coins: map['coins'],
    );
  }

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? username,
    String? profileImage,
    int? coins,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      coins: coins ?? this.coins,
    );
  }
}