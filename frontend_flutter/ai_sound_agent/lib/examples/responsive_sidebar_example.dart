import 'package:flutter/material.dart';
import '../widgets/shared/responsive_sidebar.dart';
import '../services/theme_manager.dart';

class ResponsiveSidebarExample extends StatefulWidget {
  const ResponsiveSidebarExample({super.key});

  @override
  State<ResponsiveSidebarExample> createState() => _ResponsiveSidebarExampleState();
}

class _ResponsiveSidebarExampleState extends State<ResponsiveSidebarExample> {
  final GlobalKey<ResponsiveSidebarState> _sidebarKey = GlobalKey<ResponsiveSidebarState>();

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('响应式侧边栏示例'),
        backgroundColor: themeManager.baseColor,
        foregroundColor: themeManager.lightTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _sidebarKey.currentState?.open();
            },
            tooltip: '打开侧边栏',
          ),
        ],
      ),
      body: ResponsiveSidebar(
        key: _sidebarKey,
        backgroundColor: themeManager.lighterColor,
        barrierColor: themeManager.darkerColor.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '主内容区域',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeManager.darkTextColor,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.baseColor,
                  foregroundColor: themeManager.lightTextColor,
                ),
                onPressed: () {
                  final isOpen = _sidebarKey.currentState?.isOpen() ?? false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isOpen ? '侧边栏已打开' : '侧边栏已关闭'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('检查侧边栏状态'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.darkerColor,
                  foregroundColor: themeManager.lightTextColor,
                ),
                onPressed: () {
                  _sidebarKey.currentState?.toggle();
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('切换侧边栏'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.baseColor.withOpacity(0.8),
                  foregroundColor: themeManager.lightTextColor,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RightSidebarExample(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('从右边滑出示例'),
              ),
              const SizedBox(height: 40),
              Card(
                color: themeManager.lighterColor.withOpacity(0.1),
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.screen_rotation,
                        size: 48,
                        color: themeManager.baseColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '响应式设计',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeManager.darkTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '旋转设备查看不同屏幕尺寸下的效果',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: themeManager.darkTextColor.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _sidebarKey.currentState?.open();
        },
        child: const Icon(Icons.menu_open),
        tooltip: '打开侧边栏',
      ),
    );
  }
}

// 从右边滑出的示例
class RightSidebarExample extends StatefulWidget {
  const RightSidebarExample({super.key});

  @override
  State<RightSidebarExample> createState() => _RightSidebarExampleState();
}

class _RightSidebarExampleState extends State<RightSidebarExample> {
  final GlobalKey<ResponsiveSidebarState> _sidebarKey = GlobalKey<ResponsiveSidebarState>();

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('右边侧边栏示例'),
        backgroundColor: themeManager.baseColor,
        foregroundColor: themeManager.lightTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _sidebarKey.currentState?.open();
            },
            tooltip: '打开右边侧边栏',
          ),
        ],
      ),
      body: ResponsiveSidebar(
        key: _sidebarKey,
        isLeft: false, // 从右边滑出
        backgroundColor: themeManager.lighterColor,
        barrierColor: themeManager.darkerColor.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '主内容区域',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeManager.darkTextColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '侧边栏将从右边滑出',
                style: TextStyle(
                  fontSize: 16,
                  color: themeManager.baseColor,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.baseColor,
                  foregroundColor: themeManager.lightTextColor,
                ),
                onPressed: () {
                  final isOpen = _sidebarKey.currentState?.isOpen() ?? false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isOpen ? '右边侧边栏已打开' : '右边侧边栏已关闭'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('检查状态'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.darkerColor,
                  foregroundColor: themeManager.lightTextColor,
                ),
                onPressed: () {
                  _sidebarKey.currentState?.open();
                },
                icon: const Icon(Icons.menu_open),
                label: const Text('打开右边侧边栏'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _sidebarKey.currentState?.open();
        },
        backgroundColor: themeManager.baseColor,
        foregroundColor: themeManager.lightTextColor,
        child: const Icon(Icons.menu_open),
        tooltip: '打开右边侧边栏',
      ),
    );
  }
}

// 侧边栏内容组件
class SidebarContent extends StatelessWidget {
  const SidebarContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('用户名称'),
          accountEmail: Text('user@example.com'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, color: Colors.white),
          ),
          decoration: BoxDecoration(
            color: Colors.blue,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('首页'),
          onTap: () {
            // 处理导航
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('设置'),
          onTap: () {
            // 处理导航
          },
        ),
        ListTile(
          leading: const Icon(Icons.help),
          title: const Text('帮助'),
          onTap: () {
            // 处理导航
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退出'),
          onTap: () {
            // 处理退出
          },
        ),
      ],
    );
  }
}

// 完整的侧边栏使用示例
class ResponsiveSidebarDemo extends StatelessWidget {
  const ResponsiveSidebarDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ResponsiveSidebarState> sidebarKey = GlobalKey<ResponsiveSidebarState>();

    return MaterialApp(
      title: '响应式侧边栏演示',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: ResponsiveSidebar(
          key: sidebarKey,
          backgroundColor: Colors.white,
          barrierColor: Colors.black54,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('完整演示'),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => sidebarKey.currentState?.open(),
              ),
            ),
            body: const Center(
              child: Text(
                '这是一个完整的响应式侧边栏演示',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => sidebarKey.currentState?.open(),
          child: const Icon(Icons.menu_open),
        ),
      ),
    );
  }
}