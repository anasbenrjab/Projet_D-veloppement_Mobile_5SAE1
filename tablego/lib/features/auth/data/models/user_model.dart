class UserModel {
  final int id;
  final String email;
  final String userType; // 'client' | 'restaurant'

  const UserModel({
    required this.id,
    required this.email,
    required this.userType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        email: json['email'] as String,
        userType: json['user_type'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'user_type': userType,
      };

  bool get isClient => userType == 'client';
  bool get isRestaurant => userType == 'restaurant';
}
