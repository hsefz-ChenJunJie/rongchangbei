import 'package:flutter/material.dart';
import 'package:idialogue/widgets/shared/base.dart';
import 'package:idialogue/services/dp_manager.dart';
import 'package:idialogue/services/theme_manager.dart';

class ManageLocalDpFilePage extends BasePage {
  const ManageLocalDpFilePage({super.key})
      : super(
          title: '本地对话包管理',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  _ManageLocalDpFilePageState createState() => _ManageLocalDpFilePageState();
}

class _ManageLocalDpFilePageState extends BasePageState<ManageLocalDpFilePage> {
  final DPManager _dpManager = DPManager();
  List<DialoguePackage> _dialoguePackages = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDialoguePackages();
  }

  Future<void> _loadDialoguePackages() async {
    try {
      await _dpManager.init();
      final packageNames = await _dpManager.refreshDpFileList();
      
      final packages = <DialoguePackage>[];
      for (final name in packageNames) {
        try {
          final package = await _dpManager.getDp(name);
          packages.add(package);
        } catch (e) {
          debugPrint('加载对话包失败: $name - $e');
        }
      }
      
      setState(() {
        _dialoguePackages = packages;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('初始化DPManager失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDialoguePackage(String fileName) async {
    if (fileName == 'default') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('不能删除默认对话包')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除对话包 "$fileName" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dpManager.deleteDp(fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('对话包已删除')),
          );
        }
        await _loadDialoguePackages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  List<DialoguePackage> get _filteredPackages {
    if (_searchQuery.isEmpty) return _dialoguePackages;
    
    return _dialoguePackages.where((package) {
      return package.packageName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             package.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             package.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget buildContent(BuildContext context) {
    final themeColor = ThemeManager().baseColor;
    
    return Column(
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                '本地对话包',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDialoguePackages,
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        
        // 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索本地对话包...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 对话包列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPackages.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty 
                            ? '暂无对话包'
                            : '未找到匹配的对话包',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPackages.length,
                      itemBuilder: (context, index) {
                        final package = _filteredPackages[index];
                        return _buildDialoguePackageCard(package);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDialoguePackageCard(DialoguePackage package) {
    final themeColor = ThemeManager().baseColor;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.packageName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.fileName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description.isEmpty ? '暂无描述' : package.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (package.fileName != 'default')
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteDialoguePackage(package.fileName),
                tooltip: '删除',
              ),
          ],
        ),
      ),
    );
  }
}