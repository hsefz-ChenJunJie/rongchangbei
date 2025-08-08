import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';
import '../widgets/shared/base_line_input.dart';
import '../widgets/shared/base_elevated_button.dart';
import '../utils/theme_color_constants.dart';
import '../services/userdata_services.dart';
import '../services/theme_manager.dart';

class Settings extends BasePage {
  const Settings({Key? key})
      : super(
          key: key,
          title: '设置',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends BasePageState<Settings> {
  late Userdata _userData;
  bool _isLoading = true;
  bool _hasChanges = false;

  // 控制器
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _llmIntervalController = TextEditingController();
  final TextEditingController _sttIntervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _colorController.dispose();
    _llmIntervalController.dispose();
    _sttIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      _userData = Userdata();
      await _userData.loadUserData();
      
      // 设置控制器初始值
      _colorController.text = _userData.preferences['color'] ?? 'defaultColor';
      _llmIntervalController.text = _userData.preferences['llmCallingInterval'].toString();
      _sttIntervalController.text = _userData.preferences['sttSendingInterval'].toString();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加载用户数据失败: $e');
      // 使用默认数据
      _userData = Userdata();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleColorChanged(String value) async {
    setState(() {
      _userData.preferences['color'] = value;
      _hasChanges = true;
    });
    
    // 立即更新主题
    await ThemeManager().updateTheme(value);
  }

  void _handleLlmIntervalChanged(String value) {
    setState(() {
      _userData.preferences['llmCallingInterval'] = int.tryParse(value) ?? 10;
      _hasChanges = true;
    });
  }

  void _handleSttIntervalChanged(String value) {
    setState(() {
      _userData.preferences['sttSendingInterval'] = int.tryParse(value) ?? -1;
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    try {
      await _userData.saveUserData();
      setState(() {
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要重置所有设置为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _userData.resetToDefaults();
      
      // 重新加载控制器值
      _colorController.text = _userData.preferences['color'] ?? 'defaultColor';
      _llmIntervalController.text = _userData.preferences['llmCallingInterval'].toString();
      _sttIntervalController.text = _userData.preferences['sttSendingInterval'].toString();
      
      setState(() {
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置为默认设置'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (args != null && args['message'] != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '来源: ${args['message']}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          const Text(
            '外观设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          BaseLineInput(
            label: '主题颜色',
            controller: _colorController,
            placeholder: '例如: defaultColor, defaultRedColor, peachpuffColor',
            onChanged: _handleColorChanged,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ThemeColor.values.map((themeColor) {
              final isSelected = _colorController.text == themeColor.name;
              return GestureDetector(
                onTap: () => _handleColorChanged(themeColor.name),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: themeColor.baseColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      themeColor.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: themeColor.lightTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            '功能设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          BaseLineInput(
            label: 'LLM调用间隔 (秒)',
            controller: _llmIntervalController,
            placeholder: '请输入调用间隔，-1表示禁用',
            keyboardType: TextInputType.number,
            onChanged: _handleLlmIntervalChanged,
          ),
          
          const SizedBox(height: 16),
          
          BaseLineInput(
            label: 'STT发送间隔 (秒)',
            controller: _sttIntervalController,
            placeholder: '请输入发送间隔，-1表示禁用',
            keyboardType: TextInputType.number,
            onChanged: _handleSttIntervalChanged,
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            '高级功能',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: BaseElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/device-test');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.devices, size: 20),
                  label: '设备测试',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BaseElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings/advanced');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.settings, size: 20),
                  label: '高级设置',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: BaseElevatedButton(
                  onPressed: _hasChanges ? _saveSettings : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeManager().baseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '保存设置',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BaseElevatedButton(
                  onPressed: _resetToDefaults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeManager().baseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '重置为默认',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          BaseElevatedButton(
            onPressed: () {
              Navigator.pop(context, '设置已更新');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '返回',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}