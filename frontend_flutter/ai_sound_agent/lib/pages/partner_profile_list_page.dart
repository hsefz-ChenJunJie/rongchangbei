import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/partner_profile.dart';
import '../services/profile_manager.dart';
import '../services/partner_manager.dart';
import '../widgets/shared/base.dart';
import 'partner_profile_detail_page.dart';
import 'partner_profile_edit_page.dart';

/// 对话人档案列表页
class PartnerProfileListPage extends BasePage {
  const PartnerProfileListPage({super.key})
      : super(
          title: '档案管理',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  PartnerProfileListPageState createState() => PartnerProfileListPageState();
}

class PartnerProfileListPageState extends BasePageState<PartnerProfileListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<PartnerProfile> _allProfiles = [];
  List<PartnerProfile> _filteredProfiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profileManager = await ProfileManager.getInstance();
      final profiles = profileManager.getAllProfiles();
      
      // 获取对应的对话人信息以显示最近沟通时间
      final partnerManager = await PartnerManager.getInstance();
      final profilesWithPartnerInfo = await _enrichProfilesWithPartnerInfo(
        profiles, 
        partnerManager
      );

      if (mounted) {
        setState(() {
          _allProfiles = profilesWithPartnerInfo;
          _filteredProfiles = _sortProfilesByPinyin(profilesWithPartnerInfo);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载档案失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<PartnerProfile>> _enrichProfilesWithPartnerInfo(
    List<PartnerProfile> profiles,
    PartnerManager partnerManager,
  ) async {
    final enrichedProfiles = <PartnerProfile>[];
    
    for (final profile in profiles) {
      final partner = partnerManager.getPartnerById(profile.partnerId);
      if (partner != null) {
        enrichedProfiles.add(profile);
      }
    }
    
    return enrichedProfiles;
  }

  List<PartnerProfile> _sortProfilesByPinyin(List<PartnerProfile> profiles) {
    profiles.sort((a, b) {
      final aPinyin = _getFirstLetter(a.name);
      final bPinyin = _getFirstLetter(b.name);
      return aPinyin.compareTo(bPinyin);
    });
    return profiles;
  }

  String _getFirstLetter(String name) {
    try {
      if (name.isEmpty) return '#';
      
      final firstChar = name[0];
      final pinyin = PinyinHelper.getFirstWordPinyin(firstChar);
      
      if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(firstChar)) {
        return pinyin.isNotEmpty ? pinyin[0].toUpperCase() : '#';
      } else {
        return firstChar.toUpperCase();
      }
    } catch (e) {
      return '#';
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _filterProfiles();
      });
    }
  }

  void _filterProfiles() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredProfiles = _sortProfilesByPinyin(List.from(_allProfiles));
      });
    } else {
      final profileManager = await ProfileManager.getInstance();
      final results = profileManager.searchProfiles(_searchQuery);
      
      // 过滤出当前存在的档案
      final validResults = results.where((profile) => 
        _allProfiles.any((p) => p.id == profile.id)
      ).toList();
      
      setState(() {
        _filteredProfiles = _sortProfilesByPinyin(validResults);
      });
    }
  }

  void _performSearch() {
    _filterProfiles();
    _searchFocusNode.unfocus();
  }

  void _showCreateProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PartnerProfileEditPage(),
      ),
    ).then((_) => _loadProfiles());
  }

  void _navigateToProfileDetail(PartnerProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnerProfileDetailPage(profile: profile),
      ),
    ).then((_) => _loadProfiles());
  }

  @override
  Widget buildContent(BuildContext context) {
    return buildBody(context);
  }

  @override
  Widget buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredProfiles.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildProfileList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: '搜索对话人姓名...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无对话人档案',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 按钮创建',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredProfiles.length,
      itemBuilder: (context, index) {
        final profile = _filteredProfiles[index];
        return _buildProfileCard(profile);
      },
    );
  }

  Widget _buildProfileCard(PartnerProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToProfileDetail(profile),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getAvatarColor(profile.name),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    profile.name.isNotEmpty ? profile.name[0] : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (profile.age != null || profile.gender != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            profile.ageGenderDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getRelationshipIcon(profile.relationship),
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.fullRelationship,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (profile.personalityTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: profile.personalityTags
                            .take(3)
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 箭头图标
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[name.hashCode % colors.length];
  }

  IconData _getRelationshipIcon(String relationship) {
    switch (relationship) {
      case '家人':
        return Icons.family_restroom;
      case '朋友':
        return Icons.people;
      case '同事':
        return Icons.work;
      case '医生':
        return Icons.medical_services;
      default:
        return Icons.person;
    }
  }

  @override
  Widget? buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: _showCreateProfileDialog,
      child: const Icon(Icons.add),
      tooltip: '新建档案',
    );
  }
}