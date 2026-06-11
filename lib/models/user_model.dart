class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String subscriptionPlan;
  final int documentsAnalyzed;
  final int highRiskCount;
  final double storageUsedMB;
  final double storageLimitMB;
  final DateTime createdAt;
  final bool isVerified;
  final int aiChatCount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.subscriptionPlan = 'Free',
    this.documentsAnalyzed = 0,
    this.highRiskCount = 0,
    this.storageUsedMB = 0,
    this.storageLimitMB = 20,
    required this.createdAt,
    this.isVerified = false,
    this.aiChatCount = 0,
  });

  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

  double get storagePercentage => (storageUsedMB / storageLimitMB).clamp(0, 1);

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? subscriptionPlan,
    int? documentsAnalyzed,
    int? highRiskCount,
    double? storageUsedMB,
    double? storageLimitMB,
    DateTime? createdAt,
    bool? isVerified,
    int? aiChatCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      documentsAnalyzed: documentsAnalyzed ?? this.documentsAnalyzed,
      highRiskCount: highRiskCount ?? this.highRiskCount,
      storageUsedMB: storageUsedMB ?? this.storageUsedMB,
      storageLimitMB: storageLimitMB ?? this.storageLimitMB,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      aiChatCount: aiChatCount ?? this.aiChatCount,
    );
  }



  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['full_name'] ?? json['name'] ?? 'User',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Legal Professional',
      avatarUrl: json['profile_image'] ?? json['avatarUrl'],
      subscriptionPlan: json['subscription_plan'] ?? 'Free',
      documentsAnalyzed: json['documents_analyzed'] ?? 0,
      highRiskCount: json['high_risk_count'] ?? 0,
      storageUsedMB: (json['storage_used_mb'] ?? 0).toDouble(),
      storageLimitMB: (json['storage_limit_mb'] ?? 20).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      isVerified: json['is_verified'] ?? false,
      aiChatCount: json['ai_chat_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'email': email,
      'role': role,
      'profile_image': avatarUrl,
      'subscription_plan': subscriptionPlan,
      'documents_analyzed': documentsAnalyzed,
      'high_risk_count': highRiskCount,
      'storage_used_mb': storageUsedMB,
      'storage_limit_mb': storageLimitMB,
      'created_at': createdAt.toIso8601String(),
      'is_verified': isVerified,
      'ai_chat_count': aiChatCount,
    };
  }
}

