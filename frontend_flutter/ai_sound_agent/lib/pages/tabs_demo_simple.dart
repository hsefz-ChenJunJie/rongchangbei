import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/shared/tabs_fixed.dart';

/// 简化的Tab组件演示页面
class TabsDemoSimple extends BasePage {
  const TabsDemoSimple({super.key})
      : super(
          title: 'Tab组件演示',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _TabsDemoSimpleState createState() => _TabsDemoSimpleState();
}

class _TabsDemoSimpleState extends BasePageState<TabsDemoSimple> {
  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tab组件演示',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            '轻量级Tab组件，避免内存泄漏',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          
          // 标准Tab组件
          _buildSectionTitle('标准Tab组件'),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildStandardTabs(),
          ),
          const SizedBox(height: 30),

          // 卡片式Tab组件
          _buildSectionTitle('卡片式Tab组件'),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildCardTabs(),
          ),
          const SizedBox(height: 30),

          // 简化Tab组件
          _buildSectionTitle('简化Tab组件'),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildSimpleTabs(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStandardTabs() {
    final tabs = [
      TabConfig(
        label: '全部',
        icon: Icons.list,
        content: const ContentView(
          title: '全部项目',
          items: ['项目1', '项目2', '项目3'],
          color: Colors.blue,
        ),
      ),
      TabConfig(
        label: '进行中',
        icon: Icons.timelapse,
        content: const ContentView(
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
        content: const ContentView(
          title: '已完成项目',
          items: ['项目X', '项目Y'],
          color: Colors.green,
        ),
      ),
    ];

    return LightweightTabs(
      tabs: tabs,
      onTabChanged: (index) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换到: ${tabs[index].label}')),
        );
      },
    );
  }

  Widget _buildCardTabs() {
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

    return LightweightCardTabs(
      tabs: tabs,
      onTabChanged: (index) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('卡片Tab切换到: ${tabs[index].label}')),
        );
      },
    );
  }

  Widget _buildSimpleTabs() {
    final tabs = [
      TabConfig(
        label: '新闻',
        content: const ContentListView(
          title: '新闻',
          items: ['头条新闻', '科技新闻', '体育新闻'],
          icon: Icons.article,
        ),
      ),
      TabConfig(
        label: '视频',
        content: const ContentListView(
          title: '视频',
          items: ['热门视频', '推荐视频'],
          icon: Icons.video_library,
        ),
      ),
      TabConfig(
        label: '音乐',
        content: const ContentListView(
          title: '音乐',
          items: ['流行歌曲', '经典老歌'],
          icon: Icons.music_note,
        ),
      ),
    ];

    return LightweightTabs(
      tabs: tabs,
      onTabChanged: (index) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('简化Tab切换到: ${tabs[index].label}')),
        );
      },
    );
  }
}

/// 内容视图组件
class ContentView extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const ContentView({
    Key? key,
    required this.title,
    required this.items,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(Icons.circle, color: color, size: 12),
          title: Text('${items[index]}'),
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
    Key? key,
    required this.title,
    required this.items,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text('${items[index]}'),
        );
      },
    );
  }
}