import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as flutter_contacts;
import 'package:permission_handler/permission_handler.dart';
import '../services/partner_manager.dart';
import '../widgets/shared/base.dart';
import '../widgets/shared/base_line_input.dart';
import '../widgets/shared/add_partner_dialog.dart';
import '../services/theme_manager.dart';
import '../pages/main_processing.dart'; // 添加MainProcessingPage的导入
import '../app/route.dart'; // 添加路由导入

class ChatPartnersPage extends BasePage {
  const ChatPartnersPage({super.key})
      : super(
          title: '对话人管理',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  ChatPartnersPageState createState() => ChatPartnersPageState();
}

class ChatPartnersPageState extends BasePageState<ChatPartnersPage> {
  @override
  int getInitialBottomNavIndex() => 2; // 对话人页面索引为2
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  
  List<ChatPartner> _allPartners = [];
  List<ChatPartner> _filteredPartners = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPartners() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final partnerManager = await PartnerManager.getInstance();
      final partners = partnerManager.getAllPartners();
      
      if (mounted) {
        setState(() {
          _allPartners = partners;
          _filteredPartners = _sortPartnersByPinyin(partners);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载对话人失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ChatPartner> _sortPartnersByPinyin(List<ChatPartner> partners) {
    // 按拼音首字母排序
    partners.sort((a, b) {
      final aPinyin = _getFirstLetter(a.name);
      final bPinyin = _getFirstLetter(b.name);
      return aPinyin.compareTo(bPinyin);
    });
    return partners;
  }

  String _getFirstLetter(String name) {
    try {
      if (name.isEmpty) return '#';
      
      // 获取第一个字符的拼音首字母
      final firstChar = name[0];
      final pinyin = PinyinHelper.getFirstWordPinyin(firstChar);
      
      // 如果是中文，取拼音首字母；如果是英文，直接取首字母
      if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(firstChar)) {
        return pinyin.isNotEmpty ? pinyin[0].toUpperCase() : '#';
      } else {
        return firstChar.toUpperCase();
      }
    } catch (e) {
      return '#';
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _filterPartners();
      });
    }
  }

