/// Public representation of an authenticated user.
///
/// Contains only the fields that the UI and state layer need.
/// Credential fields (password_hash, salt, password_iterations,
/// reset_answer_hash, reset_answer_salt) are never exposed outside
/// [AuthRepository]; they live in the private [_CredentialsRow] class there.
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.resetQuestion,
  });

  final int id;

  /// Always lowercase; normalised at the repository layer.
  final String email;

  /// Either `'client'` or `'restaurant'`.
  final String userType;

  final bool isActive;

  /// ISO-8601 string, e.g. `'2026-10-20T14:32:00Z'`.
  final String createdAt;

  /// ISO-8601 string, updated on every write to the users table.
  final String updatedAt;

  /// The security question shown to the user during the forgot-password flow.
  /// `null` if the user has not set one.
  final String? resetQuestion;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isClient     => userType == 'client';
  bool get isRestaurant => userType == 'restaurant';

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Constructs a [UserModel] from a database row.
  ///
  /// Only the columns exposed to the UI are read here.  Credential columns
  /// (password_hash, salt, …) are deliberately absent — they must be queried
  /// separately in [AuthRepository] using the private [_CredentialsRow] class.
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id:            map['id']             as int,
        email:         map['email']          as String,
        userType:      map['user_type']      as String,
        isActive:      (map['is_active']     as int) == 1,
        createdAt:     map['created_at']     as String,
        updatedAt:     map['updated_at']     as String,
        resetQuestion: map['reset_question'] as String?,
      );

  /// Returns only the columns that belong to [UserModel].
  ///
  /// Used when the caller needs to persist a projection of the user row
  /// (e.g. caching, logging).  Never includes credential fields.
  Map<String, dynamic> toMap() => {
        'id':             id,
        'email':          email,
        'user_type':      userType,
        'is_active':      isActive ? 1 : 0,
        'created_at':     createdAt,
        'updated_at':     updatedAt,
        'reset_question': resetQuestion,
      };

  UserModel copyWith({
    int?    id,
    String? email,
    String? userType,
    bool?   isActive,
    String? createdAt,
    String? updatedAt,
    // Use [clearResetQuestion] = true to set it to null explicitly.
    String? resetQuestion,
    bool    clearResetQuestion = false,
  }) =>
      UserModel(
        id:            id            ?? this.id,
        email:         email         ?? this.email,
        userType:      userType      ?? this.userType,
        isActive:      isActive      ?? this.isActive,
        createdAt:     createdAt     ?? this.createdAt,
        updatedAt:     updatedAt     ?? this.updatedAt,
        resetQuestion: clearResetQuestion ? null : resetQuestion ?? this.resetQuestion,
      );

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, userType: $userType, '
      'isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          userType == other.userType &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, email, userType, isActive);
}
