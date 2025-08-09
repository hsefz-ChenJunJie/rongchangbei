import 'package:flutter/material.dart';
import 'dart:async';
import '../services/userdata_services.dart';
import '../widgets/shared/base_elevated_button.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Userdata _userdata;
  
  // 表单控制器
  final Map<String, TextEditingController> _controllers = {};
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _userdata = Userdata();
    _loadUserData();
    _startAutoSave();
  }

  Future<void> _loadUserData() async {
    await _userdata.loadUserData();
    setState(() {
      _initControllers();
    });
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_hasUnsavedChanges) {
        _saveSettingsSilently();
      }
    });
  }

  void _markAsChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveSettingsSilently() async {
    try {
      // 保存STT设置
      await _userdata.updateNestedPreference('stt', 'url', _controllers['stt_url']!.text);
      await _userdata.updateNestedPreference('stt', 'ip', _controllers['stt_ip']!.text);
      await _userdata.updateNestedPreference('stt', 'port', int.tryParse(_controllers['stt_port']!.text) ?? 8000);
      await _userdata.updateNestedPreference('stt', 'route', _controllers['stt_route']!.text);
      await _userdata.updateNestedPreference('stt', 'api_key', _controllers['stt_api_key']!.text);

      // 保存TTS设置
      await _userdata.updateNestedPreference('tts', 'ip', _controllers['tts_ip']!.text);
      await _userdata.updateNestedPreference('tts', 'port', int.tryParse(_controllers['tts_port']!.text) ?? 8000);
      await _userdata.updateNestedPreference('tts', 'url', _controllers['tts_url']!.text);
      await _userdata.updateNestedPreference('tts', 'route', _controllers['tts_route']!.text);
      await _userdata.updateNestedPreference('tts', 'api_key', _controllers['tts_api_key']!.text);

      // 保存LLM设置
      await _userdata.updateNestedPreference('llm', 'ip', _controllers['llm_ip']!.text);
      await _userdata.updateNestedPreference('llm', 'port', int.tryParse(_controllers['llm_port']!.text) ?? 8000);
      await _userdata.updateNestedPreference('llm', 'url', _controllers['llm_url']!.text);
      await _userdata.updateNestedPreference('llm', 'route', _controllers['llm_route']!.text);
      await _userdata.updateNestedPreference('llm', 'api_key', _controllers['llm_api_key']!.text);

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      debugPrint('自动保存失败: $e');
    }
  }

  void _initControllers() {
    // STT 控制器
    _controllers['stt_url'] = TextEditingController(
        text: _userdata.preferences['stt']['url'] ?? 'http://localhost:8000');
    _controllers['stt_ip'] = TextEditingController(
        text: _userdata.preferences['stt']['ip'] ?? '127.0.0.1');
    _controllers['stt_port'] = TextEditingController(
        text: _userdata.preferences['stt']['port']?.toString() ?? '8000');
    _controllers['stt_route'] = TextEditingController(
        text: _userdata.preferences['stt']['route'] ?? '/stt');
    _controllers['stt_api_key'] = TextEditingController(
        text: _userdata.preferences['stt']['api_key'] ?? '');

    // TTS 控制器
    _controllers['tts_ip'] = TextEditingController(
        text: _userdata.preferences['tts']['ip'] ?? '127.0.0.1');
    _controllers['tts_port'] = TextEditingController(
        text: _userdata.preferences['tts']['port']?.toString() ?? '8000');
    _controllers['tts_url'] = TextEditingController(
        text: _userdata.preferences['tts']['url'] ?? 'http://localhost:8000');
    _controllers['tts_route'] = TextEditingController(
        text: _userdata.preferences['tts']['route'] ?? '/tts');
    _controllers['tts_api_key'] = TextEditingController(
        text: _userdata.preferences['tts']['api_key'] ?? '');

    // LLM 控制器
    _controllers['llm_ip'] = TextEditingController(
        text: _userdata.preferences['llm']['ip'] ?? '127.0.0.1');
    _controllers['llm_port'] = TextEditingController(
        text: _userdata.preferences['llm']['port']?.toString() ?? '8000');
    _controllers['llm_url'] = TextEditingController(
        text: _userdata.preferences['llm']['url'] ?? 'http://localhost:8000');
    _controllers['llm_route'] = TextEditingController(
        text: _userdata.preferences['llm']['route'] ?? '/llm');
    _controllers['llm_api_key'] = TextEditingController(
        text: _userdata.preferences['llm']['api_key'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autoSaveTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await _saveSettingsSilently();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  Widget _buildTextField(String label, String key, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: obscureText,
        onChanged: (_) => _markAsChanged(),
      ),
    );
  }

  Widget _buildSTTTab() {
    bool isUrlMode = (_userdata.preferences['stt']['mode'] ?? 'url') == 'url';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '语音识别 (STT) 设置',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // 根据模式显示不同的输入框
          if (isUrlMode) ...[
            _buildTextField('URL', 'stt_url'),
          ] else ...[
            _buildTextField('IP地址', 'stt_ip'),
            _buildTextField('端口', 'stt_port'),
          ],
          
          _buildTextField('路由', 'stt_route'),
          _buildTextField('API密钥', 'stt_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['stt']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('stt', 'use_api_key', value);
              _markAsChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text(isUrlMode ? 'URL模式' : 'IP端口模式'),
            value: isUrlMode,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('stt', 'mode', value ? 'url' : 'ip-port');
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTTSTab() {
    bool isIpPortMode = (_userdata.preferences['tts']['mode'] ?? 'ip-port') == 'ip-port';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '语音合成 (TTS) 设置',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // 根据模式显示不同的输入框
          if (isIpPortMode) ...[
            _buildTextField('IP地址', 'tts_ip'),
            _buildTextField('端口', 'tts_port'),
          ] else ...[
            _buildTextField('URL', 'tts_url'),
          ],
          
          _buildTextField('路由', 'tts_route'),
          _buildTextField('API密钥', 'tts_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['tts']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('tts', 'use_api_key', value);
              _markAsChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text(isIpPortMode ? 'IP端口模式' : 'URL模式'),
            value: isIpPortMode,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('tts', 'mode', value ? 'ip-port' : 'url');
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLLMTab() {
    bool isIpPortMode = (_userdata.preferences['llm']['mode'] ?? 'ip-port') == 'ip-port';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '大语言模型 (LLM) 设置',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // 根据模式显示不同的输入框
          if (isIpPortMode) ...[
            _buildTextField('IP地址', 'llm_ip'),
            _buildTextField('端口', 'llm_port'),
          ] else ...[
            _buildTextField('URL', 'llm_url'),
          ],
          
          _buildTextField('路由', 'llm_route'),
          _buildTextField('API密钥', 'llm_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['llm']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('llm', 'use_api_key', value);
              _markAsChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text(isIpPortMode ? 'IP端口模式' : 'URL模式'),
            value: isIpPortMode,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('llm', 'mode', value ? 'ip-port' : 'url');
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedFillTab() {
    final TextEditingController unifiedUrlController = TextEditingController();
    final TextEditingController unifiedIpController = TextEditingController();
    final TextEditingController unifiedPortController = TextEditingController();
    final TextEditingController unifiedApiKeyController = TextEditingController();
    final TextEditingController unifiedRouteController = TextEditingController();
    
    bool fillUrl = false;
    bool fillIpPort = false;
    bool fillApiKey = false;
    bool fillRoute = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '统一填充设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // 填充选项
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('选择要填充的内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        title: const Text('填充URL地址'),
                        value: fillUrl,
                        onChanged: (value) => setState(() => fillUrl = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('填充IP和端口'),
                        value: fillIpPort,
                        onChanged: (value) => setState(() => fillIpPort = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('填充API密钥'),
                        value: fillApiKey,
                        onChanged: (value) => setState(() => fillApiKey = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('填充路由'),
                        value: fillRoute,
                        onChanged: (value) => setState(() => fillRoute = value ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 统一值输入
              if (fillUrl)
                _buildUnifiedTextField('统一URL地址', unifiedUrlController),
              if (fillIpPort) ...[
                _buildUnifiedTextField('统一IP地址', unifiedIpController),
                _buildUnifiedTextField('统一端口', unifiedPortController),
              ],
              if (fillApiKey)
                _buildUnifiedTextField('统一API密钥', unifiedApiKeyController, obscureText: true),
              if (fillRoute)
                _buildUnifiedTextField('统一路由', unifiedRouteController),
              
              const SizedBox(height: 30),
              
              // 填充按钮
              BaseElevatedButton.icon(
                onPressed: (fillUrl || fillIpPort || fillApiKey || fillRoute) 
                    ? () => _applyUnifiedSettings(
                        url: fillUrl ? unifiedUrlController.text : null,
                        ip: fillIpPort ? unifiedIpController.text : null,
                        port: fillIpPort ? unifiedPortController.text : null,
                        apiKey: fillApiKey ? unifiedApiKeyController.text : null,
                        route: fillRoute ? unifiedRouteController.text : null,
                      )
                    : null,
                icon: const Icon(Icons.sync),
                label: '统一填充到所有服务',
                expanded: true,
              ),
              
              const SizedBox(height: 20),
              
              // 使用说明
              Card(
                color: Colors.blue.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '使用说明：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• 选择要填充的内容类型'),
                      Text('• 输入统一的值'),
                      Text('• 点击"统一填充到所有服务"按钮'),
                      Text('• 只会填充已选中的内容'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedTextField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: obscureText,
      ),
    );
  }

  Future<void> _applyUnifiedSettings({
    String? url,
    String? ip,
    String? port,
    String? apiKey,
    String? route,
  }) async {
    try {
      final services = ['stt', 'tts', 'llm'];
      for (final service in services) {
        if (url != null) {
          await _userdata.updateNestedPreference(service, 'url', url);
          _controllers['${service}_url']?.text = url;
        }
        if (ip != null) {
          await _userdata.updateNestedPreference(service, 'ip', ip);
          _controllers['${service}_ip']?.text = ip;
        }
        if (port != null) {
          final portInt = int.tryParse(port) ?? 8000;
          await _userdata.updateNestedPreference(service, 'port', portInt);
          _controllers['${service}_port']?.text = port;
        }
        if (apiKey != null) {
          await _userdata.updateNestedPreference(service, 'api_key', apiKey);
          _controllers['${service}_api_key']?.text = apiKey;
        }
        if (route != null) {
          await _userdata.updateNestedPreference(service, 'route', route);
          _controllers['${service}_route']?.text = route;
        }
      }
      _markAsChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('统一填充完成')),
        );
      }
    } catch (e) {
      debugPrint('统一填充失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级设置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'STT', icon: Icon(Icons.mic)),
            Tab(text: 'TTS', icon: Icon(Icons.volume_up)),
            Tab(text: 'LLM', icon: Icon(Icons.smart_toy)),
            Tab(text: '统一填充', icon: Icon(Icons.settings_input_component)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存设置',
          ),
        ],
      ),
      body: _controllers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_hasUnsavedChanges)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          '有未保存的更改',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.green.withValues(alpha: 0.1),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          '所有更改已自动保存',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSTTTab(),
                      _buildTTSTab(),
                      _buildLLMTab(),
                      _buildUnifiedFillTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}