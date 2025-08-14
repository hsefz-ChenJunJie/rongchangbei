import 'package:flutter/material.dart';
import '../shared/popup.dart';
import 'role_manager.dart';

class ChatRole {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const ChatRole({
    required this.id,
    required this.name,
    this.color = Colors.blue,
    this.icon = Icons.person,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRole &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  ChatRole copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
  }) {
    return ChatRole(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}

/// 角色选择器组件
/// 使用全局RoleManager管理角色状态
class RoleSelector extends StatefulWidget {
  /// 是否使用全局角色管理器
  final bool useGlobalManager;

  /// 角色选择回调
  final Function(ChatRole)? onRoleChanged;

  const RoleSelector({
    super.key,
    this.useGlobalManager = true,
    this.onRoleChanged,
  });

  @override
  State<RoleSelector> createState() => RoleSelectorState();
}

class RoleSelectorState extends State<RoleSelector> {
  final GlobalKey<PopupState> _popupKey = GlobalKey<PopupState>();
  late final RoleManager _roleManager;

  @override
  void initState() {
    super.initState();
    _roleManager = RoleManager.instance;
    
    // 添加状态监听器
    _roleManager.addListener(_onRoleManagerChanged);
  }

  @override
  void dispose() {
    _roleManager.removeListener(_onRoleManagerChanged);
    super.dispose();
  }

  void _onRoleManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 获取当前角色
  ChatRole getCurrentRole() {
    return _roleManager.currentRole;
  }

  /// 切换角色
  void changeRole(ChatRole newRole) {
    _roleManager.setRole(newRole);
    widget.onRoleChanged?.call(newRole);
  }

  /// 添加新角色
  void addRole(ChatRole newRole) {
    _roleManager.addRole(newRole);
    widget.onRoleChanged?.call(newRole);
  }

  /// 获取所有角色
  List<ChatRole> getAllRoles() {
    return _roleManager.allRoles;
  }

  void _showRoleSelector() {
    _popupKey.currentState?.show();
  }

  void _closeRoleSelector() {
    _popupKey.currentState?.close();
  }

  Future<void> _addRoleDialog() async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    IconData selectedIcon = Icons.person;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加新角色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '角色名称',
                    hintText: '请输入角色名称',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('选择颜色:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.red, Colors.blue, Colors.green, Colors.orange,
                    Colors.purple, Colors.pink, Colors.teal, Colors.indigo,
                    Colors.brown, Colors.grey
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color 
                            ? Colors.black 
                            : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('选择图标:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    children: [
                      Icons.person, Icons.work, Icons.school, Icons.home,
                      Icons.directions_car, Icons.phone, Icons.email, Icons.favorite,
                      Icons.star, Icons.thumb_up, Icons.check, Icons.close,
                      Icons.settings, Icons.search, Icons.delete, Icons.edit,
                    ].map((icon) => GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedIcon == icon 
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                            : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: selectedColor),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final newRole = ChatRole(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    color: selectedColor,
                    icon: selectedIcon,
                  );
                  addRole(newRole);
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    
    _closeRoleSelector();
  }

  Widget _buildRoleSelectorContent() {
    final roles = getAllRoles();
    
    return Material(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '选择角色',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closeRoleSelector,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: roles.length + 1,
                itemBuilder: (context, index) {
                  if (index == roles.length) {
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('添加新角色'),
                      onTap: _addRoleDialog,
                    );
                  }
                  
                  final role = roles[index];
                  final isSelected = role == getCurrentRole();
                  
                  return ListTile(
                    leading: Icon(role.icon, color: role.color),
                    title: Text(role.name),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    selected: isSelected,
                    onTap: () {
                      changeRole(role);
                      _closeRoleSelector();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = getCurrentRole();
    
    return Stack(
      children: [
        // 角色显示组件
        GestureDetector(
          onTap: _showRoleSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(currentRole.icon, color: currentRole.color, size: 18),
                const SizedBox(width: 6),
                Text(
                  currentRole.name,
                  style: TextStyle(
                    color: currentRole.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        
        // Popup组件
        Popup(
          key: _popupKey,
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          backgroundColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          child: _buildRoleSelectorContent(),
        ),
      ],
    );
  }
}