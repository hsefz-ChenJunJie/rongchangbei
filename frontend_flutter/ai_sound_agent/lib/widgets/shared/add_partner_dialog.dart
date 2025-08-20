import 'package:flutter/material.dart';
import 'base_line_input.dart';

class AddPartnerDialog extends StatefulWidget {
  final Function(String, String) onAddPartner; // 修改为接受两个参数：name和description
  final String? initialName;

  const AddPartnerDialog({
    Key? key,
    required this.onAddPartner,
    this.initialName,
  }) : super(key: key);

  @override
  State<AddPartnerDialog> createState() => _AddPartnerDialogState();
}

class _AddPartnerDialogState extends State<AddPartnerDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isNotEmpty) {
      widget.onAddPartner(name, description);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加对话人',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            BaseLineInput(
              label: '姓名',
              controller: _nameController,
              placeholder: '请输入对话人姓名',
              onSubmitted: (value) => _handleAdd(),
            ),
            const SizedBox(height: 16),
            BaseLineInput(
              label: '备注',
              controller: _descriptionController,
              placeholder: '请输入备注信息（可选）',
              maxLines: 3,
              onSubmitted: (value) => _handleAdd(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _handleAdd,
                  child: const Text('确认添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}