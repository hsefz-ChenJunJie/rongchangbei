import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

class SaveDialoguePopup extends StatefulWidget {
  final Function(String) onSave;

  const SaveDialoguePopup({super.key, required this.onSave});

  @override
  SaveDialoguePopupState createState() => SaveDialoguePopupState();
}

class SaveDialoguePopupState extends State<SaveDialoguePopup> {
  final TextEditingController _nameController = TextEditingController(text: 'untitled');
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // 选择默认文本以便用户可以直接输入
    _nameController.selection = TextSelection(baseOffset: 0, extentOffset: _nameController.text.length);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 验证名称是否符合要求（只能包含字母、数字和下划线）
  bool _validateName(String name) {
    if (name.isEmpty) {
      return false;
    }
    // 正则表达式匹配：只能包含字母、数字和下划线
    final RegExp nameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');
    return nameRegExp.hasMatch(name);
  }

  void _handleSave() {
    final String name = _nameController.text.trim();
    
    if (!_validateName(name)) {
      setState(() {
        _errorMessage = '名称只能包含字母、数字和下划线';
      });
      return;
    }
    
    widget.onSave(name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 300,
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '保存对话包',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: themeManager.darkTextColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '对话包名称',
                hintText: '请输入名称（字母、数字、下划线）',
                errorText: _errorMessage.isEmpty ? null : _errorMessage,
                border: const OutlineInputBorder(),
              ),
              inputFormatters: [
                // 限制输入字符
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              ],
              onSubmitted: (_) => _handleSave(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSave,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


}