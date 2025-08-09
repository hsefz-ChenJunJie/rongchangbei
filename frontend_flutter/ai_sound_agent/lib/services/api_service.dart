import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:ai_sound_agent/utils/constants.dart';
import 'package:ai_sound_agent/services/userdata_services.dart';

class ApiService {
  static final Dio _dio = Dio();

  /// 获取一言（Hitokoto）API的一句话
  /// 无需传入参数，返回一句话内容
  static Future<String> getHitokoto() async {
    try {
      final response = await _dio.get(
        hitokotoApi,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // 从返回的JSON中提取hitokoto字段
        return data['hitokoto'] ?? '获取一言失败';
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('获取一言时发生错误: $e');
      return '获取一言失败';
    }
  }

  /// 语音转文本API调用
  /// [audioBytes] 音频文件的二进制数据
  /// 返回识别到的文本内容
  static Future<String> speechToText(List<int> audioBytes) async {
    try {
      // 获取用户配置
      final userdata = Userdata();
      await userdata.loadUserData();
      
      final sttConfig = userdata.preferences['stt'];
      final String baseUrl = sttConfig['url'] ?? 'http://localhost:8000';
      final String route = sttConfig['route'] ?? '/stt';
      final String method = sttConfig['method'] ?? 'POST';
      final Map<String, dynamic> headers = Map<String, dynamic>.from(sttConfig['headers'] ?? {});
      
      final String fullUrl = '$baseUrl$route';
      
      // 准备请求数据
      final formData = FormData();
      formData.files.add(MapEntry(
        'audio_file',
        MultipartFile.fromBytes(
          audioBytes,
          filename: 'audio.wav',
        ),
      ));

      // 发送请求
      final response = await _dio.post(
        fullUrl,
        data: formData,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // 根据API文档返回格式提取文本
        if (data is Map<String, dynamic>) {
          return data['text'] ?? data['result'] ?? '语音识别失败';
        } else if (data is String) {
          return data;
        } else {
          return '语音识别失败';
        }
      } else {
        throw Exception('语音识别请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('语音识别时发生错误: $e');
      return '语音识别失败';
    }
  }

  /// 文本转语音API调用
  /// [text] 要转换为语音的文本内容
  /// 返回音频文件的二进制数据
  static Future<List<int>> textToSpeech(String text) async {
    try {
      // 获取用户配置
      final userdata = Userdata();
      await userdata.loadUserData();
      
      final ttsConfig = userdata.preferences['tts'];
      final String baseUrl = ttsConfig['url'] ?? 
          (ttsConfig['mode'] == 'ip-port' 
              ? 'http://${ttsConfig['ip']}:${ttsConfig['port']}' 
              : ttsConfig['url'] ?? 'http://localhost:8000');
      final String route = ttsConfig['route'] ?? '/tts';
      final String method = ttsConfig['method'] ?? 'POST';
      final Map<String, dynamic> headers = Map<String, dynamic>.from(ttsConfig['headers'] ?? {});
      
      final String fullUrl = '$baseUrl$route';
      
      // 准备请求数据
      final Map<String, dynamic> requestData = {
        'text': text,
      };

      // 发送请求
      final response = await _dio.post(
        fullUrl,
        data: requestData,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes, // 获取二进制响应
        ),
      );

      if (response.statusCode == 200) {
        // 返回音频文件的二进制数据
        return response.data as List<int>;
      } else {
        throw Exception('文本转语音请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('文本转语音时发生错误: $e');
      return []; // 返回空列表表示失败
    }
  }

  /// 生成建议API调用（LLM）
  /// [scenarioContext] 场景上下文
  /// [userOpinion] 用户观点
  /// [targetDialogue] 目标对话
  /// [modificationSuggestion] 修改建议列表
  /// [suggestionCount] 建议数量（默认3个）
  /// 返回生成的建议列表
  static Future<List<String>> generateSuggestion({
    required String scenarioContext,
    required String userOpinion,
    required String targetDialogue,
    List<String> modificationSuggestion = const [],
    int suggestionCount = 3,
  }) async {
    try {
      // 获取用户配置
      final userdata = Userdata();
      await userdata.loadUserData();
      
      final llmConfig = userdata.preferences['llm'];
      final String baseUrl = llmConfig['url'] ?? 
          (llmConfig['mode'] == 'ip-port' 
              ? 'http://${llmConfig['ip']}:${llmConfig['port']}' 
              : llmConfig['url'] ?? 'http://localhost:8000');
      final String route = llmConfig['route'] ?? '/llm';
      final String method = llmConfig['method'] ?? 'POST';
      final Map<String, dynamic> headers = Map<String, dynamic>.from(llmConfig['headers'] ?? {});
      
      final String fullUrl = '$baseUrl$route';
      
      // 准备请求数据（符合API文档格式）
      final Map<String, dynamic> requestData = {
        'scenario_context': scenarioContext,
        'user_opinion': userOpinion,
        'target_dialogue': targetDialogue,
        'modification_suggestion': modificationSuggestion,
        'suggestion_count': suggestionCount,
      };

      // 设置正确的Content-Type
      headers['Content-Type'] = 'application/json';

      // 添加API密钥（如果配置了）
      if (llmConfig['use_api_key'] == true && llmConfig['api_key'] != null && llmConfig['api_key'].isNotEmpty) {
        headers['Authorization'] = 'Bearer ${llmConfig['api_key']}';
      }

      // 发送请求
      final response = await _dio.post(
        fullUrl,
        data: requestData,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 解析返回的建议列表
        if (data is Map<String, dynamic>) {
          final suggestions = data['suggestions'] ?? data['modification_suggestions'];
          if (suggestions is List) {
            return List<String>.from(suggestions.map((s) => s.toString()));
          } else {
            return ['生成建议失败'];
          }
        } else if (data is List) {
          return List<String>.from(data.map((s) => s.toString()));
        } else {
          return ['生成建议失败'];
        }
      } else {
        throw Exception('生成建议请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('生成建议时发生错误: $e');
      return ['生成建议失败']; // 返回包含错误信息的列表
    }
  }
}