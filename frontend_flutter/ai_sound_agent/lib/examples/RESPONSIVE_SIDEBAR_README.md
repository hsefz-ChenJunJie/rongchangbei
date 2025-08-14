# 响应式侧边栏组件 (ResponsiveSidebar)

## 概述

`ResponsiveSidebar` 是一个智能的响应式侧边栏组件，能够根据设备屏幕的宽高比自动调整显示方式：

- **手机模式**（瘦长型屏幕，width < height）：侧边栏占满整个屏幕宽度
- **平板模式**（宽屏设备，width > height）：侧边栏占据屏幕左侧约50%的宽度

## 特性

- 🎯 **响应式设计**：自动适配不同屏幕尺寸
- 📱 **手机优化**：在手机上全屏显示
- 📱 **平板优化**：在平板上占据合理空间
- ✨ **平滑动画**：带有优雅的过渡动画
- 🎮 **手势支持**：点击遮罩关闭
- 🎯 **简单易用**：提供简洁的API接口

## 使用方法

### 基本用法

```dart
import 'package:flutter/material.dart';
import '../widgets/shared/responsive_sidebar.dart';

class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final GlobalKey<ResponsiveSidebarState> _sidebarKey = GlobalKey<ResponsiveSidebarState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveSidebar(
        key: _sidebarKey,
        backgroundColor: Colors.white,
        barrierColor: Colors.black54,
        child: Scaffold(
          appBar: AppBar(
            title: Text('我的应用'),
            leading: IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => _sidebarKey.currentState?.open(),
            ),
          ),
          body: Center(
            child: Text('主内容区域'),
          ),
        ),
      ),
    );
  }
}
```

## API 接口

### 公共方法

| 方法 | 返回类型 | 描述 |
|------|----------|------|
| `isOpen()` | `bool` | 判断侧边栏是否处于打开状态 |
| `open()` | `void` | 打开侧边栏 |
| `close()` | `void` | 关闭侧边栏 |

### 使用示例

```dart
// 获取侧边栏状态
bool isSidebarOpen = _sidebarKey.currentState?.isOpen() ?? false;

// 打开侧边栏
_sidebarKey.currentState?.open();

// 关闭侧边栏
_sidebarKey.currentState?.close();

// 切换侧边栏状态
if (_sidebarKey.currentState?.isOpen() ?? false) {
  _sidebarKey.currentState?.close();
} else {
  _sidebarKey.currentState?.open();
}
```

## 自定义选项

### 构造函数参数

```dart
ResponsiveSidebar({
  Key? key,
  Widget? child,                    // 主内容区域
  Color? backgroundColor,          // 侧边栏背景色
  Color? barrierColor,             // 遮罩层颜色
  Duration animationDuration = const Duration(milliseconds: 300),  // 动画时长
  bool isLeft = true,              // 是否从左边滑出，false为从右边滑出
})
```

### 示例：自定义样式

```dart
ResponsiveSidebar(
  key: _sidebarKey,
  backgroundColor: Colors.grey[100],
  barrierColor: Colors.black45,
  animationDuration: const Duration(milliseconds: 400),
  child: YourMainContent(),
)
```

## 响应式行为

### 手机模式 (Portrait)
- **触发条件**：屏幕宽度 < 屏幕高度
- **行为**：侧边栏占满整个屏幕宽度
- **适用场景**：手机竖屏、窄屏设备

### 平板模式 (Landscape)
- **触发条件**：屏幕宽度 > 屏幕高度
- **行为**：侧边栏占据屏幕左侧约50%的宽度
- **适用场景**：平板、横屏手机、桌面设备

## 方向控制

### 从左边滑出（默认）

```dart
ResponsiveSidebar(
  key: _sidebarKey,
  isLeft: true, // 或不设置，默认为true
  backgroundColor: Colors.white,
  child: YourMainContent(),
)
```

### 从右边滑出

```dart
ResponsiveSidebar(
  key: _sidebarKey,
  isLeft: false, // 从右边滑出
  backgroundColor: Colors.white,
  child: YourMainContent(),
)
```

## 完整示例

### 带侧边栏内容的完整示例

```dart
import 'package:flutter/material.dart';
import '../widgets/shared/responsive_sidebar.dart';

class CompleteExample extends StatefulWidget {
  @override
  _CompleteExampleState createState() => _CompleteExampleState();
}

class _CompleteExampleState extends State<CompleteExample> {
  final GlobalKey<ResponsiveSidebarState> _sidebarKey = GlobalKey<ResponsiveSidebarState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveSidebar(
        key: _sidebarKey,
        backgroundColor: Colors.white,
        barrierColor: Colors.black54,
        child: Scaffold(
          appBar: AppBar(
            title: Text('完整示例'),
            leading: IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => _sidebarKey.currentState?.open(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('主内容区域'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final isOpen = _sidebarKey.currentState?.isOpen() ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isOpen ? '侧边栏已打开' : '侧边栏已关闭'),
                      ),
                    );
                  },
                  child: Text('检查状态'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sidebarKey.currentState?.open(),
        child: Icon(Icons.menu_open),
      ),
    );
  }
}
```

## 注意事项

1. **必须使用 GlobalKey**：为了调用公共方法，必须使用 `GlobalKey<ResponsiveSidebarState>`
2. **关闭按钮**：组件内置关闭按钮（×），点击后会自动调用 `close()` 方法
3. **遮罩层**：点击遮罩区域也会关闭侧边栏
4. **动画效果**：打开和关闭都有平滑的动画过渡
5. **性能优化**：使用 `AnimationController` 优化动画性能

## 与现有组件集成

该组件可以与项目中的其他组件无缝集成：

- 与 `BasePage` 配合使用
- 与 `BottomNavigator` 一起使用
- 支持主题色跟随
- 响应式设计适配

## 测试建议

1. **旋转测试**：在模拟器中旋转屏幕测试响应式效果
2. **多设备测试**：在不同尺寸的设备上测试显示效果
3. **性能测试**：确保动画流畅，无卡顿
4. **手势测试**：测试点击遮罩关闭功能