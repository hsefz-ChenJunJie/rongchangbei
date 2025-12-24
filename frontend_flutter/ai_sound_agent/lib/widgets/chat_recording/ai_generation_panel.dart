import 'package:flutter/material.dart';

class AIGenerationPanel extends StatefulWidget {
  final bool isVisible;
  final Function(String) onSuggestionSelected;
  final VoidCallback onClose;

  const AIGenerationPanel({
    Key? key,
    required this.isVisible,
    required this.onSuggestionSelected,
    required this.onClose,
  }) : super(key: key);

  @override
  State<AIGenerationPanel> createState() => _AIGenerationPanelState();
}

class _AIGenerationPanelState extends State<AIGenerationPanel> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

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
                    color: Colors.black.withOpacity(0.1),
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
                  
                  // 内容区域 - 使用Flexible避免无限高度约束问题
                  Flexible(
                    child: SingleChildScrollView(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionSection() {
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
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSuggestionButton('表达同意'),
              const SizedBox(width: 8),
              _buildSuggestionButton('表示反对'),
              const SizedBox(width: 8),
              _buildSuggestionButton('提出质疑'),
              const SizedBox(width: 8),
              _buildSuggestionButton('表示困惑'),
              const SizedBox(width: 8),
              _buildSuggestionButton('表示理解'),
              const SizedBox(width: 8),
              _buildSuggestionButton('继续深入'),
              const SizedBox(width: 8),
              _buildSuggestionButton('转换话题'),
              const SizedBox(width: 8),
              _buildSuggestionButton('总结要点'),
            ],
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
          height: 50,
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
              _buildScenarioButton('在工作中'),
              const SizedBox(width: 8),
              _buildScenarioButton('在娱乐中'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionButton(String text) {
    return ElevatedButton(
      onPressed: () => widget.onSuggestionSelected(text),
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

  Widget _buildScenarioButton(String text) {
    return ElevatedButton(
      onPressed: () => widget.onSuggestionSelected(text),
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
}