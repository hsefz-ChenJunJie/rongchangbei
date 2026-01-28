import 'package:flutter/material.dart';
import 'package:idialogue/widgets/shared/base.dart';
import 'package:idialogue/services/user_profile_service.dart';

class UserProfilePage extends BasePage {
  const UserProfilePage({super.key})
      : super(
          title: '我的个人资料',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends BasePageState<UserProfilePage> {
  @override
  int getInitialBottomNavIndex() => 3; // User profile index

  int _selectedModuleIndex = 0; // Default to basic info module
  bool _isLoading = true;
  bool _isSaving = false;
  
  final UserProfileService _profileService = UserProfileService();

  // User profile data models
  Map<String, dynamic> basicInfo = {
    'displayName': '用户',
    'avatar': '',
    'communicationScenes': <String>[],
    'selfIntroduction': '',
  };

  Map<String, dynamic> corpusData = {
    'phrases': <Map<String, dynamic>>[],
    'expressionHabits': {
      'sentenceStyle': '短句',
      'toneWords': <String>[],
      'abbreviations': <String, String>{},
      'typoCorrections': <String, String>{},
    },
    'contextTemplates': <Map<String, dynamic>>[],
  };

  Map<String, dynamic> preferences = {
    'topicPreferences': <String>[],
    'fieldPreferences': <String, List<String>>{},
  };

  Map<String, dynamic> restrictions = {
    'topicBlacklist': <String>[],
    'sensitiveWords': <Map<String, String>>[],
    'communicationRedlines': <String>[],
    'emergencyAvoidWords': <String>[],
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// 加载用户资料数据
  Future<void> _loadUserProfile() async {
    try {
      final profileData = await _profileService.loadProfile();
      if (profileData != null) {
        setState(() {
          basicInfo = Map<String, dynamic>.from(profileData['basicInfo'] ?? {});
          corpusData = Map<String, dynamic>.from(profileData['corpusData'] ?? {});
          preferences = Map<String, dynamic>.from(profileData['preferences'] ?? {});
          restrictions = Map<String, dynamic>.from(profileData['restrictions'] ?? {});
          _isLoading = false;
        });
        debugPrint('用户资料加载成功');
      }
    } catch (e) {
      debugPrint('加载用户资料失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存用户资料数据
  Future<void> _saveUserProfile() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final profileData = {
        'basicInfo': basicInfo,
        'corpusData': corpusData,
        'preferences': preferences,
        'restrictions': restrictions,
      };

      final success = await _profileService.saveProfile(profileData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '设置已保存' : '保存失败，请重试'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('保存用户资料失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载用户资料...'),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left navigation sidebar
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildNavigationItem(0, '基本资料', Icons.person),
              _buildNavigationItem(1, '语料库管理', Icons.chat_bubble),
              _buildNavigationItem(2, '用户偏好设置', Icons.settings),
              _buildNavigationItem(3, '禁忌与敏感设置', Icons.block),
            ],
          ),
        ),
        // Main content area
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: _buildSelectedModule(),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationItem(int index, String title, IconData icon) {
    final isSelected = _selectedModuleIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedModuleIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedModule() {
    switch (_selectedModuleIndex) {
      case 0:
        return _buildBasicInfoModule();
      case 1:
        return _buildCorpusManagementModule();
      case 2:
        return _buildPreferencesModule();
      case 3:
        return _buildRestrictionsModule();
      default:
        return _buildBasicInfoModule();
    }
  }

  // Module 1: Basic Info (基本资料)
  Widget _buildBasicInfoModule() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本资料',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildAvatarSection(),
          const SizedBox(height: 24),
          _buildTextField('显示名称', basicInfo['displayName'], (value) {
            setState(() {
              basicInfo['displayName'] = value;
            });
          }),
          const SizedBox(height: 16),
          _buildCommunicationScenesSection(),
          const SizedBox(height: 16),
          _buildTextField('自我介绍模板', basicInfo['selfIntroduction'], (value) {
            setState(() {
              basicInfo['selfIntroduction'] = value;
            });
          }, maxLines: 3),
          const SizedBox(height: 24),
          _buildSaveButton('保存基本资料'),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade300,
          child: Icon(Icons.person, size: 40, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement avatar upload
          },
          icon: const Icon(Icons.upload),
          label: const Text('上传头像'),
        ),
      ],
    );
  }

  Widget _buildCommunicationScenesSection() {
    final scenes = ['家庭', '工作', '医疗', '社交', '教育', '购物'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('常用交流场景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: scenes.map((scene) {
            final isSelected = basicInfo['communicationScenes'].contains(scene);
            return FilterChip(
              label: Text(scene),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    basicInfo['communicationScenes'].add(scene);
                  } else {
                    basicInfo['communicationScenes'].remove(scene);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // Module 2: Corpus Management (语料库管理)
  Widget _buildCorpusManagementModule() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '语料库管理',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildCorpusTabs(),
        ],
      ),
    );
  }

  Widget _buildCorpusTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '常用短语库'),
              Tab(text: '个性化表达习惯'),
              Tab(text: '语境模板'),
            ],
          ),
          SizedBox(
            height: 500, // Fixed height for tab content
            child: TabBarView(
              children: [
                _buildPhrasesTab(),
                _buildExpressionHabitsTab(),
                _buildContextTemplatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhrasesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '添加常用短语...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      setState(() {
                        corpusData['phrases'].add({
                          'text': text,
                          'tags': ['常用'],
                          'frequency': 0,
                          'lastUsed': DateTime.now().toString(),
                        });
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Add phrase logic
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: corpusData['phrases'].length,
            itemBuilder: (context, index) {
              final phrase = corpusData['phrases'][index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(phrase['text']),
                  subtitle: Text('使用次数: ${phrase['frequency']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          // Play audio
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            corpusData['phrases'].removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpressionHabitsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('句式偏好', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: corpusData['expressionHabits']['sentenceStyle'],
            items: ['短句', '长句', '关键词式'].map((style) {
              return DropdownMenuItem(value: style, child: Text(style));
            }).toList(),
            onChanged: (value) {
              setState(() {
                corpusData['expressionHabits']['sentenceStyle'] = value!;
              });
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _buildTextFieldList('语气词', corpusData['expressionHabits']['toneWords']),
          const SizedBox(height: 16),
          _buildKeyValueList('缩写习惯', corpusData['expressionHabits']['abbreviations']),
          const SizedBox(height: 16),
          _buildKeyValueList('错别字纠正', corpusData['expressionHabits']['typoCorrections']),
        ],
      ),
    );
  }

  Widget _buildContextTemplatesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Add template logic
            },
            icon: const Icon(Icons.add),
            label: const Text('添加语境模板'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: corpusData['contextTemplates'].length,
              itemBuilder: (context, index) {
                final template = corpusData['contextTemplates'][index];
                return Card(
                  child: ListTile(
                    title: Text(template['name'] ?? '模板 ${index + 1}'),
                    subtitle: Text(template['description'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Edit template logic
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Module 3: Preferences (用户偏好设置)
  Widget _buildPreferencesModule() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '用户偏好设置',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildTextFieldList('话题偏好', preferences['topicPreferences']),
          const SizedBox(height: 24),
          _buildFieldPreferencesSection(),
          const SizedBox(height: 24),
          _buildSaveButton('保存偏好设置'),
        ],
      ),
    );
  }

  Widget _buildFieldPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('各个领域喜好设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...preferences['fieldPreferences'].entries.map<Widget>((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value.join(', ')),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _editFieldPreference(entry.key, entry.value);
                },
              ),
            ),
          );
        }).toList(),
        ElevatedButton.icon(
          onPressed: () {
            _addFieldPreference();
          },
          icon: const Icon(Icons.add),
          label: const Text('添加领域偏好'),
        ),
      ],
    );
  }

  // Module 4: Restrictions (禁忌与敏感设置)
  Widget _buildRestrictionsModule() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '禁忌与敏感设置',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildTextFieldList('话题黑名单', restrictions['topicBlacklist']),
          const SizedBox(height: 24),
          _buildSensitiveWordsSection(),
          const SizedBox(height: 24),
          _buildTextFieldList('交流红线', restrictions['communicationRedlines']),
          const SizedBox(height: 24),
          _buildTextFieldList('紧急回避词', restrictions['emergencyAvoidWords']),
          const SizedBox(height: 24),
          _buildSaveButton('保存敏感设置'),
        ],
      ),
    );
  }

  Widget _buildSensitiveWordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('敏感词替代方案', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...restrictions['sensitiveWords'].map<Widget>((word) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('敏感词: ${word['word']}'),
              subtitle: Text('替代方案: ${word['replacement']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    restrictions['sensitiveWords'].remove(word);
                  });
                },
              ),
            ),
          );
        }).toList(),
        ElevatedButton.icon(
          onPressed: () {
            _addSensitiveWord();
          },
          icon: const Icon(Icons.add),
          label: const Text('添加敏感词'),
        ),
      ],
    );
  }

  // Common UI components
  Widget _buildTextField(String label, String value, Function(String) onChanged, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '请输入$label',
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldList(String label, List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: list.map<Widget>((item) {
            return Chip(
              label: Text(item.toString()),
              onDeleted: () {
                setState(() {
                  list.remove(item);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '添加新项...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Add item logic
              },
            ),
          ),
          onSubmitted: (text) {
            if (text.isNotEmpty) {
              setState(() {
                list.add(text);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildKeyValueList(String label, Map<String, dynamic> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...map.entries.map<Widget>((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${entry.key}: ${entry.value}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    map.remove(entry.key);
                  });
                },
              ),
            ),
          );
        }).toList(),
        ElevatedButton.icon(
          onPressed: () {
            _addKeyValuePair(map);
          },
          icon: const Icon(Icons.add),
          label: Text('添加$label'),
        ),
      ],
    );
  }

  Widget _buildSaveButton(String text) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : () {
          _saveData();
        },
        icon: _isSaving 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? '保存中...' : text),
      ),
    );
  }

  // Dialog methods
  void _addKeyValuePair(Map<String, dynamic> map) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加键值对'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: '键'),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: '值'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                setState(() {
                  map[keyController.text] = valueController.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addFieldPreference() {
    final fieldController = TextEditingController();
    final preferencesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加领域偏好'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fieldController,
              decoration: const InputDecoration(labelText: '领域名称'),
            ),
            TextField(
              controller: preferencesController,
              decoration: const InputDecoration(labelText: '偏好项 (用逗号分隔)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (fieldController.text.isNotEmpty && preferencesController.text.isNotEmpty) {
                setState(() {
                  preferences['fieldPreferences'][fieldController.text] = 
                      preferencesController.text.split(',').map((s) => s.trim()).toList();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _editFieldPreference(String field, List<String> currentPreferences) {
    final controller = TextEditingController(text: currentPreferences.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑 $field 偏好'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '偏好项 (用逗号分隔)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                preferences['fieldPreferences'][field] = 
                    controller.text.split(',').map((s) => s.trim()).toList();
              });
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _addSensitiveWord() {
    final wordController = TextEditingController();
    final replacementController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加敏感词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wordController,
              decoration: const InputDecoration(labelText: '敏感词'),
            ),
            TextField(
              controller: replacementController,
              decoration: const InputDecoration(labelText: '替代方案'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (wordController.text.isNotEmpty && replacementController.text.isNotEmpty) {
                setState(() {
                  restrictions['sensitiveWords'].add({
                    'word': wordController.text,
                    'replacement': replacementController.text,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _saveData() {
    _saveUserProfile();
  }
}