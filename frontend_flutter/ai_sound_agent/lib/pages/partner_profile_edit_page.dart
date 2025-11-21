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

  /// 构建基础信息部分
  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基础信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 姓名输入
            BaseLineInput(
                controller: _nameController,
                label: '姓名',
                placeholder: '请输入对话人姓名',
                onChanged: (value) {
                  _updateFinalText(); // 实时更新最终文本
                },
              ),
            const SizedBox(height: 16),
            
            // 关系选择
            const Text('关系', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['家人', '朋友', '同事', '恋人', '其他'].map((relationship) {
                final isSelected = _selectedRelationship == relationship;
                return ChoiceChip(
                  label: Text(relationship),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRelationship = selected ? relationship : null;
                    });
                    _updateFinalText(); // 实时更新最终文本
                  },
                );
              }).toList(),
            ),
            if (_selectedRelationship == '其他') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customRelationshipController,
                decoration: const InputDecoration(
                  labelText: '自定义关系',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _updateFinalText(); // 实时更新最终文本
                },
              ),
            ],
            const SizedBox(height: 16),
            
            // 年龄输入
            BaseLineInput(
              controller: _ageController,
              label: '年龄',
              placeholder: '请输入年龄',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                _updateFinalText(); // 实时更新最终文本
              },
            ),
            const SizedBox(height: 16),
            
            // 性别选择
            const Text('性别', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: ['男', '女', '保密'].map((gender) {
                final isSelected = _selectedGender == gender;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(gender),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGender = selected ? gender : null;
                      });
                      _updateFinalText(); // 实时更新最终文本
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建声纹部分
  Widget _buildVoiceprintSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '声纹信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_hasVoiceprint) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text('已录制声纹'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _hasVoiceprint = false;
                        _voiceprintPath = null;
                      });
                    },
                    child: const Text('删除'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.mic_off, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text('未录制声纹'),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isRecordingVoiceprint ? null : _recordVoiceprint,
                    icon: const Icon(Icons.mic),
                    label: Text(_isRecordingVoiceprint ? '录制中...' : '录制声纹'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建扩展信息部分
  Widget _buildExtendedInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '扩展信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 性格标签选择
            const Text('性格标签', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['开朗', '内向', '幽默', '严肃', '温柔', '直率', '细心', '大方'].map((personality) {
                final isSelected = _selectedPersonalityTags.contains(personality);
                return FilterChip(
                  label: Text(personality),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPersonalityTags.add(personality);
                      } else {
                        _selectedPersonalityTags.remove(personality);
                      }
                    });
                    _updateFinalText(); // 实时更新最终文本
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // 禁忌话题输入
            BaseLineInput(
              controller: _tabooTopicsController,
              label: '禁忌话题',
              placeholder: '请输入对话中应避免的话题',
              maxLines: 2,
              onChanged: (value) {
                _updateFinalText(); // 实时更新最终文本
              },
            ),
            const SizedBox(height: 16),
            
            // 共同经历输入
            BaseLineInput(
              controller: _sharedExperiencesController,
              label: '共同经历',
              placeholder: '请输入与对话人的共同经历',
              maxLines: 3,
              onChanged: (value) {
                _updateFinalText(); // 实时更新最终文本
              },
            ),
            const SizedBox(height: 16),
            
            // 生成示例文本按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateExampleText,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成示例文本'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? '保存' : '创建'),
            ),
          ),
        ],
      ),
    );
  }

  /// 录制声纹
  void _recordVoiceprint() async {
    setState(() {
      _isRecordingVoiceprint = true;
    });
    
    try {
      // 模拟录制过程
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        _hasVoiceprint = true;
        _voiceprintPath = 'voiceprint_${DateTime.now().millisecondsSinceEpoch}.wav';
        _isRecordingVoiceprint = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('声纹录制成功')),
        );
      }
    } catch (e) {
      setState(() {
        _isRecordingVoiceprint = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录制失败: $e')),
        );
      }
    }
  }

  /// 生成示例文本
  void _generateExampleText() {
    final exampleNames = ['小明', '小红', '小李', '小王', '小张'];
    final exampleCities = ['北京', '上海', '广州', '深圳', '杭州'];
    final exampleZodiacs = ['白羊座', '金牛座', '双子座', '巨蟹座', '狮子座'];
    final exampleHobbies = ['看书', '听音乐', '运动', '旅行', '摄影'];
    
    final randomName = exampleNames[DateTime.now().millisecond % exampleNames.length];
    final randomCity = exampleCities[DateTime.now().millisecond % exampleCities.length];
    final randomZodiac = exampleZodiacs[DateTime.now().millisecond % exampleZodiacs.length];
    final randomHobby = exampleHobbies[DateTime.now().millisecond % exampleHobbies.length];
    
    final exampleText = '名字叫$randomName，来自$randomCity，是$randomZodiac，喜欢$randomHobby。性格开朗、幽默，不喜欢谈论工作压力，我们曾一起旅行、看电影。';
    
    setState(() {
      _sharedExperiencesController.text = exampleText;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已生成示例文本')),
    );
    
    // 更新最终文本
    _updateFinalText();
  }

  /// 保存档案
  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入姓名')),
      );
      return;
    }
    
    if (_selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择关系')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final profileManager = await ProfileManager.getInstance();
      PartnerProfile profile;
      
      if (_isEditing) {
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
        final partnerManager = await PartnerManager.getInstance();
        final targetPartnerId = widget.partnerId ?? partnerManager.getAllPartners().firstOrNull?.id;
        if (targetPartnerId == null) {
          throw Exception('无法获取当前伙伴ID');
        }
        
        final newProfile = await profileManager.createProfile(
          partnerId: targetPartnerId,
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
        
        if (newProfile == null) {
          throw Exception('创建档案失败');
        }
        profile = newProfile;
      }
      
      if (mounted) {
        Navigator.of(context).pop(profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 主要的自然语言文本显示
              _buildMainTextDisplay(),
              const SizedBox(height: 16),
              
              // 切换按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showForm = !_showForm;
                    });
                  },
                  icon: Icon(_showForm ? Icons.visibility_off : Icons.visibility),
                  label: Text(_showForm ? '隐藏编辑表单' : '显示编辑表单'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 表单部分（可折叠）
              if (_showForm) ...[
                _buildBasicInfoSection(),
                const SizedBox(height: 16),
                _buildVoiceprintSection(),
                const SizedBox(height: 16),
                _buildExtendedInfoSection(),
                const SizedBox(height: 16),
              ],
              
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
}