import 'package:flutter/material.dart';
import 'package:ai_sound_agent/app/route.dart';
import '../../services/theme_manager.dart';


class BreadcrumbTrail extends StatelessWidget {
  final AppRouteState state;
  
  const BreadcrumbTrail({super.key, required this.state});
  
  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    if (state.breadcrumbs.isEmpty) {
      return Text(
        '首页',
        style: TextStyle(color: themeManager.darkTextColor),
      );
    }
    
    return Wrap(
      spacing: 4,
      children: [
        for (int i = 0; i < state.breadcrumbs.length; i++)
          GestureDetector(
            onTap: () => state.popTo(i),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getDisplayName(state.breadcrumbs[i]),
                  style: TextStyle(
                    color: i == state.breadcrumbs.length - 1 
                      ? themeManager.lighterColor
                      : themeManager.darkTextColor.withValues(alpha: 0.6),
                    fontWeight: i == state.breadcrumbs.length - 1 
                      ? FontWeight.bold
                      : FontWeight.normal,
                  ),
                ),
                if (i < state.breadcrumbs.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('>', style: TextStyle(color: themeManager.darkTextColor.withValues(alpha: 0.4))),
                  )
              ],
            ),
          ),
        ],
    );
  }
  
  String _getDisplayName(String route) {
    // 将路由路径转换为显示名称
    switch (route) {
      case '/':
        return '首页';
      case 'settings':
        return '设置';
      case 'advanced':
        return '高级设置';
      case 'shop':
        return '商店';
      case 'chat-recording':
        return '聊天录音';
      case 'device-test':
        return '设备测试';
      case 'main-processing':
        return '语音处理中心';
      default:
        return route.isEmpty ? '首页' : route;
    }
  }
}