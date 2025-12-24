import 'package:shared_preferences/shared_preferences.dart';

/// 建议设置服务 - 管理用户的默认建议配置
class SuggestionSettingsService {
  static const String _keyPrefix = 'default_suggestions';
  static const String _suggestionsKey = '$_keyPrefix:list';
  
  /// 获取默认建议列表
  static Future<List<String>> getDefaultSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final suggestions = prefs.getStringList(_suggestionsKey);
    
    if (suggestions == null || suggestions.isEmpty) {
      // 返回内置的默认建议
      return [
        '表达同意',
        '表示反对',
        '提出质疑',
        '表示困惑',
        '表示理解',
        '继续深入',
        '转移话题'
      ];
    }
    
    return suggestions;
  }
  
  /// 保存默认建议列表
  static Future<bool> saveDefaultSuggestions(List<String> suggestions) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setStringList(_suggestionsKey, suggestions);
  }
  
  /// 添加新的默认建议
  static Future<bool> addDefaultSuggestion(String suggestion) async {
    final currentSuggestions = await getDefaultSuggestions();
    if (!currentSuggestions.contains(suggestion)) {
      currentSuggestions.add(suggestion);
      return await saveDefaultSuggestions(currentSuggestions);
    }
    return false;
  }
  
  /// 删除默认建议
  static Future<bool> removeDefaultSuggestion(String suggestion) async {
    final currentSuggestions = await getDefaultSuggestions();
    final updated = currentSuggestions.where((s) => s != suggestion).toList();
    if (updated.length < currentSuggestions.length) {
      return await saveDefaultSuggestions(updated);
    }
    return false;
  }
  
  /// 更新默认建议
  static Future<bool> updateDefaultSuggestion(String oldSuggestion, String newSuggestion) async {
    final currentSuggestions = await getDefaultSuggestions();
    final index = currentSuggestions.indexOf(oldSuggestion);
    if (index != -1) {
      currentSuggestions[index] = newSuggestion;
      return await saveDefaultSuggestions(currentSuggestions);
    }
    return false;
  }
  
  /// 重置为内置默认建议
  static Future<bool> resetToBuiltInDefaults() async {
    final builtInDefaults = [
      '表达同意',
      '表示反对',
      '提出质疑',
      '表示困惑',
      '表示理解',
      '继续深入',
      '转移话题'
    ];
    return await saveDefaultSuggestions(builtInDefaults);
  }
}