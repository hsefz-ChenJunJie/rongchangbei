import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

/// Tab配置数据模型
class TabConfig {
  final String label;
  final Widget content;
  final IconData? icon;
  final String? badgeText;
  final Color? badgeColor;
  final bool enabled;

  const TabConfig({
    required this.label,
    required this.content,
    this.icon,
    this.badgeText,
    this.badgeColor,
    this.enabled = true,
  });
}

/// 轻量级Tab组件，避免内存泄漏
class LightweightTabs extends StatefulWidget {
  final List<TabConfig> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final bool showIndicator;

  const LightweightTabs({
    Key? key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.showIndicator = true,
  }) : super(key: key);

  @override
  State<LightweightTabs> createState() => _LightweightTabsState();
}

class _LightweightTabsState extends State<LightweightTabs> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.tabs.length - 1);
  }

  void changeTab(int index) {
    if (index >= 0 && index < widget.tabs.length && index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
      widget.onTabChanged?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const Center(child: Text('没有可用的标签页'));
    }

    final themeManager = ThemeManager();
    
    return Column(
      children: [
        _buildTabBar(themeManager),
        Expanded(
          child: widget.tabs[_currentIndex].content,
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeManager themeManager) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: themeManager.lighterColor,
        border: Border(
          bottom: BorderSide(
            color: themeManager.darkTextColor.withOpacity(0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _currentIndex;
          
          return Expanded(
            child: InkWell(
              onTap: tab.enabled ? () => changeTab(index) : null,
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tab.icon != null) ...[
                      Icon(
                        tab.icon,
                        size: 18,
                        color: _getIconColor(themeManager, isSelected, tab.enabled),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: _getTextColor(themeManager, isSelected, tab.enabled),
                      ),
                    ),
                    if (tab.badgeText != null) ...[
                      const SizedBox(width: 4),
                      _buildBadge(themeManager, tab),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getIconColor(ThemeManager themeManager, bool isSelected, bool enabled) {
    if (!enabled) return themeManager.darkTextColor.withOpacity(0.3);
    return isSelected ? themeManager.baseColor : themeManager.darkTextColor.withOpacity(0.6);
  }

  Color _getTextColor(ThemeManager themeManager, bool isSelected, bool enabled) {
    if (!enabled) return themeManager.darkTextColor.withOpacity(0.3);
    return isSelected ? themeManager.baseColor : themeManager.darkTextColor.withOpacity(0.6);
  }

  Widget _buildBadge(ThemeManager themeManager, TabConfig tab) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tab.badgeColor ?? themeManager.baseColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 16),
      child: Text(
        tab.badgeText!,
        style: TextStyle(
          fontSize: 10,
          color: themeManager.lightTextColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 简化版卡片Tab组件
class LightweightCardTabs extends StatefulWidget {
  final List<TabConfig> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const LightweightCardTabs({
    Key? key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
  }) : super(key: key);

  @override
  State<LightweightCardTabs> createState() => _LightweightCardTabsState();
}

class _LightweightCardTabsState extends State<LightweightCardTabs> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.tabs.length - 1);
  }

  void changeTab(int index) {
    if (index >= 0 && index < widget.tabs.length && index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
      widget.onTabChanged?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const Center(child: Text('没有可用的标签页'));
    }

    final themeManager = ThemeManager();
    
    return Column(
      children: [
        _buildCardTabBar(themeManager),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            child: widget.tabs[_currentIndex].content,
          ),
        ),
      ],
    );
  }

  Widget _buildCardTabBar(ThemeManager themeManager) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: widget.tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = index == _currentIndex;
            
            return Expanded(
              child: InkWell(
                onTap: tab.enabled ? () => changeTab(index) : null,
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? themeManager.baseColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tab.icon != null) ...[
                        Icon(
                          tab.icon,
                          size: 16,
                          color: isSelected 
                              ? themeManager.lightTextColor
                              : themeManager.darkTextColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? themeManager.lightTextColor
                              : themeManager.darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 使用示例
class LightweightTabsExample extends StatelessWidget {
  const LightweightTabsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '首页',
        icon: Icons.home,
        content: const Center(child: Text('首页内容')),
      ),
      TabConfig(
        label: '消息',
        icon: Icons.message,
        content: const Center(child: Text('消息内容')),
        badgeText: '3',
        badgeColor: Colors.red,
      ),
      TabConfig(
        label: '设置',
        icon: Icons.settings,
        content: const Center(child: Text('设置内容')),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('轻量级Tab组件示例')),
      body: LightweightTabs(
        tabs: tabs,
        onTabChanged: (index) => print('切换到Tab: $index'),
      ),
    );
  }
}