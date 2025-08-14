import 'package:flutter/material.dart';
import 'role_manager.dart';
import 'role_selector.dart';

/// 角色自定义初始化示例
class RoleCustomizationExample extends StatelessWidget {
  const RoleCustomizationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('角色自定义示例')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text('请在应用启动时初始化角色'),
              Text('示例代码在 main() 函数中'),
              RoleSelector(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 应用启动时的角色初始化工具类
class RoleInitializer {
  /// 方法1: 使用自定义角色列表和默认角色
  static void initializeWithCustomRoles() {
    RoleManager.instance.initialize(
      initialRoles: [
        const ChatRole(
          id: 'developer',
          name: '开发者',
          color: Colors.blue,
          icon: Icons.code,
        ),
        const ChatRole(
          id: 'designer',
          name: '设计师',
          color: Colors.purple,
          icon: Icons.design_services,
        ),
        const ChatRole(
          id: 'tester',
          name: '测试员',
          color: Colors.orange,
          icon: Icons.bug_report,
        ),
      ],
      defaultRole: const ChatRole(
        id: 'developer',
        name: '开发者',
        color: Colors.blue,
        icon: Icons.code,
      ),
    );
  }

  /// 方法2: 仅设置默认角色，使用内置角色列表
  static void initializeWithDefaultRoleOnly() {
    RoleManager.instance.initialize(
      defaultRole: const ChatRole(
        id: 'custom_user',
        name: '自定义用户',
        color: Colors.teal,
        icon: Icons.person_outline,
      ),
    );
  }

  /// 方法3: 完全自定义角色系统
  static void initializeFullyCustom() {
    RoleManager.instance.initialize(
      initialRoles: [
        const ChatRole(
          id: 'admin',
          name: '管理员',
          color: Colors.red,
          icon: Icons.admin_panel_settings,
        ),
        const ChatRole(
          id: 'moderator',
          name: '版主',
          color: Colors.green,
          icon: Icons.shield,
        ),
        const ChatRole(
          id: 'user',
          name: '普通用户',
          color: Colors.grey,
          icon: Icons.person,
        ),
        const ChatRole(
          id: 'guest',
          name: '访客',
          color: Colors.blueGrey,
          icon: Icons.account_circle,
        ),
      ],
      defaultRole: const ChatRole(
        id: 'user',
        name: '普通用户',
        color: Colors.grey,
        icon: Icons.person,
      ),
    );
  }

  /// 方法4: 从配置加载角色（示例）
  static void initializeFromConfig(Map<String, dynamic> config) {
    final roles = <ChatRole>[];
    
    if (config['roles'] != null) {
      for (final roleData in config['roles']) {
        roles.add(ChatRole(
          id: roleData['id'],
          name: roleData['name'],
          color: Color(roleData['color']),
          icon: IconData(roleData['icon'], fontFamily: 'MaterialIcons'),
        ));
      }
    }

    final defaultRoleId = config['defaultRoleId'] ?? 'user';
    final defaultRole = roles.firstWhere(
      (role) => role.id == defaultRoleId,
      orElse: () => roles.isNotEmpty ? roles.first : const ChatRole(
        id: 'user',
        name: '用户',
        color: Colors.blue,
        icon: Icons.person,
      ),
    );

    RoleManager.instance.initialize(
      initialRoles: roles.isNotEmpty ? roles : null,
      defaultRole: defaultRole,
    );
  }

  /// 方法5: 动态角色配置（支持运行时修改）
  static Future<void> initializeDynamic() async {
    // 模拟从API或本地存储加载配置
    await Future.delayed(const Duration(milliseconds: 100));
    
    final dynamicRoles = [
      const ChatRole(
        id: 'ai_assistant',
        name: 'AI助手',
        color: Colors.indigo,
        icon: Icons.smart_toy,
      ),
      const ChatRole(
        id: 'human_user',
        name: '人类用户',
        color: Colors.green,
        icon: Icons.face,
      ),
      const ChatRole(
        id: 'system',
        name: '系统',
        color: Colors.deepPurple,
        icon: Icons.computer,
      ),
    ];

    RoleManager.instance.initialize(
      initialRoles: dynamicRoles,
      defaultRole: dynamicRoles.first,
    );
  }
}

/// 角色配置可视化组件
class RoleConfigViewer extends StatelessWidget {
  const RoleConfigViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleConsumer(
      builder: (context, currentRole, allRoles) {
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前角色配置',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('当前角色: ${currentRole.name}'),
                    Text('角色数量: ${allRoles.length}'),
                    const SizedBox(height: 8),
                    Text(
                      '所有角色:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...allRoles.map((role) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(role.icon, color: role.color, size: 16),
                          const SizedBox(width: 4),
                          Text(role.name),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const RoleSelector(),
          ],
        );
      },
    );
  }
}

/// 使用示例：如何在 main() 中初始化
/*
void main() {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 方法1: 使用自定义角色
  RoleInitializer.initializeWithCustomRoles();
  
  // 方法2: 仅设置默认角色
  // RoleInitializer.initializeWithDefaultRoleOnly();
  
  // 方法3: 完全自定义
  // RoleInitializer.initializeFullyCustom();
  
  // 方法4: 从配置加载
  // final config = {
  //   'roles': [
  //     {'id': 'admin', 'name': '管理员', 'color': 0xFFFF0000, 'icon': 0xe7ef},
  //     {'id': 'user', 'name': '用户', 'color': 0xFF0000FF, 'icon': 0xe7fd},
  //   ],
  //   'defaultRoleId': 'admin',
  // };
  // RoleInitializer.initializeFromConfig(config);
  
  // 方法5: 动态配置
  // await RoleInitializer.initializeDynamic();
  
  runApp(const MyApp());
}
*/