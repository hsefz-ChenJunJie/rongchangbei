import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/services/theme_manager.dart';
import 'package:ai_sound_agent/services/dp_download_manager.dart';
import 'package:ai_sound_agent/services/dp_manager.dart';
import 'package:ai_sound_agent/app/route.dart';

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
  final DPDownloadManager _downloadManager = DPDownloadManager();
  List<OnlineResource> _onlineResources = [];
  final List<String> _downloadedOnlineFiles = [];
  bool _isLoadingOnline = false;
  String _onlineSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOnlineResources();
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

      // 刷新DPManager的文件列表
      final dpManager = DPManager();
      await dpManager.refreshDpFileList();

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
    
    return _buildOnlinePackagesSection(themeColor);
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
              TextButton.icon(
                icon: const Icon(Icons.folder, size: 18),
                label: const Text('local'),
                onPressed: () {
                  Navigator.pushNamed(context, Routes.manageLocalDpFile);
                },
              ),
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