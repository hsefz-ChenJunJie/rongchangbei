import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Userdata {
  String username = 'anonymous';

  Map<String, dynamic> preferences = {
    'color': 'defaultColor',
    'llmCallingInterval': 10,
    'sttSendingInterval': -1,
    'stt': {
      'mode': 'url',
      'url': 'http://localhost:8000',
      'route': '/stt',
      'method': 'POST',
      'headers': {
        'Content-Type': 'audio/wav',
      },
    },
    'tts': {
      'mode': 'ip-port',
      'ip': '127.0.0.1',
      'port': 8000,
      'route': '/tts',
      'method': 'POST',
      'headers': {
        'Content-Type': 'text/plain',
      },
    },
    'llm': {
      'mode': 'ip-port',
      'ip': '127.0.0.1',
      'port': 8000,
      'route': '/llm',
      'method': 'POST',
      'headers': {
        'Content-Type': 'text/plain',
      },
    }
  };

  // 构造函数
  Userdata();

  // 从SharedPreferences加载用户数据，如果不存在则创建默认数据
  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 检查是否存在用户数据
      final hasUserData = prefs.containsKey('username') && prefs.containsKey('preferences');
      
      if (!hasUserData) {
        // 如果不存在用户数据，先保存默认数据
        print('未找到用户数据，创建默认数据...');
        await saveUserData();
        print('默认用户数据已创建');
      }
      
      // 加载用户名
      username = prefs.getString('username') ?? 'anonymous';
      
      // 加载偏好设置
      final preferencesJson = prefs.getString('preferences');
      if (preferencesJson != null) {
        try {
          preferences = json.decode(preferencesJson);
        } catch (e) {
          print('解析偏好设置时出错，使用默认值: $e');
          // 如果解析失败，重新保存默认设置
          await saveUserData();
        }
      } else {
        // 如果preferences不存在，也重新保存默认设置
        await saveUserData();
      }
      
      print('用户数据加载成功 - 用户名: $username');
    } catch (e) {
      print('加载用户数据时出错: $e');
      // 出错时也确保有默认数据
      await saveUserData();
    }
  }

  // 保存用户数据到SharedPreferences
  Future<void> saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存用户名
      await prefs.setString('username', username);
      
      // 保存偏好设置
      final preferencesJson = json.encode(preferences);
      await prefs.setString('preferences', preferencesJson);
      
      print('用户数据保存成功');
    } catch (e) {
      print('保存用户数据时出错: $e');
    }
  }

  // 检查用户数据是否存在
  static Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('username') && prefs.containsKey('preferences');
    } catch (e) {
      print('检查用户数据时出错: $e');
      return false;
    }
  }

  // 更新特定偏好设置
  Future<void> updatePreference(String key, dynamic value) async {
    preferences[key] = value;
    await saveUserData();
  }

  // 更新嵌套偏好设置（如stt, tts, llm配置）
  Future<void> updateNestedPreference(String category, String key, dynamic value) async {
    if (preferences.containsKey(category)) {
      preferences[category][key] = value;
      await saveUserData();
    }
  }

  // 重置到默认设置
  Future<void> resetToDefaults() async {
    username = 'anonymous';
    preferences = {
      'color': 'defaultColor',
      'llmCallingInterval': 10,
      'sttSendingInterval': -1,
      'stt': {
        'mode': 'url',
        'url': 'http://localhost:8000',
        'route': '/stt',
        'method': 'POST',
        'headers': {
          'Content-Type': 'audio/wav',
        },
      },
      'tts': {
        'mode': 'ip-port',
        'ip': '127.0.0.1',
        'port': 8000,
        'route': '/tts',
        'method': 'POST',
        'headers': {
          'Content-Type': 'text/plain',
        },
      },
      'llm': {
        'mode': 'ip-port',
        'ip': '127.0.0.1',
        'port': 8000,
        'route': '/llm',
        'method': 'POST',
        'headers': {
          'Content-Type': 'text/plain',
        },
      }
    };
    await saveUserData();
  }

  // 清除所有用户数据
  static Future<void> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('preferences');
      print('所有用户数据已清除');
    } catch (e) {
      print('清除用户数据时出错: $e');
    }
  }
}