import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

class SaveDialoguePopup extends StatefulWidget {
  final Function(String) onSave;

  const SaveDialoguePopup({
    super.key, 
    required this.onSave,
  });

  @override
  SaveDialoguePopupState createState() => SaveDialoguePopupState();
}

class SaveDialoguePopupState extends State<SaveDialoguePopup> {
  final TextEditingController _fileNameController = TextEditingController(text: 'untitled');
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // 选择默认文本以便用户可以直接输入
    _fileNameController.selection = TextSelection(
      baseOffset: 0, 
      extentOffset: _fileNameController.text.length
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  // 验证文件名是否符合要求（字母、数字、下划线、连字符）
  void _validateFileName(String value) {
    final RegExp validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (value.isEmpty) {
      setState(() {
        _errorMessage = '文件名不能为空';
      });
    } else if (!validPattern.hasMatch(value)) {
      setState(() {
        _errorMessage = '文件名只能包含字母、数字、下划线和连字符';
      });
    } else {
      setState(() {
        _errorMessage = '';
      });
    }
  }

  void _handleSave() {
    final String name = _fileNameController.text.trim();
    _validateFileName(name);
    if (_errorMessage.isNotEmpty) return;

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
              controller: _fileNameController,
              decoration: InputDecoration(
                labelText: '文件名',
                hintText: '请输入文件名',
                border: const OutlineInputBorder(),
                errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
              ),
              onChanged: _validateFileName,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
              ],
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