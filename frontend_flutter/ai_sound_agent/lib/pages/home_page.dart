import 'package:flutter/material.dart';
import 'package:idialogue/widgets/shared/base.dart';
import 'package:idialogue/widgets/home_page/animation.dart';
import 'package:idialogue/widgets/shared/base_elevated_button.dart';
import 'package:idialogue/widgets/shared/base_text_area.dart';
import 'package:idialogue/services/dp_manager.dart';

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

class _HomePageState extends BasePageState<HomePage> with WidgetsBindingObserver {
  @override
  int getInitialBottomNavIndex() => 0; // 首页索引为0
  final TextEditingController _dialogueController = TextEditingController();
  final DPManager _dpManager = DPManager();
  List<DialoguePackage> _recommendedPackages = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendedPackages();
    // 监听应用生命周期状态变化
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _dialogueController.dispose();
    // 移除生命周期监听器
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 监听应用生命周期状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用恢复到前台时，重新加载对话包列表
    if (state == AppLifecycleState.resumed) {
      _loadRecommendedPackages();
    }
  }





  Future<void> _loadRecommendedPackages() async {
    try {
      await _dpManager.init();
      final dpFiles = _dpManager.getAvailableDpFiles();
      final nonCurrentFiles = dpFiles.where((name) => name != 'current').toList();
      
      if (nonCurrentFiles.isNotEmpty) {
        nonCurrentFiles.shuffle();
        final selectedNames = nonCurrentFiles.take(3).toList();
        
        final packages = <DialoguePackage>[];
        for (final name in selectedNames) {
          try {
            final package = await _dpManager.getDp(name);
            packages.add(package);
          } catch (e) {
            // 如果某个包加载失败，跳过它
          }
        }
        
        setState(() {
          _recommendedPackages = packages;
        });
      } else {
        // 如果没有找到对话包，使用示例数据
        _loadSamplePackages();
      }
    } catch (e) {
      // Web平台或其他错误，使用示例数据
      _loadSamplePackages();
    }
  }

  void _loadSamplePackages() {
    // 提供示例对话包数据
    final samplePackages = [
      DialoguePackage(
        type: 'dialogue_package',
        packageName: '商务谈判',
        fileName: 'business_negotiation',
        description: '模拟商务谈判场景，学习如何达成双赢协议',
        responseCount: 1,
        scenarioDescription: '模拟商务谈判场景，学习如何达成双赢协议',
        messages: [],
        modification: '',
        userOpinion: '',
        scenarioSupplement: '',
      ),
      DialoguePackage(
        type: 'dialogue_package',
        packageName: '面试技巧',
        fileName: 'interview_skills',
        description: '模拟求职面试，提升面试表现和沟通技巧',
        responseCount: 2,
        scenarioDescription: '模拟求职面试，提升面试表现和沟通技巧',
        messages: [],
        modification: '',
        userOpinion: '',
        scenarioSupplement: '',
      ),
      DialoguePackage(
        type: 'dialogue_package',
        packageName: '日常对话',
        fileName: 'daily_conversation',
        description: '日常生活对话练习，提高日常交流能力',
        responseCount: 3,
        scenarioDescription: '日常生活对话练习，提高日常交流能力',
        messages: [],
        modification: '',
        userOpinion: '',
        scenarioSupplement: '',
      ),
    ];
    
    setState(() {
      _recommendedPackages = samplePackages;
    });
  }

  Future<void> _prepareCurrentDialogue(String scenarioDescription) async {
    try {
      // 读取default.dp作为模板
      var defaultPackage = await _dpManager.getDefaultDp();
      
      // 创建新的current.dp，使用用户输入的场景描述和default的结构
      final currentPackage = DialoguePackage(
        type: defaultPackage.type,
        packageName: defaultPackage.packageName,
        fileName: 'current',
        description: defaultPackage.description,
        responseCount: defaultPackage.responseCount,
        scenarioDescription: scenarioDescription,
        messages: defaultPackage.messages,
        modification: defaultPackage.modification,
        userOpinion: defaultPackage.userOpinion,
        scenarioSupplement: defaultPackage.scenarioSupplement,
      );
      
      // 保存为current.dp
      await _dpManager.saveDp(currentPackage);
    } catch (e) {
      // 如果default.dp不存在，创建一个基础的current.dp
      final currentPackage = DialoguePackage(
        type: 'dialogue_package',
        packageName: '默认对话包',
        fileName: 'current',
        description: '',
        responseCount: 3,
        scenarioDescription: scenarioDescription,
        messages: [],
        modification: '',
        userOpinion: '',
        scenarioSupplement: '',
      );
      
      await _dpManager.saveDp(currentPackage);
    }
  }

  Future<void> _loadPackageToCurrent(String fileName) async {
    try {
      // 读取选中的dp文件
      final selectedPackage = await _dpManager.getDp(fileName);
      
      // 创建current.dp，使用选中包的内容，但保留原来的packageName
      final currentPackage = DialoguePackage(
        type: 'dialogue_package',
        packageName: selectedPackage.packageName,
        fileName: 'current',
        description: selectedPackage.description,
        responseCount: selectedPackage.responseCount,
        scenarioDescription: selectedPackage.scenarioDescription,
        messages: selectedPackage.messages,
        modification: selectedPackage.modification,
        userOpinion: selectedPackage.userOpinion,
        scenarioSupplement: selectedPackage.scenarioSupplement,
      );
      
      // 保存为current.dp
      await _dpManager.saveDp(currentPackage);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加载对话包: ${selectedPackage.packageName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载对话包失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 动画区域
          const SizedBox(height: 20),
          const Center(
            child: SizedBox(
              height: 150,
              child: SineWaveAnimation(),
            ),
          ),
          const SizedBox(height: 40),
          
          // 对话情景文本区域和按钮容器
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  BaseTextArea(
                    label: '对话情景',
                    placeholder: '请描述您的对话情景，例如：模拟面试、日常对话、商务谈判等...',
                    controller: _dialogueController,
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 300,
                  ),
                  const SizedBox(height: 24),
                  
                  // 即刻开始按钮
                  SizedBox(
                    width: double.infinity,
                    child: BaseElevatedButton.icon(
                      label: '即刻开始',
                      icon: const Icon(Icons.play_arrow),
                      expanded: true,
                      onPressed: () async {
                        // 处理开始对话的逻辑
                        final dialogueContext = _dialogueController.text.trim();
                        if (dialogueContext.isNotEmpty) {
                          try {
                            await _prepareCurrentDialogue(dialogueContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('正在准备对话环境...')),
                            );
                            // 跳转到main_processing.dart
                            Navigator.pushNamed(context, '/main-processing');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('创建对话失败: ${e.toString()}')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请先描述对话情景')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          // 猜你喜欢区域
          const Text(
            '猜你喜欢',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_recommendedPackages.isEmpty)
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: const Center(
                  child: Text(
                    '暂无推荐对话包',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendedPackages.length,
                itemBuilder: (context, index) {
                  final package = _recommendedPackages[index];
                  return InkWell(
                    onTap: () async {
                      // 处理卡片点击事件
                      await _loadPackageToCurrent(package.fileName);
                      // 跳转到main_processing.dart
                      Navigator.pushNamed(context, '/main-processing');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              package.packageName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                package.description.isNotEmpty ? package.description : package.scenarioDescription,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${package.fileName}.dp',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}



