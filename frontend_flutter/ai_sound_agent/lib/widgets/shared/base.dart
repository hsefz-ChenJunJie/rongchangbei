import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bottom_navigator.dart';
import 'bread_crumb_trail.dart';
import 'basebutton.dart';
import '../../pages/settings.dart';
import '../../app/route.dart';
import '../../utils/constants.dart';
import '../../services/theme_manager.dart';

abstract class BasePage extends StatefulWidget {
  final String title;
  final bool showBottomNav;
  final bool showBreadcrumb;
  final bool showSettingsFab;

  const BasePage({
    Key? key,
    required this.title,
    this.showBottomNav = true,
    this.showBreadcrumb = true,
    this.showSettingsFab = true,
  }) : super(key: key);
}

abstract class BasePageState<T extends BasePage> extends State<T> {
  int _currentBottomNavIndex = 0;
  late AppRouteState _routeState;

  @override
  void initState() {
    super.initState();
    // 使用 Provider 或直接使用 ChangeNotifierProvider 获取路由状态
    // 这里我们创建一个默认的路由状态实例
    _routeState = AppRouteState();
  }

  // 子类需要实现的内容区域
  Widget buildContent(BuildContext context);

  // 底部导航栏项目，子类可以重写
  List<BottomNavItem> get bottomNavItems => pagetiles;

  // 处理底部导航栏点击
  void onBottomNavTap(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentBottomNavIndex = index;
    });
    
    // 这里可以添加页面切换逻辑
    onPageChange(index);
  }

  // 子类可以重写页面切换逻辑
  void onPageChange(int index) {
    // 默认实现：打印日志
    debugPrint('切换到页面: ${bottomNavItems[index].label}');
  }

  // 跳转到设置页面
  void navigateToSettings() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Settings(),
        settings: RouteSettings(
          arguments: {'message': '从${widget.title}页面进入设置'},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    return Scaffold(
      backgroundColor: themeManager.lighterColor,
      appBar: widget.showBreadcrumb || widget.title.isNotEmpty
          ? AppBar(
                title: widget.showBreadcrumb
                    ? BreadcrumbTrail(state: _routeState)
                    : Text(
                        widget.title,
                        style: TextStyle(color: themeManager.darkTextColor),
                      ),
              backgroundColor: themeManager.lighterColor,
              elevation: 0,
              iconTheme: IconThemeData(color: themeManager.darkTextColor),
            )
          : null,
      
      body: SafeArea(
        child: buildContent(context),
      ),
      
      floatingActionButton: widget.showSettingsFab
          ? FloatingActionButton(
              onPressed: navigateToSettings,
              backgroundColor: themeManager.darkerColor,
              child: Icon(Icons.settings, color: themeManager.lightTextColor),
            )
          : null,
      
      bottomNavigationBar: widget.showBottomNav && bottomNavItems.isNotEmpty
          ? BottomNavigator(
              currentIndex: _currentBottomNavIndex,
              onTap: onBottomNavTap,
              items: bottomNavItems,
            )
          : null,
    );
  }

  // 工具方法：显示加载状态
  Widget buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // 工具方法：显示空状态
  Widget buildEmptyState({
    String? message,
    IconData? icon,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? '暂无数据',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            BaseButton(
              text: '重试',
              primaryColor: Theme.of(context).colorScheme.primary,
              secondaryColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }

  // 工具方法：显示错误状态
  Widget buildErrorState({
    required String error,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '出错了: $error',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            BaseButton(
              text: '重试',
              primaryColor: Colors.red,
              secondaryColor: Colors.red.shade700,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

// 使用示例：
/*
class HomePage extends BasePage {
  const HomePage({Key? key}) : super(
    key: key,
    title: '首页',
    showBottomNav: true,
    showBreadcrumb: true,
    showSettingsFab: true,
  );

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage> {
  @override
  Widget buildContent(BuildContext context) {
    return const Center(
      child: Text('这是首页内容'),
    );
  }

  @override
  void onPageChange(int index) {
    super.onPageChange(index);
    // 根据索引切换页面内容
    switch (index) {
      case 0:
        // 首页
        break;
      case 1:
        // 发现页
        break;
      case 2:
        // 我的页面
        break;
    }
  }

  // 使用默认的底部导航栏（来自constants.dart）
  // 如需自定义，可以重写此方法
}
*/