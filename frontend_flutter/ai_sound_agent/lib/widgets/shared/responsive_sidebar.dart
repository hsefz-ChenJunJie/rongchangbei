import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

class ResponsiveSidebar extends StatefulWidget {
  final Widget? child;
  final Color? backgroundColor;
  final Color? barrierColor;
  final Duration animationDuration;
  final bool isLeft;

  const ResponsiveSidebar({
    super.key,
    this.child,
    this.backgroundColor,
    this.barrierColor,
    this.animationDuration = const Duration(milliseconds: 300),
    this.isLeft = true,
  });

  @override
  ResponsiveSidebarState createState() => ResponsiveSidebarState();
}

class ResponsiveSidebarState extends State<ResponsiveSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
  }



  /// 判断是否开启
  bool isOpen() => _isOpen;

  /// 打开侧边栏
  void open() {
    if (!_isOpen) {
      HapticFeedback.lightImpact();
      setState(() {
        _isOpen = true;
      });
      _animationController.forward();
    }
  }

  /// 关闭侧边栏
  void close() {
    if (_isOpen) {
      HapticFeedback.lightImpact();
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isOpen = false;
          });
        }
      });
    }
  }

  /// 切换侧边栏状态
  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < screenHeight; // 瘦长型为手机
    
    if (!isMobile) {
      // 平板模式：侧边栏占据1/2，主内容压缩到另一半
      return Row(
        children: [
          // 主内容区域
          Expanded(
            flex: 1,
            child: Container(
              margin: EdgeInsets.only(
                left: _isOpen ? (widget.isLeft ? screenWidth * 0.5 : 0) : 0,
                right: _isOpen ? (!widget.isLeft ? screenWidth * 0.5 : 0) : 0,
              ),
              child: widget.child ?? Container(),
            ),
          ),
          
          // 侧边栏 - 占据左边1/2
          if (_isOpen)
            SizedBox(
              width: screenWidth * 0.5,
              child: _buildSidebarContent(false),
            ),
        ],
      );
    } else {
      // 手机模式：侧边栏占满屏幕（原有逻辑）
      return Stack(
        children: [
          // 主内容区域
          widget.child ?? Container(),
          
          // 侧边栏和遮罩层
          if (_isOpen) ...[
            // 遮罩层
              GestureDetector(
                onTap: close,
                child: Container(
                  color: (widget.barrierColor ?? themeManager.darkerColor).withValues(alpha: 0.5),
                ),
              ),
            
            // 侧边栏内容 - 手机模式直接显示，不需要复杂动画
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildSidebarContent(true),
            ),
          ],
        ],
      );
    }
  }



  Widget _buildSidebarContent(bool isMobile) {
    final themeManager = ThemeManager();
    
    return Material(
      elevation: isMobile ? 16 : 8,
      color: widget.backgroundColor ?? themeManager.lighterColor,
      child: Stack(
        children: [
          // 侧边栏内容区域
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 48.0), // 为关闭按钮留出空间
              child: widget.child != null 
                  ? (widget.child is Container || widget.child is SizedBox)
                      ? Center(
                          child: Text(
                            '侧边栏内容',
                            style: TextStyle(
                              color: themeManager.darkTextColor,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : widget.child!
                  : Center(
                      child: Text(
                        '侧边栏内容',
                        style: TextStyle(
                          color: themeManager.darkTextColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          ),
          
          // 关闭按钮 - 根据滑出方向调整位置
          Positioned(
            top: 8,
            right: widget.isLeft ? 8 : null,
            left: widget.isLeft ? null : 8,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: 24,
                color: themeManager.baseColor,
              ),
              onPressed: close,
              tooltip: '关闭',
            ),
          ),
        ],
      ),
    );
  }
}

