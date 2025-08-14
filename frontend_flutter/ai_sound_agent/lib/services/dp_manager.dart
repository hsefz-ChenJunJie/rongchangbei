import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class DialoguePackage {
  final String type;
  final String name;
  final int responseCount;
  final String scenarioDescription;
  final List<Message> messages;
  final String modification;
  final String userOpinion;
  final String scenarioSupplement;

  DialoguePackage({
    required this.type,
    required this.name,
    required this.responseCount,
    required this.scenarioDescription,
    required this.messages,
    required this.modification,
    required this.userOpinion,
    required this.scenarioSupplement,
  });

  factory DialoguePackage.fromJson(Map<String, dynamic> json) {
    var messageList = json['message'] as List;
    List<Message> messages = messageList.map((i) => Message.fromJson(i)).toList();

    return DialoguePackage(
      type: json['type'],
      name: json['name'],
      responseCount: json['response_count'],
      scenarioDescription: json['scenario_description'],
      messages: messages,
      modification: json['modification'] ?? '',
      userOpinion: json['user_opinion'] ?? '',
      scenarioSupplement: json['scenario_supplement'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'response_count': responseCount,
      'scenario_description': scenarioDescription,
      'message': messages.map((e) => e.toJson()).toList(),
      'modification': modification,
      'user_opinion': userOpinion,
      'scenario_supplement': scenarioSupplement,
    };
  }
}

class Message {
  final int idx;
  final String name;
  final String content;
  final String time;
  final bool isMe;

  Message({
    required this.idx,
    required this.name,
    required this.content,
    required this.time,
    required this.isMe,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      idx: json['idx'] ?? 0,
      name: json['name'] ?? '',
      content: json['content'] ?? '',
      time: json['time'] ?? '',
      isMe: json['is_me'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idx': idx,
      'name': name,
      'content': content,
      'time': time,
      'is_me': isMe,
    };
  }

  // 从ChatDialogue的getSelection格式创建Message
  factory Message.fromSelection(Map<String, dynamic> selection) {
    return Message(
      idx: selection['idx'] ?? 0,
      name: selection['name'] ?? '',
      content: selection['content'] ?? '',
      time: selection['time'] ?? '',
      isMe: selection['is_me'] ?? false,
    );
  }
}

class DPManager {
  static const String _dpFolderName = 'dp';
  static const String _defaultDpFileName = 'default.dp';
  
  late Directory _dpDirectory;
  List<String> _availableDpFiles = [];

  // 单例模式
  static final DPManager _instance = DPManager._internal();
  factory DPManager() => _instance;
  DPManager._internal();

  // 初始化DP管理器
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _dpDirectory = Directory('${directory.path}/$_dpFolderName');
    
    // 确保dp文件夹存在
    if (!await _dpDirectory.exists()) {
      await _dpDirectory.create(recursive: true);
    }

    // 检查并创建默认对话包
    await _ensureDefaultDpExists();
    
    // 更新dp文件列表
    await _updateDpFileList();
  }

  // 确保默认对话包存在
  Future<void> _ensureDefaultDpExists() async {
    final defaultDpPath = '${_dpDirectory.path}/$_defaultDpFileName';
    final defaultDpFile = File(defaultDpPath);

    if (!await defaultDpFile.exists()) {
      await _createDefaultDp(defaultDpFile);
    }
  }

  // 创建默认对话包
  Future<void> _createDefaultDp(File targetFile) async {
    try {
      // 从assets加载默认对话包数据
      final String defaultDpJson = await rootBundle.loadString('defaults/default_dialogue_package.json');
      final Map<String, dynamic> defaultData = json.decode(defaultDpJson);
      
      // 保存到目标文件
      await targetFile.writeAsString(json.encode(defaultData));
    } catch (e) {
      // 如果assets加载失败，使用内置默认数据
      final defaultData = {
        "type": "dialogue_package",
        "name": "default",
        "response_count": 3,
        "scenario_description": "对话情景描述文本",
        "message": [
          {
            "idx": 0,
            "name": "system",
            "content": "Created a conversation",
            "time": "2025/8/11 12:34:56",
            "is_me": false
          }
        ],
        "modification": "",
        "user_opinion": "", 
        "scenario_supplement": ""
      };
      
      await targetFile.writeAsString(json.encode(defaultData));
    }
  }

  // 获取DP目录路径
  String get dpDirectoryPath => _dpDirectory.path;

  // 更新dp文件列表
  Future<void> _updateDpFileList() async {
    _availableDpFiles = [];
    if (!await _dpDirectory.exists()) {
      return;
    }

    final files = _dpDirectory.listSync();
    for (final entity in files) {
      if (entity is File && entity.path.endsWith('.dp')) {
        final fileName = entity.path.split('/').last.replaceAll('.dp', '');
        _availableDpFiles.add(fileName);
      }
    }
    
    // 按字母顺序排序
    _availableDpFiles.sort();
  }

  // 获取当前可用的dp文件列表
  List<String> getAvailableDpFiles() {
    return List.from(_availableDpFiles);
  }

  // 异步获取最新的dp文件列表（会重新扫描文件夹）
  Future<List<String>> refreshDpFileList() async {
    await _updateDpFileList();
    return getAvailableDpFiles();
  }

  // 获取所有对话包文件
  Future<List<File>> getAllDpFiles() async {
    if (!await _dpDirectory.exists()) {
      return [];
    }

    final files = _dpDirectory.listSync();
    return files
        .where((entity) => entity is File && entity.path.endsWith('.dp'))
        .map((entity) => entity as File)
        .toList();
  }

  // 获取默认对话包
  Future<DialoguePackage> getDefaultDp() async {
    return await getDp('default');
  }

  // 根据名称获取对话包
  Future<DialoguePackage> getDp(String name) async {
    final dpPath = '${_dpDirectory.path}/$name.dp';
    final dpFile = File(dpPath);

    if (!await dpFile.exists()) {
      throw FileSystemException('对话包不存在: $name');
    }

    final content = await dpFile.readAsString();
    final jsonData = json.decode(content);
    return DialoguePackage.fromJson(jsonData);
  }

  // 保存对话包
  Future<void> saveDp(DialoguePackage dp) async {
    final dpPath = '${_dpDirectory.path}/${dp.name}.dp';
    final dpFile = File(dpPath);
    
    await dpFile.writeAsString(json.encode(dp.toJson()));
    await _updateDpFileList();
  }

  // 删除对话包
  Future<void> deleteDp(String name) async {
    if (name == 'default' || name == 'current') {
      throw Exception('不能删除默认对话包');
    }

    final dpPath = '${_dpDirectory.path}/$name.dp';
    final dpFile = File(dpPath);

    if (await dpFile.exists()) {
      await dpFile.delete();
      await _updateDpFileList();
    }
  }

  // 检查对话包是否存在
  Future<bool> exists(String name) async {
    final dpPath = '${_dpDirectory.path}/$name.dp';
    final dpFile = File(dpPath);
    return await dpFile.exists();
  }

  // 创建新的对话包
  Future<DialoguePackage> createNewDp(String name, {
    String scenarioDescription = '新的对话情景',
    List<Message>? initialMessages,
  }) async {
    if (await exists(name)) {
      throw Exception('对话包已存在: $name');
    }

    final newDp = DialoguePackage(
      type: 'dialogue_package',
      name: name,
      responseCount: 0,
      scenarioDescription: scenarioDescription,
      messages: initialMessages ?? [],
      modification: '',
      userOpinion: '',
      scenarioSupplement: '',
    );

    await saveDp(newDp);
    return newDp;
  }

  // 从ChatDialogue的getSelection数据创建对话包
  Future<DialoguePackage> createDpFromChatSelection(
    String name, 
    List<Map<String, dynamic>> chatMessages, {
    String scenarioDescription = '从聊天记录创建的对话包',
    int responseCount = 0,
    String modification = '',
    String userOpinion = '',
    String scenarioSupplement = '',
  }) async {
    final messages = chatMessages.map((msg) => Message.fromSelection(msg)).toList();
    
    if (await exists(name)) {
      throw Exception('对话包已存在: $name');
    }

    final newDp = DialoguePackage(
      type: 'dialogue_package',
      name: name,
      responseCount: responseCount,
      scenarioDescription: scenarioDescription,
      messages: messages,
      modification: modification,
      userOpinion: userOpinion,
      scenarioSupplement: scenarioSupplement,
    );

    await saveDp(newDp);
    return newDp;
  }

  // 将DialoguePackage转换为ChatMessage列表（用于加载到ChatDialogue）
  List<Map<String, dynamic>> toChatMessages(DialoguePackage dp) {
    return dp.messages.map((msg) => msg.toJson()).toList();
  }

  // 将DialoguePackage转换为历史消息列表（用于发送到服务器）
  List<Map<String, dynamic>> toHistoryMessages(DialoguePackage dp) {
    return dp.messages.map((msg) {
      final json = msg.toJson();
      // 添加message_id和sender字段以满足服务器要求
      json['message_id'] = '${msg.idx}';
      json['sender'] = msg.isMe ? 'user' : msg.name;
      return json;
    }).toList();
  }
}