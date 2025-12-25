import 'package:flutter/material.dart';
import '../shared/tabs.dart'; // 导入tabs组件
import '../../services/suggestion_settings_service.dart';

class AIGenerationPanel extends StatefulWidget {
  final bool isVisible;
  final Function(String) onSuggestionSelected;
  final VoidCallback onClose;
  final List<String> suggestionKeywords; // 来自后端的建议关键词
  final List<String> responseSuggestions; // 来自后端的LLM响应建议
  final Function(String) onUserModification; // 发送用户修改意见
  final Function(String) onScenarioSupplement; // 发送情景补充
  final bool llmResponseSameScreen; // 是否启用同屏模式
  final bool clickToSwitch; // 是否点击后自动切换到LLM响应标签页

  const AIGenerationPanel({
    super.key,
    required this.isVisible,
    required this.onSuggestionSelected,
    required this.onClose,
    this.suggestionKeywords = const ['暂未生成'], // 默认值
    this.responseSuggestions = const [], // 默认值
    required this.onUserModification,
    required this.onScenarioSupplement,
    this.llmResponseSameScreen = false, // 默认不启用同屏模式
    this.clickToSwitch = false, // 默认不启用点击切换
  });

  @override
  State<AIGenerationPanel> createState() => _AIGenerationPanelState();
}

class _AIGenerationPanelState extends State<AIGenerationPanel> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  List<String> _defaultSuggestions = [];
  bool _isLoadingSuggestions = true;
  
  // Tab controller for switching between tabs when needed
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    if (widget.isVisible) {
      _animationController.forward();
    }
    _loadDefaultSuggestions();
  }

  Future<void> _loadDefaultSuggestions() async {
    try {
      final suggestions = await SuggestionSettingsService.getDefaultSuggestions();
      setState(() {
        _defaultSuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      // 静默处理错误，避免影响用户体验
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void didUpdateWidget(AIGenerationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(MediaQuery.of(context).size.width * _slideAnimation.value, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              width: MediaQuery.of(context).size.width, // 横向扩展到整个屏幕
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AI 生成',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                  
                  // 根据同屏模式决定显示内容
                  Expanded(
                    child: widget.llmResponseSameScreen 
                      ? _buildUnifiedContent()  // 同屏模式：无标签页，直接显示内容
                      : _buildTabbedContent(), // 标签页模式
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建AI助手标签页内容 - 包含建议生成和情景补充
  Widget _buildAIAssistantContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 建议按钮 - 水平滚动布局
          _buildSuggestionSection(),
          
          const SizedBox(height: 16),
          
          // 情景补充 - 水平滚动布局
          _buildScenarioSection(),
        ],
      ),
    );
  }

  // 构建LLM响应部分（用于同屏模式）
  Widget _buildLLMResponseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LLM响应处理',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.responseSuggestions.isEmpty)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '等待生成中...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '请输入您的意见或点击手动生成按钮',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          )
        else ...[
          const Text(
            '收到的建议:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // 建议按钮列表 - 垂直排列
          ...widget.responseSuggestions.map((suggestion) => 
            Column(
              children: [
                _buildLLMSuggestionButton(suggestion),
                const SizedBox(height: 8),
              ],
            )
          ),
        ],
      ],
    );
  }

  // 构建LLM响应标签页内容 - 标题和建议一起滚动
  Widget _buildLLMResponseContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LLM响应处理',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.responseSuggestions.isEmpty)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '等待生成中...',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.orange,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '请输入您的意见或点击手动生成按钮',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            )
          else ...[
            const Text(
              '收到的建议:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            // 建议按钮列表 - 垂直排列
            ...widget.responseSuggestions.map((suggestion) => 
              Column(
                children: [
                  _buildLLMSuggestionButton(suggestion),
                  const SizedBox(height: 8),
                ],
              )
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionSection() {
    // 合并后端返回的建议（在前）和默认建议（在后），去重
    final allSuggestions = <String>[];
    
    // 先添加后端返回的建议
    for (final suggestion in widget.suggestionKeywords) {
      if (!allSuggestions.contains(suggestion)) {
        allSuggestions.add(suggestion);
      }
    }
    
    // 再添加默认建议（如果还没有的话）
    for (final suggestion in _defaultSuggestions) {
      if (!allSuggestions.contains(suggestion)) {
        allSuggestions.add(suggestion);
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '建议意见',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        // 水平滚动的建议按钮
        SizedBox(
          height: 40,
          child: _isLoadingSuggestions
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allSuggestions.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index < allSuggestions.length - 1 ? 8 : 0),
                      child: _buildSuggestionButton(allSuggestions[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScenarioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '情景补充',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        // 水平滚动的情景按钮
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildScenarioButton('在讨论中'),
              const SizedBox(width: 8),
              _buildScenarioButton('在辩论中'),
              const SizedBox(width: 8),
              _buildScenarioButton('在咨询中'),
              const SizedBox(width: 8),
              _buildScenarioButton('在学习中'),
              const SizedBox(width: 8),
              _buildScenarioButton('在工作'),
              const SizedBox(width: 8),
              _buildScenarioButton('在娱乐中'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLLMSuggestionButton(String text) {
    return ElevatedButton(
      onPressed: () {
        // LLM响应建议，直接追加到输入框
        widget.onSuggestionSelected(text);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSuggestionButton(String text) {
    return ElevatedButton(
      onPressed: () {
        // AI助手建议，发送用户修改意见
        widget.onUserModification(text);
        
        // 如果在标签页模式下且启用了点击切换，则切换到LLM响应标签页
        if (!widget.llmResponseSameScreen && widget.clickToSwitch) {
          // 在标签页模式下，需要切换到LLM响应标签页 (索引为1)
          setState(() {
            _currentTabIndex = 1;
          });
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildScenarioButton(String text) {
    return ElevatedButton(
      onPressed: () {
        // 发送情景补充消息到后端
        widget.onScenarioSupplement(text);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // 构建统一内容视图（同屏模式）
  Widget _buildUnifiedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 建议按钮 - 水平滚动布局
          _buildSuggestionSection(),
          
          const SizedBox(height: 16),
          
          // LLM响应部分 - 显示在建议和情景之间
          _buildLLMResponseSection(),
          
          const SizedBox(height: 16),
          
          // 情景补充 - 水平滚动布局
          _buildScenarioSection(),
        ],
      ),
    );
  }

  // 构建标签页内容（传统模式）
  Widget _buildTabbedContent() {
    // 使用Column和TabBar/TabBarView实现可控制的标签页
    return Column(
      children: [
        // 自定义标签栏
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentTabIndex = 0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _currentTabIndex == 0 
                        ? Theme.of(context).primaryColor 
                        : Colors.transparent,
                      border: Border(
                        right: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: _currentTabIndex == 0 
                            ? Colors.white 
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI助手',
                          style: TextStyle(
                            color: _currentTabIndex == 0 
                              ? Colors.white 
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentTabIndex = 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _currentTabIndex == 1 
                        ? Theme.of(context).primaryColor 
                        : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.data_object,
                          size: 18,
                          color: _currentTabIndex == 1 
                            ? Colors.white 
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LLM响应',
                          style: TextStyle(
                            color: _currentTabIndex == 1 
                              ? Colors.white 
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 标签页内容
        Expanded(
          child: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildAIAssistantContent(),
              _buildLLMResponseContent(),
            ],
          ),
        ),
      ],
    );
  }
}