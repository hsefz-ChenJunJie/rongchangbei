# Popup 弹出式模态框组件

## 简介

这是一个灵活的弹出式模态框组件，支持通过公共方法控制显示和隐藏，提供了良好的用户体验。

## 特性

- ✅ 支持通过方法控制显示/隐藏
- ✅ 包含关闭按钮
- ✅ 支持点击背景关闭
- ✅ 可自定义样式和尺寸
- ✅ 支持动画效果
- ✅ 响应式设计
- ✅ 主题跟随：自动适配应用主题颜色

## 基本用法

### 1. 创建和使用

```dart
import 'package:flutter/material.dart';
import '../widgets/shared/popup.dart';

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final GlobalKey<PopupState> _popupKey = GlobalKey<PopupState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: () => _popupKey.currentState?.show(),
              child: const Text('显示弹出框'),
            ),
          ),
          Popup(
            key: _popupKey,
            child: const Text('这是弹出内容'),
          ),
        ],
      ),
    );
  }
}
```

### 2. 公共方法

#### isShown()
判断弹出框是否正在显示。

```dart
bool isVisible = _popupKey.currentState?.isShown() ?? false;
```

#### show()
显示弹出框。

```dart
_popupKey.currentState?.show();
```

#### close()
关闭弹出框。

```dart
_popupKey.currentState?.close();
```

#### toggle()
切换弹出框的显示/隐藏状态。

```dart
_popupKey.currentState?.toggle();
```

## 自定义样式

### 基本样式参数

```dart
Popup(
  key: _popupKey,
  width: 300,                    // 设置宽度
  height: 200,                   // 设置高度
  backgroundColor: Colors.white, // 背景色（可选，默认跟随主题）
  barrierColor: Colors.black54,   // 背景遮罩色（可选，默认半透明黑色）
  borderRadius: BorderRadius.circular(16), // 圆角
  padding: EdgeInsets.all(20),   // 内边距
  child: YourContentWidget(),
)
```

### 主题跟随

组件默认会跟随应用主题颜色变化：
- 背景色：使用主题的 `lighterColor`
- 边框色：使用主题的 `darkerColor` 带透明度
- 关闭按钮颜色：使用主题的 `darkTextColor`
- 阴影颜色：使用主题的 `darkerColor` 带透明度

### 阴影效果

```dart
Popup(
  key: _popupKey,
  shadow: BoxShadow(
    color: Colors.black.withOpacity(0.3),
    blurRadius: 15,
    spreadRadius: 5,
    offset: const Offset(0, 8),
  ),
  child: YourContentWidget(),
)
```

## 完整示例

```dart
import 'package:flutter/material.dart';
import '../widgets/shared/popup.dart';

class PopupDemo extends StatefulWidget {
  const PopupDemo({Key? key}) : super(key: key);

  @override
  State<PopupDemo> createState() => _PopupDemoState();
}

class _PopupDemoState extends State<PopupDemo> {
  final GlobalKey<PopupState> _popupKey = GlobalKey<PopupState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Popup 演示')),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                ElevatedButton(
                  onPressed: () => _popupKey.currentState?.show(),
                  child: const Text('显示弹出框'),
                ),
                ElevatedButton(
                  onPressed: () => _popupKey.currentState?.toggle(),
                  child: const Text('切换显示/隐藏'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final isShown = _popupKey.currentState?.isShown() ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isShown ? '正在显示' : '已隐藏'),
                      ),
                    );
                  },
                  child: const Text('检查状态'),
                ),
              ],
            ),
          ),
          Popup(
            key: _popupKey,
            width: 300,
            height: 250,
            backgroundColor: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  '操作成功！',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '您的操作已成功完成。',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _popupKey.currentState?.close(),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 注意事项

1. **必须使用 GlobalKey**：为了调用公共方法，必须使用 `GlobalKey<PopupState>`。

2. **Stack 包裹**：Popup 组件需要被 Stack 包裹，因为它使用 Overlay 实现。

3. **上下文问题**：如果在某些情况下 `show()` 方法无法获取正确的上下文，可以传入上下文参数：
   ```dart
   _popupKey.currentState?.show(context: context);
   ```

4. **内存管理**：组件会在 dispose 时自动关闭弹出框，无需手动清理。

5. **嵌套使用**：可以在其他弹出框中嵌套使用 Popup 组件。

## 技术实现

- 使用 Flutter 的 Overlay 系统实现模态框
- 支持手势识别（点击背景关闭）
- 提供流畅的动画过渡效果
- 完全响应式设计，适配不同屏幕尺寸