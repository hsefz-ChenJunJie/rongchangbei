import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 用户资料数据管理服务
/// 负责用户资料的本地持久化存储和读取
class UserProfileService {
  static const String _fileName = 'user_profile.json';
  static UserProfileService? _instance;
  
  // 默认用户资料数据
  static final Map<String, dynamic> _defaultProfile = {
    'basicInfo': {
      'displayName': '用户',
      'avatar': '',
      'communicationScenes': <String>[],
      'selfIntroduction': '',
    },
    'corpusData': {
      'phrases': <Map<String, dynamic>>[],
      'expressionHabits': {
        'sentenceStyle': '短句',
        'toneWords': <String>[],
        'abbreviations': <String, String>{},
        'typoCorrections': <String, String>{},
      },
      'contextTemplates': <Map<String, dynamic>>[],
    },
    'preferences': {
      'topicPreferences': <String>[],
      'fieldPreferences': <String, List<String>>{},
    },
    'restrictions': {
      'topicBlacklist': <String>[],
      'sensitiveWords': <Map<String, String>>[],
      'communicationRedlines': <String>[],
      'emergencyAvoidWords': <String>[],
    },
  };

  UserProfileService._internal();

  factory UserProfileService() {
    _instance ??= UserProfileService._internal();
    return _instance!;
  }

  /// 获取用户资料文件路径
  Future<String> get _localPath async {
    if (kIsWeb) {
      // Web平台使用不同的存储策略
      return _fileName;
    }
    
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 获取用户资料文件
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  /// 保存用户资料到本地文件
  Future<bool> saveProfile(Map<String, dynamic> profileData) async {
    try {
      if (kIsWeb) {
        // Web平台使用本地存储
        // 这里可以实现Web端的存储逻辑
        debugPrint('Web平台暂不支持文件存储');
        return false;
      }

      final file = await _localFile;
      final jsonString = jsonEncode(profileData);
      await file.writeAsString(jsonString);
      debugPrint('用户资料保存成功: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('保存用户资料失败: $e');
      return false;
    }
  }

  /// 从本地文件读取用户资料
  Future<Map<String, dynamic>?> loadProfile() async {
    try {
      if (kIsWeb) {
        // Web平台返回默认数据
        debugPrint('Web平台使用默认用户资料');
        return Map<String, dynamic>.from(_defaultProfile);
      }

      final file = await _localFile;
      
      // 检查文件是否存在
      if (!await file.exists()) {
        debugPrint('用户资料文件不存在，创建默认资料');
        await saveProfile(_defaultProfile);
        return Map<String, dynamic>.from(_defaultProfile);
      }

      final jsonString = await file.readAsString();
      final profileData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      debugPrint('用户资料读取成功');
      return _validateAndFixProfile(profileData);
    } catch (e) {
      debugPrint('读取用户资料失败: $e');
      return Map<String, dynamic>.from(_defaultProfile);
    }
  }

  /// 验证并修复用户资料数据结构
  Map<String, dynamic> _validateAndFixProfile(Map<String, dynamic> profileData) {
    final validatedProfile = Map<String, dynamic>.from(_defaultProfile);
    
    try {
      // 验证基本资料
      if (profileData.containsKey('basicInfo')) {
        final basicInfo = profileData['basicInfo'] as Map<String, dynamic>;
        validatedProfile['basicInfo'] = {
          'displayName': basicInfo['displayName'] ?? '用户',
          'avatar': basicInfo['avatar'] ?? '',
          'communicationScenes': List<String>.from(basicInfo['communicationScenes'] ?? []),
          'selfIntroduction': basicInfo['selfIntroduction'] ?? '',
        };
      }

      // 验证语料库数据
      if (profileData.containsKey('corpusData')) {
        final corpusData = profileData['corpusData'] as Map<String, dynamic>;
        validatedProfile['corpusData'] = {
          'phrases': List<Map<String, dynamic>>.from(corpusData['phrases'] ?? []),
          'expressionHabits': {
            'sentenceStyle': corpusData['expressionHabits']?['sentenceStyle'] ?? '短句',
            'toneWords': List<String>.from(corpusData['expressionHabits']?['toneWords'] ?? []),
            'abbreviations': Map<String, String>.from(corpusData['expressionHabits']?['abbreviations'] ?? {}),
            'typoCorrections': Map<String, String>.from(corpusData['expressionHabits']?['typoCorrections'] ?? {}),
          },
          'contextTemplates': List<Map<String, dynamic>>.from(corpusData['contextTemplates'] ?? []),
        };
      }

      // 验证用户偏好
      if (profileData.containsKey('preferences')) {
        final preferences = profileData['preferences'] as Map<String, dynamic>;
        validatedProfile['preferences'] = {
          'topicPreferences': List<String>.from(preferences['topicPreferences'] ?? []),
          'fieldPreferences': Map<String, List<String>>.from(
            preferences['fieldPreferences']?.map((key, value) => 
              MapEntry(key, List<String>.from(value))) ?? {}
          ),
        };
      }

      // 验证敏感设置
      if (profileData.containsKey('restrictions')) {
        final restrictions = profileData['restrictions'] as Map<String, dynamic>;
        validatedProfile['restrictions'] = {
          'topicBlacklist': List<String>.from(restrictions['topicBlacklist'] ?? []),
          'sensitiveWords': List<Map<String, String>>.from(
            restrictions['sensitiveWords']?.map((item) => 
              Map<String, String>.from(item)) ?? []
          ),
          'communicationRedlines': List<String>.from(restrictions['communicationRedlines'] ?? []),
          'emergencyAvoidWords': List<String>.from(restrictions['emergencyAvoidWords'] ?? []),
        };
      }

    } catch (e) {
      debugPrint('验证用户资料数据结构失败: $e');
    }

    return validatedProfile;
  }

  /// 重置用户资料为默认值
  Future<bool> resetProfile() async {
    try {
      return await saveProfile(_defaultProfile);
    } catch (e) {
      debugPrint('重置用户资料失败: $e');
      return false;
    }
  }

  /// 备份用户资料
  Future<bool> backupProfile(String backupName) async {
    try {
      final profileData = await loadProfile();
      if (profileData == null) return false;

      if (kIsWeb) {
        debugPrint('Web平台暂不支持备份功能');
        return false;
      }

      final backupFileName = 'user_profile_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/$backupFileName');
      
      await backupFile.writeAsString(jsonEncode(profileData));
      debugPrint('用户资料备份成功: ${backupFile.path}');
      return true;
    } catch (e) {
      debugPrint('备份用户资料失败: $e');
      return false;
    }
  }

  /// 获取备份文件列表
  Future<List<String>> getBackupFiles() async {
    try {
      if (kIsWeb) {
        return [];
      }

      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      return files
          .where((file) => file.path.contains('user_profile_backup_'))
          .map((file) => file.path.split('/').last)
          .toList();
    } catch (e) {
      debugPrint('获取备份文件列表失败: $e');
      return [];
    }
  }
}