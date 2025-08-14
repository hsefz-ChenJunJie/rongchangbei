import 'package:flutter/material.dart';
import 'role_manager.dart';
import 'role_selector.dart';

/// 角色交互示例组件
/// 展示如何使用RoleManager与其他组件交互
class RoleInteractionExample extends StatelessWidget {
  const RoleInteractionExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('角色交互示例')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            // 显示当前角色
            RoleConsumer(
              builder: (context, currentRole, allRoles) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '当前角色',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(currentRole.icon, color: currentRole.color),
                            const SizedBox(width: 8),
                            Text(
                              currentRole.name,
                              style: TextStyle(
                                color: currentRole.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 角色选择器
            const RoleSelector(),

            // 快速角色切换按钮
            RoleConsumer(
              builder: (context, currentRole, allRoles) {
                return Wrap(
                  spacing: 8,
                  children: allRoles.map((role) {
                    return FilterChip(
                      label: Text(role.name),
                      selected: role == currentRole,
                      onSelected: (selected) {
                        if (selected) {
                          RoleManager.instance.setRole(role);
                        }
                      },
                      avatar: Icon(role.icon, size: 16),
                    );
                  }).toList(),
                );
              },
            ),

            // 显示所有角色数量
            RoleConsumer(
              builder: (context, currentRole, allRoles) {
                return Text('总共有 ${allRoles.length} 个角色');
              },
            ),

            // 添加新角色按钮
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加测试角色'),
              onPressed: () {
                final newRole = ChatRole(
                  id: 'test_${DateTime.now().millisecondsSinceEpoch}',
                  name: '测试角色',
                  color: Colors.purple,
                  icon: Icons.star,
                );
                RoleManager.instance.addRole(newRole);
              },
            ),

            // 使用静态方法访问
            ElevatedButton(
              onPressed: () {
                final currentRole = RoleManager.instance.currentRole;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('当前角色是: ${currentRole.name}'),
                  ),
                );
              },
              child: const Text('检查当前角色'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全局角色状态组件
/// 可以放在应用的根组件中，确保所有子组件都能访问
class GlobalRoleProvider extends StatelessWidget {
  final Widget child;

  const GlobalRoleProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RoleProvider(
      roleManager: RoleManager.instance,
      child: child,
    );
  }
}

/// 角色状态监听组件
/// 用于监听角色变化并执行特定操作
class RoleStateListener extends StatefulWidget {
  final Widget child;
  final Function(ChatRole newRole) onRoleChanged;

  const RoleStateListener({
    super.key,
    required this.child,
    required this.onRoleChanged,
  });

  @override
  State<RoleStateListener> createState() => _RoleStateListenerState();
}

class _RoleStateListenerState extends State<RoleStateListener> {
  late VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      widget.onRoleChanged(RoleManager.instance.currentRole);
    };
    RoleManager.instance.addListener(_listener);
  }

  @override
  void dispose() {
    RoleManager.instance.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}