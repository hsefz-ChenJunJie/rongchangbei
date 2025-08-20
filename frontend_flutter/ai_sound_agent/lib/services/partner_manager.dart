import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';  
import 'package:lpinyin/lpinyin.dart';
import 'dp_manager.dart';

/// 经常对话的对象模型
class ChatPartner {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? email;
  final String desc;  // 描述字段，默认为空
  final DateTime lastChatTime;
  final int chatFrequency;
  final Map<String, dynamic>? extraData;
  final String dialoguePackageName; // 绑定的对话包文件名

  ChatPartner({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phoneNumber,
    this.email,
    this.desc = '',  // 默认为空字符串
    required this.lastChatTime,
    this.chatFrequency = 0,
    this.extraData,
    required this.dialoguePackageName, // 必填参数
  });

  /// 从JSON创建ChatPartner对象
  factory ChatPartner.fromJson(Map<String, dynamic> json) {
    return ChatPartner(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      desc: json['desc'] ?? '',  // 从JSON读取，默认为空
      lastChatTime: DateTime.parse(json['lastChatTime']),
      chatFrequency: json['chatFrequency'] ?? 0,
      extraData: json['extraData'],
      dialoguePackageName: json['dialoguePackageName'] ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
      'email': email,
      'desc': desc,  // 包含desc字段
      'lastChatTime': lastChatTime.toIso8601String(),
      'chatFrequency': chatFrequency,
      'extraData': extraData,
      'dialoguePackageName': dialoguePackageName,
    };
  }

  /// 复制对象并更新字段
  ChatPartner copyWith({
    String? name,
    String? avatarUrl,
    String? phoneNumber,
    String? email,
    String? desc,  // 添加desc参数
    DateTime? lastChatTime,
    int? chatFrequency,
    Map<String, dynamic>? extraData,
    String? dialoguePackageName,
  }) {
    return ChatPartner(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      desc: desc ?? this.desc,  // 更新desc字段
      lastChatTime: lastChatTime ?? this.lastChatTime,
      chatFrequency: chatFrequency ?? this.chatFrequency,
      extraData: extraData ?? this.extraData,
      dialoguePackageName: dialoguePackageName ?? this.dialoguePackageName,
    );
  }
}

/// 管理经常对话的对象
class PartnerManager {
  static const String _storageKey = 'chat_partners';
  static PartnerManager? _instance;
  late SharedPreferences _prefs;
  late DPManager _dpManager;

