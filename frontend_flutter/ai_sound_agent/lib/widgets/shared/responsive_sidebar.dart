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
  late Animation<double> _slideAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // 根据方向设置动画起始值
    // 从左边滑出：-1.0 到 0.0
    // 从右边滑出：1.0 到 0.0
    _slideAnimation = Tween<double>(
      begin: widget.isLeft ? -1.0 : 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    
    return Stack(
      children: [
        // 主要内容区域
        if (widget.child != null) widget.child!,
        
        // 遮罩层和侧边栏
        if (_isOpen) ...[
          // 遮罩层
          GestureDetector(
            onTap: close,
            child: FadeTransition(
              opacity: _animationController,
              child: Container(
                color: widget.barrierColor ?? themeManager.darkerColor.withOpacity(0.5),
              ),
            ),
          ),
          
          // 侧边栏内容
          _buildSidebarContent(),
        ],
      ],
    );
  }

  Widget _buildSidebarContent() {
    final themeManager = ThemeManager();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isPortrait = screenWidth < screenHeight;
        
        // 根据屏幕方向决定侧边栏宽度
        final sidebarWidth = isPortrait 
            ? screenWidth // 手机：占满屏幕宽度
            : screenWidth * 0.5; // 平板：占屏幕宽度的一半

        return AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            final position = widget.isLeft
                ? Positioned(
                    left: _slideAnimation.value * sidebarWidth,
                    top: 0,
                    bottom: 0,
                    width: sidebarWidth,
                    child: child!,
                  )
                : Positioned(
                    right: _slideAnimation.value * sidebarWidth,
                    top: 0,
                    bottom: 0,
                    width: sidebarWidth,
                    child: child!,
                  );

            return position;
          },
          child: Material(
            elevation: 16,
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
          ),
        );
      },
    );
  }
}

