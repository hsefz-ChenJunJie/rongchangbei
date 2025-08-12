import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/app/route.dart';
import 'package:ai_sound_agent/pages/device_test_page.dart';
import 'package:ai_sound_agent/pages/tabs_demo_simple.dart';
import 'package:ai_sound_agent/pages/main_processing.dart';
import 'package:ai_sound_agent/pages/chat_test_page.dart';
import 'package:ai_sound_agent/pages/chat_recording.dart';
import '../widgets/home_page/animation.dart';
import '../widgets/shared/base_elevated_button.dart';


class HomePage extends BasePage {
  const HomePage({super.key})
      : super(
          title: '首页',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage> {
  final List<String> _pageTitles = const [
    '首页',
    '发现',
    '我的',
  ];

  int _currentPageIndex = 0;

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 顶部动画区域
          Column(
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: const SineWaveAnimation(),
              ),
              const SizedBox(height: 16),
              Text(
                '倾听，思考，回应——让对话从未如此流畅',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '实时语音识别 + AI对话建议 + 自然语音合成',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),

          // 功能卡片区域
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 快速开始 - 独占一行
                _buildFeatureCard(
                  context: context,
                  icon: Icons.play_arrow,
                  title: '快速开始',
                  subtitle: '立即体验语音处理功能',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainProcessingPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // 记录聊天和设备设置 - 同一行
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        context: context,
                        icon: Icons.chat,
                        title: '记录聊天',
                        subtitle: '记录并管理对话内容',
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatRecordingPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFeatureCard(
                        context: context,
                        icon: Icons.settings,
                        title: '设备设置',
                        subtitle: '配置音频设备和参数',
                        color: Theme.of(context).colorScheme.tertiary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceTestPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onPageChange(int index) {
    super.onPageChange(index);
    setState(() {
      _currentPageIndex = index;
    });
  }

  // 使用默认的底部导航栏（来自constants.dart）
  // 如需自定义，可以重写此方法
}
