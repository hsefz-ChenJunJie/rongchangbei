import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'base_line_input.dart';
import '../../services/theme_manager.dart';

class EditDialogueInfoPopup extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;
  final Function(String, String) onSave;

  const EditDialogueInfoPopup({
    super.key,
    required this.initialTitle,
    required this.initialDescription,
    required this.onSave,
  });

  @override
  EditDialogueInfoPopupState createState() => EditDialogueInfoPopupState();
}

class EditDialogueInfoPopupState extends State<EditDialogueInfoPopup> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对话标题不能为空')),
      );
      return;
    }
    
    widget.onSave(title, description);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '编辑对话信息',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: themeManager.darkTextColor,
              ),
            ),
            const SizedBox(height: 24),
            BaseLineInput(
              label: '对话标题',
              controller: _titleController,
              placeholder: '请输入对话标题',
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            BaseLineInput(
              label: '对话描述',
              controller: _descriptionController,
              placeholder: '请输入对话描述（可选）',
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
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