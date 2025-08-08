import 'package:flutter/material.dart';
import '../services/userdata_services.dart';

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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userdata = Userdata();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await _userdata.loadUserData();
    setState(() {
      _initControllers();
    });
  }

  void _initControllers() {
    // STT 控制器
    _controllers['stt_url'] = TextEditingController(
        text: _userdata.preferences['stt']['url'] ?? 'http://localhost:8000');
    _controllers['stt_route'] = TextEditingController(
        text: _userdata.preferences['stt']['route'] ?? '/stt');
    _controllers['stt_api_key'] = TextEditingController(
        text: _userdata.preferences['stt']['api_key'] ?? '');

    // TTS 控制器
    _controllers['tts_ip'] = TextEditingController(
        text: _userdata.preferences['tts']['ip'] ?? '127.0.0.1');
    _controllers['tts_port'] = TextEditingController(
        text: _userdata.preferences['tts']['port']?.toString() ?? '8000');
    _controllers['tts_route'] = TextEditingController(
        text: _userdata.preferences['tts']['route'] ?? '/tts');
    _controllers['tts_api_key'] = TextEditingController(
        text: _userdata.preferences['tts']['api_key'] ?? '');

    // LLM 控制器
    _controllers['llm_ip'] = TextEditingController(
        text: _userdata.preferences['llm']['ip'] ?? '127.0.0.1');
    _controllers['llm_port'] = TextEditingController(
        text: _userdata.preferences['llm']['port']?.toString() ?? '8000');
    _controllers['llm_route'] = TextEditingController(
        text: _userdata.preferences['llm']['route'] ?? '/llm');
    _controllers['llm_api_key'] = TextEditingController(
        text: _userdata.preferences['llm']['api_key'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    // 保存STT设置
    await _userdata.updateNestedPreference('stt', 'url', _controllers['stt_url']!.text);
    await _userdata.updateNestedPreference('stt', 'route', _controllers['stt_route']!.text);
    await _userdata.updateNestedPreference('stt', 'api_key', _controllers['stt_api_key']!.text);

    // 保存TTS设置
    await _userdata.updateNestedPreference('tts', 'ip', _controllers['tts_ip']!.text);
    await _userdata.updateNestedPreference('tts', 'port', int.tryParse(_controllers['tts_port']!.text) ?? 8000);
    await _userdata.updateNestedPreference('tts', 'route', _controllers['tts_route']!.text);
    await _userdata.updateNestedPreference('tts', 'api_key', _controllers['tts_api_key']!.text);

    // 保存LLM设置
    await _userdata.updateNestedPreference('llm', 'ip', _controllers['llm_ip']!.text);
    await _userdata.updateNestedPreference('llm', 'port', int.tryParse(_controllers['llm_port']!.text) ?? 8000);
    await _userdata.updateNestedPreference('llm', 'route', _controllers['llm_route']!.text);
    await _userdata.updateNestedPreference('llm', 'api_key', _controllers['llm_api_key']!.text);

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
      ),
    );
  }

  Widget _buildSTTTab() {
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
          _buildTextField('URL', 'stt_url'),
          _buildTextField('路由', 'stt_route'),
          _buildTextField('API密钥', 'stt_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['stt']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('stt', 'use_api_key', value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text((_userdata.preferences['stt']['mode'] ?? 'url') == 'url' ? 'URL模式' : 'IP端口模式'),
            value: (_userdata.preferences['stt']['mode'] ?? 'url') == 'url',
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
          _buildTextField('IP地址', 'tts_ip'),
          _buildTextField('端口', 'tts_port'),
          _buildTextField('路由', 'tts_route'),
          _buildTextField('API密钥', 'tts_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['tts']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('tts', 'use_api_key', value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text((_userdata.preferences['tts']['mode'] ?? 'ip-port') == 'ip-port' ? 'IP端口模式' : 'URL模式'),
            value: (_userdata.preferences['tts']['mode'] ?? 'ip-port') == 'ip-port',
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
          _buildTextField('IP地址', 'llm_ip'),
          _buildTextField('端口', 'llm_port'),
          _buildTextField('路由', 'llm_route'),
          _buildTextField('API密钥', 'llm_api_key', obscureText: true),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('使用API密钥'),
            value: _userdata.preferences['llm']['use_api_key'] ?? false,
            onChanged: (value) async {
              await _userdata.updateNestedPreference('llm', 'use_api_key', value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('模式'),
            subtitle: Text((_userdata.preferences['llm']['mode'] ?? 'ip-port') == 'ip-port' ? 'IP端口模式' : 'URL模式'),
            value: (_userdata.preferences['llm']['mode'] ?? 'ip-port') == 'ip-port',
            onChanged: (value) async {
              await _userdata.updateNestedPreference('llm', 'mode', value ? 'ip-port' : 'url');
              setState(() {});
            },
          ),
        ],
      ),
    );
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSTTTab(),
                _buildTTSTab(),
                _buildLLMTab(),
              ],
            ),
    );
  }
}