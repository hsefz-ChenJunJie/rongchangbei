import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/partner_profile.dart';
import '../services/profile_manager.dart';
import '../services/partner_manager.dart';
import '../widgets/shared/base.dart';
import '../widgets/shared/base_line_input.dart';

/// 档案创建/编辑页
class PartnerProfileEditPage extends BasePage {
  final PartnerProfile? existingProfile;
  final String? partnerId;

  const PartnerProfileEditPage({
    super.key,
    this.existingProfile,
    this.partnerId,
  }) : super(
          title: '档案管理',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  PartnerProfileEditPageState createState() => PartnerProfileEditPageState();
}

class PartnerProfileEditPageState extends BasePageState<PartnerProfileEditPage> {
  // 基础信息
  final _nameController = TextEditingController();
  final _customRelationshipController = TextEditingController();
  String? _selectedRelationship;
  String? _selectedGender;
  final _ageController = TextEditingController();

  // 扩展信息
  final _tabooTopicsController = TextEditingController();
  final _sharedExperiencesController = TextEditingController();
  Set<String> _selectedPersonalityTags = {};

  // 声纹相关
  bool _hasVoiceprint = false;
  String? _voiceprintPath;
  bool _isRecordingVoiceprint = false;

  // 界面控制
  bool _isLoading = false;
  bool _isEditing = false;
  bool _showForm = false; // 控制表格显示/隐藏
  final _finalTextController = TextEditingController(); // 最终文本显示
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '对话人描述',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '(最终发送给AI)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _finalTextController.text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '上面的内容将直接发送给AI，帮助生成更贴合的对话建议',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }) : super(
          title: '档案管理',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  PartnerProfileEditPageState createState() => PartnerProfileEditPageState();
}

class PartnerProfileEditPageState extends BasePageState<PartnerProfileEditPage> {
  // 基础信息
  final _nameController = TextEditingController();
  final _customRelationshipController = TextEditingController();
  String? _selectedRelationship;
  String? _selectedGender;
  final _ageController = TextEditingController();

  // 扩展信息
  final _tabooTopicsController = TextEditingController();
  final _sharedExperiencesController = TextEditingController();
  Set<String> _selectedPersonalityTags = {};

  // 声纹相关
  bool _hasVoiceprint = false;
  String? _voiceprintPath;
  bool _isRecordingVoiceprint = false;

  // 界面控制
  bool _isLoading = false;
  bool _isEditing = false;
  bool _showForm = false; // 控制表格显示/隐藏
  final _finalTextController = TextEditingController(); // 最终文本显示

  /// 构建主要的自然语言文本显示
  Widget _buildMainTextDisplay() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '对话人描述',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '(最终发送给AI)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _finalTextController.text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '上面的内容将直接发送给AI，帮助生成更贴合的对话建议',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingProfile != null;
    if (_isEditing) {
      _loadExistingData();
    }
    
    // 添加监听器，实时更新最终文本
    _nameController.addListener(_updateFinalText);
    _ageController.addListener(_updateFinalText);
    _selectedRelationship = null;
    _selectedGender = null;
    _tabooTopicsController.addListener(_updateFinalText);
    _sharedExperiencesController.addListener(_updateFinalText);
    
    // 初始化最终文本
    _updateFinalText();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customRelationshipController.dispose();
    _ageController.dispose();
    _tabooTopicsController.dispose();
    _sharedExperiencesController.dispose();
    _finalTextController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    final profile = widget.existingProfile!;
    _nameController.text = profile.name;
    _selectedRelationship = profile.relationship;
    _customRelationshipController.text = profile.customRelationship ?? '';
    _selectedGender = profile.gender;
    _ageController.text = profile.age?.toString() ?? '';
    _tabooTopicsController.text = profile.tabooTopics ?? '';
    _sharedExperiencesController.text = profile.sharedExperiences ?? '';
    _selectedPersonalityTags = Set.from(profile.personalityTags);
    _hasVoiceprint = profile.voiceprintPath != null;
    _voiceprintPath = profile.voiceprintPath;
    
    // 加载现有数据后更新最终文本
    _updateFinalText();
  }

