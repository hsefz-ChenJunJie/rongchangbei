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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenWidth < screenHeight;
    
    // 平板模式下侧边栏宽度
    final tabletSidebarWidth = screenWidth * 0.5;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据设备类型决定布局方式
        if (isPortrait) {
          // 手机模式：使用覆盖式侧边栏
          return _buildMobileLayout(themeManager);
        } else {
          // 平板模式：使用并排式布局
          return _buildTabletLayout(themeManager, tabletSidebarWidth);
        }
      },
    );
  }

  Widget _buildMobileLayout(ThemeManager themeManager) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxSidebarWidth = screenWidth * 0.85; // 限制最大宽度为屏幕的85%
    
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
          
          // 侧边栏内容 - 限制最大宽度
          Positioned.fill(
            child: Align(
              alignment: widget.isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxSidebarWidth,
                  minWidth: 0,
                ),
                child: _buildSidebarContent(true),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabletLayout(ThemeManager themeManager, double sidebarWidth) {
    return Row(
      children: [
        // 主内容区域
        Expanded(
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(
              left: widget.isLeft && _isOpen ? sidebarWidth : 0,
              right: !widget.isLeft && _isOpen ? sidebarWidth : 0,
            ),
            child: widget.child,
          ),
        ),
        
        // 侧边栏区域
        if (_isOpen) ...[
          // 侧边栏容器 - 限制最大宽度避免溢出
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: sidebarWidth,
              minWidth: 0,
            ),
            child: AnimatedContainer(
              duration: widget.animationDuration,
              curve: Curves.easeInOut,
              width: _isOpen ? sidebarWidth : 0,
              child: _buildSidebarContent(false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSidebarContent(bool isMobile) {
    final themeManager = ThemeManager();
    
    return Container(
      color: widget.backgroundColor ?? themeManager.lighterColor,
      child: widget.child ?? Center(
        child: Text(
          '侧边栏内容',
          style: TextStyle(
            color: themeManager.darkTextColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

