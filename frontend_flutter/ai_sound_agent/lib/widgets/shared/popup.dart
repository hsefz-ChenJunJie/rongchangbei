import 'package:flutter/material.dart';
import '../../services/theme_manager.dart';

class Popup extends StatefulWidget {
  final Widget? child;
  final Color? backgroundColor;
  final Color? barrierColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;

  const Popup({
    Key? key,
    this.child,
    this.backgroundColor,
    this.barrierColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.shadow,
  }) : super(key: key);

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> {
  bool _isShown = false;
  OverlayEntry? _overlayEntry;

  // 判断是否在展示状态
  bool isShown() => _isShown;

  // 展示出模态框
  void show({BuildContext? context}) {
    if (_isShown) return;
    
    final buildContext = context ?? this.context;
    if (buildContext == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(context),
    );

    Overlay.of(buildContext).insert(_overlayEntry!);
    setState(() {
      _isShown = true;
    });
  }

  // 关闭模态框
  void close() {
    if (!_isShown) return;
    
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isShown = false;
    });
  }

  // 切换显示/隐藏状态
  void toggle({BuildContext? context}) {
    if (_isShown) {
      close();
    } else {
      show(context: context);
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final themeManager = ThemeManager();
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: close,
      child: Container(
        color: widget.barrierColor ?? Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 防止点击内容区域时关闭
            child: Container(
              width: widget.width ?? MediaQuery.of(context).size.width * 0.8,
              height: widget.height,
              padding: widget.padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? themeManager.lighterColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                border: Border.all(
                  color: themeManager.darkerColor.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  widget.shadow ??
                      BoxShadow(
                        color: themeManager.darkerColor.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                ],
              ),
              child: Stack(
                children: [
                  if (widget.child != null)
                    Positioned.fill(
                      child: widget.child!,
                    ),
                  // 关闭按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildCloseButton(themeManager, theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(ThemeManager themeManager, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: close,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: themeManager.lighterColor.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: themeManager.darkerColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.close,
            size: 18,
            color: themeManager.darkTextColor.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 这个组件本身不直接构建UI，通过show/close方法控制显示
    return const SizedBox.shrink();
  }
}

// 使用示例：
/*
// 1. 在State类中声明
class _MyPageState extends State<MyPage> {
  late PopupState popupState;

  @override
  void initState() {
    super.initState();
    // 初始化popupState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      popupState = Popup.of(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => popupState.show(),
          child: Text('显示弹出框'),
        ),
      ),
    );
  }
}

// 2. 在Widget树中使用Popup包裹
@override
Widget build(BuildContext context) {
  return Popup(
    child: Container(
      padding: EdgeInsets.all(20),
      child: Text('这是弹出内容'),
    ),
  );
}
*/