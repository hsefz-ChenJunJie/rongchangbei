import 'package:flutter/material.dart';

// 定义路由名称常量
class Routes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String advancedSettings = '/settings/advanced';
  static const String deviceTest = '/device-test';
  static const String mainProcessing = '/main-processing';
  static const String chatRecording = '/chat-recording';
}

// 路由状态类 (存储当前路由状态)
class AppRouteState extends ChangeNotifier {
  List<String> _breadcrumbs = []; // 面包屑路径队列
  
  List<String> get breadcrumbs => _breadcrumbs;
  
  // 添加新路径
  void push(String path) {
    _breadcrumbs.add(path);
    notifyListeners();
  }
  
  // 回到指定层级
  void popTo(int level) {
    if (level < 0 || level >= _breadcrumbs.length) return;
    _breadcrumbs = _breadcrumbs.sublist(0, level + 1);
    notifyListeners();
  }
  
  // 替换当前路径
  void replace(String path) {
    if (_breadcrumbs.isNotEmpty) {
      _breadcrumbs.removeLast();
    }
    _breadcrumbs.add(path);
    notifyListeners();
  }
  
  // 清除所有路径
  void clear() {
    _breadcrumbs.clear();
    notifyListeners();
  }
}

// 路由代理类 (核心路由逻辑)
class AppRouterDelegate extends RouterDelegate<List<String>>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<List<String>> {
  final AppRouteState state;
  final Widget Function(String) pageBuilder;

  AppRouterDelegate({
    required this.state,
    required this.pageBuilder,
  }) {
    state.addListener(notifyListeners);
  }

  @override
  GlobalKey<NavigatorState>? get navigatorKey => GlobalKey<NavigatorState>();

  @override
  List<String>? get currentConfiguration => state.breadcrumbs;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        for (final path in state.breadcrumbs)
          MaterialPage(
            key: ValueKey(path),
            child: pageBuilder(path),
          ),
      ],
      onDidRemovePage: (page) {
        if (state.breadcrumbs.isNotEmpty) {
          state.popTo(state.breadcrumbs.length - 2);
        }
      },
    );
  }

  @override
  Future<void> setNewRoutePath(List<String> configuration) async {
    state.clear();
    for (final path in configuration) {
      state.push(path);
    }
  }

  @override
  void dispose() {
    state.removeListener(notifyListeners);
    super.dispose();
  }
}

// 路由信息解析器
class AppRouteInformationParser extends RouteInformationParser<List<String>> {
  @override
  Future<List<String>> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    return uri.pathSegments;
  }

  @override
  RouteInformation restoreRouteInformation(List<String> configuration) {
    return RouteInformation(uri: Uri.parse('/${configuration.join('/')}'));
  }
}

