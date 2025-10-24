import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/partner_profile.dart';

/// 管理对话人档案
class ProfileManager {
  static const String _storageKey = 'partner_profiles';
  static const String _voiceprintsKey = 'partner_voiceprints';
  static ProfileManager? _instance;
  late SharedPreferences _prefs;

  /// 单例模式
  static Future<ProfileManager> getInstance() async {
    if (_instance == null) {
      _instance = ProfileManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  ProfileManager._();

  /// 初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取所有档案
  List<PartnerProfile> getAllProfiles() {
    final profilesJson = _prefs.getString(_storageKey);
    if (profilesJson == null) return [];

    try {
      final List<dynamic> profilesList = json.decode(profilesJson);
      return profilesList
          .map((json) => PartnerProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('解析档案数据失败: $e');
      return [];
    }
  }

  /// 根据ID获取档案
  PartnerProfile? getProfileById(String id) {
    final profiles = getAllProfiles();
    try {
      return profiles.firstWhere((profile) => profile.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 根据partnerId获取档案
  PartnerProfile? getProfileByPartnerId(String partnerId) {
    final profiles = getAllProfiles();
    try {
      return profiles.firstWhere((profile) => profile.partnerId == partnerId);
    } catch (e) {
      return null;
    }
  }

  /// 创建新档案
  Future<PartnerProfile?> createProfile({
    required String partnerId,
    required String name,
    required String relationship,
    String? customRelationship,
    String? voiceprintPath,
    int? age,
    String? gender,
    List<String>? personalityTags,
    String? tabooTopics,
    String? sharedExperiences,
  }) async {
    try {
      final now = DateTime.now();
      final profile = PartnerProfile(
        id: now.millisecondsSinceEpoch.toString(),
        partnerId: partnerId,
        name: name,
        relationship: relationship,
        customRelationship: customRelationship,
        voiceprintPath: voiceprintPath,
        age: age,
        gender: gender,
        personalityTags: personalityTags,
        tabooTopics: tabooTopics,
        sharedExperiences: sharedExperiences,
        createdAt: now,
        updatedAt: now,
      );

      final success = await addProfile(profile);
      return success ? profile : null;
    } catch (e) {
      print('创建档案失败: $e');
      return null;
    }
  }

  /// 添加或更新档案
  Future<bool> addProfile(PartnerProfile profile) async {
    try {
      final profiles = getAllProfiles();
      
      // 检查是否已存在
      final existingIndex = profiles.indexWhere((p) => p.id == profile.id);
      if (existingIndex != -1) {
        // 更新已存在的档案
        profiles[existingIndex] = profile;
      } else {
        // 检查是否已存在该partner的档案
        final partnerIndex = profiles.indexWhere((p) => p.partnerId == profile.partnerId);
        if (partnerIndex != -1) {
          // 更新已存在的partner档案
          profiles[partnerIndex] = profile;
        } else {
          // 添加新档案
          profiles.add(profile);
        }
      }

      return await _saveProfiles(profiles);
    } catch (e) {
      print('添加档案失败: $e');
      return false;
    }
  }

  /// 更新档案
  Future<bool> updateProfile(PartnerProfile profile) async {
    return await addProfile(profile.copyWith(updatedAt: DateTime.now()));
  }

  /// 删除档案
  Future<bool> deleteProfile(String id) async {
    try {
      final profiles = getAllProfiles();
      final profile = profiles.firstWhere((p) => p.id == id);
      
      // 删除关联的声纹文件
      if (profile.voiceprintPath != null) {
        await deleteVoiceprint(profile.voiceprintPath!);
      }
      
      // 删除档案
      profiles.removeWhere((profile) => profile.id == id);
      return await _saveProfiles(profiles);
    } catch (e) {
      print('删除档案失败: $e');
      return false;
    }
  }

  /// 根据partnerId删除档案
  Future<bool> deleteProfileByPartnerId(String partnerId) async {
    final profile = getProfileByPartnerId(partnerId);
    if (profile != null) {
      return await deleteProfile(profile.id);
    }
    return false;
  }

  /// 搜索档案
  List<PartnerProfile> searchProfiles(String query) {
    final profiles = getAllProfiles();
    final lowerQuery = query.toLowerCase();
    
    return profiles.where((profile) =>
      profile.name.toLowerCase().contains(lowerQuery) ||
      profile.relationship.toLowerCase().contains(lowerQuery) ||
      (profile.customRelationship?.toLowerCase().contains(lowerQuery) ?? false) ||
      profile.personalityTags.any((tag) => tag.toLowerCase().contains(lowerQuery))
    ).toList();
  }

  /// 保存声纹文件
  Future<String?> saveVoiceprint(String partnerId, List<int> audioData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final voiceprintsDir = Directory('${directory.path}/voiceprints');
      
      if (!await voiceprintsDir.exists()) {
        await voiceprintsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voiceprint_${partnerId}_$timestamp.pcm';
      final file = File('${voiceprintsDir.path}/$fileName');
      
      await file.writeAsBytes(audioData);
      return file.path;
    } catch (e) {
      print('保存声纹失败: $e');
      return null;
    }
  }

  /// 删除声纹文件
  Future<bool> deleteVoiceprint(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('删除声纹失败: $e');
      return false;
    }
  }

  /// 获取声纹文件
  Future<File?> getVoiceprint(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('获取声纹失败: $e');
      return null;
    }
  }

  /// 保存档案到本地存储
  Future<bool> _saveProfiles(List<PartnerProfile> profiles) async {
    try {
      final profilesJson = json.encode(
        profiles.map((profile) => profile.toJson()).toList(),
      );
      return await _prefs.setString(_storageKey, profilesJson);
    } catch (e) {
      print('保存档案失败: $e');
      return false;
    }
  }
}