import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';
import '../services/suggestion_settings_service.dart';

class DefaultSuggestionAndOpinion extends BasePage {
  const DefaultSuggestionAndOpinion({super.key})
      : super(
          title: '默认建议意见',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  State<DefaultSuggestionAndOpinion> createState() => _DefaultSuggestionAndOpinionState();
}

class _DefaultSuggestionAndOpinionState extends BasePageState<DefaultSuggestionAndOpinion> {
  List<String> _defaultSuggestions = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultSuggestions();
  }

  @override
  void dispose() {
    // 页面销毁时自动保存所有未保存的修改
    _autoSaveAllChanges();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDefaultSuggestions() async {
    final suggestions = await SuggestionSettingsService.getDefaultSuggestions();
    setState(() {
      _defaultSuggestions = suggestions;
      _isLoading = false;
    });
  }

  void _addNewSuggestion() {
    print('添加新建议前的数量: ${_defaultSuggestions.length}');
    
    setState(() {
      _defaultSuggestions.add('新建议');
      // 为新添加的建议创建控制器
      final newIndex = _defaultSuggestions.length - 1;
      _controllers[newIndex] = TextEditingController(text: '新建议');
    });
    
    print('添加新建议后的数量: ${_defaultSuggestions.length}');
    print('新建议列表: $_defaultSuggestions');
    
    // 立即保存到持久化存储
    SuggestionSettingsService.saveDefaultSuggestions(_defaultSuggestions).then((success) {
      print('添加新建议保存结果: $success');
    });
  }

  void _updateSuggestion(int index, String newText) async {
    if (newText.isEmpty) {
      // 如果修改为空，则删除该建议
      await _deleteSuggestion(index);
    } else {
      final oldText = _defaultSuggestions[index];
      if (oldText != newText) {
        await SuggestionSettingsService.updateDefaultSuggestion(oldText, newText);
        setState(() {
          _defaultSuggestions[index] = newText;
        });
        
        // 立即保存整个列表以确保数据同步
        await SuggestionSettingsService.saveDefaultSuggestions(_defaultSuggestions);
      }
    }
  }

  Future<void> _deleteSuggestion(int index) async {
    final suggestion = _defaultSuggestions[index];
    await SuggestionSettingsService.removeDefaultSuggestion(suggestion);
    setState(() {
      _defaultSuggestions.removeAt(index);
      // 清理控制器
      _controllers.remove(index);
      // 重新创建所有控制器以确保索引正确
      _controllers.clear();
      for (int i = 0; i < _defaultSuggestions.length; i++) {
        _controllers[i] = TextEditingController(text: _defaultSuggestions[i]);
      }
    });
  }

  Future<void> _resetToDefaults() async {
    await SuggestionSettingsService.resetToBuiltInDefaults();
    await _loadDefaultSuggestions();
    
    // 显示重置成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置为默认建议'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 自动保存所有修改
  Future<void> _autoSaveAllChanges() async {
    bool hasChanges = false;
    List<String> updatedSuggestions = [];
    
    print('开始自动保存，当前建议数量: ${_defaultSuggestions.length}');
    
    for (int i = 0; i < _defaultSuggestions.length; i++) {
      if (_controllers.containsKey(i)) {
        final controllerText = _controllers[i]!.text.trim();
        final currentText = _defaultSuggestions[i];
        
        print('检查建议 $i: 控制器文本="$controllerText", 当前文本="$currentText"');
        
        // 如果有修改，则保存
        if (controllerText != currentText) {
          hasChanges = true;
          print('检测到修改在索引 $i');
          if (controllerText.isEmpty) {
            // 如果为空，跳过这个建议（相当于删除）
            print('建议 $i 为空，将删除');
            continue;
          } else {
            // 否则添加到更新列表
            updatedSuggestions.add(controllerText);
            print('更新建议 $i: $controllerText');
          }
        } else {
          // 没有修改的建议直接添加到列表
          updatedSuggestions.add(currentText);
        }
      } else {
        // 没有控制器的建议直接添加到列表
        updatedSuggestions.add(_defaultSuggestions[i]);
      }
    }
    
    // 如果有修改，保存整个列表
    if (hasChanges) {
      print('检测到修改，保存更新后的建议列表: $updatedSuggestions');
      final success = await SuggestionSettingsService.saveDefaultSuggestions(updatedSuggestions);
      print('保存结果: $success');
      
      setState(() {
        _defaultSuggestions = updatedSuggestions;
      });
      
      // 重新创建控制器
      _controllers.clear();
      for (int i = 0; i < _defaultSuggestions.length; i++) {
        _controllers[i] = TextEditingController(text: _defaultSuggestions[i]);
      }
    } else {
      print('未检测到修改');
    }
    
    // 如果有修改且页面还在显示，给出提示
    if (hasChanges && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('修改已自动保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // 标题和操作按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '默认建议意见',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 保存按钮
              TextButton.icon(
                onPressed: () async {
                  await _autoSaveAllChanges();
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存'),
              ),
              const SizedBox(width: 8),
              // 重置按钮
              TextButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重置'),
              ),
              const SizedBox(width: 8),
              // 添加按钮
              ElevatedButton.icon(
                onPressed: _addNewSuggestion,
                icon: const Icon(Icons.add),
                label: const Text('添加建议'),
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // 建议列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _defaultSuggestions.length,
            itemBuilder: (context, index) {
              if (!_controllers.containsKey(index)) {
                _controllers[index] = TextEditingController(
                  text: _defaultSuggestions[index],
                );
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: TextField(
                    controller: _controllers[index],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '输入建议内容',
                    ),
                    onSubmitted: (value) => _updateSuggestion(index, value),
                    onTapOutside: (_) {
                      // 当点击外部时保存修改
                      _updateSuggestion(index, _controllers[index]!.text);
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteSuggestion(index),
                  ),
                ),
              );
            },
          ),
        ),
        
        // 底部说明
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: const Text(
            '提示：点击建议内容可编辑，清空内容后按回车可删除建议。离开页面时修改会自动保存。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}