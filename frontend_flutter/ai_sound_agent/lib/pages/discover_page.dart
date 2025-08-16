import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/services/dp_manager.dart';
import 'package:ai_sound_agent/services/theme_manager.dart';
import 'package:ai_sound_agent/services/dp_download_manager.dart';

class DiscoverPage extends BasePage {
  const DiscoverPage({super.key})
      : super(
          title: '发现',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _DiscoverPageState createState() => _DiscoverPageState();
}

class _DiscoverPageState extends BasePageState<DiscoverPage> {
  final DPManager _dpManager = DPManager();
  final DPDownloadManager _downloadManager = DPDownloadManager();
  List<DialoguePackage> _dialoguePackages = [];
  List<OnlineResource> _onlineResources = [];
  List<String> _downloadedOnlineFiles = [];
  bool _isLoading = false;
  bool _isLoadingOnline = false;
  String _searchQuery = '';
  String _onlineSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDialoguePackages();
    _loadOnlineResources();
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

  Future<void> _loadOnlineResources() async {
    try {
      setState(() => _isLoadingOnline = true);
      
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('正在获取在线资源...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      
      final resources = await _downloadManager.fetchOnlineResources();
      final downloadedFiles = await _downloadManager.getDownloadedOnlinePackages();
      
      if (mounted) {
        // 清除加载提示
        ScaffoldMessenger.of(context).clearSnackBars();
        
        setState(() {
          _onlineResources = resources;
          _downloadedOnlineFiles.clear();
          _downloadedOnlineFiles.addAll(downloadedFiles);
          _isLoadingOnline = false;
        });
        
        if (resources.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无在线资源')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOnline = false);
        // 清除加载提示
        ScaffoldMessenger.of(context).clearSnackBars();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取在线资源失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  List<OnlineResource> get _filteredOnlineResources {
    if (_onlineSearchQuery.isEmpty) return _onlineResources;
    
    return _onlineResources.where((resource) {
      return resource.packageName.toLowerCase().contains(_onlineSearchQuery.toLowerCase()) ||
             resource.fileName.toLowerCase().contains(_onlineSearchQuery.toLowerCase()) ||
             resource.description.toLowerCase().contains(_onlineSearchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _downloadOnlineResource(OnlineResource resource) async {
    try {
      setState(() => _isLoadingOnline = true);

      // 显示下载进度提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('正在下载 ${resource.packageName}...'),
              ],
            ),
            duration: const Duration(minutes: 1), // 较长的持续时间
          ),
        );
      }

      await _downloadManager.downloadDialoguePackage(
        resource.url,
        resource.fileName,
        expectedHash: resource.sha256,
      );

      final downloadedFiles = await _downloadManager.getDownloadedOnlinePackages();
      if (mounted) {
        // 清除下载提示
        ScaffoldMessenger.of(context).clearSnackBars();
        
        setState(() {
          _downloadedOnlineFiles.clear();
          _downloadedOnlineFiles.addAll(downloadedFiles);
          _isLoadingOnline = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${resource.packageName} 下载成功'),
            backgroundColor: Colors.green,
          ),
        );

        // 重新加载本地对话包列表
        await _loadDialoguePackages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOnline = false);
        // 清除下载提示
        ScaffoldMessenger.of(context).clearSnackBars();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  int getInitialBottomNavIndex() => 1; // 发现页索引为1
  
  @override
  Widget buildContent(BuildContext context) {
    final themeColor = ThemeManager().baseColor;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        
        return isWideScreen
            ? _buildWideScreenLayout(themeColor)
            : _buildNarrowScreenLayout(themeColor);
      },
    );
  }

  Widget _buildWideScreenLayout(Color themeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildLocalPackagesSection(themeColor),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _buildOnlinePackagesSection(themeColor),
        ),
      ],
    );
  }

  Widget _buildNarrowScreenLayout(Color themeColor) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: '本地对话包'),
              Tab(text: '在线对话包'),
            ],
            indicatorColor: themeColor,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLocalPackagesSection(themeColor),
                _buildOnlinePackagesSection(themeColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalPackagesSection(Color themeColor) {
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
                        return _buildDialoguePackageCard(package, false);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOnlinePackagesSection(Color themeColor) {
    return Column(
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                '在线对话包',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadOnlineResources,
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
              hintText: '搜索在线对话包...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _onlineSearchQuery = value;
              });
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 对话包列表
        Expanded(
          child: _isLoadingOnline
              ? const Center(child: CircularProgressIndicator())
              : _filteredOnlineResources.isEmpty
                  ? Center(
                      child: Text(
                        _onlineSearchQuery.isEmpty 
                            ? '暂无在线对话包'
                            : '未找到匹配的在线对话包',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredOnlineResources.length,
                      itemBuilder: (context, index) {
                        final resource = _filteredOnlineResources[index];
                        return _buildOnlineResourceCard(resource);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDialoguePackageCard(DialoguePackage package, bool isWideScreen) {
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

  Widget _buildOnlineResourceCard(OnlineResource resource) {
    final themeColor = ThemeManager().baseColor;
    final isDownloaded = _downloadedOnlineFiles.contains(resource.fileName);
    
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
                    resource.packageName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resource.fileName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resource.description,
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
            if (isDownloaded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.check_circle, color: Colors.green, size: 24),
              )
            else
              IconButton(
                icon: const Icon(Icons.download, color: Colors.blue),
                onPressed: () => _downloadOnlineResource(resource),
                tooltip: '下载',
              ),
          ],
        ),
      ),
    );
  }
}