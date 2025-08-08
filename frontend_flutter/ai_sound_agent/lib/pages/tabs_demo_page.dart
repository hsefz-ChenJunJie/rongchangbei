import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/shared/tabs.dart';

/// Tab组件演示页面
class TabsDemoPage extends BasePage {
  const TabsDemoPage({super.key})
      : super(
          title: 'Tab组件演示',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _TabsDemoPageState createState() => _TabsDemoPageState();
}

class _TabsDemoPageState extends BasePageState<TabsDemoPage> {
  @override
  Widget buildContent(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tab组件演示',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              '点击下方按钮查看不同类型的Tab组件',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            TabsDemoButtons(),
          ],
        ),
      ),
    );
  }
}

/// Tab演示按钮组
class TabsDemoButtons extends StatelessWidget {
  const TabsDemoButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StandardTabsExample(),
              ),
            );
          },
          icon: const Icon(Icons.tab),
          label: const Text('标准Tab组件'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CardTabsExample(),
              ),
            );
          },
          icon: const Icon(Icons.crop_square),
          label: const Text('卡片式Tab组件'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SimpleTabsExample(),
              ),
            );
          },
          icon: const Icon(Icons.list),
          label: const Text('简化Tab组件'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdvancedTabsExample(),
              ),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('高级Tab组件'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// 标准Tab组件示例页面
class StandardTabsExample extends StatelessWidget {
  const StandardTabsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '全部',
        icon: Icons.list,
        content: const TabContentView(
          title: '全部项目',
          items: ['项目1', '项目2', '项目3', '项目4', '项目5'],
          color: Colors.blue,
        ),
      ),
      TabConfig(
        label: '进行中',
        icon: Icons.timelapse,
        content: const TabContentView(
          title: '进行中项目',
          items: ['项目A', '项目B'],
          color: Colors.orange,
        ),
        badgeText: '2',
        badgeColor: Colors.orange,
      ),
      TabConfig(
        label: '已完成',
        icon: Icons.check_circle,
        content: const TabContentView(
          title: '已完成项目',
          items: ['项目X', '项目Y', '项目Z'],
          color: Colors.green,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('标准Tab组件'),
      ),
      body: CustomTabs(
        tabs: tabs,
        initialIndex: 0,
        onTabChanged: (index) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('切换到: ${tabs[index].label}')),
          );
        },
      ),
    );
  }
}

/// 卡片式Tab组件示例页面
class CardTabsExample extends StatelessWidget {
  const CardTabsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '图表',
        icon: Icons.bar_chart,
        content: const Center(child: Text('图表内容区域')),
      ),
      TabConfig(
        label: '数据',
        icon: Icons.table_chart,
        content: const Center(child: Text('数据内容区域')),
      ),
      TabConfig(
        label: '分析',
        icon: Icons.analytics,
        content: const Center(child: Text('分析内容区域')),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片式Tab组件'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CardTabs(
          tabs: tabs,
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          onTabChanged: (index) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('卡片Tab切换到: ${tabs[index].label}')),
            );
          },
        ),
      ),
    );
  }
}

/// 简化Tab组件示例页面
class SimpleTabsExample extends StatelessWidget {
  const SimpleTabsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简化Tab组件'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SimpleTabs(
          tabs: {
            '新闻': const ContentListView(
              title: '新闻',
              items: ['头条新闻', '科技新闻', '体育新闻', '娱乐新闻'],
              icon: Icons.article,
            ),
            '视频': const ContentListView(
              title: '视频',
              items: ['热门视频', '推荐视频', '最新视频'],
              icon: Icons.video_library,
            ),
            '音乐': const ContentListView(
              title: '音乐',
              items: ['流行歌曲', '经典老歌', '新歌推荐'],
              icon: Icons.music_note,
            ),
          },
          onTabChanged: (index) {
            final labels = ['新闻', '视频', '音乐'];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('简化Tab切换到: ${labels[index]}')),
            );
          },
        ),
      ),
    );
  }
}

/// 高级Tab组件示例页面
class AdvancedTabsExample extends StatelessWidget {
  const AdvancedTabsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '产品管理',
        icon: Icons.shopping_bag,
        content: const ProductManagementView(),
      ),
      TabConfig(
        label: '订单管理',
        icon: Icons.receipt,
        content: const OrderManagementView(),
      ),
      TabConfig(
        label: '用户管理',
        icon: Icons.people,
        content: const UserManagementView(),
      ),
      TabConfig(
        label: '数据统计',
        icon: Icons.dashboard,
        content: const StatisticsView(),
      ),
      TabConfig(
        label: '系统设置',
        icon: Icons.settings,
        content: const SettingsView(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('高级Tab组件'),
      ),
      body: CustomTabs(
        tabs: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.purple,
        labelColor: Colors.purple,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        onTabChanged: (index) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('高级Tab切换到: ${tabs[index].label}')),
          );
        },
      ),
    );
  }
}

/// 通用内容展示组件
class TabContentView extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const TabContentView({
    super.key,
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text('${index + 1}'),
            ),
            title: Text(items[index]),
            subtitle: Text('$title - 项目 ${index + 1}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('点击了: ${items[index]}')),
              );
            },
          ),
        );
      },
    );
  }
}

/// 内容列表组件
class ContentListView extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;

  const ContentListView({
    super.key,
    required this.title,
    required this.items,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(icon, color: Theme.of(context).primaryColor),
          title: Text(items[index]),
          subtitle: Text('$title分类'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('查看$title: ${items[index]}')),
            );
          },
        );
      },
    );
  }
}

/// 产品管理视图
class ProductManagementView extends StatelessWidget {
  const ProductManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16.0),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: List.generate(6, (index) {
        return Card(
          elevation: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag, size: 48, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text('产品 ${index + 1}'),
              const SizedBox(height: 4),
              Text('¥${(index + 1) * 100}'),
            ],
          ),
        );
      }),
    );
  }
}

/// 订单管理视图
class OrderManagementView extends StatelessWidget {
  const OrderManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.receipt, color: Colors.white),
            ),
            title: Text('订单 #${1000 + index}'),
            subtitle: Text('日期: 2024-01-${index + 1}'),
            trailing: Text('¥${(index + 1) * 200}'),
          ),
        );
      },
    );
  }
}

/// 用户管理视图
class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.primaries[index % Colors.primaries.length],
              child: Text('U${index + 1}'),
            ),
            title: Text('用户 ${index + 1}'),
            subtitle: Text('user${index + 1}@example.com'),
            trailing: const Icon(Icons.email),
          ),
        );
      },
    );
  }
}

/// 统计视图
class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16.0),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('销售额', '¥12,345', Icons.trending_up, Colors.green),
        _buildStatCard('订单数', '156', Icons.shopping_cart, Colors.blue),
        _buildStatCard('用户数', '2,847', Icons.people, Colors.orange),
        _buildStatCard('转化率', '12.5%', Icons.analytics, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// 设置视图
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const ListTile(
          title: Text('系统设置'),
          subtitle: Text('配置系统参数'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('通知设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('打开通知设置')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('安全设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('打开安全设置')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.color_lens),
          title: const Text('主题设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('打开主题设置')),
            );
          },
        ),
      ],
    );
  }
}