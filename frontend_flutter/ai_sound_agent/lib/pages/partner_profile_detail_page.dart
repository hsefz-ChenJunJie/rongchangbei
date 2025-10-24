import 'package:flutter/material.dart';
import '../models/partner_profile.dart';
import '../services/profile_manager.dart';
import '../services/partner_manager.dart';
import '../widgets/shared/base.dart';
import 'partner_profile_edit_page.dart';
import '../pages/main_processing.dart';

/// 档案详情页
class PartnerProfileDetailPage extends BasePage {
  final PartnerProfile profile;

  const PartnerProfileDetailPage({
    super.key,
    required this.profile,
  }) : super(
          title: '档案详情',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  PartnerProfileDetailPageState createState() => PartnerProfileDetailPageState();
}

class PartnerProfileDetailPageState extends BasePageState<PartnerProfileDetailPage> {
  late PartnerProfile _profile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnerProfileEditPage(
          existingProfile: _profile,
        ),
      ),
    );

    if (result != null && result is PartnerProfile) {
      setState(() {
        _profile = result;
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${_profile.name}" 的档案吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProfile();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile() async {
    setState(() => _isLoading = true);

    try {
      final profileManager = await ProfileManager.getInstance();
      final success = await profileManager.deleteProfile(_profile.id);

      if (success) {
        if (mounted) {
          Navigator.pop(context, 'deleted');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('档案已删除')),
          );
        }
      } else {
        throw Exception('删除失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startChat() async {
    try {
      final partnerManager = await PartnerManager.getInstance();
      final partner = partnerManager.getPartnerById(_profile.partnerId);

      if (partner != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MainProcessingPage(
                dpfile: partner.dialoguePackageName,
                partnerProfile: _profile,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到对应的对话人')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动对话失败: $e')),
        );
      }
    }
  }

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: _navigateToEdit,
        tooltip: '编辑',
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        onPressed: _showDeleteConfirmation,
        tooltip: '删除',
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context) {
    return buildBody(context);
  }

  @override
  Widget buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildBasicInfoCard(),
          const SizedBox(height: 16),
          _buildExtendedInfoCard(),
          const SizedBox(height: 16),
          _buildVoiceprintCard(),
          const SizedBox(height: 24),
          _buildChatHistoryCard(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                _profile.name.isNotEmpty ? _profile.name[0] : '?',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getRelationshipIcon(_profile.relationship),
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _profile.fullRelationship,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                if (_profile.ageGenderDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _profile.ageGenderDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '基础信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('姓名', _profile.name),
            const SizedBox(height: 12),
            _buildInfoRow('关系', _profile.fullRelationship),
            if (_profile.age != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('年龄', '${_profile.age}岁'),
            ],
            if (_profile.gender != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('性别', _profile.gender!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtendedInfoCard() {
    if (_profile.personalityTags.isEmpty && 
        _profile.tabooTopics == null && 
        _profile.sharedExperiences == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '扩展信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_profile.personalityTags.isNotEmpty) ...[
              const Text(
                '性格特征',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _profile.personalityTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            if (_profile.tabooTopics != null) ...[
              const Text(
                '禁忌话题',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _profile.tabooTopics!,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],
            
            if (_profile.sharedExperiences != null) ...[
              const Text(
                '共同经历',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _profile.sharedExperiences!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceprintCard() {
    if (_profile.voiceprintPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.mic,
              color: Colors.green.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '声纹已绑定',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '可用于声纹识别自动关联档案',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryCard() {
    return FutureBuilder(
      future: _getChatHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final historyCount = snapshot.data ?? 0;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      '沟通记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '历史对话',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$historyCount 条记录',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (historyCount > 0)
                      TextButton.icon(
                        onPressed: () {
                          // TODO: 跳转到聊天记录页面
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('查看详情'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _startChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('开始对话'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label：',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  IconData _getRelationshipIcon(String relationship) {
    switch (relationship) {
      case '家人':
        return Icons.family_restroom;
      case '朋友':
        return Icons.people;
      case '同事':
        return Icons.work;
      case '医生':
        return Icons.medical_services;
      default:
        return Icons.person;
    }
  }

  Future<int> _getChatHistory() async {
    try {
      final partnerManager = await PartnerManager.getInstance();
      final partner = partnerManager.getPartnerById(_profile.partnerId);
      
      if (partner != null) {
        final dp = await partnerManager.getPartnerDialoguePackage(partner);
        return dp?.messages.length ?? 0;
      }
    } catch (e) {
      print('获取聊天记录失败: $e');
    }
    return 0;
  }
}