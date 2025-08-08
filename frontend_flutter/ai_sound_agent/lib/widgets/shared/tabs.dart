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
  final bool? enabled;

  const TabConfig({
    required this.label,
    required this.content,
    this.icon,
    this.badgeText,
    this.badgeColor,
    this.enabled = true,
  });
}

/// 多Tab组件
class CustomTabs extends StatefulWidget {
  final List<TabConfig> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final bool isScrollable;
  final double tabHeight;
  final double indicatorWeight;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final EdgeInsetsGeometry? padding;
  final bool showIndicator;
  final TabAlignment tabAlignment;

  const CustomTabs({
    Key? key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.isScrollable = false,
    this.tabHeight = 48.0,
    this.indicatorWeight = 2.0,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.padding,
    this.showIndicator = true,
    this.tabAlignment = TabAlignment.start,
  })  : assert(tabs.length > 0, '至少需要提供一个Tab'),
        assert(initialIndex >= 0 && initialIndex < tabs.length, '初始索引超出范围'),
        super(key: key);

  @override
  State<CustomTabs> createState() => _CustomTabsState();
}

class _CustomTabsState extends State<CustomTabs> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    if (widget.tabs.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, widget.tabs.length - 1);
      _tabController = TabController(
        length: widget.tabs.length,
        initialIndex: _currentIndex,
        vsync: this,
      );
      _tabController!.addListener(_handleTabChange);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController != null && _tabController!.index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = _tabController!.index;
      });
      widget.onTabChanged?.call(_currentIndex);
    }
  }

  void changeTab(int index) {
    if (index >= 0 && index < widget.tabs.length && index != _currentIndex && _tabController != null) {
      _tabController!.animateTo(index);
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
          child: _buildTabContent(themeManager),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeManager themeManager) {
    final indicatorColor = widget.indicatorColor ?? themeManager.baseColor;
    final labelColor = widget.labelColor ?? themeManager.baseColor;
    final unselectedLabelColor = widget.unselectedLabelColor ?? 
        themeManager.darkTextColor.withOpacity(0.6);

    return Container(
      decoration: BoxDecoration(
        color: themeManager.lighterColor,
        border: Border(
          bottom: BorderSide(
            color: themeManager.darkTextColor.withOpacity(0.1),
            width: 1.0,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: widget.isScrollable,
        tabAlignment: widget.tabAlignment,
        indicator: widget.showIndicator
            ? UnderlineTabIndicator(
                borderSide: BorderSide(
                  width: widget.indicatorWeight,
                  color: indicatorColor,
                ),
                insets: const EdgeInsets.symmetric(horizontal: 16.0),
              )
            : const BoxDecoration(),
        indicatorWeight: widget.indicatorWeight,
        indicatorColor: indicatorColor,
        labelColor: labelColor,
        unselectedLabelColor: unselectedLabelColor,
        labelStyle: widget.labelStyle ?? TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
        unselectedLabelStyle: widget.unselectedLabelStyle ?? TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: unselectedLabelColor,
        ),
        padding: widget.padding,
        tabs: widget.tabs.map((tab) => _buildTab(tab, themeManager)).toList(),
      ),
    );
  }

  Widget _buildTab(TabConfig tab, ThemeManager themeManager) {
    final isEnabled = tab.enabled ?? true;
    final isSelected = widget.tabs.indexOf(tab) == _currentIndex;
    
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (tab.icon != null) ...[
            Icon(
              tab.icon,
              size: 18,
              color: isEnabled 
                  ? (isSelected ? themeManager.baseColor : themeManager.darkTextColor.withOpacity(0.6))
                  : themeManager.darkTextColor.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            tab.label,
            style: TextStyle(
              color: isEnabled
                  ? (isSelected ? themeManager.baseColor : themeManager.darkTextColor.withOpacity(0.6))
                  : themeManager.darkTextColor.withOpacity(0.3),
            ),
          ),
          if (tab.badgeText != null) ...[
            const SizedBox(width: 4),
            Container(
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(ThemeManager themeManager) {
    return TabBarView(
      controller: _tabController,
      children: widget.tabs.map((tab) {
        return Container(
          color: themeManager.lighterColor,
          child: tab.content,
        );
      }).toList(),
    );
  }
}

/// 简化的Tab组件，用于不需要复杂功能的场景
class SimpleTabs extends StatelessWidget {
  final Map<String, Widget> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const SimpleTabs({
    Key? key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabConfigs = tabs.entries.map((entry) => TabConfig(
      label: entry.key,
      content: entry.value,
    )).toList();

    return CustomTabs(
      tabs: tabConfigs,
      initialIndex: initialIndex,
      onTabChanged: onTabChanged,
    );
  }
}

/// 卡片式Tab组件
class CardTabs extends StatefulWidget {
  final List<TabConfig> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final double elevation;
  final BorderRadius? borderRadius;

  const CardTabs({
    Key? key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.elevation = 2.0,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<CardTabs> createState() => _CardTabsState();
}

class _CardTabsState extends State<CardTabs> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
        Card(
          elevation: widget.elevation,
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: widget.tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = index == _currentIndex;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () => changeTab(index),
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
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            child: widget.tabs[_currentIndex].content,
          ),
        ),
      ],
    );
  }
}

// 使用示例
class TabsExample extends StatelessWidget {
  const TabsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '首页',
        icon: Icons.home,
        content: const Center(child: Text('首页内容')),
        badgeText: '3',
      ),
      TabConfig(
        label: '消息',
        icon: Icons.message,
        content: const Center(child: Text('消息内容')),
        badgeText: '99+',
        badgeColor: Colors.red,
      ),
      TabConfig(
        label: '设置',
        icon: Icons.settings,
        content: const Center(child: Text('设置内容')),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tab组件示例')),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text('标准Tab组件'),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: CustomTabs(
              tabs: tabs,
              onTabChanged: (index) => print('切换到Tab: $index'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('卡片式Tab组件'),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: CardTabs(
              tabs: tabs.take(2).toList(),
              onTabChanged: (index) => print('卡片Tab切换到: $index'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('简化Tab组件'),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: SimpleTabs(
              tabs: {
                'Tab1': const Center(child: Text('Tab1内容')),
                'Tab2': const Center(child: Text('Tab2内容')),
                'Tab3': const Center(child: Text('Tab3内容')),
              },
              onTabChanged: (index) => print('简化Tab切换到: $index'),
            ),
          ),
        ],
      ),
    );
  }
}