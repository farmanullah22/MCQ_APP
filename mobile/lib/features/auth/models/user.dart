class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'manager'
  final String? assignedShopId;
  final String? assignedShopName;
  final String? fcmToken;
  final bool notificationEnabled;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.assignedShopId,
    this.assignedShopName,
    this.fcmToken,
    this.notificationEnabled = true,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';

  factory User.fromJson(Map<String, dynamic> json) {
    final assigned = json['assignedShop'];
    String? shopId;
    String? shopName;
    if (assigned is Map<String, dynamic>) {
      shopId = assigned['id']?.toString() ?? assigned['_id']?.toString();
      shopName = assigned['name']?.toString();
    } else if (assigned != null) {
      shopId = assigned.toString();
    } else {
      shopId = json['assignedShopId']?.toString();
      shopName = json['assignedShopName']?.toString();
    }
    return User(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'manager',
      assignedShopId: shopId,
      assignedShopName: shopName,
      fcmToken: json['fcmToken']?.toString(),
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'assignedShopId': assignedShopId,
        'assignedShopName': assignedShopName,
        'notificationEnabled': notificationEnabled,
      };
}
