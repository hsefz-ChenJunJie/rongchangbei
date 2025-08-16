import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class OnlineResource {
  final String id;
  final String packageName;
  final String fileName;
  final String description;
  final String url;
  final String? sha256;

  OnlineResource({
    required this.id,
    required this.packageName,
    required this.fileName,
    required this.description,
    required this.url,
    this.sha256,
  });

  factory OnlineResource.fromJson(Map<String, dynamic> json) {
    return OnlineResource(
      id: json['id'] ?? '',
      packageName: json['package_name'] ?? json['name'] ?? '未命名',
      fileName: json['file'] ?? '',
      description: json['description'] ?? '暂无描述',
      url: json['url'] ?? '',
      sha256: json['sha256'],
    );
  }
}

class DPDownloadManager {
  static const String _manifestUrl = 
    'https://raw.githubusercontent.com/ecjkropas/rongchangbei_project_dp_files/main/manifest.json';
  
  static const String _dpFolderName = 'dp'; // 改为与DPManager相同的目录
  final Dio _dio = Dio();

  // 获取在线资源列表
  Future<List<OnlineResource>> fetchOnlineResources() async {
    try {
      final response = await _dio.get(
        _manifestUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      
      // 解析JSON数据
      Map<String, dynamic> data;
      if (response.data is String) {
        // 如果响应是字符串，需要解析
        data = jsonDecode(response.data);
      } else if (response.data is Map) {
        // 如果响应已经是Map类型
        data = Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('无效的响应格式');
      }
      
      final resources = data['resources'] as List;
      return resources.map((json) => OnlineResource.fromJson(Map<String, dynamic>.from(json))).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('连接超时，请检查网络后重试');
      } else {
        debugPrint('获取在线资源失败: $e');
        throw Exception('无法获取在线资源: ${e.message}');
      }
    } catch (e) {
      debugPrint('获取在线资源失败: $e');
      throw Exception('无法获取在线资源: $e');
    }
  }

  // 下载对话包文件
  Future<File> downloadDialoguePackage(
    String url,
    String fileName, {
    String? expectedHash,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dpDirectory = Directory('${directory.path}/$_dpFolderName');
      
      // 确保目录存在
      if (!await dpDirectory.exists()) {
        await dpDirectory.create(recursive: true);
      }

      final filePath = '${dpDirectory.path}/$fileName';
      final file = File(filePath);

      // 如果文件已存在且校验通过，直接返回
      if (await file.exists()) {
        if (expectedHash == null || expectedHash.isEmpty) {
          return file;
        }
        
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        if (hash == expectedHash) {
          return file;
        }
      }

      // 下载文件
      await _dio.download(url, filePath);

      // 校验文件
      if (expectedHash != null && expectedHash.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        if (hash != expectedHash) {
          await file.delete();
          throw Exception('文件校验失败');
        }
      }

      return file;
    } catch (e) {
      debugPrint('下载失败: $e');
      throw Exception('下载失败: $e');
    }
  }

  // 获取已下载的在线对话包列表
  Future<List<String>> getDownloadedOnlinePackages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dpDirectory = Directory('${directory.path}/$_dpFolderName');
      
      if (!await dpDirectory.exists()) {
        return [];
      }

      final files = dpDirectory.listSync();
      return files
          .where((entity) => entity is File && entity.path.endsWith('.dp'))
          .map((entity) => entity.path.split('/').last)
          .toList();
    } catch (e) {
      debugPrint('获取已下载列表失败: $e');
      return [];
    }
  }

  // 检查特定文件是否已下载
  Future<bool> isDownloaded(String fileName) async {
    final downloaded = await getDownloadedOnlinePackages();
    return downloaded.contains(fileName);
  }

  // 删除已下载的在线对话包
  Future<void> deleteDownloadedPackage(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_dpFolderName/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('删除失败: $e');
      throw Exception('删除失败: $e');
    }
  }

  // 获取本地对话包文件路径
  Future<String?> getDownloadedFilePath(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_dpFolderName/$fileName';
      final file = File(filePath);
      
      return await file.exists() ? filePath : null;
    } catch (e) {
      debugPrint('获取文件路径失败: $e');
      return null;
    }
  }
}