  void _filterPartners() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredPartners = _sortPartnersByPinyin(List.from(_allPartners));
      });
    } else {
      final partnerManager = await PartnerManager.getInstance();
      final results = partnerManager.searchPartners(_searchQuery);
      setState(() {
        _filteredPartners = _sortPartnersByPinyin(results);
      });
    }
  }

  void _performSearch() {
    _filterPartners();
    _searchFocusNode.unfocus();
  }

  void _showAddPartnerDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPartnerDialog(
        onAddPartner: (name, description) => _addPartner(name, description: description),
        initialName: _searchController.text,
      ),
    );
  }

  Future<void> _addPartner(String name, {String description = ''}) async {
    try {
      final partnerManager = await PartnerManager.getInstance();
      final newPartner = await partnerManager.createPartner(
        name: name,
        desc: description,
      );
      
      if (newPartner != null) {
        await _loadPartners();
        if (mounted) {
          _searchController.clear();
            
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加对话人: $name')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加对话人失败')),
          );
        }
      }
    } catch (e) {
      debugPrint('添加对话人失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加对话人失败')),
        );
      }
    }
  }

  Future<void> _importFromContacts() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要通讯录权限才能导入')),
          );
        }
        return;
      }

      // 检查flutter_contacts权限
      if (!await flutter_contacts.FlutterContacts.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要通讯录权限才能导入')),
          );
        }
        return;
      }

      final contacts = await flutter_contacts.FlutterContacts.getContacts(withProperties: true);
      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('通讯录中没有联系人')),
          );
        }
        return;
      }

      // 显示联系人选择对话框
      if (mounted) {
        _showContactSelectionDialog(contacts);
      }
    } catch (e) {
      debugPrint('导入通讯录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入通讯录失败')),
        );
      }
    }
  }

  void _showContactSelectionDialog(List<dynamic> contacts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择联系人'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index] as flutter_contacts.Contact;
              return ListTile(
                title: Text(contact.displayName.isNotEmpty ? contact.displayName : '未知'),
                subtitle: contact.phones.isNotEmpty
                    ? Text(contact.phones.first.number)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _importContact(contact);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _importContact(dynamic contact) async {
    try {
      final flutterContact = contact as flutter_contacts.Contact;
      final partnerManager = await PartnerManager.getInstance();
      final name = flutterContact.displayName.isNotEmpty ? flutterContact.displayName : '未知联系人';
      
      // 从通讯录生成备注信息
      String description = '';
      if (flutterContact.phones.isNotEmpty || flutterContact.emails.isNotEmpty) {
        List<String> infoParts = [];
        if (flutterContact.phones.isNotEmpty) {
          infoParts.add('电话: ${flutterContact.phones.first.number}');
        }
        if (flutterContact.emails.isNotEmpty) {
          infoParts.add('邮箱: ${flutterContact.emails.first.address}');
        }
        description = infoParts.join(', ');
      }
      
      final newPartner = await partnerManager.createPartner(
        name: name,
        phoneNumber: flutterContact.phones.isNotEmpty 
            ? flutterContact.phones.first.number 
            : null,
        email: flutterContact.emails.isNotEmpty 
            ? flutterContact.emails.first.address 
            : null,
        desc: description,
      );

      if (newPartner != null) {
        await _loadPartners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导入: $name')),
          );
        }
      }
    } catch (e) {
      debugPrint('导入联系人失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入联系人失败')),
        );
      }
    }
  }

  Future<void> _deletePartner(ChatPartner partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除对话人 "${partner.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final partnerManager = await PartnerManager.getInstance();
        await partnerManager.removePartner(partner.id);
        await _loadPartners();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除: ${partner.name}')),
          );
        }
      } catch (e) {
        debugPrint('删除对话人失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除对话人失败')),
          );
        }
      }
    }
  }

  Map<String, List<ChatPartner>> _groupPartnersByLetter() {
    final Map<String, List<ChatPartner>> grouped = {};
    
    for (final partner in _filteredPartners) {
      final letter = _getFirstLetter(partner.name);
      if (!grouped.containsKey(letter)) {
        grouped[letter] = [];
      }
      grouped[letter]!.add(partner);
    }
    
    return grouped;
  }

  @override
  Widget buildContent(BuildContext context) {
    final themeManager = ThemeManager();
    
    return Stack(
      children: [
        Column(
          children: [
            // 搜索栏
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: BaseLineInput(
                      label: '搜索对话人',
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: '输入姓名、电话或邮箱',
                      icon: const Icon(Icons.search),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.search, size: 28),
                    onPressed: _performSearch,
                    style: IconButton.styleFrom(
                      backgroundColor: themeManager.baseColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    onPressed: _showAddPartnerDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: themeManager.baseColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Expanded(
              child: _isLoading
                  ? buildLoadingState()
                  : _filteredPartners.isEmpty
                      ? buildEmptyState(
                          message: _searchQuery.isEmpty
                              ? '暂无对话人，点击右上角添加'
                              : '未找到匹配的对话人',
                          icon: Icons.people_outline,
                          onRetry: _loadPartners,
                        )
                      : _buildPartnerList(),
            ),
            
            // 底部导入按钮
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.contacts),
                  label: const Text('从通讯录导入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeManager.baseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _importFromContacts,
                ),
              ),
            ),
          ],
        ),
        

      ],
    );
  }

  Widget _buildPartnerList() {
    final grouped = _groupPartnersByLetter();
    final letters = grouped.keys.toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final partners = grouped[letter]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...partners.map((partner) => _buildPartnerCard(partner)),
          ],
        );
      },
    );
  }

  Widget _buildPartnerCard(ChatPartner partner) {
    final themeManager = ThemeManager();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: themeManager.baseColor,
          child: Text(
            partner.name.isNotEmpty ? partner.name[0] : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          partner.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (partner.phoneNumber != null)
              Text(partner.phoneNumber!),
            if (partner.email != null)
              Text(partner.email!),
            if (partner.desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  partner.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Text(
              '最后聊天: ${_formatDate(partner.lastChatTime)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              onPressed: () => _startChatWithPartner(partner),
              tooltip: '开始对话',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除'),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deletePartner(partner);
                }
              },
            ),
          ],
        ),
        onTap: () {
          // 点击卡片也可以开始对话
          _startChatWithPartner(partner);
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }



  void _startChatWithPartner(ChatPartner partner) {
    // 导航到main_processing页面，传入对话包名称
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainProcessingPage(
          dpfile: partner.dialoguePackageName,
        ),
      ),
    );
  }

  void _navigateToProfileManagement() {
    Navigator.pushNamed(context, Routes.partnerProfileList);
  }

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.folder_shared),
        onPressed: _navigateToProfileManagement,
        tooltip: '档案管理',
      ),
      ...super.buildAppBarActions(context),
    ];
  }
}