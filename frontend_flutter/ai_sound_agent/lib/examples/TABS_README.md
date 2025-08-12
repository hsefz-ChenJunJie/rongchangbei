# 多Tab组件使用指南

## 概述

本项目提供了四种不同类型的Tab组件，每种都有其特定的使用场景和优势：

1. **CustomTabs** - 标准Tab组件，功能最完整
2. **CardTabs** - 卡片式Tab组件，适合移动端
3. **SimpleTabs** - 简化Tab组件，快速开发
4. **AdvancedTabs** - 高级自定义Tab组件

## 组件详解

### 1. CustomTabs（标准Tab组件）

#### 基本用法
```dart
final tabs = [
  TabConfig(
    label: '首页',
    icon: Icons.home,
    content: HomeContent(),
    badgeText: '3',
    badgeColor: Colors.red,
  ),
  TabConfig(
    label: '消息',
    icon: Icons.message,
    content: MessageContent(),
    enabled: false, // 禁用状态
  ),
];

CustomTabs(
  tabs: tabs,
  initialIndex: 0,
  onTabChanged: (index) {
    print('切换到Tab: $index');
  },
)
```

#### 高级配置
```dart
CustomTabs(
  tabs: tabs,
  isScrollable: true, // 可滚动
  tabAlignment: TabAlignment.start,
  indicatorColor: Colors.purple,
  labelColor: Colors.purple,
  unselectedLabelColor: Colors.grey,
  labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  unselectedLabelStyle: TextStyle(fontSize: 14),
)
```

### 2. CardTabs（卡片式Tab组件）

#### 基本用法
```dart
CardTabs(
  tabs: tabs,
  elevation: 4,
  borderRadius: BorderRadius.circular(12),
  onTabChanged: (index) {
    print('卡片Tab切换到: $index');
  },
)
```

### 3. SimpleTabs（简化Tab组件）

#### 基本用法
```dart
SimpleTabs(
  tabs: {
    'Tab1': Content1(),
    'Tab2': Content2(),
    'Tab3': Content3(),
  },
  onTabChanged: (index) {
    print('简化Tab切换到: $index');
  },
)
```

### 4. TabConfig配置

| 属性 | 类型 | 描述 | 默认值 |
|------|------|------|--------|
| label | String | Tab标签文字 | 必填 |
| content | Widget | Tab内容组件 | 必填 |
| icon | IconData? | Tab图标 | null |
| badgeText | String? | 徽章文字 | null |
| badgeColor | Color? | 徽章颜色 | null |
| enabled | bool? | 是否启用 | true |

## 主题集成

所有Tab组件都集成了ThemeManager，会自动使用当前主题的颜色配置：

- 主题主色用于指示器和选中状态
- 主题文字颜色用于标签文字
- 支持动态主题切换

## 实际应用示例

### 1. 电商应用
```dart
final tabs = [
  TabConfig(label: '全部商品', content: AllProducts()),
  TabConfig(label: '热销商品', content: HotProducts(), badgeText: 'HOT'),
  TabConfig(label: '新品上架', content: NewProducts(), badgeText: 'NEW'),
  TabConfig(label: '优惠活动', content: Promotions()),
];

CustomTabs(
  tabs: tabs,
  isScrollable: true,
  onTabChanged: (index) => loadProducts(index),
)
```

### 2. 后台管理系统
```dart
final tabs = [
  TabConfig(label: '用户管理', icon: Icons.people, content: UserManagement()),
  TabConfig(label: '订单管理', icon: Icons.receipt, content: OrderManagement()),
  TabConfig(label: '商品管理', icon: Icons.inventory, content: ProductManagement()),
  TabConfig(label: '数据统计', icon: Icons.analytics, content: Statistics()),
];

CardTabs(
  tabs: tabs,
  elevation: 2,
  onTabChanged: (index) => updateDashboard(index),
)
```

### 3. 新闻应用
```dart
SimpleTabs(
  tabs: {
    '推荐': RecommendedNews(),
    '科技': TechNews(),
    '体育': SportsNews(),
    '娱乐': EntertainmentNews(),
    '财经': FinanceNews(),
  },
  onTabChanged: (index) => loadNews(index),
)
```

## 性能优化建议

1. **懒加载内容**：每个Tab的内容应该使用`AutomaticKeepAliveClientMixin`来保持状态
2. **限制Tab数量**：移动端建议不超过5个Tab
3. **使用isScrollable**：当Tab数量较多时启用滚动
4. **缓存数据**：切换Tab时缓存已加载的数据

## 最佳实践

### 1. 状态管理
```dart
class MyTabPage extends StatefulWidget {
  @override
  _MyTabPageState createState() => _MyTabPageState();
}

class _MyTabPageState extends State<MyTabPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // 处理Tab切换
    }
  }
}
```

### 2. 响应式设计
```dart
ResponsiveBuilder(
  builder: (context, sizingInformation) {
    final isMobile = sizingInformation.deviceScreenType == DeviceScreenType.mobile;
    return isMobile 
        ? CardTabs(tabs: tabs)
        : CustomTabs(tabs: tabs, isScrollable: false);
  },
)
```

## 常见问题

### Q: 如何动态添加/删除Tab？
A: 使用StatefulWidget管理tabs列表，更新后重新构建组件

### Q: 如何保持Tab状态？
A: 在内容组件中使用`AutomaticKeepAliveClientMixin`

### Q: 如何自定义指示器样式？
A: 通过CustomTabs的indicator参数自定义

### Q: 如何处理Tab切换动画？
A: TabController提供了动画控制，可以自定义切换效果

## 更新日志

- v1.0.0: 初始版本，包含基础Tab组件
- v1.1.0: 添加徽章支持和禁用状态
- v1.2.0: 集成主题管理器
- v1.3.0: 添加卡片式Tab组件
- v1.4.0: 优化性能和响应式设计