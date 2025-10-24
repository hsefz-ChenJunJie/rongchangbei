import 'dart:convert';

/// 对话人档案模型
class PartnerProfile {
  final String id;
  final String partnerId; // 关联的ChatPartner ID
  final String name;
  final String relationship; // 关系类型
  final String? customRelationship; // 自定义关系（当relationship为"其他"时）
  final String? voiceprintPath; // 声纹文件路径
  final int? age;
  final String? gender; // 男/女
  final List<String> personalityTags; // 性格标签
  final String? tabooTopics; // 禁忌话题
  final String? sharedExperiences; // 共同经历
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerProfile({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.relationship,
    this.customRelationship,
    this.voiceprintPath,
    this.age,
    this.gender,
    List<String>? personalityTags,
    this.tabooTopics,
    this.sharedExperiences,
    required this.createdAt,
    required this.updatedAt,
  }) : personalityTags = personalityTags ?? [];

  /// 从JSON创建PartnerProfile对象
  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      id: json['id'],
      partnerId: json['partnerId'],
      name: json['name'],
      relationship: json['relationship'],
      customRelationship: json['customRelationship'],
      voiceprintPath: json['voiceprintPath'],
      age: json['age'],
      gender: json['gender'],
      personalityTags: json['personalityTags'] != null 
          ? List<String>.from(json['personalityTags']) 
          : [],
      tabooTopics: json['tabooTopics'],
      sharedExperiences: json['sharedExperiences'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partnerId': partnerId,
      'name': name,
      'relationship': relationship,
      'customRelationship': customRelationship,
      'voiceprintPath': voiceprintPath,
      'age': age,
      'gender': gender,
      'personalityTags': personalityTags,
      'tabooTopics': tabooTopics,
      'sharedExperiences': sharedExperiences,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 获取完整的关系描述
  String get fullRelationship {
    if (relationship == '其他' && customRelationship != null) {
      return customRelationship!;
    }
    return relationship;
  }

  /// 获取显示的年龄性别信息
  String get ageGenderDisplay {
    List<String> parts = [];
    if (age != null) {
      parts.add('${age}岁');
    }
    if (gender != null) {
      parts.add(gender!);
    }
    return parts.join(' · ');
  }

  /// 复制对象并更新字段
  PartnerProfile copyWith({
    String? name,
    String? relationship,
    String? customRelationship,
    String? voiceprintPath,
    int? age,
    String? gender,
    List<String>? personalityTags,
    String? tabooTopics,
    String? sharedExperiences,
    DateTime? updatedAt,
  }) {
    return PartnerProfile(
      id: id,
      partnerId: partnerId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      customRelationship: customRelationship ?? this.customRelationship,
      voiceprintPath: voiceprintPath ?? this.voiceprintPath,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      personalityTags: personalityTags ?? this.personalityTags,
      tabooTopics: tabooTopics ?? this.tabooTopics,
      sharedExperiences: sharedExperiences ?? this.sharedExperiences,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// 性格标签选项
class PersonalityTags {
  static const List<String> options = [
    '开朗',
    '严肃', 
    '内向',
    '幽默',
    '温和',
    '急躁',
    '理性',
    '感性'
  ];
}

/// 关系类型选项
class RelationshipTypes {
  static const List<String> options = [
    '家人',
    '朋友', 
    '同事',
    '医生',
    '其他'
  ];
}

/// 性别选项
class GenderOptions {
  static const List<String> options = ['男', '女'];
}