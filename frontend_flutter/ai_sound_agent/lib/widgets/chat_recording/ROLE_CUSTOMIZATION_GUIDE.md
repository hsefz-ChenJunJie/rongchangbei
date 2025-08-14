# 角色自定义初始化指南

## 概述
现在支持完全自定义角色系统的初始化，包括自定义角色列表、默认角色、运行时动态配置等。

## 快速开始

### 1. 基础初始化

在应用启动时（通常在 `main()` 函数中）初始化角色系统：

```dart
import 'package:flutter/material.dart';
import 'widgets/chat_recording/role_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化角色系统
  RoleManager.instance.initialize(
    initialRoles: [
      const ChatRole(id: 'me', name: '我自己', color: Colors.green, icon: Icons.person),
      const ChatRole(id: 'assistant', name: 'AI助手', color: Colors.blue, icon: Icons.smart_toy),
    ],
    defaultRole: const ChatRole(id: 'me', name: '我自己', color: Colors.green, icon: Icons.person),
  );
  
  runApp(const MyApp());
}
```

### 2. 使用内置工具类初始化

我们提供了 `RoleInitializer` 工具类，包含多种预设的初始化方式：

```dart
// 方法1: 开发者角色配置
RoleInitializer.initializeWithCustomRoles();

// 方法2: 仅设置默认角色
RoleInitializer.initializeWithDefaultRoleOnly();

// 方法3: 完全自定义角色系统
RoleInitializer.initializeFullyCustom();

// 方法4: 从配置加载
final config = {
  'roles': [
    {'id': 'admin', 'name': '管理员', 'color': 0xFFFF0000, 'icon': 0xe7ef},
    {'id': 'user', 'name': '用户', 'color': 0xFF0000FF, 'icon': 0xe7fd},
  ],
  'defaultRoleId': 'admin',
};
RoleInitializer.initializeFromConfig(config);

// 方法5: 动态配置（支持异步加载）
await RoleInitializer.initializeDynamic();
```

## 高级用法

### 1. 运行时动态修改

```dart
// 添加新角色
RoleManager.instance.addRole(
  const ChatRole(
    id: 'new_role',
    name: '新角色',
    color: Colors.purple,
    icon: Icons.star,
  ),
);

// 切换角色
RoleManager.instance.setRole(newRole);

// 获取当前角色
final currentRole = RoleManager.instance.currentRole;

// 获取所有角色
final allRoles = RoleManager.instance.allRoles;
```

### 2. 在组件中使用

#### 基础用法
```dart
// 在任意组件中直接使用RoleSelector
const RoleSelector()
```

#### 监听角色变化
```dart
RoleConsumer(
  builder: (context, currentRole, allRoles) {
    return Text('当前角色: ${currentRole.name}');
  },
)
```

#### 自定义监听
```dart
class MyComponent extends StatefulWidget {
  @override
  State<MyComponent> createState() => _MyComponentState();
}

class _MyComponentState extends State<MyComponent> {
  late VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      final currentRole = RoleManager.instance.currentRole;
      // 处理角色变化
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
    return Text('当前: ${RoleManager.instance.currentRole.name}');
  }
}
```

### 3. 重置到默认配置

```dart
// 重置到内置默认角色
RoleManager.instance.resetToDefaults();
```

## 完整示例

### 示例1: 企业聊天应用
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  RoleManager.instance.initialize(
    initialRoles: [
      const ChatRole(id: 'ceo', name: 'CEO', color: Colors.red, icon: Icons.business),
      const ChatRole(id: 'cto', name: 'CTO', color: Colors.blue, icon: Icons.computer),
      const ChatRole(id: 'pm', name: '产品经理', color: Colors.orange, icon: Icons.group),
      const ChatRole(id: 'dev', name: '开发者', color: Colors.green, icon: Icons.code),
      const ChatRole(id: 'qa', name: '测试工程师', color: Colors.purple, icon: Icons.bug_report),
    ],
    defaultRole: const ChatRole(id: 'dev', name: '开发者', color: Colors.green, icon: Icons.code),
  );
  
  runApp(const EnterpriseChatApp());
}
```

### 示例2: 客服系统
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  RoleManager.instance.initialize(
    initialRoles: [
      const ChatRole(id: 'customer', name: '客户', color: Colors.blue, icon: Icons.person),
      const ChatRole(id: 'agent', name: '客服', color: Colors.green, icon: Icons.support_agent),
      const ChatRole(id: 'supervisor', name: '主管', color: Colors.orange, icon: Icons.supervisor_account),
      const ChatRole(id: 'bot', name: '机器人', color: Colors.purple, icon: Icons.smart_toy),
    ],
    defaultRole: const ChatRole(id: 'customer', name: '客户', color: Colors.blue, icon: Icons.person),
  );
  
  runApp(const CustomerServiceApp());
}
```

### 示例3: 教育平台
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  RoleManager.instance.initialize(
    initialRoles: [
      const ChatRole(id: 'student', name: '学生', color: Colors.blue, icon: Icons.school),
      const ChatRole(id: 'teacher', name: '老师', color: Colors.green, icon: Icons.person),
      const ChatRole(id: 'parent', name: '家长', color: Colors.orange, icon: Icons.family_restroom),
      const ChatRole(id: 'admin', name: '管理员', color: Colors.red, icon: Icons.admin_panel_settings),
    ],
    defaultRole: const ChatRole(id: 'student', name: '学生', color: Colors.blue, icon: Icons.school),
  );
  
  runApp(const EducationPlatformApp());
}
```

## 注意事项

1. **初始化时机**: 必须在应用启动时初始化，确保所有组件使用同一角色状态
2. **单例模式**: `RoleManager` 是单例，确保全局状态一致性
3. **不可变性**: 初始化后角色列表可以动态修改，但建议使用 `addRole` 和 `setRole` 方法
4. **性能优化**: 使用 `ListenableBuilder` 或 `RoleConsumer` 自动优化UI重建
5. **内存管理**: 组件销毁时记得移除监听器

## API参考

### RoleManager
- `initialize({List<ChatRole>? initialRoles, ChatRole? defaultRole})` - 初始化角色系统
- `setRole(ChatRole role)` - 设置当前角色
- `addRole(ChatRole role)` - 添加新角色
- `removeRole(ChatRole role)` - 移除角色
- `resetToDefaults()` - 重置到默认角色
- `currentRole` - 获取当前角色
- `allRoles` - 获取所有角色

### RoleSelector
- `const RoleSelector()` - 基础角色选择器
- `const RoleSelector({Function(ChatRole)? onRoleChanged})` - 带回调的角色选择器

### RoleConsumer
- `RoleConsumer({required Widget Function(BuildContext, ChatRole, List<ChatRole>) builder})` - 简化状态消费