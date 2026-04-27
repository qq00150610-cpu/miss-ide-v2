import 'dart:io';
import 'dart:convert';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 最近文件管理器
class RecentFiles {
  static final RecentFiles _instance = RecentFiles._internal();
  factory RecentFiles() => _instance;
  RecentFiles._internal();

  final List<RecentFile> _files = [];
  final int _maxCount = AppConstants.maxOpenFiles;

  /// 获取最近文件列表
  List<RecentFile> get files => List.unmodifiable(_files);

  /// 添加文件
  void addFile(String path, {String? projectId}) {
    // 移除已存在的
    _files.removeWhere((f) => f.path == path);

    // 添加到开头
    _files.insert(0, RecentFile(
      path: path,
      name: path.split('/').last,
      projectId: projectId,
      openedAt: DateTime.now(),
    ));

    // 限制数量
    while (_files.length > _maxCount) {
      _files.removeLast();
    }

    _saveToStorage();
    logger.i(LogTags.fileManager, 'Added to recent files: $path');
  }

  /// 移除文件
  void removeFile(String path) {
    _files.removeWhere((f) => f.path == path);
    _saveToStorage();
  }

  /// 清除所有
  void clear() {
    _files.clear();
    _saveToStorage();
    logger.i(LogTags.fileManager, 'Recent files cleared');
  }

  /// 加载
  Future<void> load() async {
    try {
      final file = File(_storagePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List;
        _files.clear();
        for (final item in json) {
          _files.add(RecentFile.fromJson(item as Map<String, dynamic>));
        }
      }
      logger.i(LogTags.fileManager, 'Loaded ${_files.length} recent files');
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to load recent files', error: e);
    }
  }

  /// 保存
  Future<void> _saveToStorage() async {
    try {
      final json = _files.map((f) => f.toJson()).toList();
      final file = File(_storagePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to save recent files', error: e);
    }
  }

  String get _storagePath {
    // 需要根据实际存储路径
    return '${Directory.current.path}/recent_files.json';
  }
}

/// 最近文件
class RecentFile {
  final String path;
  final String name;
  final String? projectId;
  final DateTime openedAt;

  const RecentFile({
    required this.path,
    required this.name,
    this.projectId,
    required this.openedAt,
  });

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String get languageDisplay {
    final lang = ProgrammingLanguage.fromExtension(extension);
    return lang.displayName;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'projectId': projectId,
      'openedAt': openedAt.toIso8601String(),
    };
  }

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      path: json['path'] as String,
      name: json['name'] as String,
      projectId: json['projectId'] as String?,
      openedAt: DateTime.parse(json['openedAt'] as String),
    );
  }
}

/// 全局实例
final recentFiles = RecentFiles();