  /// 更新最终自然语言文本
  void _updateFinalText() {
    final parts = <String>[];
    
    // 姓名
    if (_nameController.text.trim().isNotEmpty) {
      parts.add('名字叫${_nameController.text.trim()}');
    }
    
    // 年龄
    if (_ageController.text.trim().isNotEmpty) {
      parts.add('年龄为${_ageController.text.trim()}岁');
    }
    
    // 关系
    if (_selectedRelationship != null) {
      if (_selectedRelationship == '其他' && _customRelationshipController.text.trim().isNotEmpty) {
        parts.add('是我的${_customRelationshipController.text.trim()}');
      } else if (_selectedRelationship != '其他') {
        parts.add('是我的$_selectedRelationship');
      }
    }
    
    // 性别
    if (_selectedGender != null) {
      parts.add('性别为$_selectedGender');
    }
    
    // 性格标签
    if (_selectedPersonalityTags.isNotEmpty) {
      parts.add('性格${_selectedPersonalityTags.join('、')}');
    }
    
    // 禁忌话题
    if (_tabooTopicsController.text.trim().isNotEmpty) {
      parts.add('不喜欢谈论${_tabooTopicsController.text.trim()}');
    }
    
    // 共同经历
    if (_sharedExperiencesController.text.trim().isNotEmpty) {
      parts.add(_sharedExperiencesController.text.trim());
    }
    
    // 组合成自然语言文本
    String finalText;
    if (parts.isEmpty) {
      finalText = '请输入对话人信息...';
    } else {
      finalText = parts.join('，') + '。';
    }
    
    setState(() {
      _finalTextController.text = finalText;
    });
  }

