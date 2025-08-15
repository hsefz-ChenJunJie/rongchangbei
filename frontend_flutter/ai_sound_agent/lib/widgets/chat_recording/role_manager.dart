import 'package:flutter/material.dart';
import 'role_selector.dart';

/// 全局角色管理器
/// 提供单例模式的角色状态管理，确保所有组件访问同一角色状态
class RoleManager extends ChangeNotifier {
  static RoleManager? _instance;
  
  // 单例实例
  static RoleManager get instance {
    _instance ??= RoleManager._();
    return _instance!;
  }

  // 私有构造函数
  RoleManager._();

  // 默认角色列表
  List<ChatRole> _roles = [
    const ChatRole(id: 'user', name: '我自己', color: Colors.green, icon: Icons.person),
    const ChatRole(id: 'system', name: 'system', color: Colors.blue, icon: Icons.settings),
    const ChatRole(id: 'boss', name: '老板', color: Colors.red, icon: Icons.business),
    const ChatRole(id: 'pm', name: '项目经理', color: Colors.orange, icon: Icons.group),
    const ChatRole(id: 'client', name: '客户', color: Colors.blue, icon: Icons.account_circle),
  ];

  ChatRole _currentRole = const ChatRole(id: 'user', name: '我自己', color: Colors.green, icon: Icons.person);
  
  // 监听器列表
  final List<VoidCallback> _listeners = [];

  /// 是否已经初始化
  bool _isInitialized = false;

  /// 获取当前角色
  ChatRole get currentRole => _currentRole;

  /// 获取所有可用角色
  List<ChatRole> get allRoles => List.unmodifiable(_roles);

  /// 设置初始角色和角色列表
  /// 只能在应用启动时调用一次
  void initialize({
    List<ChatRole>? initialRoles,
    ChatRole? defaultRole,
  }) {
    if (_isInitialized) return;
    
    if (initialRoles != null && initialRoles.isNotEmpty) {
      _roles = List.from(initialRoles);
    }
    
    if (defaultRole != null) {
      if (_roles.contains(defaultRole)) {
        _currentRole = defaultRole;
      } else if (_roles.any((role) => role.id == defaultRole.id)) {
        _currentRole = _roles.firstWhere((role) => role.id == defaultRole.id);
      } else {
        _roles.add(defaultRole);
        _currentRole = defaultRole;
      }
    } else if (_roles.isNotEmpty) {
      _currentRole = _roles.first;
    }
    
    _isInitialized = true;
    _notifyListeners();
  }

  /// 重置到默认角色配置
  void resetToDefaults() {
    _roles = [
      const ChatRole(id: 'user', name: '我自己', color: Colors.green, icon: Icons.person),
      const ChatRole(id: 'system', name: 'system', color: Colors.blue, icon: Icons.settings),
      const ChatRole(id: 'boss', name: '老板', color: Colors.red, icon: Icons.business),
      const ChatRole(id: 'pm', name: '项目经理', color: Colors.orange, icon: Icons.group),
      const ChatRole(id: 'client', name: '客户', color: Colors.blue, icon: Icons.account_circle),
    ];
    _currentRole = _roles.first;
    _notifyListeners();
  }

  /// 设置当前角色
  void setRole(ChatRole role) {
    if (_currentRole == role) return;
    
    _currentRole = role;
    _notifyListeners();
  }

  /// 添加新角色
  void addRole(ChatRole role) {
    if (!_roles.contains(role)) {
      _roles.add(role);
    }
    setRole(role);
  }

  /// 移除角色
  void removeRole(ChatRole role) {
    _roles.remove(role);
    if (_currentRole == role && _roles.isNotEmpty) {
      setRole(_roles.first);
    } else if (_roles.isEmpty) {
      // 如果没有角色了，添加默认角色
      resetToDefaults();
    }
    _notifyListeners();
  }

  /// 通过ID获取角色
  ChatRole? getRoleById(String id) {
    try {
      return _roles.firstWhere((role) => role.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 添加监听器
  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 清理资源
  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
  
  /// 通知所有监听器
  void _notifyListeners() {
    notifyListeners();
    for (final listener in _listeners) {
      listener();
    }
  }
}

/// 角色提供者组件
/// 使用 InheritedWidget 提供角色状态给子组件
class RoleProvider extends InheritedWidget {
  final RoleManager roleManager;

  const RoleProvider({
    super.key,
    required this.roleManager,
    required super.child,
  });

  static RoleManager of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<RoleProvider>();
    return provider?.roleManager ?? RoleManager.instance;
  }

  @override
  bool updateShouldNotify(RoleProvider oldWidget) {
    return roleManager != oldWidget.roleManager;
  }
}

/// 角色消费者组件
/// 简化从上下文中获取角色管理器的过程
class RoleConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, ChatRole currentRole, List<ChatRole> allRoles) builder;

  const RoleConsumer({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final roleManager = RoleProvider.of(context);
    return ListenableBuilder(
      listenable: roleManager,
      builder: (context, _) {
        return builder(context, roleManager.currentRole, roleManager.allRoles);
      },
    );
  }
}