  /// 单例模式
  static Future<PartnerManager> getInstance() async {
    if (_instance == null) {
      _instance = PartnerManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  PartnerManager._();

  /// 初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _dpManager = DPManager();
    await _dpManager.init();
  }

  /// 将中文名字转换为拼音文件名
  String _nameToPinyinFileName(String name) {
    try {
      // 使用lpinyin转换为拼音，并处理特殊字符
      String pinyin = PinyinHelper.getPinyin(name, separator: '', format: PinyinFormat.WITHOUT_TONE);
      
      // 移除非字母数字字符，确保文件名安全
      pinyin = pinyin.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      
      // 如果为空或太短，使用时间戳
      if (pinyin.isEmpty || pinyin.length < 2) {
        pinyin = 'partner_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      return pinyin.toLowerCase();
    } catch (e) {
      // 如果转换失败，使用时间戳
      return 'partner_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 创建新的聊天伙伴并自动创建对应的对话包
  Future<ChatPartner?> createPartner({
    required String name,
    String? avatarUrl,
    String? phoneNumber,
    String? email,
    String desc = '',
  }) async {
    try {
      // 生成拼音文件名
      final dialoguePackageName = _nameToPinyinFileName(name);
      
      // 检查对话包是否已存在
      final exists = await _dpManager.exists(dialoguePackageName);
      
      if (!exists) {
        // 创建初始消息，以该人物身份发出
        final initialMessage = Message(
          idx: 0,
          name: name,
          content: '我们可以开始聊天了',
          time: DateTime.now().toString(),
          isMe: false, // 以人物身份发出，不是用户
        );

        // 创建对应的对话包
        await _dpManager.createNewDp(
          dialoguePackageName,
          packageName: name, // 包名使用人名
          description: '与$name的聊天记录',
          scenarioDescription: '与$name的聊天对话',
          subjectMatter: '聊天对象',
          initialMessages: [initialMessage],
        );
      }

      // 创建ChatPartner对象
      final partner = ChatPartner(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        email: email,
        desc: desc,
        lastChatTime: DateTime.now(),
        chatFrequency: 0,
        dialoguePackageName: dialoguePackageName,
      );

      // 保存到本地
      await addPartner(partner);
      
      return partner;
    } catch (e) {
      print('创建聊天伙伴失败: $e');
      return null;
    }
  }

  /// 获取聊天伙伴对应的对话包
  Future<DialoguePackage?> getPartnerDialoguePackage(ChatPartner partner) async {
    try {
      return await _dpManager.getDp(partner.dialoguePackageName);
    } catch (e) {
      print('获取对话包失败: $e');
      return null;
    }
  }

  /// 更新聊天伙伴的对话包
  Future<bool> updatePartnerDialoguePackage(ChatPartner partner, DialoguePackage dialoguePackage) async {
    try {
      await _dpManager.saveDp(dialoguePackage);
      return true;
    } catch (e) {
      print('更新对话包失败: $e');
      return false;
    }
  }

  /// 获取所有经常对话的对象
  List<ChatPartner> getAllPartners() {
    final String? partnersJson = _prefs.getString(_storageKey);
    if (partnersJson == null) return [];

    try {
      final List<dynamic> partnersList = json.decode(partnersJson);
      return partnersList
          .map((json) => ChatPartner.fromJson(json))
          .toList();
    } catch (e) {
      print('解析聊天伙伴数据失败: $e');
      return [];
    }
  }

  /// 根据ID获取特定对象
  ChatPartner? getPartnerById(String id) {
    final partners = getAllPartners();
    return partners.firstWhere((partner) => partner.id == id);
  }

  /// 添加新的聊天对象
  Future<bool> addPartner(ChatPartner partner) async {
    try {
      final partners = getAllPartners();
      
      // 检查是否已存在
      final existingIndex = partners.indexWhere((p) => p.id == partner.id);
      if (existingIndex != -1) {
        // 更新已存在的对象
        partners[existingIndex] = partner;
      } else {
        // 添加新对象
        partners.add(partner);
      }

      return await _savePartners(partners);
    } catch (e) {
      print('添加聊天伙伴失败: $e');
      return false;
    }
  }

  /// 更新聊天对象的聊天频率和最后聊天时间
  Future<bool> updateChatActivity(String partnerId) async {
    try {
      final partners = getAllPartners();
      final index = partners.indexWhere((p) => p.id == partnerId);
      
      if (index == -1) return false;

      final updatedPartner = partners[index].copyWith(
        lastChatTime: DateTime.now(),
        chatFrequency: partners[index].chatFrequency + 1,
      );

      partners[index] = updatedPartner;
      return await _savePartners(partners);
    } catch (e) {
      print('更新聊天活动失败: $e');
      return false;
    }
  }

  /// 删除聊天对象及其对应的对话包
  Future<bool> removePartner(String id) async {
    try {
      final partners = getAllPartners();
      final partner = partners.firstWhere((p) => p.id == id);
      
      // 删除对应的对话包（除了default和current）
      if (partner.dialoguePackageName != 'default' && partner.dialoguePackageName != 'current') {
        try {
          await _dpManager.deleteDp(partner.dialoguePackageName);
        } catch (e) {
          print('删除对话包失败: $e');
        }
      }
      
      // 删除聊天伙伴
      partners.removeWhere((partner) => partner.id == id);
      return await _savePartners(partners);
    } catch (e) {
      print('删除聊天伙伴失败: $e');
      return false;
    }
  }

  /// 获取最常聊天的前N个对象
  List<ChatPartner> getTopPartners(int count) {
    final partners = getAllPartners();
    partners.sort((a, b) => b.chatFrequency.compareTo(a.chatFrequency));
    return partners.take(count).toList();
  }

  /// 获取最近聊天的对象
  List<ChatPartner> getRecentPartners({int days = 7}) {
    final partners = getAllPartners();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    return partners.where((partner) => 
      partner.lastChatTime.isAfter(cutoffDate)
    ).toList()
      ..sort((a, b) => b.lastChatTime.compareTo(a.lastChatTime));
  }

  /// 搜索聊天对象
  List<ChatPartner> searchPartners(String query) {
    final partners = getAllPartners();
    final lowerQuery = query.toLowerCase();
    
    return partners.where((partner) =>
      partner.name.toLowerCase().contains(lowerQuery) ||
      partner.phoneNumber?.toLowerCase().contains(lowerQuery) == true ||
      partner.email?.toLowerCase().contains(lowerQuery) == true ||
      partner.desc.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// 清空所有聊天对象
  Future<bool> clearAllPartners() async {
    try {
      return await _prefs.remove(_storageKey);
    } catch (e) {
      print('清空聊天伙伴失败: $e');
      return false;
    }
  }

  /// 保存聊天对象列表到本地存储
  Future<bool> _savePartners(List<ChatPartner> partners) async {
    try {
      final partnersJson = json.encode(
        partners.map((partner) => partner.toJson()).toList()
      );
      return await _prefs.setString(_storageKey, partnersJson);
    } catch (e) {
      print('保存聊天伙伴失败: $e');
      return false;
    }
  }

  /// 从联系人导入聊天对象并创建对应对话包
  static Future<ChatPartner?> importFromContacts(String contactId) async {
    try {
      // 请求联系人权限
      if (!await FlutterContacts.requestPermission()) {
        print('没有联系人访问权限');
        return null;
      }

      // 获取所有联系人
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final contact = contacts.firstWhere((c) => c.id == contactId);
      
      if (contact == null) return null;

      // 获取PartnerManager实例
      final partnerManager = await PartnerManager.getInstance();
      
      // 使用createPartner创建对象和对话包
      return await partnerManager.createPartner(
        name: contact.displayName.isNotEmpty ? contact.displayName : '未知联系人',
        phoneNumber: contact.phones.isNotEmpty 
            ? contact.phones.first.number 
            : null,
        email: contact.emails.isNotEmpty 
            ? contact.emails.first.address 
            : null,
      );
    } catch (e) {
      print('从联系人导入失败: $e');
      return null;
    }
  }

  /// 获取统计数据
  Map<String, dynamic> getStats() {
    final partners = getAllPartners();
    final totalPartners = partners.length;
    final totalChats = partners.fold(0, (sum, partner) => sum + partner.chatFrequency);
    final mostActivePartner = partners.isEmpty 
        ? null 
        : partners.reduce((a, b) => a.chatFrequency > b.chatFrequency ? a : b);

    return {
      'totalPartners': totalPartners,
      'totalChats': totalChats,
      'mostActivePartner': mostActivePartner?.name,
      'mostActiveCount': mostActivePartner?.chatFrequency,
    };
  }
}