  Future<void> _saveProfile() async {
    if (!_validateBasicInfo()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileManager = await ProfileManager.getInstance();
      
      PartnerProfile? profile;
      
      if (_isEditing) {
        // 更新现有档案
        final existing = widget.existingProfile!;
        profile = existing.copyWith(
          name: _nameController.text.trim(),
          relationship: _selectedRelationship!,
          customRelationship: _selectedRelationship == '其他' 
              ? _customRelationshipController.text.trim()
              : null,
          age: _ageController.text.isNotEmpty 
              ? int.tryParse(_ageController.text.trim())
              : null,
          gender: _selectedGender,
          personalityTags: _selectedPersonalityTags.toList(),
          tabooTopics: _tabooTopicsController.text.trim().isNotEmpty
              ? _tabooTopicsController.text.trim()
              : null,
          sharedExperiences: _finalTextController.text, // 保存整合后的自然语言文本
          voiceprintPath: _voiceprintPath,
        );
        
        await profileManager.updateProfile(profile);
      } else {
        // 创建新档案
        String? targetPartnerId = widget.partnerId;
        
        // 如果没有指定partnerId，需要创建对应的ChatPartner
        if (targetPartnerId == null) {
          final partnerManager = await PartnerManager.getInstance();
          final newPartner = await partnerManager.createPartner(
            name: _nameController.text.trim(),
          );
          
          if (newPartner == null) {
            throw Exception('创建对话人失败');
          }
          
          targetPartnerId = newPartner.id;
        }
        
        profile = await profileManager.createProfile(
          partnerId: targetPartnerId!,
          name: _nameController.text.trim(),
          relationship: _selectedRelationship!,
          customRelationship: _selectedRelationship == '其他' 
              ? _customRelationshipController.text.trim()
              : null,
          age: _ageController.text.isNotEmpty 
              ? int.tryParse(_ageController.text.trim())
              : null,
          gender: _selectedGender,
          personalityTags: _selectedPersonalityTags.toList(),
          tabooTopics: _tabooTopicsController.text.trim().isNotEmpty
              ? _tabooTopicsController.text.trim()
              : null,
          sharedExperiences: _finalTextController.text, // 保存整合后的自然语言文本
          voiceprintPath: _voiceprintPath,
        );
      }

      if (profile != null) {
        if (mounted) {
          Navigator.pop(context, profile);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? '档案已更新' : '档案已创建'),
            ),
          );
        }
      } else {
        throw Exception('保存档案失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateBasicInfo() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入姓名')),
      );
      return false;
    }

    if (_selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择关系')),
      );
      return false;
    }

    if (_selectedRelationship == '其他' && 
        _customRelationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入自定义关系')),
      );
      return false;
    }

    return true;
  }

  Future<void> _recordVoiceprint() async {
    // TODO: 实现声纹录制功能
    setState(() => _isRecordingVoiceprint = true);
    
    // 模拟录制过程
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _isRecordingVoiceprint = false;
        _hasVoiceprint = true;
        _voiceprintPath = 'voiceprint_${DateTime.now().millisecondsSinceEpoch}.pcm';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('声纹录制完成')),
      );
    }
  }

  void _removeVoiceprint() {
    setState(() {
      _hasVoiceprint = false;
      _voiceprintPath = null;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return buildBody(context);
  }

  @override
  Widget buildBody(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 主要的自然语言文本框
              _buildMainTextDisplay(),
              const SizedBox(height: 16),
              
              // 切换表单显示的按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showForm = !_showForm;
                    });
                  },
                  icon: Icon(_showForm ? Icons.visibility_off : Icons.edit),
                  label: Text(_showForm ? '隐藏编辑表单' : '显示编辑表单'),
                ),
              ),
              
              // 表单部分（可折叠）
              if (_showForm) ...[
                const SizedBox(height: 24),
                _buildBasicInfoSection(),
                const SizedBox(height: 24),
                _buildVoiceprintSection(),
                const SizedBox(height: 24),
                _buildExtendedInfoSection(),
              ],
              
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '基础信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '(必填)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 姓名输入
            BaseLineInput(
              controller: _nameController,
              label: '姓名',
              placeholder: '请输入对话人姓名',
              onChanged: (value) {
                // 拼音联想功能
                if (value.isNotEmpty && _nameController.text.isNotEmpty) {
                  // TODO: 实现拼音联想
                }
                _updateFinalText(); // 实时更新最终文本
              },
            ),
            const SizedBox(height: 16),

            // 关系选择
            const Text(
              '关系',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RelationshipTypes.options.map((relationship) {
                final isSelected = _selectedRelationship == relationship;
                return ChoiceChip(
                  label: Text(relationship),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRelationship = selected ? relationship : null;
                      if (relationship != '其他') {
                        _customRelationshipController.clear();
                      }
                    });
                    _updateFinalText(); // 实时更新最终文本
                  },
                );
              }).toList(),
            ),
            
            // 自定义关系输入
            if (_selectedRelationship == '其他') ...[
              const SizedBox(height: 16),
              BaseLineInput(
                controller: _customRelationshipController,
                label: '自定义关系',
                placeholder: '请输入具体关系',
              ),
            ],
            
            const SizedBox(height: 16),
            
            // 年龄和性别
            Row(
              children: [
                Expanded(
                  child: BaseLineInput(
                    controller: _ageController,
                    label: '年龄',
                    placeholder: '选填',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: '性别',
                      border: OutlineInputBorder(),
                    ),
                    items: GenderOptions.options.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                      _updateFinalText(); // 实时更新最终文本
                    },
                    hint: const Text('选择性别'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceprintSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '声纹绑定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '(可选)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '录制对话人语音片段，用于后续声纹识别自动关联档案',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            if (!_hasVoiceprint) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRecordingVoiceprint ? null : _recordVoiceprint,
                  icon: _isRecordingVoiceprint
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic),
                  label: Text(_isRecordingVoiceprint ? '录制中...' : '录制声纹'),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    const Text('声纹已录制'),
                    const Spacer(),
                    TextButton(
                      onPressed: _removeVoiceprint,
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtendedInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '扩展信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '(选填)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 性格标签
            const Text(
              '性格标签',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择对话人的性格特征，有助于生成更合适的建议',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PersonalityTags.options.map((tag) {
                final isSelected = _selectedPersonalityTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPersonalityTags.add(tag);
                      } else {
                        _selectedPersonalityTags.remove(tag);
                      }
                    });
                    _updateFinalText(); // 实时更新最终文本
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // 禁忌话题
            BaseLineInput(
              controller: _tabooTopicsController,
              label: '禁忌话题',
              placeholder: '例如：不喜欢聊病情、工作等',
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // 共同经历
            BaseLineInput(
              controller: _sharedExperiencesController,
              label: '共同经历',
              placeholder: '例如：一起参加过婚礼、旅行等',
              maxLines: 3,
            ),
            
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateExampleText,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('生成示例文本'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isEditing ? '更新' : '保存'),
          ),
        ),
      ],
    );
  }

  void _generateExampleText() {
    // 示例数据集合
    final names = ['小明', '小红', '小李', '小王', '小张', '小刘', '小陈', '小林'];
    final cities = ['四川省成都市', '北京市', '上海市', '广东省广州市', '浙江省杭州市', '江苏省南京市', '湖北省武汉市', '陕西省西安市'];
    const zodiacSigns = ['水瓶座', '双鱼座', '白羊座', '金牛座', '双子座', '巨蟹座', '狮子座', '处女座', '天秤座', '天蝎座', '射手座', '摩羯座'];
    final hobbies = ['美食', '旅游', '摄影', '音乐', '电影', '阅读', '运动', '绘画', '手工', '园艺'];
    final personalities = ['开朗', '内向', '幽默', '认真', '温柔', '直率', '细心', '大方'];
    
    // 随机选择数据
    final random = DateTime.now().millisecond;
    final name = names[random % names.length];
    final city = cities[random % cities.length];
    final zodiac = zodiacSigns[random % zodiacSigns.length];
    final hobbyCount = 2 + (random % 3); // 2-4个爱好
    final selectedHobbies = <String>[];
    final hobbyPool = List.from(hobbies)..shuffle();
    for (int i = 0; i < hobbyCount && i < hobbyPool.length; i++) {
      selectedHobbies.add(hobbyPool[i]);
    }
    
    // 生成示例文本
    final exampleText = '名字叫做$name，来自$city，$zodiac。喜欢${selectedHobbies.join('、')}……';
    
    // 更新到共同经历输入框
    setState(() {
      _sharedExperiencesController.text = exampleText;
    });
    
    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已生成示例文本'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // 更新最终文本
    _updateFinalText();
  }
}